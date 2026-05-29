import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
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

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final api = ApiService();
      final response = await api.get('/candidates/me');
      
      if (mounted) {
        setState(() {
          _profile = response as Map<String, dynamic>;
          _phoneController.text = _profile?['phone'] ?? '';
          _emailController.text = _profile?['user']?['email'] ?? '';
          _cityController.text = _profile?['city'] ?? '';
          _selectedAvailability = _profile?['availability'];
          _selectedJobType = _profile?['desiredJobType'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar perfil: $e')),
        );
      }
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);

    try {
      final api = ApiService();
      await api.patch('/candidates/me', {
        'phone': _phoneController.text,
        'city': _cityController.text,
        'availability': _selectedAvailability,
        'desiredJobType': _selectedJobType,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cambios guardados')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  int get _profileCompletion {
    int score = 0;
    if (_profile?['fullName'] != null) score += 20;
    if (_profile?['phone'] != null) score += 20;
    if (_profile?['city'] != null) score += 20;
    if (_profile?['desiredJobType'] != null) score += 20;
    if (_profile?['availability'] != null) score += 20;
    return score;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Empleo'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await context.read<AuthProvider>().logout();
              if (context.mounted) {
                context.go('/welcome');
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
      bottomNavigationBar: const BottomNavBar(currentIndex: 4),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mi perfil',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          Text(
            'Edita tus datos en la misma vista\ny revisa tu progreso.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          
          const SizedBox(height: 24),
          
          // Profile header
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: Icon(Icons.person, size: 50, color: AppColors.primary),
                ),
                const SizedBox(height: 12),
                Text(
                  _profile?['fullName'] ?? 'Usuario',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_profile?['city'] ?? 'Nicaragua'}',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                Text(
                  _profile?['phone'] ?? '',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Profile completion
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
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
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '$_profileCompletion%',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: _profileCompletion / 100,
                  backgroundColor: AppColors.border,
                  valueColor: AlwaysStoppedAnimation(AppColors.primary),
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 8),
                Text(
                  _profileCompletion < 100
                      ? '¡Vas muy bien! Completa tu perfil al 100%.'
                      : '¡Perfil completo!',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Editable fields
          _buildEditableField(
            'Trabajo que buscas',
            _selectedJobType ?? 'Sin especificar',
            Icons.work_outline,
            onEdit: _showJobTypeSelector,
          ),
          _buildEditableField(
            'Disponibilidad',
            _selectedAvailability ?? 'Inmediata',
            Icons.schedule,
            onEdit: _showAvailabilitySelector,
          ),
          _buildEditableField(
            'Teléfono',
            _phoneController.text.isEmpty ? 'Sin especificar' : _phoneController.text,
            Icons.phone_outlined,
            onEdit: () => _showEditDialog('Teléfono', _phoneController),
          ),
          _buildEditableField(
            'Correo electrónico',
            _emailController.text,
            Icons.email_outlined,
            onEdit: null, // Email is read-only
          ),
          _buildEditableField(
            'Ciudad',
            _cityController.text.isEmpty ? 'Sin especificar' : _cityController.text,
            Icons.location_city,
            onEdit: () => _showEditDialog('Ciudad', _cityController),
          ),
          
          const SizedBox(height: 16),
          
          // Navigation links
          _buildNavigationItem(
            'Mis documentos',
            '${_profile?['documentsCount'] ?? 0} de 5 completos',
            Icons.description_outlined,
            () => context.go('/documents'),
          ),
          _buildNavigationItem(
            'Mis postulaciones',
            '${_profile?['applicationsCount'] ?? 0} activas',
            Icons.assignment_outlined,
            () => context.go('/applications'),
          ),
          
          const SizedBox(height: 24),
          
          // Save button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveChanges,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Guardar cambios'),
            ),
          ),
          
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildEditableField(
    String label,
    String value,
    IconData icon, {
    VoidCallback? onEdit,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (onEdit != null)
            IconButton(
              icon: Icon(Icons.edit_outlined, color: AppColors.primary),
              onPressed: onEdit,
            ),
        ],
      ),
    );
  }

  Widget _buildNavigationItem(
    String label,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
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
            ...['security', 'cleaning', 'warehouse', 'reception', 'other'].map((type) {
              final labels = {
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
              final labels = {
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
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
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
