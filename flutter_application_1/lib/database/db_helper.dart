import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import '../models/user_model.dart';
import '../models/password_model.dart';
import '../models/vault_model.dart';

/// DatabaseHelper manages our SQLite database operations.
///
/// We use the "Singleton pattern" here:
/// This means only ONE instance of DatabaseHelper exists throughout the app,
/// avoiding open connection conflicts.
class DatabaseHelper {
  // 1. Private constructor ensures nobody can create instances with 'DatabaseHelper()'
  DatabaseHelper._privateConstructor();

  // 2. The single public instance of DatabaseHelper
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  // 3. Database instance reference
  static Database? _database;

  // 4. Getter for database: if already opened, return it; otherwise open it
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initializes the SQLite database file and tables
  Future<Database> _initDatabase() async {
    String path;

    if (kIsWeb) {
      // 1. When running on Web (Chrome, Edge, Safari), use Web FFI factory
      databaseFactory = databaseFactoryFfiWeb;
      path = 'password_vault.db';
    } else {
      // 2. When running on Desktop (macOS, Windows, Linux), use Desktop FFI
      if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      }
      // 3. Mobile (Android/iOS) and Desktop: get native databases path
      final dbPath = await getDatabasesPath();
      path = join(dbPath, 'password_vault.db');
    }

    // Open/create the database with version 6
    final db = await openDatabase(
      path,
      version: 6,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    // Defensive check to guarantee tables & columns exist on existing databases
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS vaults (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER NOT NULL,
          name TEXT NOT NULL,
          description TEXT,
          icon_name TEXT DEFAULT 'shield',
          color_hex TEXT DEFAULT '#4F46E5',
          pin TEXT,
          created_at TEXT,
          FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
        )
      ''');
      final info = await db.rawQuery('PRAGMA table_info(passwords)');
      final colNames = info.map((r) => r['name'] as String).toSet();
      if (!colNames.contains('website_url')) {
        await db.execute('ALTER TABLE passwords ADD COLUMN website_url TEXT');
      }
      if (!colNames.contains('custom_logo')) {
        await db.execute('ALTER TABLE passwords ADD COLUMN custom_logo TEXT');
      }
      if (!colNames.contains('vault_id')) {
        await db.execute('ALTER TABLE passwords ADD COLUMN vault_id INTEGER');
      }
      if (!colNames.contains('is_favorite')) {
        await db.execute('ALTER TABLE passwords ADD COLUMN is_favorite INTEGER DEFAULT 0');
      }
      if (!colNames.contains('totp_secret')) {
        await db.execute('ALTER TABLE passwords ADD COLUMN totp_secret TEXT');
      }
      if (!colNames.contains('custom_fields')) {
        await db.execute('ALTER TABLE passwords ADD COLUMN custom_fields TEXT');
      }
      if (!colNames.contains('expires_at')) {
        await db.execute('ALTER TABLE passwords ADD COLUMN expires_at TEXT');
      }
    } catch (_) {}

    // Ensure default admin user is seeded
    await _seedDefaultAdmin(db);

    // Ensure app_settings table exists for local device settings (e.g. last changed theme)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    return db;
  }

  /// Ensures default administrator account (email: 'admin', password: 'admin') is pre-seeded
  Future<void> _seedDefaultAdmin(Database db) async {
    final existing = await db.query(
      'users',
      where: 'LOWER(email) = ?',
      whereArgs: ['admin'],
    );
    if (existing.isEmpty) {
      await db.insert('users', {
        'name': 'System Administrator',
        'email': 'admin',
        'password': 'admin',
        'role': 'admin',
        'theme_mode': 'dark',
      });
    }
  }

  /// Called when the database is created for the first time
  Future<void> _onCreate(Database db, int version) async {
    // 1. Create Users Table with 4-digit PIN, saved theme mode, and role
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        profile_image TEXT,
        pin TEXT,
        theme_mode TEXT,
        role TEXT DEFAULT 'user'
      )
    ''');

    // 2. Create Vaults Table
    await db.execute('''
      CREATE TABLE vaults (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        description TEXT,
        icon_name TEXT DEFAULT 'shield',
        color_hex TEXT DEFAULT '#4F46E5',
        pin TEXT,
        created_at TEXT,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // 3. Create Passwords Table with website_url, custom_logo, vault_id, is_favorite, totp_secret, custom_fields, expires_at
    await db.execute('''
      CREATE TABLE passwords (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        vault_id INTEGER,
        title TEXT NOT NULL,
        username_or_email TEXT NOT NULL,
        password TEXT NOT NULL,
        category TEXT,
        notes TEXT,
        website_url TEXT,
        custom_logo TEXT,
        is_favorite INTEGER DEFAULT 0,
        totp_secret TEXT,
        custom_fields TEXT,
        expires_at TEXT,
        created_at TEXT,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
        FOREIGN KEY (vault_id) REFERENCES vaults (id) ON DELETE SET NULL
      )
    ''');

    // 4. Create Session Table (Remembers active logged-in user for quick PIN unlock)
    await db.execute('''
      CREATE TABLE session (
        id INTEGER PRIMARY KEY,
        user_id INTEGER NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // 5. Create App Settings Table (Stores persistent local device preferences like last changed theme)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    // Pre-seed default admin
    await _seedDefaultAdmin(db);
  }

  /// Called when upgrading from an older database version
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS app_settings (
          key TEXT PRIMARY KEY,
          value TEXT
        )
      ''');
    } catch (_) {}
    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE users ADD COLUMN pin TEXT');
      } catch (_) {}
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS session (
            id INTEGER PRIMARY KEY,
            user_id INTEGER NOT NULL,
            FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
          )
        ''');
      } catch (_) {}
    }
    if (oldVersion < 3) {
      try {
        await db.execute('ALTER TABLE users ADD COLUMN theme_mode TEXT');
      } catch (_) {}
    }
    if (oldVersion < 4) {
      try {
        await db.execute("ALTER TABLE users ADD COLUMN role TEXT DEFAULT 'user'");
      } catch (_) {}
      try {
        await _seedDefaultAdmin(db);
      } catch (_) {}
    }
    if (oldVersion < 5) {
      try {
        await db.execute('ALTER TABLE passwords ADD COLUMN website_url TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE passwords ADD COLUMN custom_logo TEXT');
      } catch (_) {}
    }
    if (oldVersion < 6) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS vaults (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            name TEXT NOT NULL,
            description TEXT,
            icon_name TEXT DEFAULT 'shield',
            color_hex TEXT DEFAULT '#4F46E5',
            pin TEXT,
            created_at TEXT,
            FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
          )
        ''');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE passwords ADD COLUMN vault_id INTEGER');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE passwords ADD COLUMN is_favorite INTEGER DEFAULT 0');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE passwords ADD COLUMN totp_secret TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE passwords ADD COLUMN custom_fields TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE passwords ADD COLUMN expires_at TEXT');
      } catch (_) {}
    }
  }

  // =========================================================================
  // USER OPERATIONS (Signup, Login, Profile)
  // =========================================================================

  /// Register a new user account.
  /// Returns the registered UserModel with its new ID, or throws an Exception if email exists.
  Future<UserModel> registerUser(UserModel user) async {
    final db = await database;

    // Check if email already exists
    final existing = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [user.email.trim().toLowerCase()],
    );

    if (existing.isNotEmpty) {
      throw Exception('An account with this email already exists.');
    }

    // Prepare map with normalized email
    final userMap = user.toMap();
    userMap['email'] = user.email.trim().toLowerCase();

    // Insert user into 'users' table
    final id = await db.insert('users', userMap);

    return user.copyWith(id: id, email: user.email.trim().toLowerCase());
  }

  /// Authenticate user with email and password.
  /// Returns UserModel if valid, or null if credentials do not match.
  Future<UserModel?> loginUser(String email, String password) async {
    final db = await database;

    final result = await db.query(
      'users',
      where: 'LOWER(email) = ? AND password = ?',
      whereArgs: [email.trim().toLowerCase(), password],
    );

    if (result.isNotEmpty) {
      return UserModel.fromMap(result.first);
    }
    return null;
  }

  /// Get user details by their ID
  Future<UserModel?> getUserById(int id) async {
    final db = await database;
    final result = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (result.isNotEmpty) {
      return UserModel.fromMap(result.first);
    }
    return null;
  }

  /// Update user profile (Name or Profile Photo)
  Future<int> updateUserProfile(UserModel user) async {
    final db = await database;
    return await db.update(
      'users',
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  /// Sets or updates the 4-digit PIN for a user
  Future<void> setUserPin(int userId, String pin) async {
    final db = await database;
    await db.update(
      'users',
      {'pin': pin},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  /// Sets a persistent key-value configuration in local SQLite database (app_settings table)
  Future<void> setLocalSetting(String key, String value) async {
    final db = await database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
    await db.insert(
      'app_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Retrieves a persistent key-value configuration from local SQLite database
  Future<String?> getLocalSetting(String key) async {
    final db = await database;
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS app_settings (
          key TEXT PRIMARY KEY,
          value TEXT
        )
      ''');
      final rows = await db.query(
        'app_settings',
        where: 'key = ?',
        whereArgs: [key],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        return rows.first['value'] as String?;
      }
    } catch (_) {}
    return null;
  }

  /// Persists the last changed theme mode ('light' or 'dark') to localDB
  Future<void> setLocalTheme(String themeMode) async {
    await setLocalSetting('theme_mode', themeMode);
  }

  /// Retrieves the last changed theme mode from localDB (defaults to 'light')
  Future<String> getLocalTheme() async {
    final theme = await getLocalSetting('theme_mode');
    return theme ?? 'light';
  }

  /// Sets or updates the preferred theme mode ('light' or 'dark').
  /// Persists to localDB so the last changed theme is remembered globally on this device.
  Future<void> setUserTheme(int userId, String themeMode) async {
    await setLocalTheme(themeMode);
    final db = await database;
    await db.update(
      'users',
      {'theme_mode': themeMode},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  /// Remembers the logged-in user in SQLite session table
  Future<void> saveUserSession(int userId) async {
    final db = await database;
    await db.delete('session'); // Clear old session
    await db.insert('session', {'id': 1, 'user_id': userId});
  }

  /// Clears the active session when user logs out
  Future<void> clearUserSession() async {
    final db = await database;
    await db.delete('session');
  }

  /// Checks if there is an active remembered user from the last session
  Future<UserModel?> getActiveSessionUser() async {
    final db = await database;
    final sessionRows = await db.query('session', limit: 1);
    if (sessionRows.isEmpty) return null;

    final userId = sessionRows.first['user_id'] as int?;
    if (userId == null) return null;

    return await getUserById(userId);
  }

  // =========================================================================
  // ADMIN PANEL OPERATIONS
  // =========================================================================

  /// Retrieves all registered users along with their total saved password count.
  Future<List<Map<String, dynamic>>> getAllUsersWithStats() async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT 
        u.id, 
        u.name, 
        u.email, 
        u.profile_image, 
        u.pin, 
        u.theme_mode, 
        u.role,
        COUNT(DISTINCT p.id) AS password_count,
        COUNT(DISTINCT v.id) AS vault_count
      FROM users u
      LEFT JOIN passwords p ON u.id = p.user_id
      LEFT JOIN vaults v ON u.id = v.user_id
      GROUP BY u.id, u.name, u.email, u.profile_image, u.pin, u.theme_mode, u.role
      ORDER BY u.id ASC
    ''');
    return results;
  }

  /// Retrieves high-level system statistics for the admin dashboard.
  Future<Map<String, dynamic>> getSystemStats() async {
    final db = await database;

    final usersCountRes = await db.rawQuery('SELECT COUNT(*) as count FROM users');
    final totalUsers = Sqflite.firstIntValue(usersCountRes) ?? 0;

    final passwordsCountRes = await db.rawQuery('SELECT COUNT(*) as count FROM passwords');
    final totalPasswords = Sqflite.firstIntValue(passwordsCountRes) ?? 0;

    final vaultsCountRes = await db.rawQuery('SELECT COUNT(*) as count FROM vaults');
    final totalVaults = Sqflite.firstIntValue(vaultsCountRes) ?? 0;

    final categoriesCountRes = await db.rawQuery(
      "SELECT COUNT(DISTINCT category) as count FROM passwords WHERE category IS NOT NULL AND TRIM(category) != ''",
    );
    final totalCategories = Sqflite.firstIntValue(categoriesCountRes) ?? 0;

    return {
      'totalUsers': totalUsers,
      'totalPasswords': totalPasswords,
      'totalVaults': totalVaults,
      'totalCategories': totalCategories,
    };
  }

  /// Admin operation: Deletes a user account and cascades their passwords.
  /// (Safeguard: Protects the default 'admin' account from accidental deletion)
  Future<void> deleteUserByAdmin(int userId) async {
    final db = await database;

    // Check if user is the main admin
    final user = await getUserById(userId);
    if (user != null && user.email.toLowerCase() == 'admin') {
      throw Exception('The default admin account cannot be deleted.');
    }

    await db.delete('passwords', where: 'user_id = ?', whereArgs: [userId]);
    await db.delete('users', where: 'id = ?', whereArgs: [userId]);
  }

  /// Admin operation: Force reset a user\'s master password
  Future<void> resetUserPasswordByAdmin(int userId, String newPassword) async {
    final db = await database;
    await db.update(
      'users',
      {'password': newPassword},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  /// Admin operation: Remove 4-digit PIN for a user
  Future<void> resetUserPinByAdmin(int userId) async {
    final db = await database;
    await db.update(
      'users',
      {'pin': null},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  /// Admin operation: Update all details of a user (name, photo, password, and PIN/passlock)
  Future<void> adminUpdateUserDetails({
    required int userId,
    required String name,
    required String? profileImage,
    required String password,
    required String? pin,
  }) async {
    final db = await database;
    await db.update(
      'users',
      {
        'name': name.trim(),
        'profile_image': profileImage,
        'password': password,
        'pin': (pin != null && pin.trim().length == 4) ? pin.trim() : null,
      },
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  /// Admin operation: Get all passwords across all users, with user names, emails, and vault info attached
  Future<List<Map<String, dynamic>>> getAllPasswordsAcrossUsers({
    String? searchQuery,
    int? userId,
    int? vaultId,
  }) async {
    final db = await database;
    String sql = '''
      SELECT 
        p.id, 
        p.user_id, 
        p.vault_id,
        p.title, 
        p.username_or_email, 
        p.password, 
        p.category, 
        p.notes, 
        p.website_url,
        p.custom_logo,
        p.totp_secret,
        p.is_favorite,
        p.created_at,
        u.name as user_name,
        u.email as user_email,
        u.profile_image as user_profile_image,
        v.name as vault_name,
        v.color_hex as vault_color,
        v.icon_name as vault_icon
      FROM passwords p
      JOIN users u ON p.user_id = u.id
      LEFT JOIN vaults v ON p.vault_id = v.id
    ''';
    List<dynamic> args = [];
    List<String> conditions = [];

    if (userId != null) {
      conditions.add('p.user_id = ?');
      args.add(userId);
    }

    if (vaultId != null) {
      conditions.add('p.vault_id = ?');
      args.add(vaultId);
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      conditions.add('(p.title LIKE ? OR p.username_or_email LIKE ? OR u.name LIKE ? OR u.email LIKE ? OR p.category LIKE ? OR p.website_url LIKE ? OR v.name LIKE ?)');
      final pattern = '%${searchQuery.trim()}%';
      args.addAll([pattern, pattern, pattern, pattern, pattern, pattern, pattern]);
    }

    if (conditions.isNotEmpty) {
      sql += ' WHERE ${conditions.join(' AND ')}';
    }

    sql += ' ORDER BY p.id DESC';
    return await db.rawQuery(sql, args);
  }

  /// Admin operation: Get all vaults across all users with owner details and item counts
  Future<List<Map<String, dynamic>>> getAllVaultsAcrossUsers({String? searchQuery}) async {
    final db = await database;
    String sql = '''
      SELECT 
        v.id,
        v.user_id,
        v.name,
        v.description,
        v.icon_name,
        v.color_hex,
        v.pin,
        v.created_at,
        u.name as user_name,
        u.email as user_email,
        u.profile_image as user_profile_image,
        COUNT(p.id) as item_count
      FROM vaults v
      JOIN users u ON v.user_id = u.id
      LEFT JOIN passwords p ON v.id = p.vault_id
    ''';
    List<dynamic> args = [];
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      sql += ' WHERE v.name LIKE ? OR v.description LIKE ? OR u.name LIKE ? OR u.email LIKE ?';
      final pattern = '%${searchQuery.trim()}%';
      args.addAll([pattern, pattern, pattern, pattern]);
    }
    sql += ' GROUP BY v.id, v.user_id, v.name, v.description, v.icon_name, v.color_hex, v.pin, v.created_at, u.name, u.email, u.profile_image';
    sql += ' ORDER BY v.id DESC';
    return await db.rawQuery(sql, args);
  }

  /// Admin operation: Delete any password item by ID
  Future<void> deletePasswordByAdmin(int passwordId) async {
    final db = await database;
    await db.delete('passwords', where: 'id = ?', whereArgs: [passwordId]);
  }

  // =========================================================================
  // PASSWORD OPERATIONS (CRUD: Create, Read, Update, Delete)
  // =========================================================================

  /// Save a new password entry for a specific user
  Future<int> addPassword(PasswordItemModel item) async {
    final db = await database;
    return await db.insert('passwords', item.toMap());
  }

  /// Retrieve all passwords belonging ONLY to the logged-in user.
  /// Can also filter by vault, favorites, category, or search query!
  Future<List<PasswordItemModel>> getPasswordsForUser(
    int userId, {
    int? vaultId,
    bool? onlyFavorites,
    String? category,
    String? searchQuery,
  }) async {
    final db = await database;

    String whereClause = 'user_id = ?';
    List<dynamic> whereArguments = [userId];

    // Optional vault filter
    if (vaultId != null) {
      whereClause += ' AND vault_id = ?';
      whereArguments.add(vaultId);
    }

    // Optional favorites filter
    if (onlyFavorites == true) {
      whereClause += ' AND is_favorite = 1';
    }

    // Optional category filter (e.g. "Social", "Work")
    if (category != null && category != 'All') {
      whereClause += ' AND category = ?';
      whereArguments.add(category);
    }

    // Optional search filter (matches title, username, or website url)
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      whereClause += ' AND (title LIKE ? OR username_or_email LIKE ? OR website_url LIKE ? OR notes LIKE ?)';
      final queryPattern = '%${searchQuery.trim()}%';
      whereArguments.add(queryPattern);
      whereArguments.add(queryPattern);
      whereArguments.add(queryPattern);
      whereArguments.add(queryPattern);
    }

    final result = await db.query(
      'passwords',
      where: whereClause,
      whereArgs: whereArguments,
      orderBy: 'is_favorite DESC, id DESC', // Favorites pinned first, then newest
    );

    return result.map((map) => PasswordItemModel.fromMap(map)).toList();
  }

  /// Toggles favorite status for a password entry
  Future<int> togglePasswordFavorite(int passwordId, int userId, bool isFavorite) async {
    final db = await database;
    return await db.update(
      'passwords',
      {'is_favorite': isFavorite ? 1 : 0},
      where: 'id = ? AND user_id = ?',
      whereArgs: [passwordId, userId],
    );
  }

  /// Update an existing password entry
  Future<int> updatePassword(PasswordItemModel item) async {
    final db = await database;
    return await db.update(
      'passwords',
      item.toMap(),
      where: 'id = ? AND user_id = ?',
      whereArgs: [item.id, item.userId],
    );
  }

  /// Delete a password entry
  Future<int> deletePassword(int id, int userId) async {
    final db = await database;
    return await db.delete(
      'passwords',
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, userId],
    );
  }

  /// Count how many passwords this user has saved (optionally within a vault)
  Future<int> getPasswordCount(int userId, {int? vaultId}) async {
    final db = await database;
    String sql = 'SELECT COUNT(*) as count FROM passwords WHERE user_id = ?';
    List<dynamic> args = [userId];
    if (vaultId != null) {
      sql += ' AND vault_id = ?';
      args.add(vaultId);
    }
    final result = await db.rawQuery(sql, args);
    if (result.isNotEmpty) {
      return Sqflite.firstIntValue(result) ?? 0;
    }
    return 0;
  }

  // =========================================================================
  // VAULT OPERATIONS (Create, Read, Update, Delete)
  // =========================================================================

  /// Creates a new vault for the user
  Future<VaultModel> createVault(VaultModel vault) async {
    final db = await database;
    final id = await db.insert('vaults', vault.toMap());
    return vault.copyWith(id: id);
  }

  /// Gets all vaults for a specific user, with item counts computed
  Future<List<VaultModel>> getVaultsForUser(int userId) async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT 
        v.id,
        v.user_id,
        v.name,
        v.description,
        v.icon_name,
        v.color_hex,
        v.pin,
        v.created_at,
        COUNT(p.id) as item_count
      FROM vaults v
      LEFT JOIN passwords p ON v.id = p.vault_id
      WHERE v.user_id = ?
      GROUP BY v.id, v.user_id, v.name, v.description, v.icon_name, v.color_hex, v.pin, v.created_at
      ORDER BY v.id ASC
    ''', [userId]);

    return results.map((r) => VaultModel.fromMap(r)).toList();
  }

  /// Gets a specific vault by ID
  Future<VaultModel?> getVaultById(int vaultId) async {
    final db = await database;
    final res = await db.query('vaults', where: 'id = ?', whereArgs: [vaultId]);
    if (res.isNotEmpty) {
      return VaultModel.fromMap(res.first);
    }
    return null;
  }

  /// Updates an existing vault
  Future<int> updateVault(VaultModel vault) async {
    final db = await database;
    return await db.update(
      'vaults',
      vault.toMap(),
      where: 'id = ? AND user_id = ?',
      whereArgs: [vault.id, vault.userId],
    );
  }

  /// Deletes a vault and resets its passwords' vault_id to NULL
  Future<void> deleteVault(int vaultId, int userId) async {
    final db = await database;
    await db.update(
      'passwords',
      {'vault_id': null},
      where: 'vault_id = ? AND user_id = ?',
      whereArgs: [vaultId, userId],
    );
    await db.delete(
      'vaults',
      where: 'id = ? AND user_id = ?',
      whereArgs: [vaultId, userId],
    );
  }

  /// Gets or creates the default "Personal Vault" for a user
  Future<VaultModel> getOrCreateDefaultVault(int userId) async {
    final db = await database;
    final existing = await db.query(
      'vaults',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'id ASC',
      limit: 1,
    );

    if (existing.isNotEmpty) {
      return VaultModel.fromMap(existing.first);
    }

    final defaultVault = VaultModel(
      userId: userId,
      name: 'Personal Vault',
      description: 'Your primary password vault',
      iconName: 'shield',
      colorHex: '#4F46E5',
      createdAt: DateTime.now().toIso8601String(),
    );

    final id = await db.insert('vaults', defaultVault.toMap());
    return defaultVault.copyWith(id: id);
  }

  // =========================================================================
  // EXPORT & IMPORT OPERATIONS
  // =========================================================================

  /// Exports all saved passwords of the user as a formatted JSON String.
  Future<String> exportPasswordsToJson(int userId) async {
    final list = await getPasswordsForUser(userId);
    final vaults = await getVaultsForUser(userId);

    final exportData = {
      'backup_type': 'passwords_export',
      'version': 2,
      'exported_at': DateTime.now().toIso8601String(),
      'vaults': vaults.map((v) => v.toMap()).toList(),
      'passwords': list.map((item) => {
        'title': item.title,
        'username_or_email': item.usernameOrEmail,
        'password': item.password,
        'category': item.category,
        'notes': item.notes,
        'website_url': item.websiteUrl,
        'custom_logo': item.customLogo,
        'vault_id': item.vaultId,
        'is_favorite': item.isFavorite ? 1 : 0,
        'totp_secret': item.totpSecret,
        'custom_fields': item.customFieldsJson,
        'expires_at': item.expiresAt,
        'created_at': item.createdAt,
      }).toList(),
    };

    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(exportData);
  }

  /// Imports passwords from any valid JSON string into the user's account.
  /// Universal importer: handles raw password lists, single user backups, and system backups.
  /// Returns the number of successfully imported passwords.
  Future<int> importPasswordsFromJson(int userId, String jsonString) async {
    final dynamic decoded = jsonDecode(jsonString);
    int importedCount = 0;
    final nowString = DateTime.now().toIso8601String();

    List passwordsList = [];
    List vaultsList = [];

    if (decoded is Map) {
      if (decoded['passwords'] is List) {
        passwordsList = decoded['passwords'] as List;
        if (decoded['vaults'] is List) {
          vaultsList = decoded['vaults'] as List;
        }
      } else if (decoded['users'] is List) {
        // System backup: extract passwords and vaults from all users
        for (final u in decoded['users']) {
          if (u is Map) {
            if (u['vaults'] is List) vaultsList.addAll(u['vaults']);
            if (u['passwords'] is List) passwordsList.addAll(u['passwords']);
          }
        }
      } else if (decoded['user'] is Map && decoded['passwords'] is List) {
        passwordsList = decoded['passwords'] as List;
        if (decoded['vaults'] is List) {
          vaultsList = decoded['vaults'] as List;
        }
      }
    } else if (decoded is List) {
      if (decoded.isNotEmpty &&
          decoded.first is Map &&
          (decoded.first.containsKey('passwords') || decoded.first.containsKey('user'))) {
        for (final item in decoded) {
          if (item is Map) {
            if (item['vaults'] is List) vaultsList.addAll(item['vaults']);
            if (item['passwords'] is List) passwordsList.addAll(item['passwords']);
          }
        }
      } else {
        passwordsList = decoded;
      }
    }

    if (passwordsList.isEmpty && decoded is! List && (decoded is! Map || (!decoded.containsKey('passwords') && !decoded.containsKey('users')))) {
      throw const FormatException('Invalid JSON format: No password entries found in file.');
    }

    // 1. Map custom vaults for this user if present
    final Map<int, int> vaultIdMap = {};
    if (vaultsList.isNotEmpty) {
      final existingVaults = await getVaultsForUser(userId);
      for (final v in vaultsList) {
        if (v is Map) {
          final oldId = v['id'] as int?;
          final vName = (v['name'] ?? 'Vault').toString().trim();
          if (vName.isEmpty) continue;

          final match = existingVaults.where((ev) => ev.name.toLowerCase() == vName.toLowerCase()).firstOrNull;
          if (match != null && match.id != null) {
            if (oldId != null) vaultIdMap[oldId] = match.id!;
          } else {
            final created = await createVault(VaultModel(
              userId: userId,
              name: vName,
              description: (v['description'] ?? '').toString(),
              iconName: (v['icon_name'] ?? 'shield').toString(),
              colorHex: (v['color_hex'] ?? '#4F46E5').toString(),
              pin: v['pin'] as String?,
              createdAt: (v['created_at'] ?? nowString).toString(),
            ));
            if (oldId != null && created.id != null) {
              vaultIdMap[oldId] = created.id!;
            }
          }
        }
      }
    }

    final db = await database;

    // 2. Insert passwords
    for (final item in passwordsList) {
      if (item is Map) {
        final title = (item['title'] ?? '').toString().trim();
        final username = (item['username_or_email'] ?? item['username'] ?? '').toString().trim();
        final password = (item['password'] ?? '').toString();
        final rawVaultId = item['vault_id'] as int?;
        final mappedVaultId = rawVaultId != null ? vaultIdMap[rawVaultId] : null;

        if (title.isNotEmpty && password.isNotEmpty) {
          // Check if password already exists to avoid redundant duplicate entries
          final existing = await db.query(
            'passwords',
            where: 'user_id = ? AND LOWER(title) = ? AND LOWER(username_or_email) = ?',
            whereArgs: [userId, title.toLowerCase(), username.toLowerCase()],
          );

          final customFieldsVal = (item['custom_fields'] is String)
              ? item['custom_fields'] as String
              : (item['custom_fields'] != null ? jsonEncode(item['custom_fields']) : null);

          if (existing.isNotEmpty) {
            // Update existing entry with newer info
            final existingId = existing.first['id'] as int;
            await db.update(
              'passwords',
              {
                'password': password,
                'category': (item['category'] ?? existing.first['category'] ?? 'Other').toString(),
                'notes': (item['notes'] ?? existing.first['notes'] ?? '').toString(),
                'website_url': item['website_url'] as String? ?? existing.first['website_url'] as String?,
                'custom_logo': item['custom_logo'] as String? ?? existing.first['custom_logo'] as String?,
                'vault_id': mappedVaultId ?? existing.first['vault_id'] as int?,
                'is_favorite': (item['is_favorite'] == 1 || item['is_favorite'] == true) ? 1 : (existing.first['is_favorite'] ?? 0),
                'totp_secret': item['totp_secret'] as String? ?? existing.first['totp_secret'] as String?,
                'custom_fields': customFieldsVal ?? existing.first['custom_fields'] as String?,
                'expires_at': item['expires_at'] as String? ?? existing.first['expires_at'] as String?,
              },
              where: 'id = ?',
              whereArgs: [existingId],
            );
            importedCount++;
          } else {
            // Add new password
            final newPassword = PasswordItemModel(
              userId: userId,
              vaultId: mappedVaultId,
              title: title,
              usernameOrEmail: username,
              password: password,
              category: (item['category'] ?? 'Other').toString(),
              notes: (item['notes'] ?? '').toString(),
              websiteUrl: item['website_url'] as String?,
              customLogo: item['custom_logo'] as String?,
              isFavorite: item['is_favorite'] == 1 || item['is_favorite'] == true,
              totpSecret: item['totp_secret'] as String?,
              customFieldsJson: customFieldsVal,
              expiresAt: item['expires_at'] as String?,
              createdAt: (item['created_at'] ?? nowString).toString(),
            );
            await addPassword(newPassword);
            importedCount++;
          }
        }
      }
    }

    return importedCount;
  }

  /// Admin: Exports a particular user's profile and password vault as formatted JSON.
  Future<String> exportSingleUserDataToJson(int userId) async {
    final user = await getUserById(userId);
    if (user == null) {
      throw Exception('User with ID $userId not found.');
    }

    final vaults = await getVaultsForUser(userId);
    final passwords = await getPasswordsForUser(userId);

    final exportData = {
      'backup_type': 'single_user_backup',
      'version': 2,
      'exported_at': DateTime.now().toIso8601String(),
      'user': {
        'id': user.id,
        'name': user.name,
        'email': user.email,
        'password': user.password,
        'pin': user.pin,
        'profile_image': user.profileImage,
        'theme_mode': user.themeMode,
        'role': user.role,
      },
      'vaults': vaults.map((v) => v.toMap()).toList(),
      'passwords': passwords.map((p) => {
        'title': p.title,
        'username_or_email': p.usernameOrEmail,
        'password': p.password,
        'category': p.category,
        'notes': p.notes,
        'website_url': p.websiteUrl,
        'custom_logo': p.customLogo,
        'vault_id': p.vaultId,
        'is_favorite': p.isFavorite ? 1 : 0,
        'totp_secret': p.totpSecret,
        'custom_fields': p.customFieldsJson,
        'expires_at': p.expiresAt,
        'created_at': p.createdAt,
      }).toList(),
    };

    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(exportData);
  }

  /// Admin: Exports all registered users and all their password vaults as a complete system backup JSON.
  Future<String> exportAllUsersDataToJson() async {
    final db = await database;
    final users = await db.query('users');
    final List<Map<String, dynamic>> allUsersExport = [];

    for (final u in users) {
      final userId = u['id'] as int;
      final vaults = await getVaultsForUser(userId);
      final passwords = await getPasswordsForUser(userId);

      allUsersExport.add({
        'user': {
          'id': userId,
          'name': u['name'],
          'email': u['email'],
          'password': u['password'],
          'pin': u['pin'],
          'profile_image': u['profile_image'],
          'theme_mode': u['theme_mode'],
          'role': u['role'],
        },
        'vaults': vaults.map((v) => v.toMap()).toList(),
        'passwords': passwords.map((p) => {
          'title': p.title,
          'username_or_email': p.usernameOrEmail,
          'password': p.password,
          'category': p.category,
          'notes': p.notes,
          'website_url': p.websiteUrl,
          'custom_logo': p.customLogo,
          'vault_id': p.vaultId,
          'is_favorite': p.isFavorite ? 1 : 0,
          'totp_secret': p.totpSecret,
          'custom_fields': p.customFieldsJson,
          'expires_at': p.expiresAt,
          'created_at': p.createdAt,
        }).toList(),
      });
    }

    final fullBackup = {
      'backup_type': 'system_all_users_backup',
      'version': 2,
      'exported_at': DateTime.now().toIso8601String(),
      'total_users': allUsersExport.length,
      'users': allUsersExport,
    };

    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(fullBackup);
  }

  /// Admin: Imports a system backup containing all users, a single user, or passwords.
  /// Universal importer: handles single_user_backup, system_all_users_backup, and password lists.
  Future<Map<String, int>> importAllUsersDataFromJson(String jsonString) async {
    final dynamic decoded = jsonDecode(jsonString);

    List usersList = [];
    if (decoded is Map) {
      if (decoded['users'] is List) {
        usersList = decoded['users'] as List;
      } else if (decoded['user'] is Map || decoded['backup_type'] == 'single_user_backup') {
        // Single user export being restored via system backup
        usersList = [decoded];
      } else if (decoded['passwords'] is List) {
        // Passwords export being restored via system backup
        usersList = [
          {
            'user': decoded['user'] ?? {
              'name': 'Restored User',
              'email': 'restored_${DateTime.now().millisecondsSinceEpoch}@vault.local',
            },
            'vaults': decoded['vaults'] ?? [],
            'passwords': decoded['passwords'],
          }
        ];
      }
    } else if (decoded is List) {
      if (decoded.isNotEmpty && decoded.first is Map && (decoded.first.containsKey('user') || decoded.first.containsKey('email'))) {
        usersList = decoded;
      } else {
        // Raw list of passwords
        usersList = [
          {
            'user': {
              'name': 'Restored User',
              'email': 'restored_${DateTime.now().millisecondsSinceEpoch}@vault.local',
            },
            'vaults': [],
            'passwords': decoded,
          }
        ];
      }
    }

    if (usersList.isEmpty) {
      throw const FormatException('Invalid JSON format: Could not find user or password data in backup.');
    }

    int totalUsersProcessed = 0;
    int totalPasswordsImported = 0;
    final db = await database;
    final nowString = DateTime.now().toIso8601String();

    for (final userEntry in usersList) {
      if (userEntry is! Map) continue;

      final userMap = userEntry['user'];
      final passwordsList = userEntry['passwords'];

      if (userMap is Map) {
        final email = (userMap['email'] ?? '').toString().trim().toLowerCase();
        final name = (userMap['name'] ?? email).toString().trim();
        final rawPassword = (userMap['password'] ?? 'password123').toString();
        final pin = userMap['pin'] as String?;
        final profileImage = userMap['profile_image'] as String?;
        final themeMode = (userMap['theme_mode'] ?? 'dark').toString();
        final role = (userMap['role'] ?? 'user').toString();

        if (email.isEmpty) continue;

        // Find existing user or create a new user
        final existing = await db.query(
          'users',
          where: 'LOWER(email) = ?',
          whereArgs: [email],
        );

        int targetUserId;
        if (existing.isNotEmpty) {
          targetUserId = existing.first['id'] as int;
          // Optionally update pin / password if present
          if (pin != null && pin.isNotEmpty && (existing.first['pin'] == null || (existing.first['pin'] as String).isEmpty)) {
            await db.update('users', {'pin': pin}, where: 'id = ?', whereArgs: [targetUserId]);
          }
        } else {
          targetUserId = await db.insert('users', {
            'name': name.isNotEmpty ? name : 'Imported User',
            'email': email,
            'password': rawPassword.isNotEmpty ? rawPassword : 'password123',
            'pin': pin,
            'profile_image': profileImage,
            'theme_mode': themeMode,
            'role': role,
          });
          totalUsersProcessed++;
        }

        // Restore custom vaults for this user if present
        final Map<int, int> vaultIdMap = {};
        if (userEntry['vaults'] is List) {
          final existingVaults = await getVaultsForUser(targetUserId);
          for (final v in userEntry['vaults']) {
            if (v is Map) {
              final oldId = v['id'] as int?;
              final vName = (v['name'] ?? 'Vault').toString().trim();
              if (vName.isEmpty) continue;

              final match = existingVaults.where((ev) => ev.name.toLowerCase() == vName.toLowerCase()).firstOrNull;
              if (match != null && match.id != null) {
                if (oldId != null) vaultIdMap[oldId] = match.id!;
              } else {
                final created = await createVault(VaultModel(
                  userId: targetUserId,
                  name: vName,
                  description: (v['description'] ?? '').toString(),
                  iconName: (v['icon_name'] ?? 'shield').toString(),
                  colorHex: (v['color_hex'] ?? '#4F46E5').toString(),
                  pin: v['pin'] as String?,
                  createdAt: (v['created_at'] ?? nowString).toString(),
                ));
                if (oldId != null && created.id != null) {
                  vaultIdMap[oldId] = created.id!;
                }
              }
            }
          }
        }

        // Import passwords for this user
        if (passwordsList is List) {
          for (final p in passwordsList) {
            if (p is Map) {
              final title = (p['title'] ?? '').toString().trim();
              final username = (p['username_or_email'] ?? p['username'] ?? '').toString().trim();
              final password = (p['password'] ?? '').toString();
              final rawVaultId = p['vault_id'] as int?;
              final mappedVaultId = rawVaultId != null ? vaultIdMap[rawVaultId] : null;

              if (title.isNotEmpty && password.isNotEmpty) {
                // Check if password already exists to avoid exact duplicates
                final existingPw = await db.query(
                  'passwords',
                  where: 'user_id = ? AND LOWER(title) = ? AND LOWER(username_or_email) = ?',
                  whereArgs: [targetUserId, title.toLowerCase(), username.toLowerCase()],
                );

                final customFieldsVal = (p['custom_fields'] is String)
                    ? p['custom_fields'] as String
                    : (p['custom_fields'] != null ? jsonEncode(p['custom_fields']) : null);

                if (existingPw.isNotEmpty) {
                  final existingId = existingPw.first['id'] as int;
                  await db.update(
                    'passwords',
                    {
                      'password': password,
                      'category': (p['category'] ?? existingPw.first['category'] ?? 'Other').toString(),
                      'notes': (p['notes'] ?? existingPw.first['notes'] ?? '').toString(),
                      'website_url': p['website_url'] as String? ?? existingPw.first['website_url'] as String?,
                      'custom_logo': p['custom_logo'] as String? ?? existingPw.first['custom_logo'] as String?,
                      'vault_id': mappedVaultId ?? existingPw.first['vault_id'] as int?,
                      'is_favorite': (p['is_favorite'] == 1 || p['is_favorite'] == true) ? 1 : (existingPw.first['is_favorite'] ?? 0),
                      'totp_secret': p['totp_secret'] as String? ?? existingPw.first['totp_secret'] as String?,
                      'custom_fields': customFieldsVal ?? existingPw.first['custom_fields'] as String?,
                      'expires_at': p['expires_at'] as String? ?? existingPw.first['expires_at'] as String?,
                    },
                    where: 'id = ?',
                    whereArgs: [existingId],
                  );
                  totalPasswordsImported++;
                } else {
                  final item = PasswordItemModel(
                    userId: targetUserId,
                    vaultId: mappedVaultId,
                    title: title,
                    usernameOrEmail: username,
                    password: password,
                    category: (p['category'] ?? 'Other').toString(),
                    notes: (p['notes'] ?? '').toString(),
                    websiteUrl: p['website_url'] as String?,
                    customLogo: p['custom_logo'] as String?,
                    isFavorite: p['is_favorite'] == 1 || p['is_favorite'] == true,
                    totpSecret: p['totp_secret'] as String?,
                    customFieldsJson: customFieldsVal,
                    expiresAt: p['expires_at'] as String?,
                    createdAt: (p['created_at'] ?? nowString).toString(),
                  );
                  await addPassword(item);
                  totalPasswordsImported++;
                }
              }
            }
          }
        }
      }
    }

    return {
      'usersCount': totalUsersProcessed,
      'passwordsCount': totalPasswordsImported,
    };
  }
}
