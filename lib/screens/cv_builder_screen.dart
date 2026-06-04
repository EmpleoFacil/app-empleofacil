import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../services/api_service.dart';
import '../services/documents_service.dart';

class CvBuilderScreen extends StatefulWidget {
  const CvBuilderScreen({super.key});

  @override
  State<CvBuilderScreen> createState() => _CvBuilderScreenState();
}

class _CvBuilderScreenState extends State<CvBuilderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _summaryController = TextEditingController();
  final _experienceController = TextEditingController();
  final _educationController = TextEditingController();
  final _skillsController = TextEditingController();

  String _selectedTemplate = 'classic';
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _attachPreviewListeners();
    _loadProfile();
  }

  void _attachPreviewListeners() {
    for (final controller in [
      _fullNameController,
      _emailController,
      _phoneController,
      _cityController,
      _summaryController,
      _experienceController,
      _educationController,
      _skillsController,
    ]) {
      controller.addListener(_refreshPreview);
    }
  }

  void _refreshPreview() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final controller in [
      _fullNameController,
      _emailController,
      _phoneController,
      _cityController,
      _summaryController,
      _experienceController,
      _educationController,
      _skillsController,
    ]) {
      controller.removeListener(_refreshPreview);
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final api = context.read<ApiService>();
      final response = await api.get('/candidates/me') as Map<String, dynamic>;

      if (!mounted) return;

      setState(() {
        _fullNameController.text = response['fullName'] as String? ?? '';
        _emailController.text = response['user']?['email'] as String? ?? '';
        _phoneController.text = response['phone'] as String? ?? '';
        _cityController.text = response['city'] as String? ?? '';
        _summaryController.text =
            'Persona responsable, con disposiciÃƒÂ³n para trabajar y aprender rÃƒÂ¡pidamente.';
        _experienceController.text =
            'Guardia de seguridad en empresa privada.\nControl de accesos, rondas y registro de novedades.';
        _educationController.text =
            'Bachillerato completo.\nCursos bÃƒÂ¡sicos de atenciÃƒÂ³n al cliente y seguridad.';
        _skillsController.text =
            'Responsabilidad, puntualidad, trabajo en equipo, atenciÃƒÂ³n al detalle';
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  _CvData get _currentData => _CvData(
    fullName: _fullNameController.text.trim(),
    email: _emailController.text.trim(),
    phone: _phoneController.text.trim(),
    city: _cityController.text.trim(),
    summary: _summaryController.text.trim(),
    experience: _experienceController.text.trim(),
    education: _educationController.text.trim(),
    skills: _skillsController.text
        .split(',')
        .map((skill) => skill.trim())
        .where((skill) => skill.isNotEmpty)
        .toList(),
  );

  Future<void> _generateAndUploadCv() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final documentsService = DocumentsService(context.read<ApiService>());
      final pdf = pw.Document();
      final data = _currentData;

      pdf.addPage(
        pw.MultiPage(
          pageTheme: pw.PageTheme(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(28),
          ),
          build: (_) => _selectedTemplate == 'compact'
              ? _buildCompactTemplate(data)
              : _buildClassicTemplate(data),
        ),
      );

      final bytes = await pdf.save();
      final filename = _buildFilename(data.fullName);
      await documentsService.uploadBytes(
        type: 'cv',
        bytes: bytes,
        filename: filename,
        replace: true,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CV generado y subido correctamente')),
      );
      context.go('/documents');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al generar CV: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  List<pw.Widget> _buildClassicTemplate(_CvData data) {
    return [
      _pdfHeader(data, bordered: true),
      pw.SizedBox(height: 14),
      _pdfBox(
        title: 'OBJETIVO PROFESIONAL',
        child: pw.Text(
          data.summary,
          style: const pw.TextStyle(fontSize: 10.5, lineSpacing: 2.8),
        ),
      ),
      pw.SizedBox(height: 14),
      _pdfSplitBox(
        title: 'EXPERIENCIA',
        left: 'Reciente',
        right: data.experience.isEmpty
            ? 'Sin experiencia agregada.'
            : data.experience,
      ),
      pw.SizedBox(height: 14),
      _pdfSplitBox(
        title: 'EDUCACIÃƒâ€œN',
        left: 'FormaciÃƒÂ³n',
        right: data.education.isEmpty
            ? 'Sin educaciÃƒÂ³n agregada.'
            : data.education,
      ),
      pw.SizedBox(height: 14),
      _pdfBox(
        title: 'HABILIDADES',
        child: pw.Wrap(
          spacing: 6,
          runSpacing: 6,
          children: data.skills.isEmpty
              ? [
                  pw.Text(
                    'Sin habilidades agregadas.',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ]
              : data.skills
                    .map(
                      (skill) => pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(
                            color: PdfColors.grey600,
                            width: 0.6,
                          ),
                          borderRadius: pw.BorderRadius.circular(8),
                        ),
                        child: pw.Text(
                          skill,
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ),
                    )
                    .toList(),
        ),
      ),
    ];
  }

  List<pw.Widget> _buildCompactTemplate(_CvData data) {
    return [
      pw.Container(
        padding: const pw.EdgeInsets.all(18),
        decoration: pw.BoxDecoration(
          color: PdfColors.blue50,
          borderRadius: pw.BorderRadius.circular(12),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              data.fullName,
              style: pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(_joinMeta(data), style: const pw.TextStyle(fontSize: 10.5)),
          ],
        ),
      ),
      pw.SizedBox(height: 16),
      _pdfBox(
        title: 'RESUMEN',
        child: pw.Text(
          data.summary,
          style: const pw.TextStyle(fontSize: 10.5, lineSpacing: 2.8),
        ),
      ),
      pw.SizedBox(height: 12),
      _pdfBox(
        title: 'EXPERIENCIA',
        child: pw.Text(
          data.experience.isEmpty
              ? 'Sin experiencia agregada.'
              : data.experience,
          style: const pw.TextStyle(fontSize: 10.5, lineSpacing: 2.8),
        ),
      ),
      pw.SizedBox(height: 12),
      _pdfBox(
        title: 'EDUCACIÃƒâ€œN',
        child: pw.Text(
          data.education.isEmpty
              ? 'Sin educaciÃƒÂ³n agregada.'
              : data.education,
          style: const pw.TextStyle(fontSize: 10.5, lineSpacing: 2.8),
        ),
      ),
      pw.SizedBox(height: 12),
      _pdfBox(
        title: 'HABILIDADES',
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: data.skills.isEmpty
              ? [
                  pw.Text(
                    'Sin habilidades agregadas.',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ]
              : data.skills.map((skill) => pw.Bullet(text: skill)).toList(),
        ),
      ),
    ];
  }

  pw.Widget _pdfHeader(_CvData data, {bool bordered = false}) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(18),
      decoration: bordered
          ? pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey700, width: 0.8),
            )
          : null,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            data.fullName,
            style: pw.TextStyle(
              fontSize: 21,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey800,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(_joinMeta(data), style: const pw.TextStyle(fontSize: 10)),
          if (data.summary.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Text(
              data.summary.length > 90
                  ? '${data.summary.substring(0, 90)}...'
                  : data.summary,
              style: const pw.TextStyle(fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _pdfBox({required String title, required pw.Widget child}) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey700, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey800,
            ),
          ),
          pw.SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  pw.Widget _pdfSplitBox({
    required String title,
    required String left,
    required String right,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey700, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey800,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: 90,
                child: pw.Text(
                  left,
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey600,
                  ),
                ),
              ),
              pw.Expanded(
                child: pw.Text(
                  right,
                  style: const pw.TextStyle(fontSize: 10.5, lineSpacing: 2.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _joinMeta(_CvData data) {
    return [
      data.city,
      data.phone,
      data.email,
    ].where((item) => item.isNotEmpty).join(' Ã¢â‚¬Â¢ ');
  }

  String _buildFilename(String fullName) {
    final normalized = fullName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return 'cv_${normalized.isEmpty ? 'candidato' : normalized}.pdf';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Crear CV'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Genera tu currÃƒÂ­culum',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Llena tus datos, elige una plantilla y revisa la vista previa antes de subir el PDF.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildTemplateSelector(),
                    const SizedBox(height: 20),
                    _buildPreviewCard(),
                    const SizedBox(height: 20),
                    _buildField(
                      controller: _fullNameController,
                      label: 'Nombre completo',
                      validator: _required,
                    ),
                    _buildField(
                      controller: _emailController,
                      label: 'Correo electrÃƒÂ³nico',
                    ),
                    _buildField(
                      controller: _phoneController,
                      label: 'TelÃƒÂ©fono',
                      validator: _required,
                    ),
                    _buildField(controller: _cityController, label: 'Ciudad'),
                    _buildField(
                      controller: _summaryController,
                      label: 'Perfil profesional',
                      validator: _required,
                      maxLines: 4,
                    ),
                    _buildField(
                      controller: _experienceController,
                      label: 'Experiencia',
                      hint:
                          'Ej: Guardia de seguridad en Empresa XYZ (2024-2026). Control de accesos y rondas.',
                      maxLines: 5,
                    ),
                    _buildField(
                      controller: _educationController,
                      label: 'EducaciÃƒÂ³n',
                      hint:
                          'Ej: Bachillerato completo - Instituto Nacional, Managua.',
                      maxLines: 4,
                    ),
                    _buildField(
                      controller: _skillsController,
                      label: 'Habilidades',
                      hint:
                          'Separa con comas. Ej: puntualidad, liderazgo, Excel',
                      validator: _required,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _generateAndUploadCv,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Generar y subir CV'),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTemplateSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Plantilla',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _TemplateCard(
                title: 'ClÃƒÂ¡sica',
                subtitle: 'Cajas y secciones marcadas',
                isSelected: _selectedTemplate == 'classic',
                onTap: () => setState(() => _selectedTemplate = 'classic'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TemplateCard(
                title: 'Compacta',
                subtitle: 'MÃƒÂ¡s limpia y resumida',
                isSelected: _selectedTemplate == 'compact',
                onTap: () => setState(() => _selectedTemplate = 'compact'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPreviewCard() {
    final data = _currentData;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Vista previa',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: AspectRatio(
            aspectRatio: 0.74,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFC8CED8)),
              ),
              child: _selectedTemplate == 'compact'
                  ? _CompactCvPreview(data: data)
                  : _ClassicCvPreview(data: data),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        validator: validator,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Este campo es obligatorio';
    }
    return null;
  }
}

class _ClassicCvPreview extends StatelessWidget {
  final _CvData data;

  const _ClassicCvPreview({required this.data});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PreviewBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.fullName.isEmpty ? 'Tu nombre completo' : data.fullName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4B5563),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _joinMetaText(data),
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFF6B7280),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _PreviewSection(
            title: 'OBJETIVO PROFESIONAL',
            child: Text(
              data.summary.isEmpty
                  ? 'Agrega tu perfil profesional.'
                  : data.summary,
              style: const TextStyle(
                fontSize: 10.5,
                color: Color(0xFF6B7280),
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 10),
          _PreviewSection(
            title: 'EXPERIENCIA',
            child: _PreviewSplitBody(
              left: 'Reciente',
              right: data.experience.isEmpty
                  ? 'Agrega aquÃƒÂ­ tu experiencia mÃƒÂ¡s relevante.'
                  : data.experience,
            ),
          ),
          const SizedBox(height: 10),
          _PreviewSection(
            title: 'EDUCACIÃƒâ€œN',
            child: _PreviewSplitBody(
              left: 'FormaciÃƒÂ³n',
              right: data.education.isEmpty
                  ? 'Agrega aquÃƒÂ­ tu educaciÃƒÂ³n.'
                  : data.education,
            ),
          ),
          const SizedBox(height: 10),
          _PreviewSection(
            title: 'HABILIDADES',
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: data.skills.isEmpty
                  ? [
                      const Text(
                        'Agrega habilidades.',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ]
                  : data.skills
                        .map(
                          (skill) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xFFB8C1CC),
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              skill,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF4B5563),
                              ),
                            ),
                          ),
                        )
                        .toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _joinMetaText(_CvData data) {
    final values = [
      data.city,
      data.phone,
      data.email,
    ].where((item) => item.isNotEmpty).toList();
    return values.isEmpty
        ? 'Ciudad Ã¢â‚¬Â¢ TelÃƒÂ©fono Ã¢â‚¬Â¢ Correo electrÃƒÂ³nico'
        : values.join(' Ã¢â‚¬Â¢ ');
  }
}

class _CompactCvPreview extends StatelessWidget {
  final _CvData data;

  const _CompactCvPreview({required this.data});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.fullName.isEmpty ? 'Tu nombre completo' : data.fullName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  [data.city, data.phone, data.email]
                          .where((item) => item.isNotEmpty)
                          .join(' Ã¢â‚¬Â¢ ')
                          .isEmpty
                      ? 'Ciudad Ã¢â‚¬Â¢ TelÃƒÂ©fono Ã¢â‚¬Â¢ Correo electrÃƒÂ³nico'
                      : [
                          data.city,
                          data.phone,
                          data.email,
                        ].where((item) => item.isNotEmpty).join(' Ã¢â‚¬Â¢ '),
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _CompactSection(
            title: 'Resumen',
            body: data.summary.isEmpty ? 'Agrega tu resumen.' : data.summary,
          ),
          const SizedBox(height: 10),
          _CompactSection(
            title: 'Experiencia',
            body: data.experience.isEmpty
                ? 'Agrega tu experiencia.'
                : data.experience,
          ),
          const SizedBox(height: 10),
          _CompactSection(
            title: 'EducaciÃƒÂ³n',
            body: data.education.isEmpty
                ? 'Agrega tu educaciÃƒÂ³n.'
                : data.education,
          ),
          const SizedBox(height: 10),
          _CompactSection(
            title: 'Habilidades',
            body: data.skills.isEmpty
                ? 'Agrega habilidades.'
                : data.skills.join(' Ã¢â‚¬Â¢ '),
          ),
        ],
      ),
    );
  }
}

class _PreviewBox extends StatelessWidget {
  final Widget child;

  const _PreviewBox({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF9CA3AF)),
      ),
      child: child,
    );
  }
}

class _PreviewSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _PreviewSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return _PreviewBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _PreviewSplitBody extends StatelessWidget {
  final String left;
  final String right;

  const _PreviewSplitBody({required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 76,
          child: Text(
            left,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7280),
            ),
          ),
        ),
        Expanded(
          child: Text(
            right,
            style: const TextStyle(
              fontSize: 10.5,
              color: Color(0xFF6B7280),
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

class _CompactSection extends StatelessWidget {
  final String title;
  final String body;

  const _CompactSection({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(
              fontSize: 10.5,
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _TemplateCard({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primarySoft : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _CvData {
  final String fullName;
  final String email;
  final String phone;
  final String city;
  final String summary;
  final String experience;
  final String education;
  final List<String> skills;

  _CvData({
    required this.fullName,
    required this.email,
    required this.phone,
    required this.city,
    required this.summary,
    required this.experience,
    required this.education,
    required this.skills,
  });
}
