import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../models/application.dart';
import '../models/document.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/applications_service.dart';
import '../services/documents_service.dart';
import '../widgets/bottom_nav_bar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  bool _isSaving = false;

  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _cityController = TextEditingController();
  String? _selectedAvailability;
  String? _selectedJobType;

  int _docsCount = 0;
  int _docsTotal = 0;
  int _appsActive = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final api = context.read<ApiService>();
      final documentsService = DocumentsService(api);
      final applicationsService = ApplicationsService(api);
      final results = await Future.wait([
        api.get('/candidates/me'),
        documentsService.getDocumentTypes(),
        documentsService.getMyDocuments(),
        applicationsService.getMyApplications(),
      ]);
      final response = results[0] as Map<String, dynamic>;
      final types = results[1] as List<DocumentType>;
      final docs = results[2] as List<CandidateDocument>;
      final applications = results[3] as List<Application>;
      final completedDocumentTypes = docs
          .where(
            (doc) => doc.status == 'uploaded' || doc.status == 'approved',
          )
          .map((doc) => doc.type)
          .toSet();
      final validTypeIds = types.map((type) => type.id).toSet();
      final activeApplications = applications.where((application) {
        switch (application.status) {
          case 'applied':
          case 'reviewing':
          case 'preselected':
          case 'interview_scheduled':
          case 'interview_confirmed':
            return true;
          default:
            return false;
        }
      }).length;

      if (mounted) {
        setState(() {
          _profile = response;
          _phoneController.text = _profile?['phone'] ?? '';
          _emailController.text = _profile?['user']?['email'] ?? '';
          _cityController.text = _profile?['city'] ?? '';
          _selectedAvailability = _profile?['availability'];
          _selectedJobType = _profile?['desiredJobType'];
          _docsTotal = types.length;
          _docsCount = completedDocumentTypes
              .where(validTypeIds.contains)
              .length;
          _appsActive = activeApplications;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al cargar perfil: $e')));
      }
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);

    try {
      final api = context.read<ApiService>();
      await api.patch('/candidates/me', {
        'phone': _phoneController.text,
        'email': _emailController.text,
        'city': _cityController.text,
        'availability': _selectedAvailability,
        'desiredJobType': _selectedJobType,
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Cambios guardados')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  int get _profileCompletion {
    int score = 0;
    if (_profile?['fullName'] != null &&
        (_profile!['fullName'] as String).isNotEmpty)
      score += 20;
    if (_phoneController.text.isNotEmpty) score += 20;
    if (_cityController.text.isNotEmpty) score += 20;
    if (_selectedJobType != null && _selectedJobType!.isNotEmpty) score += 20;
    if (_selectedAvailability != null && _selectedAvailability!.isNotEmpty)
      score += 20;
    return score;
  }

  String _getJobTypeLabel(String? type) {
    if (type == null || type.isEmpty) return 'Sin especificar';
    const labels = {
      'security': 'Guardia de seguridad',
      'cleaning': 'Auxiliar de limpieza',
      'warehouse': 'Bodeguero',
      'reception': 'Recepcionista',
      'other': 'Otro',
    };
    return labels[type] ?? type;
  }

  String _getAvailabilityLabel(String? availability) {
    if (availability == null || availability.isEmpty) return 'Inmediata';
    const labels = {
      'immediate': 'Inmediata',
      '1_week': 'En 1 semana',
      '2_weeks': 'En 2 semanas',
      '1_month': 'En 1 mes',
    };
    return labels[availability] ?? availability;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _buildHeader(),
                  Expanded(child: _buildContent()),
                ],
              ),
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 3),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Empleo',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, size: 26),
            color: AppColors.textPrimary,
            onPressed: () async {
              await context.read<AuthProvider>().logout();
              if (context.mounted) {
                context.go('/welcome');
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mi perfil',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontSize: 26,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Edita tus datos en la misma vista y revisa tu progreso.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          _buildProfileCard(),
          const SizedBox(height: 16),
          _buildProgressCard(),
          const SizedBox(height: 16),
          _buildEditableFieldsCard(),
          const SizedBox(height: 16),
          _buildNavigationCard(),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveChanges,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Guardar cambios'),
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 38,
                backgroundColor: AppColors.primarySoft,
                child: Icon(Icons.person, size: 42, color: AppColors.primary),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _profile?['fullName'] ?? 'Usuario',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _cityController.text.isEmpty
                            ? 'Nicaragua'
                            : _cityController.text,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.phone_outlined,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _phoneController.text.isEmpty
                            ? 'Sin teléfono'
                            : _phoneController.text,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Progreso de perfil',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '$_profileCompletion%',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _profileCompletion / 100,
              minHeight: 8,
              backgroundColor: AppColors.borderSoft,
              valueColor: const AlwaysStoppedAnimation(AppColors.success),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _profileCompletion < 100
                ? '¡Vas muy bien! Completa tu perfil al 100%.'
                : '¡Perfil completo!',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableFieldsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _buildEditableRow(
            'Trabajo que buscas',
            _getJobTypeLabel(_selectedJobType),
            onEdit: _showJobTypeSelector,
          ),
          _divider(),
          _buildEditableRow(
            'Disponibilidad',
            _getAvailabilityLabel(_selectedAvailability),
            onEdit: _showAvailabilitySelector,
          ),
          _divider(),
          _buildEditableRow(
            'Teléfono',
            _phoneController.text.isEmpty
                ? 'Sin especificar'
                : _phoneController.text,
            onEdit: () => _showEditDialog('Teléfono', _phoneController),
          ),
          _divider(),
          _buildEditableRow(
            'Correo electrónico',
            _emailController.text.isEmpty
                ? 'Sin especificar'
                : _emailController.text,
            onEdit: () =>
                _showEditDialog('Correo electrónico', _emailController),
          ),
          _divider(),
          _buildEditableRow(
            'Ciudad',
            _cityController.text.isEmpty
                ? 'Sin especificar'
                : _cityController.text,
            onEdit: () => _showEditDialog('Ciudad', _cityController),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _buildNavigationRow(
            icon: Icons.description_outlined,
            label: 'Mis documentos',
            subtitle: '$_docsCount de $_docsTotal completos',
            onTap: () => context.go('/documents'),
          ),
          _divider(),
          _buildNavigationRow(
            icon: Icons.assignment_outlined,
            label: 'Mis postulaciones',
            subtitle: '$_appsActive activas',
            onTap: () => context.go('/applications'),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Divider(height: 1, thickness: 1, color: AppColors.borderSoft);
  }

  Widget _buildEditableRow(
    String label,
    String value, {
    required VoidCallback onEdit,
  }) {
    return InkWell(
      onTap: onEdit,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationRow({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 20, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  void _showJobTypeSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Trabajo que buscas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...['security', 'cleaning', 'warehouse', 'reception', 'other'].map((
              type,
            ) {
              const labels = {
                'security': 'Guardia de seguridad',
                'cleaning': 'Auxiliar de limpieza',
                'warehouse': 'Bodeguero',
                'reception': 'Recepcionista',
                'other': 'Otro',
              };
              return ListTile(
                title: Text(labels[type] ?? type),
                trailing: _selectedJobType == type
                    ? Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  setState(() => _selectedJobType = type);
                  Navigator.pop(context);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showAvailabilitySelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Disponibilidad',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...['immediate', '1_week', '2_weeks', '1_month'].map((avail) {
              const labels = {
                'immediate': 'Inmediata',
                '1_week': 'En 1 semana',
                '2_weeks': 'En 2 semanas',
                '1_month': 'En 1 mes',
              };
              return ListTile(
                title: Text(labels[avail] ?? avail),
                trailing: _selectedAvailability == avail
                    ? Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  setState(() => _selectedAvailability = avail);
                  Navigator.pop(context);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(String field, TextEditingController controller) {
    final editController = TextEditingController(text: controller.text);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Editar $field'),
        content: TextField(
          controller: editController,
          decoration: InputDecoration(
            labelText: field,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => controller.text = editController.text);
              Navigator.pop(context);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}
