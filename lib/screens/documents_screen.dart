import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
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
      
      final types = await documentsService.getDocumentTypes();
      final docs = await documentsService.getMyDocuments();
      
      if (mounted) {
        setState(() {
          _documentTypes = types;
          _myDocuments = docs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar documentos: $e')),
        );
      }
    }
  }

  CandidateDocument? _getDocumentForType(String typeId) {
    try {
      return _myDocuments.firstWhere((d) => d.type == typeId);
    } catch (_) {
      return null;
    }
  }

  void _showUploadOptions(DocumentType type) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Subir ${type.label}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.camera_alt, color: AppColors.primary),
              ),
              title: const Text('Tomar foto'),
              subtitle: const Text('Usa la cámara para capturar el documento'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUpload(type, ImageSource.camera);
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.upload_file, color: AppColors.primary),
              ),
              title: const Text('Subir archivo'),
              subtitle: const Text('Selecciona un PDF, JPG o PNG'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUpload(type, ImageSource.gallery);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUpload(DocumentType type, ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 2000,
      );
      if (picked == null) return;

      final file = await http.MultipartFile.fromPath('file', picked.path, filename: picked.name);
      final api = context.read<ApiService>();
      final documentsService = DocumentsService(api);
      await documentsService.upload(type: type.id, file: file, replace: true);
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Documento enviado (${source == ImageSource.camera ? 'foto' : 'archivo'})')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir documento: $e')),
        );
      }
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
            'Sube solo lo necesario',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          
          const SizedBox(height: 24),
          
          ..._documentTypes.map((type) {
            final doc = _getDocumentForType(type.id);
            return _DocumentCard(
              type: type,
              document: doc,
              onTap: () => _showUploadOptions(type),
            );
          }),
          
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _documentTypes.isNotEmpty
                      ? () => _showUploadOptions(_documentTypes.first)
                      : null,
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Tomar foto'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _documentTypes.isNotEmpty
                      ? () => _showUploadOptions(_documentTypes.first)
                      : null,
                  icon: const Icon(Icons.upload_file_outlined),
                  label: const Text('Subir archivo'),
                ),
              ),
            ],
          ),

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
    this.document,
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
    
    return Container(
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
          GestureDetector(
            onTap: hasDocument ? () => _showPreview(document!.fileUrl!) : null,
            child: Container(
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
                color: hasDocument ? AppColors.primary : AppColors.textSecondary,
                size: 28,
              ),
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                  hasDocument 
                      ? 'Subido el ${_formatDate(document!.uploadedAt)}'
                      : 'Toma una foto clara',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Icon(Icons.chevron_right, color: AppColors.textSecondary),
              TextButton(
                onPressed: onTap,
                child: Text(hasDocument ? 'Reemplazar' : 'Subir'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    final localDate = date.toLocal();
    return '${localDate.day}/${localDate.month}/${localDate.year}';
  }

  Future<void> _showPreview(String fileUrl) async {
    try {
      final uri = Uri.parse(fileUrl);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        throw Exception('No se pudo abrir el documento');
      }
    } catch (e) {
      throw Exception('Error al abrir documento: $e');
    }
  }
}
