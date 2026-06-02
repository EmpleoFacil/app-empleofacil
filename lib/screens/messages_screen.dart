import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../services/api_service.dart';
import '../services/message_realtime_service.dart';
import '../services/messages_service.dart';
import '../widgets/bottom_nav_bar.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  List<dynamic> _messages = [];
  bool _isLoading = true;
  String _filter = 'all';
  StreamSubscription<Map<String, dynamic>>? _messageCreatedSub;
  StreamSubscription<Map<String, dynamic>>? _messageUpdatedSub;
  StreamSubscription<Map<String, dynamic>>? _messageRespondedSub;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _connectRealtime();
  }

  @override
  void dispose() {
    _messageCreatedSub?.cancel();
    _messageUpdatedSub?.cancel();
    _messageRespondedSub?.cancel();
    super.dispose();
  }

  void _connectRealtime() {
    final realtimeService = context.read<MessageRealtimeService>();
    _messageCreatedSub = realtimeService.messageCreated.listen((_) {
      _loadMessages(showLoading: false, showErrors: false);
    });
    _messageUpdatedSub = realtimeService.messageUpdated.listen((_) {
      _loadMessages(showLoading: false, showErrors: false);
    });
    _messageRespondedSub = realtimeService.messageResponded.listen((_) {
      _loadMessages(showLoading: false, showErrors: false);
    });
    realtimeService.connect();
  }

  Future<void> _loadMessages({
    bool showLoading = true,
    bool showErrors = true,
  }) async {
    if (showLoading) setState(() => _isLoading = true);

    try {
      final api = context.read<ApiService>();
      final messagesService = MessagesService(api);
      final response = await messagesService.getMessages(filter: _filter);

      if (mounted) {
        setState(() {
          _messages = response;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        if (showLoading) setState(() => _isLoading = false);
        if (showErrors) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al cargar mensajes: $e')),
          );
        }
      }
    }
  }

  List<dynamic> get _filteredMessages {
    if (_filter == 'all') return _messages;
    if (_filter == 'important') {
      return _messages
          .where(
            (m) =>
                m['type'] == 'interview_invitation' ||
                m['type'] == 'document_request',
          )
          .toList();
    }
    if (_filter == 'unread') {
      return _messages
          .where((m) => m['status'] == 'sent' || m['status'] == 'unread')
          .toList();
    }
    return _messages;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Empleo'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mensajes',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildFilterChips(),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredMessages.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _loadMessages,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredMessages.length,
                      itemBuilder: (context, index) {
                        return _MessageCard(message: _filteredMessages[index]);
                      },
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 2),
    );
  }

  Widget _buildFilterChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _FilterChip(
          label: 'Todos',
          isSelected: _filter == 'all',
          onTap: () {
            setState(() => _filter = 'all');
            _loadMessages();
          },
        ),
        _FilterChip(
          label: 'Importantes',
          icon: Icons.star_outline,
          isSelected: _filter == 'important',
          onTap: () {
            setState(() => _filter = 'important');
            _loadMessages();
          },
        ),
        _FilterChip(
          label: 'Sin leer',
          icon: Icons.mark_email_unread_outlined,
          isSelected: _filter == 'unread',
          onTap: () {
            setState(() => _filter = 'unread');
            _loadMessages();
          },
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          Text(
            'No tienes mensajes',
            style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isSelected ? Colors.white : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final dynamic message;

  const _MessageCard({required this.message});

  bool get _isUnread =>
      message['status'] == 'sent' || message['status'] == 'unread';

  String get _typeLabel {
    switch (message['type']) {
      case 'interview_invitation':
        return 'Invitación a entrevista';
      case 'document_request':
        return 'Documentos solicitados';
      case 'status_update':
        return 'Actualización de postulación';
      default:
        return 'Mensaje';
    }
  }

  Color get _statusColor {
    switch (message['status']) {
      case 'responded':
        return AppColors.success;
      case 'pending':
        return const Color(0xFFFFA000);
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/messages/${message['id']}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _isUnread
                ? AppColors.primary.withOpacity(0.35)
                : AppColors.border,
            width: _isUnread ? 1.4 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                message['type'] == 'interview_invitation'
                    ? Icons.shield_outlined
                    : message['type'] == 'document_request'
                    ? Icons.cleaning_services_outlined
                    : Icons.inventory_2_outlined,
                color: AppColors.primary,
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
                          message['company']?['name'] ?? 'Empresa',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _statusColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            _isUnread ? 'Nuevo' : _typeLabel,
                            style: TextStyle(
                              fontSize: 11,
                              color: _statusColor,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    message['body'] ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatTime(message['createdAt']),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                if (message['status'] == 'responded')
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Respondido',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.success,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                if (_isUnread)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    final date = DateTime.parse(dateStr);
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays > 0) {
      return '${date.day} ${_getMonth(date.month)}';
    }
    return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _getMonth(int month) {
    const months = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];
    return months[month - 1];
  }
}
