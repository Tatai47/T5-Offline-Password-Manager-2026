/// Model class representing a User in our Password Manager app.
///
/// Each user has their own account with:
/// - [id]: A unique number given by the database (1, 2, 3...)
/// - [name]: The user's full name
/// - [email]: The user's login email
/// - [password]: The user's master login password
/// - [profileImage]: A Base64 encoded string representing the user's photo
/// - [pin]: An optional 4-digit quick unlock passcode (e.g. '1234')
/// - [themeMode]: Saved theme preference for this account ('light' or 'dark')
/// - [role]: User privilege role ('admin' or 'user')
class UserModel {
  final int? id;
  final String name;
  final String email;
  final String password;
  final String? profileImage;
  final String? pin;
  final String? themeMode;
  final String role;

  UserModel({
    this.id,
    required this.name,
    required this.email,
    required this.password,
    this.profileImage,
    this.pin,
    this.themeMode,
    this.role = 'user',
  });

  /// Helper getter to quickly check if this user has admin privileges
  bool get isAdmin => role == 'admin' || email.trim().toLowerCase() == 'admin';

  /// Converts a [UserModel] object into a Map (Key-Value pairs)
  /// so that SQLite can insert or update it in the database.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'password': password,
      'profile_image': profileImage,
      'pin': pin,
      'theme_mode': themeMode,
      'role': role,
    };
  }

  /// Creates a [UserModel] object from a Map (retrieved from SQLite).
  factory UserModel.fromMap(Map<String, dynamic> map) {
    final emailVal = map['email'] as String? ?? '';
    final roleVal = (map['role'] as String?) ??
        (emailVal.trim().toLowerCase() == 'admin' ? 'admin' : 'user');

    return UserModel(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      email: emailVal,
      password: map['password'] as String? ?? '',
      profileImage: map['profile_image'] as String?,
      pin: map['pin'] as String?,
      themeMode: map['theme_mode'] as String?,
      role: roleVal,
    );
  }

  /// Helper method to create a copy of the user with updated fields.
  UserModel copyWith({
    int? id,
    String? name,
    String? email,
    String? password,
    String? profileImage,
    String? pin,
    String? themeMode,
    String? role,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
      profileImage: profileImage ?? this.profileImage,
      pin: pin ?? this.pin,
      themeMode: themeMode ?? this.themeMode,
      role: role ?? this.role,
    );
  }
}
