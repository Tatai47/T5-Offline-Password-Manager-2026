import 'dart:convert';
import 'package:flutter/material.dart';
import '../utils/url_helper.dart';

/// A reusable avatar widget that intelligently displays:
/// 1. A manual custom logo (Base64 string or image URL) if provided by the user.
/// 2. OR automatically fetches and displays the website's favicon if a websiteUrl is present.
/// 3. OR falls back to a stylish category icon if no logo/favicon is available or if loading fails.
class VaultLogoAvatar extends StatelessWidget {
  final String? customLogo;
  final String? websiteUrl;
  final IconData fallbackIcon;
  final Color fallbackColor;
  final double size;
  final double borderRadius;
  final Color? backgroundColor;

  const VaultLogoAvatar({
    super.key,
    this.customLogo,
    this.websiteUrl,
    required this.fallbackIcon,
    required this.fallbackColor,
    this.size = 44,
    this.borderRadius = 12,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? fallbackColor.withValues(alpha: 0.12);

    Widget fallbackWidget() {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        alignment: Alignment.center,
        child: Icon(fallbackIcon, color: fallbackColor, size: size * 0.52),
      );
    }

    // 1. Manual custom logo takes top precedence
    if (customLogo != null && customLogo!.trim().isNotEmpty) {
      final logoStr = customLogo!.trim();
      final isNetwork = logoStr.startsWith('http://') || logoStr.startsWith('https://');

      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        clipBehavior: Clip.antiAlias,
        child: isNetwork
            ? Image.network(
                logoStr,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallbackWidget(),
              )
            : Image.memory(
                base64Decode(logoStr),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallbackWidget(),
              ),
      );
    }

    // 2. Auto-fetched favicon from website URL
    if (websiteUrl != null && websiteUrl!.trim().isNotEmpty) {
      final primaryFavicon = getFaviconUrl(websiteUrl);
      final backupFavicon = getBackupFaviconUrl(websiteUrl);

      if (primaryFavicon != null) {
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          clipBehavior: Clip.antiAlias,
          padding: EdgeInsets.all(size * 0.14),
          child: Image.network(
            primaryFavicon,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) {
              if (backupFavicon != null) {
                return Image.network(
                  backupFavicon,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => fallbackWidget(),
                );
              }
              return fallbackWidget();
            },
          ),
        );
      }
    }

    // 3. Fallback to category icon
    return fallbackWidget();
  }
}
