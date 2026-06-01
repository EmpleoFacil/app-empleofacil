import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../config/theme.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;

  const BottomNavBar({super.key, required this.currentIndex});

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
                  icon: PhosphorIcons.houseSimple(PhosphorIconsStyle.regular),
                  activeIcon: PhosphorIcons.houseSimple(PhosphorIconsStyle.fill),
                  label: 'Inicio',
                  isActive: currentIndex == 0,
                  onTap: () => context.go('/home'),
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: PhosphorIcons.clipboardText(PhosphorIconsStyle.regular),
                  activeIcon: PhosphorIcons.clipboardText(PhosphorIconsStyle.fill),
                  label: 'Postulaciones',
                  isActive: currentIndex == 1,
                  onTap: () => context.go('/applications'),
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: PhosphorIcons.chatsCircle(PhosphorIconsStyle.regular),
                  activeIcon: PhosphorIcons.chatsCircle(PhosphorIconsStyle.fill),
                  label: 'Mensajes',
                  isActive: currentIndex == 2,
                  onTap: () => context.go('/messages'),
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: PhosphorIcons.userCircle(PhosphorIconsStyle.regular),
                  activeIcon: PhosphorIcons.userCircle(PhosphorIconsStyle.fill),
                  label: 'Perfil',
                  isActive: currentIndex == 3,
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

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
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
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? AppColors.primary : AppColors.textSecondary,
              size: 22,
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
