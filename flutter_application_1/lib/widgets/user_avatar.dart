import 'dart:convert';
import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// A reusable avatar widget that gracefully displays either:
/// 1. A user's uploaded profile picture (decoded from Base64 string), OR
/// 2. An attractive initials fallback circle with gradient background.
class UserAvatar extends StatelessWidget {
  final String? base64Image;
  final String displayName;
  final double radius;
  final VoidCallback? onTap;

  const UserAvatar({
    super.key,
    required this.base64Image,
    required this.displayName,
    this.radius = 24,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget avatarContent;

    // Check if the user has an uploaded base64 image
    if (base64Image != null && base64Image!.trim().isNotEmpty) {
      try {
        final imageBytes = base64Decode(base64Image!);
        avatarContent = ClipOval(
          child: Image.memory(
            imageBytes,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildInitials(),
          ),
        );
      } catch (e) {
        // If decoding fails for any reason, fallback to initials
        avatarContent = _buildInitials();
      }
    } else {
      // Default: Initial letters or icon
      avatarContent = _buildInitials();
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: avatarContent,
      );
    }

    return avatarContent;
  }

  /// Builds a colorful circular badge with the user's first letter
  Widget _buildInitials() {
    final initial = displayName.trim().isNotEmpty
        ? displayName.trim()[0].toUpperCase()
        : '?';

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [AppTheme.primaryLight, AppTheme.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
