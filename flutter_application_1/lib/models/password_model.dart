import 'dart:convert';

/// Represents an optional extra custom key-value field for a credential (e.g., "PIN", "Recovery Email", "Secret Question").
class CustomFieldModel {
  final String label;
  final String value;
  final bool isSecret;

  const CustomFieldModel({
    required this.label,
    required this.value,
    this.isSecret = false,
  });

  Map<String, dynamic> toMap() => {
        'label': label,
        'value': value,
        'isSecret': isSecret,
      };

  factory CustomFieldModel.fromMap(Map<String, dynamic> map) => CustomFieldModel(
        label: (map['label'] ?? '').toString(),
        value: (map['value'] ?? '').toString(),
        isSecret: map['isSecret'] == true,
      );
}

/// Model class representing a saved Password Entry.
///
/// Notice the [userId] field: This links each password to the specific user
/// who created it (foreign key relationship).
/// [vaultId]: Optional link to a specific custom vault (Personal, Work, etc.).
class PasswordItemModel {
  final int? id;
  final int userId; // Which user does this password belong to?
  final int? vaultId; // Which vault in the user's account? (null = Default)
  final String title; // E.g., "Google", "GitHub", "Netflix", "Wi-Fi"
  final String usernameOrEmail; // E.g., "john@gmail.com"
  final String password; // The actual password
  final String category; // E.g., "Social", "Work", "Email", "Finance", "Other"
  final String notes; // Extra info, e.g. "Security question answers"
  final String? websiteUrl; // Optional website address, e.g. "https://google.com"
  final String? customLogo; // Optional custom website logo stored as Base64 image
  final bool isFavorite; // Starred / pinned to top
  final String? totpSecret; // Authenticator 2FA secret key (RFC 6238 Base32)
  final String? customFieldsJson; // JSON serialized list of CustomFieldModel
  final String? expiresAt; // Expiry or rotation reminder date (ISO8601 string)
  final String createdAt; // Timestamp when saved

  PasswordItemModel({
    this.id,
    required this.userId,
    this.vaultId,
    required this.title,
    required this.usernameOrEmail,
    required this.password,
    this.category = 'Other',
    this.notes = '',
    this.websiteUrl,
    this.customLogo,
    this.isFavorite = false,
    this.totpSecret,
    this.customFieldsJson,
    this.expiresAt,
    required this.createdAt,
  });

  /// Decodes [customFieldsJson] into a list of [CustomFieldModel]
  List<CustomFieldModel> get customFields {
    if (customFieldsJson == null || customFieldsJson!.trim().isEmpty) {
      return [];
    }
    try {
      final List<dynamic> list = jsonDecode(customFieldsJson!);
      return list
          .whereType<Map<String, dynamic>>()
          .map((m) => CustomFieldModel.fromMap(m))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Whether this password entry has an expired rotation reminder
  bool get isExpired {
    if (expiresAt == null || expiresAt!.trim().isEmpty) return false;
    try {
      final exp = DateTime.parse(expiresAt!);
      return DateTime.now().isAfter(exp);
    } catch (_) {
      return false;
    }
  }

  /// Converts this model into a Map for SQLite insertion/updating
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'vault_id': vaultId,
      'title': title,
      'username_or_email': usernameOrEmail,
      'password': password,
      'category': category,
      'notes': notes,
      'website_url': websiteUrl,
      'custom_logo': customLogo,
      'is_favorite': isFavorite ? 1 : 0,
      'totp_secret': totpSecret,
      'custom_fields': customFieldsJson,
      'expires_at': expiresAt,
      'created_at': createdAt,
    };
  }

  /// Recreates a [PasswordItemModel] from a Map retrieved from SQLite
  factory PasswordItemModel.fromMap(Map<String, dynamic> map) {
    return PasswordItemModel(
      id: map['id'] as int?,
      userId: map['user_id'] as int,
      vaultId: map['vault_id'] as int?,
      title: (map['title'] as String?) ?? '',
      usernameOrEmail: (map['username_or_email'] as String?) ?? '',
      password: (map['password'] as String?) ?? '',
      category: (map['category'] as String?) ?? 'Other',
      notes: (map['notes'] as String?) ?? '',
      websiteUrl: map['website_url'] as String?,
      customLogo: map['custom_logo'] as String?,
      isFavorite: (map['is_favorite'] == 1 || map['is_favorite'] == true),
      totpSecret: map['totp_secret'] as String?,
      customFieldsJson: map['custom_fields'] as String?,
      expiresAt: map['expires_at'] as String?,
      createdAt: (map['created_at'] as String?) ?? '',
    );
  }

  /// Creates a copy of this object with optional updated fields
  PasswordItemModel copyWith({
    int? id,
    int? userId,
    int? vaultId,
    bool clearVaultId = false,
    String? title,
    String? usernameOrEmail,
    String? password,
    String? category,
    String? notes,
    String? websiteUrl,
    String? customLogo,
    bool? isFavorite,
    String? totpSecret,
    bool clearTotp = false,
    String? customFieldsJson,
    String? expiresAt,
    bool clearExpiry = false,
    String? createdAt,
  }) {
    return PasswordItemModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      vaultId: clearVaultId ? null : (vaultId ?? this.vaultId),
      title: title ?? this.title,
      usernameOrEmail: usernameOrEmail ?? this.usernameOrEmail,
      password: password ?? this.password,
      category: category ?? this.category,
      notes: notes ?? this.notes,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      customLogo: customLogo ?? this.customLogo,
      isFavorite: isFavorite ?? this.isFavorite,
      totpSecret: clearTotp ? null : (totpSecret ?? this.totpSecret),
      customFieldsJson: customFieldsJson ?? this.customFieldsJson,
      expiresAt: clearExpiry ? null : (expiresAt ?? this.expiresAt),
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
