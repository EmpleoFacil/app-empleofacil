import 'package:flutter/material.dart';

import '../config/theme.dart';

class CompanyLogoAvatar extends StatelessWidget {
  final String? logoUrl;
  final String companyName;
  final double size;
  final double borderRadius;
  final IconData fallbackIcon;
  final Color? backgroundColor;
  final Color? iconColor;
  final double? iconSize;

  const CompanyLogoAvatar({
    super.key,
    required this.logoUrl,
    required this.companyName,
    required this.size,
    this.borderRadius = 12,
    this.fallbackIcon = Icons.business,
    this.backgroundColor,
    this.iconColor,
    this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedLogoUrl = logoUrl?.trim();
    final fallback = _LogoFallback(
      size: size,
      borderRadius: borderRadius,
      icon: fallbackIcon,
      backgroundColor: backgroundColor,
      iconColor: iconColor,
      iconSize: iconSize,
      semanticLabel: companyName,
    );

    if (normalizedLogoUrl == null || normalizedLogoUrl.isEmpty) {
      return fallback;
    }

    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.network(
          normalizedLogoUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, error, stackTrace) => fallback,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              return child;
            }
            return fallback;
          },
        ),
      ),
    );
  }
}

class _LogoFallback extends StatelessWidget {
  final double size;
  final double borderRadius;
  final IconData icon;
  final Color? backgroundColor;
  final Color? iconColor;
  final double? iconSize;
  final String semanticLabel;

  const _LogoFallback({
    required this.size,
    required this.borderRadius,
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
    required this.iconSize,
    required this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor ?? AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Icon(
          icon,
          color: iconColor ?? AppColors.primary,
          size: iconSize ?? size * 0.48,
        ),
      ),
    );
  }
}
