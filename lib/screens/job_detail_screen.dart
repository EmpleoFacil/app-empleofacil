import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../models/job.dart';
import '../services/api_service.dart';
import '../services/applications_service.dart';
import '../services/saved_jobs_service.dart';
import '../services/documents_service.dart';
import '../models/document.dart';
import '../widgets/company_logo_avatar.dart';

class JobDetailScreen extends StatefulWidget {
  final String jobId;

  const JobDetailScreen({super.key, required this.jobId});

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  Job? _job;
  bool _isLoading = true;
  bool _isSaved = false;
  bool _hasApplied = false;
  bool _isApplying = false;

  bool _handleBack() {
    if (Navigator.of(context).canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _loadJob();
  }

  Future<void> _loadJob() async {
    try {
      final api = context.read<ApiService>();
      final applicationsService = ApplicationsService(api);
      final results = await Future.wait([
        api.get('/jobs/${widget.jobId}'),
        applicationsService.getByJobForMe(widget.jobId),
      ]);
      final job = Job.fromJson(results[0]);
      final myApplication = results[1];

      if (mounted) {
        setState(() {
          _job = job;
          _isSaved = job.isSaved;
          _hasApplied = myApplication != null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al cargar vacante: $e')));
      }
    }
  }

  Future<void> _toggleSave() async {
    try {
      final api = context.read<ApiService>();
      final savedJobsService = SavedJobsService(api);

      if (_isSaved) {
        await savedJobsService.unsave(widget.jobId);
      } else {
        await savedJobsService.save(widget.jobId);
      }

      if (mounted) setState(() => _isSaved = !_isSaved);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _apply() async {
    setState(() => _isApplying = true);

    try {
      final api = context.read<ApiService>();

      // Check for required documents
      final documentsService = DocumentsService(api);
      final results = await Future.wait([
        documentsService.getMyDocuments(),
        documentsService.getDocumentTypes(),
      ]);
      final myDocuments = results[0] as List<CandidateDocument>;
      final documentTypes = results[1] as List<DocumentType>;

      final requiredTypes = documentTypes.where((type) => type.isRequired);
      final missingDocuments = requiredTypes.where((type) {
        return !myDocuments.any(
          (doc) =>
              doc.type == type.id &&
              (doc.status == 'uploaded' || doc.status == 'approved'),
        );
      }).toList();

      if (missingDocuments.isNotEmpty) {
        if (mounted) {
          setState(() => _isApplying = false);
          _showMissingDocumentsDialog(missingDocuments);
        }
        return;
      }

      final applicationsService = ApplicationsService(api);
      await applicationsService.apply(widget.jobId);

      if (mounted) {
        setState(() {
          _hasApplied = true;
          _isApplying = false;
        });
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isApplying = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al postularte: $e')));
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check, color: AppColors.success, size: 48),
            ),
            const SizedBox(height: 16),
            const Text(
              '¡Postulación enviada!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Tu postulación ha sido enviada correctamente.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/applications');
            },
            child: const Text('Ver mis postulaciones'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
  }

  void _showMissingDocumentsDialog(List<DocumentType> missingDocuments) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFA000).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning,
                color: Color(0xFFFFA000),
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Documentos faltantes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Para postularte necesitas subir los siguientes documentos:',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            ...missingDocuments.map(
              (doc) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.circle, size: 8, color: Color(0xFFFFA000)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        doc.label,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/documents');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Subir documentos'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => _handleBack(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBack,
          ),
          title: const Text('Empleo'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(
                _isSaved ? Icons.bookmark : Icons.bookmark_border,
                color: _isSaved ? AppColors.primary : null,
              ),
              onPressed: _toggleSave,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _job == null
            ? const Center(child: Text('Vacante no encontrada'))
            : _buildContent(),
        bottomNavigationBar: _job != null ? _buildBottomBar() : null,
      ),
    );
  }

  Widget _buildContent() {
    final job = _job!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con logo e info
          Center(
            child: Column(
              children: [
                CompanyLogoAvatar(
                  logoUrl: job.company?.logoUrl,
                  companyName: job.company?.name ?? 'Empresa',
                  size: 80,
                  borderRadius: 16,
                  fallbackIcon: Icons.shield,
                  iconSize: 40,
                ),
                const SizedBox(height: 16),
                Text(
                  job.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  job.company?.name ?? '',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      job.city ?? 'Nicaragua',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      job.salaryRange,
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Tags
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildTag(
                Icons.access_time,
                job.employmentType ?? 'Tiempo completo',
              ),
              const SizedBox(width: 8),
              _buildTag(Icons.schedule, job.modality ?? 'Turnos rotativos'),
            ],
          ),

          const SizedBox(height: 24),

          // Lo principal
          const Text(
            'Lo principal',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          _buildBullet('Ingreso inmediato'),
          _buildBullet('Pago puntual'),
          _buildBullet('Con o sin experiencia'),

          const SizedBox(height: 24),

          // Qué harás
          const Text(
            'Qué harás',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Text(
            job.description ??
                'Vigilar y proteger las instalaciones, controlar accesos y registrar novedades. Asegurar el cumplimiento de normas de seguridad.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.5),
          ),

          const SizedBox(height: 24),

          // Nota documentos
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Antes de postularte, asegúrate de tener tus documentos listos.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildTag(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _hasApplied ? null : (_isApplying ? null : _apply),
                icon: _isApplying
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(_hasApplied ? Icons.check : Icons.send),
                label: Text(_hasApplied ? 'Ya aplicaste' : 'Postularme'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _hasApplied
                      ? AppColors.success
                      : AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _toggleSave,
                icon: Icon(_isSaved ? Icons.bookmark : Icons.bookmark_border),
                label: Text(_isSaved ? 'Guardada' : 'Guardar'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
