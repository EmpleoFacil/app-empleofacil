import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../services/api_service.dart';
import '../services/message_realtime_service.dart';
import '../services/messages_service.dart';

class BottomNavBar extends StatefulWidget {
  final int currentIndex;

  const BottomNavBar({super.key, required this.currentIndex});

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  int _unreadCount = 0;
  MessageRealtimeService? _realtimeService;
  StreamSubscription<Map<String, dynamic>>? _messageCreatedSub;
  StreamSubscription<Map<String, dynamic>>? _messageUpdatedSub;
  StreamSubscription<Map<String, dynamic>>? _messageRespondedSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUnreadCount();
      _connectRealtime();
    });
  }

  @override
  void dispose() {
    _messageCreatedSub?.cancel();
    _messageUpdatedSub?.cancel();
    _messageRespondedSub?.cancel();
    _realtimeService?.dispose();
    super.dispose();
  }

  Future<void> _loadUnreadCount() async {
    try {
      final api = context.read<ApiService>();
      final messagesService = MessagesService(api);
      final count = await messagesService.getUnreadCount();
      if (mounted) setState(() => _unreadCount = count);
    } catch (_) {}
  }

  void _connectRealtime() {
    final api = context.read<ApiService>();
    final realtimeService = MessageRealtimeService(api);
    _realtimeService = realtimeService;
    _messageCreatedSub = realtimeService.messageCreated.listen((_) {
      _loadUnreadCount();
    });
    _messageUpdatedSub = realtimeService.messageUpdated.listen((_) {
      _loadUnreadCount();
    });
    _messageRespondedSub = realtimeService.messageResponded.listen((_) {
      _loadUnreadCount();
    });
    realtimeService.connect();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.borderSoft, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(
                child: _NavItem(
                  icon: PhosphorIconsRegular.houseSimple,
                  activeIcon: PhosphorIconsFill.houseSimple,
                  label: 'Inicio',
                  isActive: widget.currentIndex == 0,
                  onTap: () => context.go('/home'),
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: PhosphorIconsRegular.clipboardText,
                  activeIcon: PhosphorIconsFill.clipboardText,
                  label: 'Postulaciones',
                  isActive: widget.currentIndex == 1,
                  onTap: () => context.go('/applications'),
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: PhosphorIconsRegular.chatsCircle,
                  activeIcon: PhosphorIconsFill.chatsCircle,
                  label: 'Mensajes',
                  isActive: widget.currentIndex == 2,
                  badgeCount: _unreadCount,
                  onTap: () => context.go('/messages'),
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: PhosphorIconsRegular.userCircle,
                  activeIcon: PhosphorIconsFill.userCircle,
                  label: 'Perfil',
                  isActive: widget.currentIndex == 3,
                  onTap: () => context.go('/profile'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final int badgeCount;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isActive ? activeIcon : icon,
                  color: isActive ? AppColors.primary : AppColors.textSecondary,
                  size: 22,
                ),
                if (badgeCount > 0)
                  Positioned(
                    right: -8,
                    top: -7,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 17,
                        minHeight: 17,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Center(
                        child: Text(
                          badgeCount > 9 ? '9+' : '$badgeCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isActive ? AppColors.primary : AppColors.textSecondary,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
