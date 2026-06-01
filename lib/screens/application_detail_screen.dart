import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/theme.dart';
import '../models/application.dart';
import '../services/api_service.dart';
import '../widgets/bottom_nav_bar.dart';

class ApplicationDetailScreen extends StatefulWidget {
  final String applicationId;

  const ApplicationDetailScreen({super.key, required this.applicationId});

  @override
  State<ApplicationDetailScreen> createState() => _ApplicationDetailScreenState();
}

class _ApplicationDetailScreenState extends State<ApplicationDetailScreen> {
  Application? _application;
  Map<String, dynamic>? _interview;
  bool _isLoading = true;
  bool _isConfirming = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final api = context.read<ApiService>();
      final rawResponse = await api.get('/applications/${widget.applicationId}');
      final rawApp = rawResponse as Map<String, dynamic>;
      final application = Application.fromJson(rawApp);
      final interview = await _resolveInterview(api, rawApp, application);

      if (mounted) {
        setState(() {
          _application = application;
          _interview = interview;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar detalle: $e')),
        );
      }
    }
  }

  Future<Map<String, dynamic>?> _resolveInterview(
    ApiService api,
    Map<String, dynamic> rawApp,
    Application application,
  ) async {
    final embedded = _extractEmbeddedInterview(rawApp);
    final interviewId = _extractInterviewId(rawApp, application, embedded);

    if (interviewId != null) {
      try {
        final response = await api.get('/interviews/$interviewId');
        return response as Map<String, dynamic>;
      } catch (_) {
        if (embedded != null) return embedded;
      }
    }

    if (_isInterviewStatus(application.status)) {
      try {
        final response = await api.get('/interviews/me');
        if (response is List) {
          for (final item in response) {
            if (item is! Map<String, dynamic>) continue;
            final appId = item['applicationId'] ?? item['application']?['id'];
            if (appId == application.id) {
              final id = item['id'] as String?;
              if (id != null) {
                try {
                  final detail = await api.get('/interviews/$id');
                  return detail as Map<String, dynamic>;
                } catch (_) {
                  return item;
                }
              }
              return item;
            }
          }
        }
      } catch (_) {}
    }

    if (embedded != null) return embedded;

    if (application.nextInterview != null) {
      return _interviewFromModel(application.nextInterview!);
    }

    return null;
  }

  Map<String, dynamic>? _extractEmbeddedInterview(Map<String, dynamic> rawApp) {
    final nextInterview = rawApp['nextInterview'];
    if (nextInterview is Map<String, dynamic>) {
      return Map<String, dynamic>.from(nextInterview);
    }

    final interview = rawApp['interview'];
    if (interview is Map<String, dynamic>) {
      return Map<String, dynamic>.from(interview);
    }

    final interviews = rawApp['interviews'];
    if (interviews is List && interviews.isNotEmpty && interviews.first is Map) {
      return Map<String, dynamic>.from(interviews.first as Map);
    }

    return null;
  }

  String? _extractInterviewId(
    Map<String, dynamic> rawApp,
    Application application,
    Map<String, dynamic>? embedded,
  ) {
    final fromEmbedded = embedded?['id'];
    if (fromEmbedded != null && fromEmbedded.toString().isNotEmpty) {
      return fromEmbedded.toString();
    }

    final interviewId = rawApp['interviewId'];
    if (interviewId != null && interviewId.toString().isNotEmpty) {
      return interviewId.toString();
    }

    return application.nextInterview?.id;
  }

  Map<String, dynamic> _interviewFromModel(Interview interview) {
    return {
      'id': interview.id,
      'date': interview.date.toIso8601String(),
      'modality': interview.modality,
      'location': interview.location,
      'meetingUrl': interview.meetingUrl,
      'status': interview.status,
    };
  }

  bool _isInterviewStatus(String status) {
    return status == 'interview_scheduled' ||
        status == 'interview_confirmed' ||
        status == 'preselected';
  }

  bool _shouldShowInterviewSection(Application app) {
    return _interview != null || _isInterviewStatus(app.status);
  }

  String? get _interviewId {
    final id = _interview?['id'];
    if (id != null && id.toString().isNotEmpty) return id.toString();
    return _application?.nextInterview?.id;
  }

  String? _interviewDateRaw() {
    final date = _interview?['date'];
    if (date is String && date.isNotEmpty) return date;
    if (date is DateTime) return date.toIso8601String();
    return _application?.nextInterview?.date.toIso8601String();
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/applications');
    }
  }

  Future<void> _confirmAttendance() async {
    final interviewId = _interviewId;
    if (interviewId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entrevista no disponible para confirmar')),
      );
      return;
    }

    setState(() => _isConfirming = true);

    try {
      final api = context.read<ApiService>();
      await api.patch('/interviews/$interviewId/confirm', {});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Asistencia confirmada')),
        );
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isConfirming = false);
    }
  }

  void _showRescheduleModal() {
    final interviewId = _interviewId;
    if (interviewId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entrevista no disponible para reprogramar')),
      );
      return;
    }

    final reasonController = TextEditingController();
    DateTime? selectedDate;
    TimeOfDay? selectedTime;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Solicitar cambio de fecha',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Motivo',
                  hintText: 'Explica por qué necesitas cambiar la fecha',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_outlined),
                title: Text(
                  selectedDate == null
                      ? 'Seleccionar fecha'
                      : _formatDate(selectedDate!.toIso8601String()),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 1)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setModalState(() => selectedDate = picked);
                  }
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.access_time),
                title: Text(
                  selectedTime == null
                      ? 'Seleccionar hora'
                      : selectedTime!.format(context),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (picked != null) {
                    setModalState(() => selectedTime = picked);
                  }
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () async {
                    if (reasonController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Ingresa un motivo')),
                      );
                      return;
                    }
                    if (selectedDate == null || selectedTime == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Selecciona fecha y hora')),
                      );
                      return;
                    }

                    try {
                      final api = context.read<ApiService>();
                      final requestedDate = DateTime(
                        selectedDate!.year,
                        selectedDate!.month,
                        selectedDate!.day,
                        selectedTime!.hour,
                        selectedTime!.minute,
                      );
                      await api.patch('/interviews/$interviewId/reschedule-request', {
                        'reason': reasonController.text,
                        'requestedDate': requestedDate.toIso8601String(),
                      });

                      if (mounted) {
                        Navigator.pop(modalContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Solicitud enviada')),
                        );
                        await _loadData();
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  },
                  child: const Text('Enviar solicitud'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openMaps() async {
    final mapUrl = _interview?['mapUrl'] as String?;
    final meetingUrl = _interview?['meetingUrl'] as String?;
    final modality = (_interview?['modality'] as String? ?? _application?.nextInterview?.modality)?.toLowerCase();

    try {
      if (mapUrl != null && mapUrl.isNotEmpty) {
        final uri = Uri.parse(mapUrl);
        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!ok && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo abrir Maps')),
          );
        }
        return;
      }

      if ((modality == 'online' || modality == 'virtual') &&
          meetingUrl != null &&
          meetingUrl.isNotEmpty) {
        final uri = Uri.parse(meetingUrl);
        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!ok && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo abrir el enlace de la reunión')),
          );
        }
        return;
      }

      final location = _interviewLocationName();
      if (location.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ubicación no disponible')),
          );
        }
        return;
      }

      final encoded = Uri.encodeComponent(location);
      final webUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encoded');
      final ok = await launchUrl(webUri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir Maps')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al abrir ubicación: $e')),
        );
      }
    }
  }

  String _interviewLocationName() {
    final fromInterview = (_interview?['location'] ??
            _interview?['locationName'] ??
            _interview?['place'] ??
            '') as String;
    if (fromInterview.isNotEmpty) return fromInterview;
    return _application?.nextInterview?.location ?? '';
  }

  String _interviewAddress() {
    return (_interview?['address'] ??
            _interview?['locationAddress'] ??
            _interview?['fullAddress'] ??
            '') as String;
  }

  String _interviewerName() {
    final direct = _interview?['interviewerName'] ??
        _interview?['interviewer'] ??
        _interview?['interviewerFullName'];
    if (direct != null && direct.toString().isNotEmpty) return direct.toString();

    final user = _interview?['responsibleUser'];
    if (user is Map && user['fullName'] != null) {
      return user['fullName'].toString();
    }
    return 'Por confirmar';
  }

  String _contactPhone() {
    return (_interview?['contactPhone'] ??
            _interview?['contactPhoneNumber'] ??
            _interview?['phone'] ??
            _interview?['notesForCandidate'] ??
            'Por confirmar') as String;
  }

  String _interviewModality() {
    final modality = _interview?['modality'] as String?;
    if (modality != null && modality.isNotEmpty) {
      return _formatModality(modality);
    }
    return _formatModality(_application?.nextInterview?.modality);
  }

  String _formatModality(String? modality) {
    if (modality == null || modality.isEmpty) return 'Presencial';
    switch (modality.toLowerCase()) {
      case 'in_person':
      case 'presencial':
        return 'Presencial';
      case 'online':
      case 'virtual':
        return 'Virtual';
      case 'hybrid':
        return 'Híbrida';
      default:
        return modality[0].toUpperCase() + modality.substring(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _application == null
                  ? const Center(child: Text('Postulación no encontrada'))
                  : _buildContent(),
        ),
        bottomNavigationBar: const BottomNavBar(currentIndex: 1),
      ),
    );
  }

  Widget _buildContent() {
    final app = _application!;
    final showInterviewSection = _shouldShowInterviewSection(app);
    final statusLabel = _isInterviewStatus(app.status)
        ? 'Entrevista programada'
        : app.statusLabel;
    final interviewDate = _interviewDateRaw();

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: _goBack,
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back, color: AppColors.primary, size: 22),
                const SizedBox(width: 4),
                Text(
                  'Empleo',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Detalle de postulación',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 26,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            showInterviewSection ? statusLabel : app.statusLabel,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.shield_outlined, color: AppColors.primary, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            app.job?.title ?? 'Vacante',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            app.job?.company?.name ?? '',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                app.job?.city ?? 'Nicaragua',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (showInterviewSection) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF8EF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_outlined, size: 18, color: AppColors.success),
                        const SizedBox(width: 8),
                        Text(
                          statusLabel,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    Icons.calendar_today_outlined,
                    'Fecha',
                    _formatDate(interviewDate),
                  ),
                  _buildDetailRow(
                    Icons.access_time,
                    'Hora',
                    _formatTime(interviewDate),
                  ),
                  _buildDetailRow(
                    Icons.location_on_outlined,
                    'Lugar',
                    _interviewLocationName().isEmpty ? 'Por confirmar' : _interviewLocationName(),
                    subtitle: _interviewAddress().isNotEmpty ? _interviewAddress() : null,
                  ),
                  _buildDetailRow(
                    Icons.work_outline,
                    'Modalidad',
                    _interviewModality(),
                  ),
                  _buildDetailRow(
                    Icons.account_circle_outlined,
                    'Entrevistador',
                    _interviewerName(),
                  ),
                  _buildDetailRow(
                    Icons.phone_outlined,
                    'Teléfono de contacto',
                    _contactPhone(),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isConfirming ? null : _confirmAttendance,
                      icon: _isConfirming
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_circle_outline, size: 20),
                      label: const Text('Confirmar asistencia'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: _showRescheduleModal,
                      icon: const Icon(Icons.edit_note_outlined, size: 20),
                      label: const Text('Solicitar cambio'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: _openMaps,
                      icon: const Icon(Icons.location_on_outlined, size: 20),
                      label: const Text('Ver ubicación'),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Estado actual: ${app.statusLabel}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textMedium,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value, {
    String? subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Por confirmar';
    final date = DateTime.parse(dateStr);
    const months = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
    ];
    return '${date.day} de ${months[date.month - 1]} de ${date.year}';
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return 'Por confirmar';
    final date = DateTime.parse(dateStr);
    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final period = date.hour >= 12 ? 'p.m.' : 'a.m.';
    return '${hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} $period';
  }
}
