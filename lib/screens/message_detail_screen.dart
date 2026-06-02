import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../services/api_service.dart';
import '../services/message_realtime_service.dart';
import '../services/messages_service.dart';
import '../widgets/bottom_nav_bar.dart';

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
  List<Map<String, dynamic>> _responses = [];
  MessageRealtimeService? _realtimeService;
  StreamSubscription<Map<String, dynamic>>? _messageUpdatedSub;
  StreamSubscription<Map<String, dynamic>>? _messageRespondedSub;

  bool _handleBack() {
    if (Navigator.of(context).canPop()) {
      context.pop();
    } else {
      context.go('/messages');
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _loadMessage();
    _connectRealtime();
  }

  @override
  void dispose() {
    _messageUpdatedSub?.cancel();
    _messageRespondedSub?.cancel();
    _realtimeService?.unsubscribeFromMessage(widget.messageId);
    _realtimeService?.dispose();
    _responseController.dispose();
    super.dispose();
  }

  void _connectRealtime() {
    final api = context.read<ApiService>();
    final realtimeService = MessageRealtimeService(api);
    _realtimeService = realtimeService;
    _messageUpdatedSub = realtimeService.messageUpdated.listen((event) {
      if (event['id'] == widget.messageId) {
        _loadMessage(showLoading: false, showErrors: false);
      }
    });
    _messageRespondedSub = realtimeService.messageResponded.listen((event) {
      if (event['id'] == widget.messageId) {
        _loadMessage(showLoading: false, showErrors: false);
      }
    });
    realtimeService.subscribeToMessage(widget.messageId);
  }

  Future<void> _loadMessage({
    bool showLoading = true,
    bool showErrors = true,
  }) async {
    try {
      final api = context.read<ApiService>();
      final messagesService = MessagesService(api);
      final response = await api.get('/messages/${widget.messageId}');

      // Mark as read
      if (response['status'] == 'sent' || response['status'] == 'unread') {
        await messagesService.markRead(widget.messageId);
      }

      if (mounted) {
        setState(() {
          _message = response as Map<String, dynamic>;
          _isLoading = false;
          final list = (_message?['responses'] as List?) ?? [];
          _responses = list.whereType<Map<String, dynamic>>().toList();
        });
      }
    } catch (e) {
      if (mounted) {
        if (showLoading) setState(() => _isLoading = false);
        if (showErrors) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al cargar mensaje: $e')),
          );
        }
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
      final api = context.read<ApiService>();
      await api.post('/messages/${widget.messageId}/respond', {
        'responseType': _selectedResponse,
        'body': _responseController.text,
      });

      if (mounted) {
        setState(() {
          _responses.add({
            'responseType': _selectedResponse,
            'body': _responseController.text,
            'createdAt': DateTime.now().toIso8601String(),
            'from': 'me',
          });
          _selectedResponse = null;
          _responseController.clear();
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Respuesta enviada')));
        await _loadMessage(showLoading: false, showErrors: false);
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

  Widget _buildResponsesSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Respuestas',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ..._responses.map((r) {
            final fromMe = r['from'] == 'me';
            final createdAt = r['createdAt'] as String?;
            final time = createdAt != null && createdAt.isNotEmpty
                ? _formatTime(createdAt)
                : '';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: fromMe
                    ? AppColors.primary.withOpacity(0.06)
                    : AppColors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    r['responseType'] == 'confirm'
                        ? Icons.check_circle
                        : r['responseType'] == 'decline'
                        ? Icons.cancel
                        : Icons.help_outline,
                    color: r['responseType'] == 'confirm'
                        ? AppColors.success
                        : r['responseType'] == 'decline'
                        ? AppColors.error
                        : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if ((r['body'] as String?)?.isNotEmpty == true)
                          Text(
                            r['body'],
                            style: const TextStyle(fontSize: 14, height: 1.4),
                            softWrap: true,
                          ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              r['responseType'] == 'confirm'
                                  ? 'Confirmado'
                                  : r['responseType'] == 'decline'
                                  ? 'No asistiré'
                                  : 'Necesita ayuda',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              time,
                              style: TextStyle(
                                fontSize: 12,
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
            );
          }),
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
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _message == null
            ? const Center(child: Text('Mensaje no encontrado'))
            : _buildContent(),
        bottomNavigationBar: const BottomNavBar(currentIndex: 2),
      ),
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
                  isInterview
                      ? 'Invitación a entrevista'
                      : msg['title'] ?? 'Mensaje',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (msg['status'] == 'sent' || msg['status'] == 'unread')
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
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
                  child: Icon(
                    Icons.business,
                    color: AppColors.primary,
                    size: 20,
                  ),
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
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
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
            softWrap: true,
          ),

          const SizedBox(height: 16),
          if (_responses.isNotEmpty) _buildResponsesSection(),

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
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
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
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text('Fecha: Por confirmar'),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text('Hora: Por confirmar'),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
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
            if (isSelected) Icon(Icons.check_circle, color: iconColor),
          ],
        ),
      ),
    );
  }
}
