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

  String _selectedTemplate = _CvTemplates.classic;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _attachPreviewListeners();
    _loadProfile();
  }

  void _attachPreviewListeners() {
    for (final controller in _controllers) {
      controller.addListener(_refreshPreview);
    }
  }

  List<TextEditingController> get _controllers => [
    _fullNameController,
    _emailController,
    _phoneController,
    _cityController,
    _summaryController,
    _experienceController,
    _educationController,
    _skillsController,
  ];

  void _refreshPreview() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
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
            'Persona responsable, con disposición para trabajar y aprender rápidamente.';
        _experienceController.text =
            'Guardia de seguridad en empresa privada.\nControl de accesos, rondas y registro de novedades.';
        _educationController.text =
            'Bachillerato completo.\nCursos básicos de atención al cliente y seguridad.';
        _skillsController.text =
            'Responsabilidad, puntualidad, trabajo en equipo, atención al detalle';
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
      final pdf = _buildDocument(_currentData);
      final bytes = await pdf.save();
      final filename = _buildFilename(_currentData.fullName);

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

  pw.Document _buildDocument(_CvData data) {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
        ),
        build: (_) => _buildPdfTemplate(data),
      ),
    );
    return pdf;
  }

  List<pw.Widget> _buildPdfTemplate(_CvData data) {
    switch (_selectedTemplate) {
      case _CvTemplates.compact:
        return _buildCompactPdf(data);
      case _CvTemplates.executive:
        return _buildExecutivePdf(data);
      case _CvTemplates.sidebar:
        return _buildSidebarPdf(data);
      case _CvTemplates.classic:
      default:
        return _buildClassicPdf(data);
    }
  }

  List<pw.Widget> _buildClassicPdf(_CvData data) {
    return [
      _pdfClassicHeader(data),
      pw.SizedBox(height: 14),
      _pdfBox(
        title: 'OBJETIVO PROFESIONAL',
        child: pw.Text(data.summary, style: _pdfBodyStyle),
      ),
      pw.SizedBox(height: 14),
      _pdfSplitBox(
        title: 'EXPERIENCIA',
        left: 'Reciente',
        right: _fallback(data.experience, 'Sin experiencia agregada.'),
      ),
      pw.SizedBox(height: 14),
      _pdfSplitBox(
        title: 'EDUCACIÓN',
        left: 'Formación',
        right: _fallback(data.education, 'Sin educación agregada.'),
      ),
      pw.SizedBox(height: 14),
      _pdfBox(
        title: 'HABILIDADES',
        child: pw.Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _pdfSkillChips(data.skills),
        ),
      ),
    ];
  }

  List<pw.Widget> _buildCompactPdf(_CvData data) {
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
        child: pw.Text(data.summary, style: _pdfBodyStyle),
      ),
      pw.SizedBox(height: 12),
      _pdfBox(
        title: 'EXPERIENCIA',
        child: pw.Text(
          _fallback(data.experience, 'Sin experiencia agregada.'),
          style: _pdfBodyStyle,
        ),
      ),
      pw.SizedBox(height: 12),
      _pdfBox(
        title: 'EDUCACIÓN',
        child: pw.Text(
          _fallback(data.education, 'Sin educación agregada.'),
          style: _pdfBodyStyle,
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

  List<pw.Widget> _buildExecutivePdf(_CvData data) {
    return [
      pw.Text(
        data.fullName,
        style: pw.TextStyle(
          fontSize: 24,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.grey900,
        ),
      ),
      pw.SizedBox(height: 4),
      pw.Text(_joinMeta(data), style: const pw.TextStyle(fontSize: 10)),
      pw.SizedBox(height: 10),
      pw.Divider(color: PdfColors.grey600, thickness: 0.8),
      pw.SizedBox(height: 10),
      _pdfLineSection('RESUMEN', data.summary),
      _pdfLineSection(
        'EXPERIENCIA',
        _fallback(data.experience, 'Sin experiencia agregada.'),
      ),
      _pdfLineSection(
        'EDUCACIÓN',
        _fallback(data.education, 'Sin educación agregada.'),
      ),
      _pdfLineSection(
        'HABILIDADES',
        data.skills.isEmpty
            ? 'Sin habilidades agregadas.'
            : data.skills.join(' | '),
      ),
    ];
  }

  List<pw.Widget> _buildSidebarPdf(_CvData data) {
    return [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 150,
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#EAF2FF'),
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'CONTACTO',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  _fallback(data.city, 'Ciudad'),
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  _fallback(data.phone, 'Teléfono'),
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  _fallback(data.email, 'Correo'),
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.SizedBox(height: 14),
                pw.Text(
                  'HABILIDADES',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.SizedBox(height: 8),
                ...(data.skills.isEmpty
                    ? [
                        pw.Text(
                          'Sin habilidades',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ]
                    : data.skills.map((skill) => pw.Bullet(text: skill))),
              ],
            ),
          ),
          pw.SizedBox(width: 18),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  data.fullName,
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey900,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Currículum profesional',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue700,
                  ),
                ),
                pw.SizedBox(height: 14),
                _pdfLineSection('RESUMEN', data.summary),
                _pdfLineSection(
                  'EXPERIENCIA',
                  _fallback(data.experience, 'Sin experiencia agregada.'),
                ),
                _pdfLineSection(
                  'EDUCACIÓN',
                  _fallback(data.education, 'Sin educación agregada.'),
                ),
              ],
            ),
          ),
        ],
      ),
    ];
  }

  pw.Widget _pdfClassicHeader(_CvData data) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(18),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey700, width: 0.8),
      ),
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
              pw.Expanded(child: pw.Text(right, style: _pdfBodyStyle)),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfLineSection(String title, String body) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 14),
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
          pw.SizedBox(height: 4),
          pw.Divider(color: PdfColors.grey500, thickness: 0.6),
          pw.SizedBox(height: 6),
          pw.Text(body, style: _pdfBodyStyle),
        ],
      ),
    );
  }

  List<pw.Widget> _pdfSkillChips(List<String> skills) {
    if (skills.isEmpty) {
      return [
        pw.Text(
          'Sin habilidades agregadas.',
          style: const pw.TextStyle(fontSize: 10),
        ),
      ];
    }

    return skills
        .map(
          (skill) => pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey600, width: 0.6),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Text(skill, style: const pw.TextStyle(fontSize: 10)),
          ),
        )
        .toList();
  }

  pw.TextStyle get _pdfBodyStyle =>
      const pw.TextStyle(fontSize: 10.5, lineSpacing: 2.8);

  String _joinMeta(_CvData data) {
    return [
      data.city,
      data.phone,
      data.email,
    ].where((item) => item.isNotEmpty).join(' | ');
  }

  String _fallback(String value, String placeholder) {
    return value.isEmpty ? placeholder : value;
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
                      'Genera tu currículum',
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
                      label: 'Correo electrónico',
                    ),
                    _buildField(
                      controller: _phoneController,
                      label: 'Teléfono',
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
                      label: 'Educación',
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
    final templates = _CvTemplates.all;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Plantilla',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: templates.map((template) {
              final isSelected = _selectedTemplate == template.id;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: SizedBox(
                  width: 152,
                  child: _TemplateCard(
                    title: template.title,
                    subtitle: template.subtitle,
                    isSelected: isSelected,
                    accent: template.accent,
                    onTap: () =>
                        setState(() => _selectedTemplate = template.id),
                  ),
                ),
              );
            }).toList(),
          ),
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
              child: _CvPreview(templateId: _selectedTemplate, data: data),
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

class _CvPreview extends StatelessWidget {
  final String templateId;
  final _CvData data;

  const _CvPreview({required this.templateId, required this.data});

  @override
  Widget build(BuildContext context) {
    switch (templateId) {
      case _CvTemplates.compact:
        return _CompactCvPreview(data: data);
      case _CvTemplates.executive:
        return _ExecutiveCvPreview(data: data);
      case _CvTemplates.sidebar:
        return _SidebarCvPreview(data: data);
      case _CvTemplates.classic:
      default:
        return _ClassicCvPreview(data: data);
    }
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
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _previewMeta(data),
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
              style: _previewBodyStyle,
            ),
          ),
          const SizedBox(height: 10),
          _PreviewSection(
            title: 'EXPERIENCIA',
            child: _PreviewSplitBody(
              left: 'Reciente',
              right: data.experience.isEmpty
                  ? 'Agrega aquí tu experiencia más relevante.'
                  : data.experience,
            ),
          ),
          const SizedBox(height: 10),
          _PreviewSection(
            title: 'EDUCACIÓN',
            child: _PreviewSplitBody(
              left: 'Formación',
              right: data.education.isEmpty
                  ? 'Agrega aquí tu educación.'
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
                        style: _previewBodyStyle,
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
                              style: const TextStyle(fontSize: 10),
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
                  _previewMeta(data),
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
            title: 'Educación',
            body: data.education.isEmpty
                ? 'Agrega tu educación.'
                : data.education,
          ),
          const SizedBox(height: 10),
          _CompactSection(
            title: 'Habilidades',
            body: data.skills.isEmpty
                ? 'Agrega habilidades.'
                : data.skills.join(' | '),
          ),
        ],
      ),
    );
  }
}

class _ExecutiveCvPreview extends StatelessWidget {
  final _CvData data;

  const _ExecutiveCvPreview({required this.data});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.fullName.isEmpty ? 'Tu nombre completo' : data.fullName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _previewMeta(data),
            style: const TextStyle(
              fontSize: 10.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 12),
          _LinePreviewSection(
            title: 'Resumen',
            body: data.summary.isEmpty ? 'Agrega tu resumen.' : data.summary,
          ),
          _LinePreviewSection(
            title: 'Experiencia',
            body: data.experience.isEmpty
                ? 'Agrega tu experiencia.'
                : data.experience,
          ),
          _LinePreviewSection(
            title: 'Educación',
            body: data.education.isEmpty
                ? 'Agrega tu educación.'
                : data.education,
          ),
          _LinePreviewSection(
            title: 'Habilidades',
            body: data.skills.isEmpty
                ? 'Agrega habilidades.'
                : data.skills.join(' | '),
          ),
        ],
      ),
    );
  }
}

class _SidebarCvPreview extends StatelessWidget {
  final _CvData data;

  const _SidebarCvPreview({required this.data});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 92,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Contacto',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                _fallbackPreview(data.city, 'Ciudad'),
                style: const TextStyle(fontSize: 9.5),
              ),
              const SizedBox(height: 4),
              Text(
                _fallbackPreview(data.phone, 'Teléfono'),
                style: const TextStyle(fontSize: 9.5),
              ),
              const SizedBox(height: 4),
              Text(
                _fallbackPreview(data.email, 'Correo'),
                style: const TextStyle(fontSize: 9.5),
              ),
              const SizedBox(height: 10),
              const Text(
                'Habilidades',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                data.skills.isEmpty
                    ? 'Sin habilidades'
                    : data.skills.join('\n'),
                style: const TextStyle(fontSize: 9.5, height: 1.3),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
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
                const SizedBox(height: 4),
                Text(
                  'Currículum profesional',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                _LinePreviewSection(
                  title: 'Resumen',
                  body: data.summary.isEmpty
                      ? 'Agrega tu resumen.'
                      : data.summary,
                ),
                _LinePreviewSection(
                  title: 'Experiencia',
                  body: data.experience.isEmpty
                      ? 'Agrega tu experiencia.'
                      : data.experience,
                ),
                _LinePreviewSection(
                  title: 'Educación',
                  body: data.education.isEmpty
                      ? 'Agrega tu educación.'
                      : data.education,
                ),
              ],
            ),
          ),
        ),
      ],
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
        Expanded(child: Text(right, style: _previewBodyStyle)),
      ],
    );
  }
}

class _LinePreviewSection extends StatelessWidget {
  final String title;
  final String body;

  const _LinePreviewSection({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Divider(height: 1),
          const SizedBox(height: 6),
          Text(body, style: _previewBodyStyle),
        ],
      ),
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
          Text(body, style: _previewBodyStyle),
        ],
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final Color accent;
  final VoidCallback onTap;

  const _TemplateCard({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.accent,
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
          color: isSelected ? accent.withOpacity(0.12) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? accent : AppColors.border,
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

class _CvTemplateDefinition {
  final String id;
  final String title;
  final String subtitle;
  final Color accent;

  const _CvTemplateDefinition({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.accent,
  });
}

class _CvTemplates {
  static const classic = 'classic';
  static const compact = 'compact';
  static const executive = 'executive';
  static const sidebar = 'sidebar';

  static const all = [
    _CvTemplateDefinition(
      id: classic,
      title: 'Clásica',
      subtitle: 'Cajas y secciones marcadas',
      accent: AppColors.primary,
    ),
    _CvTemplateDefinition(
      id: compact,
      title: 'Compacta',
      subtitle: 'Directa y resumida',
      accent: AppColors.success,
    ),
    _CvTemplateDefinition(
      id: executive,
      title: 'Ejecutiva',
      subtitle: 'Sobria y profesional',
      accent: Color(0xFF475569),
    ),
    _CvTemplateDefinition(
      id: sidebar,
      title: 'Lateral',
      subtitle: 'Contacto y habilidades al lado',
      accent: Color(0xFF0F766E),
    ),
  ];
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

const TextStyle _previewBodyStyle = TextStyle(
  fontSize: 10.5,
  color: Color(0xFF6B7280),
  height: 1.45,
);

String _previewMeta(_CvData data) {
  final values = [
    data.city,
    data.phone,
    data.email,
  ].where((item) => item.isNotEmpty).toList();
  return values.isEmpty
      ? 'Ciudad | Teléfono | Correo electrónico'
      : values.join(' | ');
}

String _fallbackPreview(String value, String placeholder) {
  return value.isEmpty ? placeholder : value;
}
