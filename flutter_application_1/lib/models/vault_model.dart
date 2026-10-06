import 'package:flutter/material.dart';

/// Represents a distinct Vault owned by a user (e.g., Personal, Work, Finance, Crypto).
class VaultModel {
  final int? id;
  final int userId;
  final String name;
  final String description;
  final String iconName;
  final String colorHex;
  final String? pin; // Optional PIN lock specific to this vault
  final String createdAt;
  final int itemCount;

  const VaultModel({
    this.id,
    required this.userId,
    required this.name,
    this.description = '',
    this.iconName = 'shield',
    this.colorHex = '#4F46E5',
    this.pin,
    required this.createdAt,
    this.itemCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'description': description,
      'icon_name': iconName,
      'color_hex': colorHex,
      'pin': (pin != null && pin!.trim().isNotEmpty) ? pin!.trim() : null,
      'created_at': createdAt,
    };
  }

  factory VaultModel.fromMap(Map<String, dynamic> map, {int itemCount = 0}) {
    return VaultModel(
      id: map['id'] as int?,
      userId: map['user_id'] as int,
      name: (map['name'] as String?) ?? 'Vault',
      description: (map['description'] as String?) ?? '',
      iconName: (map['icon_name'] as String?) ?? 'shield',
      colorHex: (map['color_hex'] as String?) ?? '#4F46E5',
      pin: map['pin'] as String?,
      createdAt: (map['created_at'] as String?) ?? '',
      itemCount: (map['item_count'] as int?) ?? itemCount,
    );
  }

  VaultModel copyWith({
    int? id,
    int? userId,
    String? name,
    String? description,
    String? iconName,
    String? colorHex,
    String? pin,
    bool clearPin = false,
    String? createdAt,
    int? itemCount,
  }) {
    return VaultModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      description: description ?? this.description,
      iconName: iconName ?? this.iconName,
      colorHex: colorHex ?? this.colorHex,
      pin: clearPin ? null : (pin ?? this.pin),
      createdAt: createdAt ?? this.createdAt,
      itemCount: itemCount ?? this.itemCount,
    );
  }

  Color get color {
    try {
      final hex = colorHex.replaceAll('#', '');
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      }
      return const Color(0xFF4F46E5);
    } catch (_) {
      return const Color(0xFF4F46E5);
    }
  }

  IconData get iconData => getIconForName(iconName);

  bool get isPinProtected => pin != null && pin!.trim().isNotEmpty;

  static IconData getIconForName(String name) {
    switch (name.toLowerCase()) {
      case 'work':
      case 'briefcase':
        return Icons.work_outline;
      case 'finance':
      case 'bank':
      case 'account_balance':
        return Icons.account_balance_outlined;
      case 'lock':
        return Icons.lock_outline;
      case 'vpn_key':
      case 'key':
        return Icons.vpn_key_outlined;
      case 'shopping':
      case 'shopping_bag':
        return Icons.shopping_bag_outlined;
      case 'folder':
        return Icons.folder_outlined;
      case 'cloud':
        return Icons.cloud_outlined;
      case 'code':
      case 'terminal':
        return Icons.code_rounded;
      case 'favorite':
      case 'heart':
        return Icons.favorite_outline;
      case 'star':
        return Icons.star_outline;
      case 'sports_esports':
      case 'gaming':
        return Icons.sports_esports_outlined;
      case 'people':
      case 'family':
        return Icons.people_outline;
      case 'medical':
      case 'health':
        return Icons.medical_services_outlined;
      case 'shield':
      default:
        return Icons.shield_outlined;
    }
  }
}
