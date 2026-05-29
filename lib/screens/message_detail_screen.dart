import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../services/api_service.dart';

class MessageDetailScreen extends StatefulWidget {
  final String messageId;

  const MessageDetailScreen({super.key, required this.messageId});

  @override
  State<MessageDetailScreen> createState() => _MessageDetailScreenState();
}

class _MessageDetailScreenState extends State<MessageDetailScreen> {
  Map<String, dynamic>? _message;
  bool _isLoading = true;
  String? _selectedResponse;
  final _responseController = TextEditingController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadMessage();
  }

  Future<void> _loadMessage() async {
    try {
      final api = ApiService();
      final response = await api.get('/messages/${widget.messageId}');
      
      // Mark as read
      if (response['status'] == 'sent' || response['status'] == 'unread') {
        await api.patch('/messages/${widget.messageId}/read', {});
      }
      
      if (mounted) {
        setState(() {
          _message = response as Map<String, dynamic>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar mensaje: $e')),
        );
      }
    }
  }

  Future<void> _sendResponse() async {
    if (_selectedResponse == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una opción de respuesta')),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      final api = ApiService();
      await api.post('/messages/${widget.messageId}/respond', {
        'responseType': _selectedResponse,
        'body': _responseController.text,
      });

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar respuesta: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
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
              '¡Respuesta enviada!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Tu respuesta ha sido enviada correctamente.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/messages');
            },
            child: const Text('Volver a mensajes'),
          ),
          if (_message?['applicationId'] != null)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                context.go('/applications/${_message!['applicationId']}');
              },
              child: const Text('Ver postulación'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Empleo'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _message == null
              ? const Center(child: Text('Mensaje no encontrado'))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final msg = _message!;
    final isInterview = msg['type'] == 'interview_invitation';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Text(
                  isInterview ? 'Invitación a entrevista' : msg['title'] ?? 'Mensaje',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              if (msg['status'] == 'sent' || msg['status'] == 'unread')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Nuevo',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Company info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.business, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        msg['company']?['name'] ?? 'Empresa',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Hoy, ${_formatTime(msg['createdAt'])}',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Message body
          Text(
            msg['body'] ?? '',
            style: const TextStyle(fontSize: 15, height: 1.6),
          ),
          
          // Interview details if applicable
          if (isInterview && msg['application']?['job'] != null) ...[
            const SizedBox(height: 24),
            _buildInterviewDetails(msg),
          ],
          
          const SizedBox(height: 32),
          
          // Response section
          const Text(
            '¿Podrás asistir?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          
          _ResponseOption(
            icon: Icons.check_circle,
            iconColor: AppColors.success,
            label: 'Sí asistiré',
            isSelected: _selectedResponse == 'confirm',
            onTap: () => setState(() => _selectedResponse = 'confirm'),
          ),
          const SizedBox(height: 8),
          _ResponseOption(
            icon: Icons.cancel,
            iconColor: AppColors.error,
            label: 'No podré asistir',
            isSelected: _selectedResponse == 'decline',
            onTap: () => setState(() => _selectedResponse = 'decline'),
          ),
          const SizedBox(height: 8),
          _ResponseOption(
            icon: Icons.help,
            iconColor: Colors.orange,
            label: 'Necesito ayuda',
            isSelected: _selectedResponse == 'help',
            onTap: () => setState(() => _selectedResponse = 'help'),
          ),
          
          const SizedBox(height: 24),
          
          // Optional message
          Text(
            'Respuesta opcional (escribe un mensaje corto)',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _responseController,
            maxLines: 3,
            maxLength: 150,
            decoration: InputDecoration(
              hintText: 'Escribe tu respuesta (opcional)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Send button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isSending ? null : _sendResponse,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Enviar respuesta'),
            ),
          ),
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildInterviewDetails(Map<String, dynamic> msg) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Modalidad: ${msg['application']?['job']?['modality'] ?? 'Presencial'}',
            style: const TextStyle(fontSize: 14),
          ),
          if (msg['application']?['interviews'] != null && 
              (msg['application']['interviews'] as List).isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text('Fecha: Por confirmar'),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text('Hora: Por confirmar'),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.location_on_outlined, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(child: Text('Lugar: Por confirmar')),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    final date = DateTime.parse(dateStr);
    final hour = date.hour > 12 ? date.hour - 12 : date.hour;
    final period = date.hour >= 12 ? 'p.m.' : 'a.m.';
    return '$hour:${date.minute.toString().padLeft(2, '0')} $period';
  }
}

class _ResponseOption extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ResponseOption({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? iconColor.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? iconColor : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            const Spacer(),
            if (isSelected)
              Icon(Icons.check_circle, color: iconColor),
          ],
        ),
      ),
    );
  }
}
