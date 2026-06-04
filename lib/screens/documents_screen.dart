import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/theme.dart';
import '../models/document.dart';
import '../services/api_service.dart';
import '../services/documents_service.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  List<DocumentType> _documentTypes = [];
  List<CandidateDocument> _myDocuments = [];
  bool _isLoading = true;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final api = context.read<ApiService>();
      final documentsService = DocumentsService(api);
      final results = await Future.wait([
        documentsService.getDocumentTypes(),
        documentsService.getMyDocuments(),
      ]);
      final types = results[0] as List<DocumentType>;
      final docs = results[1] as List<CandidateDocument>;

      if (!mounted) return;

      setState(() {
        _documentTypes = types;
        _myDocuments = docs;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al cargar documentos: $e')));
    }
  }

  CandidateDocument? _getDocumentForType(String typeId) {
    try {
      return _myDocuments.firstWhere((document) => document.type == typeId);
    } catch (_) {
      return null;
    }
  }

  void _showDocumentActions(DocumentType type) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: 24 + MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: _DocumentActionsSheet(
          type: type,
          document: _getDocumentForType(type.id),
          onTakePhoto: () {
            Navigator.pop(sheetContext);
            _pickAndUploadFromCamera(type);
          },
          onUploadFile: () {
            Navigator.pop(sheetContext);
            _pickAndUploadFile(type);
          },
          onCreateCv: type.id == 'cv'
              ? () {
                  Navigator.pop(sheetContext);
                  context.push('/documents/cv-builder');
                }
              : null,
        ),
      ),
    );
  }

  Future<void> _pickAndUploadFromCamera(DocumentType type) async {
    try {
      final documentsService = DocumentsService(context.read<ApiService>());
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 2000,
      );
      if (picked == null) return;

      final file = await http.MultipartFile.fromPath(
        'file',
        picked.path,
        filename: picked.name,
      );
      await documentsService.upload(type: type.id, file: file, replace: true);
      await _loadData();

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${type.label} cargado con foto')));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al subir documento: $e')));
    }
  }

  Future<void> _pickAndUploadFile(DocumentType type) async {
    try {
      final documentsService = DocumentsService(context.read<ApiService>());
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );
      final file = result?.files.singleOrNull;
      if (file == null) return;

      if (file.bytes != null) {
        await documentsService.uploadBytes(
          type: type.id,
          bytes: file.bytes!,
          filename: file.name,
          replace: true,
        );
      } else if (file.path != null) {
        final multipartFile = await http.MultipartFile.fromPath(
          'file',
          file.path!,
          filename: file.name,
        );
        await documentsService.upload(
          type: type.id,
          file: multipartFile,
          replace: true,
        );
      } else {
        throw Exception('No se pudo leer el archivo seleccionado');
      }

      await _loadData();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${type.label} cargado correctamente')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al subir documento: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (Navigator.of(context).canPop()) {
          context.pop();
        } else {
          context.go('/home');
        }
        return false;
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                context.pop();
              } else {
                context.go('/home');
              }
            },
          ),
          title: const Text('Empleo'),
          centerTitle: true,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildContent(),
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tus documentos',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Toca un documento para ver sus opciones.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          ..._documentTypes.map((type) {
            return _DocumentCard(
              type: type,
              document: _getDocumentForType(type.id),
              onTap: () => _showDocumentActions(type),
            );
          }),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.shield_outlined, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tus documentos están protegidos',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Usamos seguridad avanzada para cuidar tu información personal.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
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
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () => context.go('/profile'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Volver al perfil'),
          ),
        ),
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  final DocumentType type;
  final CandidateDocument? document;
  final VoidCallback onTap;

  const _DocumentCard({
    required this.type,
    required this.document,
    required this.onTap,
  });

  Color _getStatusColor() {
    if (document == null) return const Color(0xFFFFA000);

    switch (document!.status) {
      case 'approved':
        return AppColors.success;
      case 'rejected':
        return AppColors.error;
      case 'uploaded':
        return AppColors.primary;
      default:
        return const Color(0xFFFFA000);
    }
  }

  String _getStatusLabel() {
    if (document == null) return 'Pendiente';
    return document!.statusLabel;
  }

  @override
  Widget build(BuildContext context) {
    final hasDocument = document != null && document!.fileUrl != null;
    final subtitle = hasDocument
        ? 'Subido el ${_formatDate(document!.uploadedAt)}'
        : type.id == 'cv'
        ? 'Puedes subirlo o generarlo desde plantilla'
        : 'Toca para elegir cómo subirlo';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: hasDocument
                    ? AppColors.primary.withOpacity(0.1)
                    : AppColors.border.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                hasDocument ? Icons.description : Icons.add_photo_alternate,
                color: hasDocument
                    ? AppColors.primary
                    : AppColors.textSecondary,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          type.label,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor().withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          _getStatusLabel(),
                          style: TextStyle(
                            fontSize: 12.5,
                            color: _getStatusColor(),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    final localDate = date.toLocal();
    return '${localDate.day}/${localDate.month}/${localDate.year}';
  }
}

class _DocumentActionsSheet extends StatelessWidget {
  final DocumentType type;
  final CandidateDocument? document;
  final VoidCallback onTakePhoto;
  final VoidCallback onUploadFile;
  final VoidCallback? onCreateCv;

  const _DocumentActionsSheet({
    required this.type,
    required this.document,
    required this.onTakePhoto,
    required this.onUploadFile,
    this.onCreateCv,
  });

  @override
  Widget build(BuildContext context) {
    final hasDocument = document != null && document!.fileUrl != null;
    final statusLabel = document == null ? 'Pendiente' : document!.statusLabel;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.borderSoft,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          type.label,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          hasDocument
              ? 'Estado actual: $statusLabel'
              : 'Elige cómo quieres cargar este documento.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        if (hasDocument && document!.fileUrl != null) ...[
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => _openPreview(document!.fileUrl!),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Abrir documento actual'),
          ),
        ],
        if (type.id == 'cv' && onCreateCv != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              'También puedes generar tu CV desde una plantilla y subirlo automáticamente.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.4),
            ),
          ),
        ],
        const SizedBox(height: 20),
        _ActionTile(
          icon: Icons.camera_alt_outlined,
          title: hasDocument ? 'Tomar foto nueva' : 'Tomar foto',
          subtitle: 'Usa la cámara para capturar el documento',
          onTap: onTakePhoto,
        ),
        const SizedBox(height: 10),
        _ActionTile(
          icon: Icons.upload_file_outlined,
          title: hasDocument ? 'Subir archivo nuevo' : 'Subir archivo',
          subtitle: 'Selecciona PDF, JPG o PNG',
          onTap: onUploadFile,
        ),
        if (onCreateCv != null) ...[
          const SizedBox(height: 10),
          _ActionTile(
            icon: Icons.description_outlined,
            title: 'Crear mi CV',
            subtitle: 'Llena tus datos y genera un PDF con plantilla',
            onTap: onCreateCv!,
          ),
        ],
      ],
    );
  }

  Future<void> _openPreview(String fileUrl) async {
    final uri = Uri.parse(fileUrl);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      throw Exception('No se pudo abrir el documento');
    }
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
