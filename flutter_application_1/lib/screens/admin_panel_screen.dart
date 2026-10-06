import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../database/db_helper.dart';
import '../models/password_model.dart';
import '../models/user_model.dart';
import '../models/vault_model.dart';
import '../utils/app_theme.dart';
import '../utils/file_helper.dart';
import '../utils/url_helper.dart';
import '../widgets/create_vault_dialog.dart';
import '../widgets/user_avatar.dart';
import '../widgets/vault_logo_avatar.dart';
import 'home_screen.dart';
import 'login_screen.dart';

/// The AdminPanelScreen allows system administrators to oversee all registered users,
/// view system metrics, reset forgotten user credentials, and export/import data
/// both globally for all users and individually per user.
class AdminPanelScreen extends StatefulWidget {
  final UserModel currentUser;

  const AdminPanelScreen({
    super.key,
    required this.currentUser,
  });

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _vaults = [];
  Map<String, dynamic> _systemStats = {
    'totalUsers': 0,
    'totalPasswords': 0,
    'totalVaults': 0,
    'totalCategories': 0,
  };

  late TabController _tabController;

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  String _vaultSearchQuery = '';
  final TextEditingController _vaultSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAdminData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _vaultSearchController.dispose();
    super.dispose();
  }

  /// Loads registered users, all system vaults, and global system metrics
  Future<void> _loadAdminData() async {
    setState(() => _isLoading = true);

    try {
      final usersList = await DatabaseHelper.instance.getAllUsersWithStats();
      final vaultsList = await DatabaseHelper.instance.getAllVaultsAcrossUsers();
      final stats = await DatabaseHelper.instance.getSystemStats();

      if (mounted) {
        setState(() {
          _users = usersList;
          _vaults = vaultsList;
          _systemStats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading admin data: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  /// Filters users based on search input
  List<Map<String, dynamic>> get _filteredUsers {
    if (_searchQuery.trim().isEmpty) return _users;
    final query = _searchQuery.trim().toLowerCase();
    return _users.where((u) {
      final name = (u['name'] as String? ?? '').toLowerCase();
      final email = (u['email'] as String? ?? '').toLowerCase();
      return name.contains(query) || email.contains(query);
    }).toList();
  }

  /// Filters vaults based on search input
  List<Map<String, dynamic>> get _filteredVaults {
    if (_vaultSearchQuery.trim().isEmpty) return _vaults;
    final query = _vaultSearchQuery.trim().toLowerCase();
    return _vaults.where((v) {
      final name = (v['name'] as String? ?? '').toLowerCase();
      final desc = (v['description'] as String? ?? '').toLowerCase();
      final userName = (v['user_name'] as String? ?? '').toLowerCase();
      final userEmail = (v['user_email'] as String? ?? '').toLowerCase();
      return name.contains(query) || desc.contains(query) || userName.contains(query) || userEmail.contains(query);
    }).toList();
  }

  // =========================================================================
  // EXPORT & IMPORT ACTIONS (SYSTEM-WIDE & PER-USER)
  // =========================================================================

  /// Admin: Export complete system archive containing all users and their passwords
  Future<void> _exportAllUsersData() async {
    try {
      final jsonContent = await DatabaseHelper.instance.exportAllUsersDataToJson();
      final now = DateTime.now();
      final dateStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final fileName = 'system_all_users_backup_$dateStr.json';

      await FileHelper.downloadJsonFile(
        fileName: fileName,
        content: jsonContent,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('All users backup downloaded ($fileName)')),
              ],
            ),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  /// Admin: Import a system backup file to restore or merge all users and passwords
  Future<void> _importAllUsersData() async {
    try {
      final jsonString = await FileHelper.pickAndReadJsonFile();
      if (jsonString == null) return; // User cancelled dialog

      final result = await DatabaseHelper.instance.importAllUsersDataFromJson(jsonString);
      final usersCount = result['usersCount'] ?? 0;
      final passwordsCount = result['passwordsCount'] ?? 0;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('System restored! Added $usersCount new users and $passwordsCount passwords.'),
                ),
              ],
            ),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadAdminData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import error: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  /// Admin: Export a particular user's data and password vault as JSON
  Future<void> _exportSingleUser(int userId, String userName) async {
    try {
      final jsonContent = await DatabaseHelper.instance.exportSingleUserDataToJson(userId);
      final sanitizedName = userName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase();
      final dateStr = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'user_${sanitizedName}_backup_$dateStr.json';

      await FileHelper.downloadJsonFile(
        fileName: fileName,
        content: jsonContent,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('Backup for $userName downloaded ($fileName)')),
              ],
            ),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  /// Admin: Import passwords into a particular user's vault
  Future<void> _importSingleUser(int userId, String userName) async {
    try {
      final jsonString = await FileHelper.pickAndReadJsonFile();
      if (jsonString == null) return; // User cancelled

      final count = await DatabaseHelper.instance.importPasswordsFromJson(userId, jsonString);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('Imported $count passwords into $userName\'s vault!')),
              ],
            ),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadAdminData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import error: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  // =========================================================================
  // VAULT & DATA VIEWING ACTIONS
  // =========================================================================

  /// Opens a dedicated viewer to inspect an individual user's stored passwords & data
  void _showUserVaultDialog(Map<String, dynamic> user, {int? initialVaultId}) {
    showDialog(
      context: context,
      builder: (dialogCtx) => _UserVaultDialog(
        user: user,
        initialVaultId: initialVaultId,
        onDataChanged: _loadAdminData,
      ),
    );
  }

  /// Opens a system-wide explorer to view all passwords across all users in the database
  void _showAllUsersDataDialog({int? initialVaultId}) {
    showDialog(
      context: context,
      builder: (dialogCtx) => _AllUsersDataDialog(
        initialVaultId: initialVaultId,
        onDataChanged: _loadAdminData,
      ),
    );
  }

  /// Opens the CreateVaultDialog for a specific user (or prompts user selection if creating globally)
  Future<void> _showCreateVaultForAnyUser({int? preselectedUserId}) async {
    if (_users.isEmpty) return;

    int targetUserId = preselectedUserId ?? (_users.first['id'] as int);

    if (preselectedUserId == null && _users.length > 1) {
      final selectedId = await showDialog<int>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Select User for New Vault'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _users.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, idx) {
                  final u = _users[idx];
                  return ListTile(
                    leading: UserAvatar(
                      base64Image: u['profile_image'] as String?,
                      displayName: u['name'] as String? ?? 'User',
                      radius: 18,
                    ),
                    title: Text(u['name'] as String? ?? 'User', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(u['email'] as String? ?? ''),
                    onTap: () => Navigator.pop(ctx, u['id'] as int),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      );
      if (selectedId == null) return;
      targetUserId = selectedId;
    }

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => CreateVaultDialog(
        userId: targetUserId,
        onVaultSaved: _loadAdminData,
      ),
    );
  }

  /// Confirms and deletes a vault as administrator
  Future<void> _confirmDeleteVault(int vaultId, int userId, String vaultName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Vault "$vaultName"?'),
        content: const Text(
          'Are you sure you want to permanently delete this vault? Saved credentials will remain in the user account, but their vault assignment will be cleared.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Vault'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DatabaseHelper.instance.deleteVault(vaultId, userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Vault "$vaultName" was deleted.'),
            backgroundColor: AppTheme.success,
          ),
        );
        _loadAdminData();
      }
    }
  }

  // =========================================================================
  // USER MANAGEMENT ACTIONS
  // =========================================================================

  /// Opens a dialog to edit any user's Name, Photo, Password, and 4-digit Passlock
  Future<void> _showEditUserDialog(int userId) async {
    final user = await DatabaseHelper.instance.getUserById(userId);
    if (user == null) return;

    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: user.name);
    final passwordController = TextEditingController(text: user.password);
    final pinController = TextEditingController(text: user.pin ?? '');
    String? currentProfileImage = user.profileImage;
    bool isPasswordHidden = true;

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickImage(ImageSource source) async {
              try {
                final picker = ImagePicker();
                final picked = await picker.pickImage(
                  source: source,
                  maxWidth: 512,
                  maxHeight: 512,
                  imageQuality: 80,
                );
                if (picked != null) {
                  final bytes = await picked.readAsBytes();
                  setDialogState(() {
                    currentProfileImage = base64Encode(bytes);
                  });
                }
              } catch (e) {
                if (dialogCtx.mounted) {
                  ScaffoldMessenger.of(dialogCtx).showSnackBar(
                    SnackBar(content: Text('Error picking photo: $e'), backgroundColor: AppTheme.error),
                  );
                }
              }
            }

            void showPhotoOptions() {
              showModalBottomSheet(
                context: dialogCtx,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (sheetCtx) => SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.photo_library_outlined, color: AppTheme.primary),
                          title: const Text('Choose from Gallery'),
                          onTap: () {
                            Navigator.pop(sheetCtx);
                            pickImage(ImageSource.gallery);
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.camera_alt_outlined, color: AppTheme.primary),
                          title: const Text('Take a Photo'),
                          onTap: () {
                            Navigator.pop(sheetCtx);
                            pickImage(ImageSource.camera);
                          },
                        ),
                        if (currentProfileImage != null)
                          ListTile(
                            leading: const Icon(Icons.delete_outline, color: AppTheme.error),
                            title: const Text('Remove Photo'),
                            onTap: () {
                              Navigator.pop(sheetCtx);
                              setDialogState(() {
                                currentProfileImage = null;
                              });
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }

            final isDark = Theme.of(context).brightness == Brightness.dark;

            return AlertDialog(
              backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: Row(
                children: [
                  const Icon(Icons.manage_accounts, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Edit User: ${user.name}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Clickable Profile Photo with Edit Badge
                        Stack(
                          children: [
                            UserAvatar(
                              base64Image: currentProfileImage,
                              displayName: nameController.text.isNotEmpty ? nameController.text : 'U',
                              radius: 42,
                              onTap: showPhotoOptions,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: showPhotoOptions,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TextButton(
                          onPressed: showPhotoOptions,
                          child: const Text('Change Photo', style: TextStyle(fontSize: 12)),
                        ),
                        const SizedBox(height: 12),

                        // Full Name
                        TextFormField(
                          controller: nameController,
                          textCapitalization: TextCapitalization.words,
                          style: TextStyle(
                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Full Name',
                            labelStyle: TextStyle(
                              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                            ),
                            prefixIcon: const Icon(Icons.person_outline),
                            filled: true,
                            fillColor: isDark ? AppTheme.darkBackground : Colors.white,
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Name cannot be empty';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Email (Read-only identifier)
                        TextFormField(
                          initialValue: user.email,
                          readOnly: true,
                          style: TextStyle(
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Email / Username (Permanent ID)',
                            labelStyle: TextStyle(
                              color: isDark ? AppTheme.darkTextMuted : AppTheme.textMuted,
                            ),
                            prefixIcon: const Icon(Icons.email_outlined),
                            filled: true,
                            fillColor: isDark
                                ? AppTheme.darkBackground.withValues(alpha: 0.6)
                                : const Color(0xFFF1F5F9),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Master Password
                        TextFormField(
                          controller: passwordController,
                          obscureText: isPasswordHidden,
                          style: TextStyle(
                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Master Password',
                            labelStyle: TextStyle(
                              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                            ),
                            prefixIcon: const Icon(Icons.lock_outline),
                            filled: true,
                            fillColor: isDark ? AppTheme.darkBackground : Colors.white,
                            suffixIcon: IconButton(
                              icon: Icon(
                                isPasswordHidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                size: 20,
                              ),
                              onPressed: () {
                                setDialogState(() {
                                  isPasswordHidden = !isPasswordHidden;
                                });
                              },
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Password cannot be empty';
                            }
                            if (val.trim().length < 4) {
                              return 'Password must be at least 4 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // 4-Digit Passlock / PIN
                        TextFormField(
                          controller: pinController,
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                          style: TextStyle(
                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                          ),
                          decoration: InputDecoration(
                            labelText: '4-Digit Passlock / PIN',
                            labelStyle: TextStyle(
                              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                            ),
                            hintText: 'Leave empty to remove PIN',
                            counterText: '',
                            prefixIcon: const Icon(Icons.pin_outlined),
                            filled: true,
                            fillColor: isDark ? AppTheme.darkBackground : Colors.white,
                            suffixIcon: pinController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      setDialogState(() {
                                        pinController.clear();
                                      });
                                    },
                                  )
                                : null,
                          ),
                          validator: (val) {
                            if (val != null && val.trim().isNotEmpty) {
                              if (val.trim().length != 4 || int.tryParse(val.trim()) == null) {
                                return 'PIN must be exactly 4 digits';
                              }
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    final nav = Navigator.of(dialogCtx);
                    final messenger = ScaffoldMessenger.of(context);

                    final newName = nameController.text.trim();
                    final newPass = passwordController.text.trim();
                    final pinText = pinController.text.trim();
                    final newPin = pinText.length == 4 ? pinText : null;

                    await DatabaseHelper.instance.adminUpdateUserDetails(
                      userId: userId,
                      name: newName,
                      profileImage: currentProfileImage,
                      password: newPass,
                      pin: newPin,
                    );

                    nav.pop();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Expanded(child: Text('User details updated for $newName!')),
                          ],
                        ),
                        backgroundColor: AppTheme.success,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    _loadAdminData();
                  },
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Dialog to reset a user's master password
  void _showResetPasswordDialog(int userId, String userName) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Reset Password for $userName',
          style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter a new master password for this user:',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: passwordController,
                style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'New Password',
                  labelStyle: TextStyle(
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                  ),
                  prefixIcon: const Icon(Icons.lock_reset),
                  filled: true,
                  fillColor: isDark ? AppTheme.darkBackground : Colors.white,
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a password';
                  }
                  if (val.trim().length < 4) {
                    return 'Password must be at least 4 characters';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final nav = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              final newPass = passwordController.text.trim();

              await DatabaseHelper.instance.resetUserPasswordByAdmin(userId, newPass);
              nav.pop();
              messenger.showSnackBar(
                SnackBar(
                  content: Text('Password updated for $userName!'),
                  backgroundColor: AppTheme.success,
                ),
              );
            },
            child: const Text('Save Password'),
          ),
        ],
      ),
    );
  }

  /// Dialog to clear a user's 4-digit PIN
  void _confirmResetPin(int userId, String userName) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Remove PIN for $userName',
          style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
        ),
        content: Text(
          'This will clear the 4-digit quick unlock PIN for this user. They can log in using their master password.',
          style: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () async {
              final nav = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);

              await DatabaseHelper.instance.resetUserPinByAdmin(userId);
              nav.pop();
              messenger.showSnackBar(
                SnackBar(
                  content: Text('PIN removed for $userName.'),
                  backgroundColor: AppTheme.success,
                ),
              );
              _loadAdminData();
            },
            child: const Text('Remove PIN'),
          ),
        ],
      ),
    );
  }

  /// Confirmation dialog before permanently deleting a user account
  void _confirmDeleteUser(int userId, String userName, String userEmail) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (userEmail.trim().toLowerCase() == 'admin') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The primary administrator account cannot be deleted.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete User "$userName"?',
          style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
        ),
        content: Text(
          'Warning: This will permanently delete the account ($userEmail) and all passwords stored in their vault. This action cannot be undone.',
          style: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () async {
              final nav = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);

              try {
                await DatabaseHelper.instance.deleteUserByAdmin(userId);
                nav.pop();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('User $userName was deleted.'),
                    backgroundColor: AppTheme.success,
                  ),
                );
                _loadAdminData();
              } catch (e) {
                nav.pop();
                messenger.showSnackBar(
                  SnackBar(content: Text('Delete error: $e'), backgroundColor: AppTheme.error),
                );
              }
            },
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );
  }

  /// Sign out admin
  void _signOut() async {
    await DatabaseHelper.instance.clearUserSession();
    // Keep last changed theme in localDB (do not reset to light)
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideNav = screenWidth > 840;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.amber, Colors.orangeAccent],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.shield_rounded, color: Colors.black, size: 18),
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                'Admin Console',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        actions: [
          // Switch to personal vault
          if (isWideNav)
            TextButton.icon(
              icon: const Icon(Icons.lock_outline, size: 18),
              label: const Text('My Vault'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => HomeScreen(currentUser: widget.currentUser),
                  ),
                );
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.lock_outline),
              tooltip: 'My Vault',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => HomeScreen(currentUser: widget.currentUser),
                  ),
                );
              },
            ),

          // View all users data
          if (isWideNav)
            Tooltip(
              message: 'View all users saved passwords',
              child: TextButton.icon(
                icon: const Icon(Icons.dataset_outlined, size: 18),
                label: const Text('All Passwords'),
                onPressed: () => _showAllUsersDataDialog(),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.dataset_outlined),
              tooltip: 'All Users Passwords',
              onPressed: () => _showAllUsersDataDialog(),
            ),

          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Data',
            onPressed: _loadAdminData,
          ),
          // Sign Out button
          IconButton(
            icon: const Icon(Icons.logout, color: AppTheme.error),
            tooltip: 'Sign Out',
            onPressed: _signOut,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1060),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : NestedScrollView(
                    headerSliverBuilder: (context, innerBoxIsScrolled) => [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 1. Responsive System Stats Overview (4 Cards)
                              _buildStatsOverview(isDark),

                              const SizedBox(height: 16),

                              // 2. Modern Segmented Tab Navigation
                              Container(
                                decoration: BoxDecoration(
                                  color: isDark ? AppTheme.darkSurface : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isDark ? AppTheme.darkCardBorder : AppTheme.cardBorder,
                                  ),
                                ),
                                child: TabBar(
                                  controller: _tabController,
                                  indicatorSize: TabBarIndicatorSize.tab,
                                  dividerColor: Colors.transparent,
                                  indicator: BoxDecoration(
                                    color: AppTheme.primary,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  labelColor: Colors.white,
                                  unselectedLabelColor: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  tabs: [
                                    Tab(
                                      icon: const Icon(Icons.people_alt_outlined, size: 18),
                                      text: 'Users (${_users.length})',
                                    ),
                                    Tab(
                                      icon: const Icon(Icons.shield_outlined, size: 18),
                                      text: 'Vaults Hub (${_vaults.length})',
                                    ),
                                    const Tab(
                                      icon: Icon(Icons.cloud_sync_outlined, size: 18),
                                      text: 'Data & Backup',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    body: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildUsersTab(isDark),
                        _buildVaultsTab(isDark),
                        _buildBackupTab(isDark),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  /// System Metric Cards (Total Users, Passwords, Multi-Vaults, Categories & 2FA)
  Widget _buildStatsOverview(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        final cards = [
          _buildStatCard(
            icon: Icons.people_alt_outlined,
            iconColor: AppTheme.primary,
            title: 'Registered Users',
            value: '${_systemStats['totalUsers'] ?? 0}',
            subtitle: 'Active user accounts',
            isDark: isDark,
          ),
          _buildStatCard(
            icon: Icons.shield_outlined,
            iconColor: Colors.teal,
            title: 'Multi-Vaults',
            value: '${_systemStats['totalVaults'] ?? 0}',
            subtitle: 'Isolated vaults created',
            isDark: isDark,
          ),
          _buildStatCard(
            icon: Icons.vpn_key_outlined,
            iconColor: Colors.amber.shade700,
            title: 'Stored Passwords',
            value: '${_systemStats['totalPasswords'] ?? 0}',
            subtitle: 'Encrypted credentials',
            isDark: isDark,
          ),
          _buildStatCard(
            icon: Icons.category_outlined,
            iconColor: Colors.purpleAccent,
            title: 'Categories & 2FA',
            value: '${_systemStats['totalCategories'] ?? 0}',
            subtitle: 'Tags & TOTP keys',
            isDark: isDark,
          ),
        ];

        if (width >= 820) {
          return Row(
            children: cards
                .map((c) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: c,
                      ),
                    ))
                .toList(),
          );
        } else if (width >= 480) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: Padding(padding: const EdgeInsets.all(4), child: cards[0])),
                  Expanded(child: Padding(padding: const EdgeInsets.all(4), child: cards[1])),
                ],
              ),
              Row(
                children: [
                  Expanded(child: Padding(padding: const EdgeInsets.all(4), child: cards[2])),
                  Expanded(child: Padding(padding: const EdgeInsets.all(4), child: cards[3])),
                ],
              ),
            ],
          );
        } else {
          return Column(
            children: cards
                .map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: c,
                    ))
                .toList(),
          );
        }
      },
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String subtitle,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.darkCardBorder : AppTheme.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? AppTheme.darkTextMuted : AppTheme.textMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Tab 1: Users Directory
  Widget _buildUsersTab(bool isDark) {
    return RefreshIndicator(
      onRefresh: _loadAdminData,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'REGISTERED USERS (${_filteredUsers.length})',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: isDark ? AppTheme.darkTextMuted : AppTheme.textMuted,
                ),
              ),
              Text(
                'Default Admin: admin / admin',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppTheme.primaryLight : AppTheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Search by user name or email...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 14),
          if (_filteredUsers.isEmpty)
            _buildEmptyUsersState()
          else
            ..._filteredUsers.map((u) => _buildUserCard(u, isDark)),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  /// Tab 2: Vaults Hub (NEW)
  Widget _buildVaultsTab(bool isDark) {
    final filtered = _filteredVaults;
    return RefreshIndicator(
      onRefresh: _loadAdminData,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ALL SYSTEM VAULTS (${filtered.length})',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: isDark ? AppTheme.darkTextMuted : AppTheme.textMuted,
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Create Vault'),
                onPressed: () => _showCreateVaultForAnyUser(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _vaultSearchController,
            onChanged: (val) => setState(() => _vaultSearchQuery = val),
            decoration: InputDecoration(
              hintText: 'Search vaults by name, user, or description...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _vaultSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _vaultSearchController.clear();
                        setState(() => _vaultSearchQuery = '');
                      },
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 14),
          if (filtered.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Icon(Icons.shield_outlined, size: 48, color: AppTheme.textSecondary.withValues(alpha: 0.4)),
                    const SizedBox(height: 12),
                    const Text('No vaults found', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 6),
                    Text(
                      _vaultSearchQuery.isNotEmpty ? 'Try a different search keyword' : 'Create the first vault for a user',
                      style: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else
            ...filtered.map((v) => _buildVaultCard(v, isDark)),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  /// Individual Vault Card for Vaults Hub
  Widget _buildVaultCard(Map<String, dynamic> vault, bool isDark) {
    final vaultId = vault['id'] as int;
    final userId = vault['user_id'] as int;
    final vaultName = vault['name'] as String? ?? 'Vault';
    final description = vault['description'] as String? ?? '';
    final iconName = vault['icon_name'] as String? ?? 'shield';
    final colorHex = vault['color_hex'] as String? ?? '#4F46E5';
    final pin = vault['pin'] as String?;
    final userName = vault['user_name'] as String? ?? 'User';
    final userEmail = vault['user_email'] as String? ?? '';
    final userProfileImage = vault['user_profile_image'] as String?;
    final itemCount = vault['item_count'] as int? ?? 0;
    final iconData = VaultModel.getIconForName(iconName);

    Color vaultColor;
    try {
      final hex = colorHex.replaceAll('#', '');
      vaultColor = Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      vaultColor = AppTheme.primary;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkCardBorder : AppTheme.cardBorder,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 560;

            final vaultInfo = Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: vaultColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: vaultColor.withValues(alpha: 0.3)),
                  ),
                  child: Icon(iconData, color: vaultColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              vaultName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (pin != null && pin.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Tooltip(
                              message: 'Protected by Vault PIN',
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.lock_clock, size: 11, color: Colors.amber),
                                    SizedBox(width: 3),
                                    Text(
                                      'PIN',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              UserAvatar(
                                base64Image: userProfileImage,
                                displayName: userName,
                                radius: 9,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                userName,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: vaultColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$itemCount items',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: vaultColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );

            final actionButtons = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('Inspect'),
                  onPressed: () {
                    final userMatch = _users.where((u) => u['id'] == userId).firstOrNull ?? {
                      'id': userId,
                      'name': userName,
                      'email': userEmail,
                      'profile_image': userProfileImage,
                      'role': 'user',
                    };
                    _showUserVaultDialog(userMatch, initialVaultId: vaultId);
                  },
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 19, color: AppTheme.error),
                  tooltip: 'Delete Vault',
                  onPressed: () => _confirmDeleteVault(vaultId, userId, vaultName),
                ),
              ],
            );

            if (isWide) {
              return Row(
                children: [
                  Expanded(child: vaultInfo),
                  actionButtons,
                ],
              );
            } else {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  vaultInfo,
                  const Divider(height: 18),
                  Align(
                    alignment: Alignment.centerRight,
                    child: actionButtons,
                  ),
                ],
              );
            }
          },
        ),
      ),
    );
  }

  /// Tab 3: System Data & Backups
  Widget _buildBackupTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        _buildSystemBackupCard(isDark),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppTheme.darkCardBorder : AppTheme.cardBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.security_outlined, color: AppTheme.success, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'T5 Offline Cryptographic Vault Engine',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Zero cloud tracking • Offline SQLite database • Schema v6 with Isolated Multi-Vaults',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                '• All passwords, TOTP secrets, notes, and metadata are encrypted and persisted locally.\n'
                '• Multi-Vault segregation guarantees data compartmentalization per user account.\n'
                '• System JSON backups preserve vault structures and map seamlessly during restore.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  /// System-Wide Data Management Banner (Export All Users / Import System Backup)
  Widget _buildSystemBackupCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkCardBorder : AppTheme.cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.cloud_sync_outlined, color: AppTheme.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'System Data Management',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Export or import full database archive containing all user accounts, multi-vaults, and passwords.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.dataset_outlined, size: 18),
                label: const Text('View All Users\' Data'),
                onPressed: () => _showAllUsersDataDialog(),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Export All Users Data (.json)'),
                onPressed: _exportAllUsersData,
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.upload_rounded, size: 18),
                label: const Text('Import System Backup (.json)'),
                onPressed: _importAllUsersData,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Single user row card with per-user export, import, reset, and delete actions
  Widget _buildUserCard(Map<String, dynamic> user, bool isDark) {
    final userId = user['id'] as int;
    final userName = user['name'] as String? ?? 'User';
    final userEmail = user['email'] as String? ?? '';
    final profileImg = user['profile_image'] as String?;
    final pin = user['pin'] as String?;
    final role = user['role'] as String? ?? (userEmail == 'admin' ? 'admin' : 'user');
    final passwordCount = user['password_count'] as int? ?? 0;
    final vaultCount = user['vault_count'] as int? ?? 0;
    final isPrimaryAdmin = userEmail.toLowerCase() == 'admin';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPrimaryAdmin
              ? Colors.amber.withValues(alpha: 0.5)
              : (isDark ? AppTheme.darkCardBorder : AppTheme.cardBorder),
          width: isPrimaryAdmin ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 640;

            final userInfo = Row(
              children: [
                UserAvatar(
                  base64Image: profileImg,
                  displayName: userName,
                  radius: 24,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              userName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Role Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isPrimaryAdmin
                                  ? Colors.amber.withValues(alpha: 0.18)
                                  : AppTheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              role.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isPrimaryAdmin ? Colors.amber : AppTheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        userEmail,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          // Vaults pill
                          InkWell(
                            borderRadius: BorderRadius.circular(6),
                            onTap: () => _showUserVaultDialog(user),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AppTheme.primary.withValues(alpha: 0.3),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.shield_outlined, size: 13, color: AppTheme.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$vaultCount Vaults',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Passwords pill
                          InkWell(
                            borderRadius: BorderRadius.circular(6),
                            onTap: () => _showUserVaultDialog(user),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppTheme.accent.withValues(alpha: 0.15)
                                    : AppTheme.accent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AppTheme.accent.withValues(alpha: 0.3),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.vpn_key_outlined, size: 13, color: AppTheme.accent),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$passwordCount Passwords',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.accent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // PIN Status
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                pin != null && pin.isNotEmpty ? Icons.lock_clock : Icons.lock_open,
                                size: 14,
                                color: pin != null && pin.isNotEmpty ? AppTheme.success : (isDark ? AppTheme.darkTextMuted : AppTheme.textMuted),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                pin != null && pin.isNotEmpty ? 'PIN: Active' : 'PIN: None',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: pin != null && pin.isNotEmpty ? AppTheme.success : (isDark ? AppTheme.darkTextMuted : AppTheme.textMuted),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );

            // Responsive Action buttons
            Widget actionButtons;
            if (isWide) {
              actionButtons = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.visibility_outlined, size: 20),
                    tooltip: "View $userName's Vaults & Passwords",
                    color: AppTheme.accent,
                    onPressed: () => _showUserVaultDialog(user),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_moderator_outlined, size: 20),
                    tooltip: "Create New Vault for $userName",
                    color: Colors.teal,
                    onPressed: () => _showCreateVaultForAnyUser(preselectedUserId: userId),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    tooltip: 'Edit Name, Photo, Password & PIN',
                    color: AppTheme.primary,
                    onPressed: () => _showEditUserDialog(userId),
                  ),
                  IconButton(
                    icon: const Icon(Icons.download_outlined, size: 20),
                    tooltip: "Export $userName's Data (.json)",
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                    onPressed: () => _exportSingleUser(userId, userName),
                  ),
                  IconButton(
                    icon: const Icon(Icons.upload_file_outlined, size: 20),
                    tooltip: "Import Passwords into $userName's Vault",
                    color: isDark ? Colors.tealAccent : Colors.teal,
                    onPressed: () => _importSingleUser(userId, userName),
                  ),
                  IconButton(
                    icon: const Icon(Icons.password_outlined, size: 20),
                    tooltip: 'Reset Password',
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                    onPressed: () => _showResetPasswordDialog(userId, userName),
                  ),
                  if (pin != null && pin.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.pin_outlined, size: 20),
                      tooltip: 'Remove 4-digit PIN',
                      color: Colors.amber,
                      onPressed: () => _confirmResetPin(userId, userName),
                    ),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: isPrimaryAdmin ? Colors.grey : AppTheme.error,
                    ),
                    tooltip: isPrimaryAdmin ? 'Primary admin cannot be deleted' : 'Delete User',
                    onPressed: isPrimaryAdmin
                        ? null
                        : () => _confirmDeleteUser(userId, userName, userEmail),
                  ),
                ],
              );
            } else {
              // Mobile compact action toolbar
              actionButtons = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    icon: const Icon(Icons.shield_outlined, size: 16),
                    label: Text('Vaults ($vaultCount)'),
                    onPressed: () => _showUserVaultDialog(user),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 19),
                    tooltip: 'Edit User Profile',
                    onPressed: () => _showEditUserDialog(userId),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    tooltip: 'More actions',
                    onSelected: (val) {
                      switch (val) {
                        case 'create_vault':
                          _showCreateVaultForAnyUser(preselectedUserId: userId);
                          break;
                        case 'export':
                          _exportSingleUser(userId, userName);
                          break;
                        case 'import':
                          _importSingleUser(userId, userName);
                          break;
                        case 'reset_pwd':
                          _showResetPasswordDialog(userId, userName);
                          break;
                        case 'reset_pin':
                          if (pin != null && pin.isNotEmpty) {
                            _confirmResetPin(userId, userName);
                          }
                          break;
                        case 'delete':
                          if (!isPrimaryAdmin) {
                            _confirmDeleteUser(userId, userName, userEmail);
                          }
                          break;
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'create_vault',
                        child: Row(
                          children: [
                            Icon(Icons.add_moderator_outlined, size: 18, color: Colors.teal),
                            SizedBox(width: 8),
                            Text('Create Vault'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'export',
                        child: Row(
                          children: [
                            Icon(Icons.download_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('Export Data (.json)'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'import',
                        child: Row(
                          children: [
                            Icon(Icons.upload_file_outlined, size: 18, color: Colors.teal),
                            SizedBox(width: 8),
                            Text('Import Passwords'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'reset_pwd',
                        child: Row(
                          children: [
                            Icon(Icons.password_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('Reset Password'),
                          ],
                        ),
                      ),
                      if (pin != null && pin.isNotEmpty)
                        const PopupMenuItem(
                          value: 'reset_pin',
                          child: Row(
                            children: [
                              Icon(Icons.pin_outlined, size: 18, color: Colors.amber),
                              SizedBox(width: 8),
                              Text('Remove PIN'),
                            ],
                          ),
                        ),
                      if (!isPrimaryAdmin)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, size: 18, color: AppTheme.error),
                              SizedBox(width: 8),
                              Text('Delete User', style: TextStyle(color: AppTheme.error)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              );
            }

            if (isWide) {
              return Row(
                children: [
                  Expanded(child: userInfo),
                  actionButtons,
                ],
              );
            } else {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  userInfo,
                  const Divider(height: 18),
                  Align(
                    alignment: Alignment.centerRight,
                    child: actionButtons,
                  ),
                ],
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildEmptyUsersState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.search_off, size: 48, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            const Text(
              'No users found matching query',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// INDIVIDUAL USER VAULT VIEWER DIALOG
// =============================================================================

/// Modal dialog allowing the administrator to inspect, search, reveal passwords,
/// copy credentials, and delete individual password items for a specific user.
class _UserVaultDialog extends StatefulWidget {
  final Map<String, dynamic> user;
  final int? initialVaultId;
  final VoidCallback onDataChanged;

  const _UserVaultDialog({
    required this.user,
    this.initialVaultId,
    required this.onDataChanged,
  });

  @override
  State<_UserVaultDialog> createState() => _UserVaultDialogState();
}

class _UserVaultDialogState extends State<_UserVaultDialog> {
  bool _isLoading = true;
  List<PasswordItemModel> _passwords = [];
  List<VaultModel> _vaults = [];
  int? _selectedVaultId;
  final Set<int> _revealedIds = {};
  String _searchQuery = '';
  String _selectedCategory = 'All';
  final TextEditingController _searchController = TextEditingController();

  static const List<String> _categories = [
    'All',
    'Social',
    'Work',
    'Email',
    'Finance',
    'Entertainment',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _selectedVaultId = widget.initialVaultId;
    _loadPasswords();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPasswords() async {
    setState(() => _isLoading = true);
    final userId = widget.user['id'] as int;

    try {
      final list = await DatabaseHelper.instance.getPasswordsForUser(
        userId,
        vaultId: _selectedVaultId,
        category: _selectedCategory == 'All' ? null : _selectedCategory,
        searchQuery: _searchQuery,
      );
      final vaultsList = await DatabaseHelper.instance.getVaultsForUser(userId);

      if (mounted) {
        setState(() {
          _passwords = list;
          _vaults = vaultsList;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('$label copied to clipboard!'),
          ],
        ),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _deletePassword(PasswordItemModel item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete "${item.title}"?'),
        content: const Text(
          'Are you sure you want to permanently delete this password entry from this user\'s vault? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && item.id != null) {
      await DatabaseHelper.instance.deletePasswordByAdmin(item.id!);
      widget.onDataChanged();
      _loadPasswords();
    }
  }

  Future<void> _exportThisUser() async {
    final userId = widget.user['id'] as int;
    final userName = widget.user['name'] as String? ?? 'user';
    try {
      final jsonContent = await DatabaseHelper.instance.exportSingleUserDataToJson(userId);
      final sanitizedName = userName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase();
      final dateStr = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'user_${sanitizedName}_backup_$dateStr.json';

      await FileHelper.downloadJsonFile(
        fileName: fileName,
        content: jsonContent,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded vault backup for $userName ($fileName)'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _importThisUser() async {
    final userId = widget.user['id'] as int;
    final userName = widget.user['name'] as String? ?? 'user';
    try {
      final jsonString = await FileHelper.pickAndReadJsonFile();
      if (jsonString == null) return;

      final count = await DatabaseHelper.instance.importPasswordsFromJson(userId, jsonString);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('Imported $count passwords into $userName\'s vault!')),
              ],
            ),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadPasswords();
        widget.onDataChanged();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import error: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  String _formatDate(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoString;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userName = widget.user['name'] as String? ?? 'User';
    final userEmail = widget.user['email'] as String? ?? '';
    final profileImg = widget.user['profile_image'] as String?;
    final pin = widget.user['pin'] as String?;
    final role = widget.user['role'] as String? ?? (userEmail == 'admin' ? 'admin' : 'user');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? AppTheme.darkBackground : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 820),
        child: Column(
          children: [
            // 1. Header Bar with User Identity
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : AppTheme.background,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? AppTheme.darkCardBorder : AppTheme.cardBorder,
                  ),
                ),
              ),
              child: Row(
                children: [
                  UserAvatar(
                    base64Image: profileImg,
                    displayName: userName,
                    radius: 24,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                '$userName\'s Vault',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                role.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$userEmail • ${_passwords.length} saved credentials • PIN: ${pin != null && pin.isNotEmpty ? 'Active' : 'None'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // 2. Search & Category Filters
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      _searchQuery = val;
                      _loadPasswords();
                    },
                    decoration: InputDecoration(
                      hintText: 'Search within $userName\'s passwords...',
                      isDense: true,
                      prefixIcon: const Icon(Icons.search, size: 18),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                _searchQuery = '';
                                _loadPasswords();
                              },
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Vault Filter Chips Bar
                  if (_vaults.isNotEmpty) ...[
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ChoiceChip(
                            avatar: const Icon(Icons.all_inbox_outlined, size: 14),
                            label: Text('All Vaults (${_vaults.fold<int>(0, (sum, v) => sum + v.itemCount)})'),
                            selected: _selectedVaultId == null,
                            onSelected: (_) {
                              setState(() => _selectedVaultId = null);
                              _loadPasswords();
                            },
                          ),
                          const SizedBox(width: 6),
                          ..._vaults.map((v) {
                            final isSel = _selectedVaultId == v.id;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                avatar: Icon(v.iconData, size: 14, color: isSel ? Colors.white : v.color),
                                label: Text('${v.name} (${v.itemCount})'),
                                selected: isSel,
                                selectedColor: v.color,
                                onSelected: (selected) {
                                  setState(() => _selectedVaultId = selected ? v.id : null);
                                  _loadPasswords();
                                },
                              ),
                            );
                          }),
                          ActionChip(
                            avatar: const Icon(Icons.add, size: 14, color: AppTheme.primary),
                            label: const Text(
                              'Add Vault',
                              style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            onPressed: () async {
                              await showDialog(
                                context: context,
                                builder: (ctx) => CreateVaultDialog(
                                  userId: widget.user['id'] as int,
                                  onVaultSaved: () {
                                    _loadPasswords();
                                    widget.onDataChanged();
                                  },
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Category Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _categories.map((cat) {
                        final isSelected = _selectedCategory == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(
                              cat,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _selectedCategory = cat);
                                _loadPasswords();
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 16),

            // 3. Password Entries List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _passwords.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.vpn_key_off_outlined,
                                  size: 48,
                                  color: AppTheme.textSecondary.withValues(alpha: 0.4),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _searchQuery.isNotEmpty || _selectedCategory != 'All' || _selectedVaultId != null
                                      ? 'No credentials matching current filter'
                                      : 'This user has no saved passwords yet.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                          itemCount: _passwords.length,
                          itemBuilder: (context, index) {
                            final item = _passwords[index];
                            final isRevealed = item.id != null && _revealedIds.contains(item.id);
                            final catColor = AppTheme.getCategoryColor(item.category);
                            final catIcon = AppTheme.getCategoryIcon(item.category);
                            final itemVault = _vaults.where((v) => v.id == item.vaultId).firstOrNull;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDark ? AppTheme.darkSurface : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isDark ? AppTheme.darkCardBorder : AppTheme.cardBorder,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Top row: Logo + Title + Badges + Delete Button
                                  Row(
                                    children: [
                                      VaultLogoAvatar(
                                        customLogo: item.customLogo,
                                        websiteUrl: item.websiteUrl,
                                        fallbackIcon: catIcon,
                                        fallbackColor: catColor,
                                        size: 36,
                                        borderRadius: 8,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.title,
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 2,
                                              crossAxisAlignment: WrapCrossAlignment.center,
                                              children: [
                                                Text(
                                                  item.category,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: catColor,
                                                  ),
                                                ),
                                                if (itemVault != null) ...[
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: itemVault.color.withValues(alpha: 0.12),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(itemVault.iconData, size: 10, color: itemVault.color),
                                                        const SizedBox(width: 3),
                                                        Text(
                                                          itemVault.name,
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.bold,
                                                            color: itemVault.color,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                                if (item.totpSecret != null && item.totpSecret!.trim().isNotEmpty) ...[
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: AppTheme.success.withValues(alpha: 0.12),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: const Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(Icons.timer_outlined, size: 10, color: AppTheme.success),
                                                        SizedBox(width: 3),
                                                        Text(
                                                          '2FA',
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.bold,
                                                            color: AppTheme.success,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 19, color: AppTheme.error),
                                        tooltip: 'Delete this credential',
                                        onPressed: () => _deletePassword(item),
                                      ),
                                    ],
                                  ),

                                  // Optional Website URL with open & copy
                                  if (item.websiteUrl != null && item.websiteUrl!.trim().isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? AppTheme.darkBackground.withValues(alpha: 0.5)
                                            : AppTheme.background,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.language_outlined, size: 16, color: AppTheme.textSecondary),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: InkWell(
                                              onTap: () => openUrlInBrowser(item.websiteUrl!),
                                              child: Text(
                                                item.websiteUrl!,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: AppTheme.primaryLight,
                                                  decoration: TextDecoration.underline,
                                                  decorationColor: AppTheme.primaryLight.withValues(alpha: 0.5),
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.open_in_new, size: 15, color: AppTheme.primaryLight),
                                            tooltip: 'Open in new tab',
                                            onPressed: () => openUrlInBrowser(item.websiteUrl!),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.copy, size: 15),
                                            tooltip: 'Copy website URL',
                                            onPressed: () => _copyToClipboard(item.websiteUrl!, 'Website URL'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],

                                  const SizedBox(height: 10),

                                  // Username row with copy
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? AppTheme.darkBackground.withValues(alpha: 0.5)
                                          : AppTheme.background,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.person_outline, size: 16, color: AppTheme.textSecondary),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: SelectableText(
                                            item.usernameOrEmail,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.copy, size: 15),
                                          tooltip: 'Copy username/email',
                                          onPressed: () => _copyToClipboard(item.usernameOrEmail, 'Username'),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 8),

                                  // Password row with show/hide toggle & copy
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? AppTheme.darkBackground.withValues(alpha: 0.5)
                                          : AppTheme.background,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.lock_outline, size: 16, color: AppTheme.textSecondary),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            isRevealed ? item.password : '••••••••••••',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontFamily: isRevealed ? 'monospace' : null,
                                              fontWeight: isRevealed ? FontWeight.w600 : FontWeight.bold,
                                              letterSpacing: isRevealed ? 0.5 : 2.0,
                                              color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            isRevealed ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                            size: 16,
                                          ),
                                          tooltip: isRevealed ? 'Hide Password' : 'Show Password',
                                          onPressed: () {
                                            if (item.id == null) return;
                                            setState(() {
                                              if (isRevealed) {
                                                _revealedIds.remove(item.id!);
                                              } else {
                                                _revealedIds.add(item.id!);
                                              }
                                            });
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.copy, size: 15),
                                          tooltip: 'Copy Password',
                                          onPressed: () => _copyToClipboard(item.password, 'Password'),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Notes snippet (if any)
                                  if (item.notes.trim().isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.black.withValues(alpha: 0.2)
                                            : Colors.grey.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Icon(Icons.notes, size: 14, color: AppTheme.textSecondary),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              item.notes,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontStyle: FontStyle.italic,
                                                color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],

                                  const SizedBox(height: 6),

                                  // Created timestamp footer
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      'Created: ${_formatDate(item.createdAt)}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isDark ? AppTheme.darkTextMuted : AppTheme.textMuted,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),

            // 4. Footer Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : AppTheme.background,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                border: Border(
                  top: BorderSide(
                    color: isDark ? AppTheme.darkCardBorder : AppTheme.cardBorder,
                  ),
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 460;
                  if (isCompact) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.download_rounded, size: 16),
                                label: const Text('Export JSON', overflow: TextOverflow.ellipsis),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                ),
                                onPressed: _exportThisUser,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton.tonalIcon(
                                icon: const Icon(Icons.upload_file_outlined, size: 16),
                                label: const Text('Import', overflow: TextOverflow.ellipsis),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                ),
                                onPressed: _importThisUser,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          child: const Text('Close'),
                        ),
                      ],
                    );
                  }

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.download_rounded, size: 16),
                            label: const Text('Export JSON'),
                            onPressed: _exportThisUser,
                          ),
                          const SizedBox(width: 8),
                          FilledButton.tonalIcon(
                            icon: const Icon(Icons.upload_file_outlined, size: 16),
                            label: const Text('Import Passwords'),
                            onPressed: _importThisUser,
                          ),
                        ],
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// SYSTEM-WIDE ALL USERS DATA VIEWER DIALOG
// =============================================================================

/// Modal dialog allowing the administrator to search, browse, filter, reveal,
/// copy, and manage ALL passwords stored across ALL user accounts in the system.
class _AllUsersDataDialog extends StatefulWidget {
  final int? initialVaultId;
  final VoidCallback onDataChanged;

  const _AllUsersDataDialog({
    this.initialVaultId,
    required this.onDataChanged,
  });

  @override
  State<_AllUsersDataDialog> createState() => _AllUsersDataDialogState();
}

class _AllUsersDataDialogState extends State<_AllUsersDataDialog> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _allEntries = [];
  final Set<int> _revealedIds = {};
  String _searchQuery = '';
  int? _selectedUserId; // null for All Users
  int? _selectedVaultId; // null for All Vaults
  String _selectedCategory = 'All';
  final TextEditingController _searchController = TextEditingController();

  static const List<String> _categories = [
    'All',
    'Social',
    'Work',
    'Email',
    'Finance',
    'Entertainment',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _selectedVaultId = widget.initialVaultId;
    _loadAllEntries();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllEntries() async {
    setState(() => _isLoading = true);
    try {
      final list = await DatabaseHelper.instance.getAllPasswordsAcrossUsers(
        searchQuery: _searchQuery,
      );
      if (mounted) {
        setState(() {
          _allEntries = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('$label copied to clipboard!'),
          ],
        ),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _deleteEntry(Map<String, dynamic> item) async {
    final title = item['title'] as String? ?? 'this credential';
    final user = item['user_name'] as String? ?? 'User';
    final passwordId = item['id'] as int?;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete "$title"?'),
        content: Text(
          'Are you sure you want to permanently delete this credential from $user\'s vault? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && passwordId != null) {
      await DatabaseHelper.instance.deletePasswordByAdmin(passwordId);
      widget.onDataChanged();
      _loadAllEntries();
    }
  }

  /// Exports all users' data to a JSON backup
  Future<void> _exportAll() async {
    try {
      final jsonContent = await DatabaseHelper.instance.exportAllUsersDataToJson();
      final now = DateTime.now();
      final dateStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final fileName = 'system_all_users_backup_$dateStr.json';

      await FileHelper.downloadJsonFile(
        fileName: fileName,
        content: jsonContent,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('All users backup downloaded ($fileName)'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  String _formatDate(String? isoString) {
    if (isoString == null) return '';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoString;
    }
  }

  /// Get distinct users from the loaded entries to populate the user filter dropdown
  Map<int, String> get _distinctUsers {
    final Map<int, String> map = {};
    for (final e in _allEntries) {
      final uid = e['user_id'] as int?;
      final uname = e['user_name'] as String? ?? 'User #$uid';
      if (uid != null && !map.containsKey(uid)) {
        map[uid] = uname;
      }
    }
    return map;
  }

  /// Get distinct vaults from the loaded entries
  Map<int, Map<String, dynamic>> get _distinctVaults {
    final Map<int, Map<String, dynamic>> map = {};
    for (final e in _allEntries) {
      final vid = e['vault_id'] as int?;
      if (vid != null && !map.containsKey(vid)) {
        if (_selectedUserId == null || e['user_id'] == _selectedUserId) {
          map[vid] = {
            'name': e['vault_name'] as String? ?? 'Vault #$vid',
            'color': e['vault_color'] as String? ?? '#4F46E5',
            'icon': e['vault_icon'] as String? ?? 'shield',
          };
        }
      }
    }
    return map;
  }

  /// Filtered entries based on selected user, vault, and category
  List<Map<String, dynamic>> get _filteredEntries {
    return _allEntries.where((e) {
      if (_selectedUserId != null && e['user_id'] != _selectedUserId) {
        return false;
      }
      if (_selectedVaultId != null && e['vault_id'] != _selectedVaultId) {
        return false;
      }
      if (_selectedCategory != 'All') {
        final cat = (e['category'] as String? ?? 'Other').toLowerCase();
        if (cat != _selectedCategory.toLowerCase()) return false;
      }
      return true;
    }).toList();
  }

  Widget _buildUserDropdown(bool isDark, Map<int, String> distinctUsers) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppTheme.darkCardBorder : AppTheme.cardBorder,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          isExpanded: true,
          value: _selectedUserId,
          icon: const Icon(Icons.keyboard_arrow_down, size: 18),
          hint: const Row(
            children: [
              Icon(Icons.person_outline, size: 15),
              SizedBox(width: 6),
              Expanded(
                child: Text('All Users', style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          items: [
            const DropdownMenuItem<int?>(
              value: null,
              child: Row(
                children: [
                  Icon(Icons.people_outline, size: 16, color: AppTheme.primary),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('All Users', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
            ...distinctUsers.entries.map(
              (e) => DropdownMenuItem<int?>(
                value: e.key,
                child: Row(
                  children: [
                    const Icon(Icons.person_outline, size: 15),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(e.value, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
            ),
          ],
          onChanged: (val) {
            setState(() {
              _selectedUserId = val;
              if (val != null && _selectedVaultId != null) {
                final vaults = _distinctVaults;
                if (!vaults.containsKey(_selectedVaultId)) {
                  _selectedVaultId = null;
                }
              }
            });
          },
        ),
      ),
    );
  }

  Widget _buildVaultDropdown(bool isDark, Map<int, Map<String, dynamic>> distinctVaults) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppTheme.darkCardBorder : AppTheme.cardBorder,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          isExpanded: true,
          value: _selectedVaultId,
          icon: const Icon(Icons.keyboard_arrow_down, size: 18),
          hint: const Row(
            children: [
              Icon(Icons.shield_outlined, size: 15),
              SizedBox(width: 6),
              Expanded(
                child: Text('All Vaults', style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          items: [
            const DropdownMenuItem<int?>(
              value: null,
              child: Row(
                children: [
                  Icon(Icons.all_inclusive, size: 16, color: AppTheme.primary),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('All Vaults', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
            ...distinctVaults.entries.map((e) {
              final vName = e.value['name'] as String? ?? 'Vault';
              final vColorHex = e.value['color'] as String? ?? '#4F46E5';
              final vIconName = e.value['icon'] as String? ?? 'shield';
              Color color;
              try {
                final hex = vColorHex.replaceAll('#', '');
                color = hex.length == 6 ? Color(int.parse('FF$hex', radix: 16)) : AppTheme.primary;
              } catch (_) {
                color = AppTheme.primary;
              }
              final icon = VaultModel.getIconForName(vIconName);

              return DropdownMenuItem<int?>(
                value: e.key,
                child: Row(
                  children: [
                    Icon(icon, size: 15, color: color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        vName,
                        style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
          onChanged: (val) => setState(() => _selectedVaultId = val),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filteredEntries;
    final distinctUsers = _distinctUsers;
    final distinctVaults = _distinctVaults;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? AppTheme.darkBackground : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860, maxHeight: 880),
        child: Column(
          children: [
            // 1. Header Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : AppTheme.background,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? AppTheme.darkCardBorder : AppTheme.cardBorder,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.dataset_outlined, color: AppTheme.primary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'System Data Explorer: All Users\' Data',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Showing ${filtered.length} credentials across ${distinctVaults.length} vaults & ${distinctUsers.length} active users',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // 2. Responsive Search & Multi-Level Filters
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 620;
                  return Column(
                    children: [
                      // Search Bar
                      TextField(
                        controller: _searchController,
                        onChanged: (val) {
                          _searchQuery = val;
                          _loadAllEntries();
                        },
                        decoration: InputDecoration(
                          hintText: 'Search account, username, vault, or email...',
                          isDense: true,
                          prefixIcon: const Icon(Icons.search, size: 18),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: () {
                                    _searchController.clear();
                                    _searchQuery = '';
                                    _loadAllEntries();
                                  },
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // User & Vault Filter Row
                      if (isCompact) ...[
                        Row(
                          children: [
                            Expanded(child: _buildUserDropdown(isDark, distinctUsers)),
                            const SizedBox(width: 8),
                            Expanded(child: _buildVaultDropdown(isDark, distinctVaults)),
                          ],
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(flex: 3, child: _buildUserDropdown(isDark, distinctUsers)),
                            const SizedBox(width: 10),
                            Expanded(flex: 3, child: _buildVaultDropdown(isDark, distinctVaults)),
                            if (_selectedUserId != null ||
                                _selectedVaultId != null ||
                                _selectedCategory != 'All' ||
                                _searchQuery.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              TextButton.icon(
                                icon: const Icon(Icons.filter_alt_off_outlined, size: 16),
                                label: const Text('Reset', style: TextStyle(fontSize: 12)),
                                onPressed: () {
                                  setState(() {
                                    _selectedUserId = null;
                                    _selectedVaultId = null;
                                    _selectedCategory = 'All';
                                    _searchController.clear();
                                    _searchQuery = '';
                                  });
                                  _loadAllEntries();
                                },
                              ),
                            ],
                          ],
                        ),
                      ],
                      const SizedBox(height: 10),

                      // Category Filter Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _categories.map((cat) {
                            final isSelected = _selectedCategory == cat;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(
                                  cat,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                                selected: isSelected,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() => _selectedCategory = cat);
                                  }
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            const Divider(height: 16),

            // 3. Entries List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.search_off,
                                  size: 48,
                                  color: AppTheme.textSecondary.withValues(alpha: 0.4),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No saved credentials match current search or filters.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final item = filtered[index];
                            final id = item['id'] as int?;
                            final title = item['title'] as String? ?? 'Untitled';
                            final username = item['username_or_email'] as String? ?? '';
                            final password = item['password'] as String? ?? '';
                            final category = item['category'] as String? ?? 'Other';
                            final notes = item['notes'] as String? ?? '';
                            final websiteUrl = item['website_url'] as String?;
                            final customLogo = item['custom_logo'] as String?;
                            final createdAt = item['created_at'] as String?;
                            final userName = item['user_name'] as String? ?? 'User';
                            final userEmail = item['user_email'] as String? ?? '';
                            final userImage = item['user_profile_image'] as String?;
                            final vaultName = item['vault_name'] as String?;
                            final vaultColorHex = item['vault_color'] as String? ?? '#4F46E5';
                            final vaultIconName = item['vault_icon'] as String? ?? 'shield';
                            final totpSecret = item['totp_secret'] as String?;
                            final isFavorite = item['is_favorite'] as int? ?? 0;

                            final isRevealed = id != null && _revealedIds.contains(id);
                            final catColor = AppTheme.getCategoryColor(category);
                            final catIcon = AppTheme.getCategoryIcon(category);

                            Color vaultColor;
                            try {
                              final hex = vaultColorHex.replaceAll('#', '');
                              vaultColor = hex.length == 6
                                  ? Color(int.parse('FF$hex', radix: 16))
                                  : AppTheme.primary;
                            } catch (_) {
                              vaultColor = AppTheme.primary;
                            }
                            final vaultIcon = VaultModel.getIconForName(vaultIconName);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDark ? AppTheme.darkSurface : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isDark ? AppTheme.darkCardBorder : AppTheme.cardBorder,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Responsive Header Badge Row
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          children: [
                                            // User Owner Chip
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: AppTheme.primary.withValues(alpha: 0.08),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: AppTheme.primary.withValues(alpha: 0.2),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  UserAvatar(
                                                    base64Image: userImage,
                                                    displayName: userName,
                                                    radius: 9,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  ConstrainedBox(
                                                    constraints: const BoxConstraints(maxWidth: 160),
                                                    child: Text(
                                                      '$userName ($userEmail)',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.bold,
                                                        color: isDark ? AppTheme.primaryLight : AppTheme.primary,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                      maxLines: 1,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),

                                            // Vault Pill
                                            if (vaultName != null && vaultName.isNotEmpty) ...[
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: vaultColor.withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: vaultColor.withValues(alpha: 0.3)),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(vaultIcon, size: 12, color: vaultColor),
                                                    const SizedBox(width: 4),
                                                    ConstrainedBox(
                                                      constraints: const BoxConstraints(maxWidth: 120),
                                                      child: Text(
                                                        vaultName,
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.bold,
                                                          color: vaultColor,
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
                                                        maxLines: 1,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],

                                            // 2FA Badge
                                            if (totpSecret != null && totpSecret.trim().isNotEmpty) ...[
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: Colors.teal.withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
                                                ),
                                                child: const Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.lock_clock_outlined, size: 11, color: Colors.teal),
                                                    SizedBox(width: 3),
                                                    Text(
                                                      '2FA',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.teal,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],

                                            // Favorite Badge
                                            if (isFavorite == 1) ...[
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: Colors.amber.withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: const Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.star_rounded, size: 12, color: Colors.amber),
                                                    SizedBox(width: 2),
                                                    Text(
                                                      'Fav',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.amber,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],

                                            // Category Badge
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: catColor.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(catIcon, color: catColor, size: 12),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    category,
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      color: catColor,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      // Delete button
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.error),
                                        tooltip: 'Delete credential',
                                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                        padding: const EdgeInsets.all(4),
                                        onPressed: () => _deleteEntry(item),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 10),

                                  // Account Title with Logo
                                  Row(
                                    children: [
                                      VaultLogoAvatar(
                                        customLogo: customLogo,
                                        websiteUrl: websiteUrl,
                                        fallbackIcon: catIcon,
                                        fallbackColor: catColor,
                                        size: 26,
                                        borderRadius: 6,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          title,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Optional Website URL
                                  if (websiteUrl != null && websiteUrl.trim().isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? AppTheme.darkBackground.withValues(alpha: 0.5)
                                            : AppTheme.background,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.language_outlined, size: 16, color: AppTheme.textSecondary),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: InkWell(
                                              onTap: () => openUrlInBrowser(websiteUrl),
                                              child: Text(
                                                websiteUrl,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: AppTheme.primaryLight,
                                                  decoration: TextDecoration.underline,
                                                  decorationColor: AppTheme.primaryLight.withValues(alpha: 0.5),
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.open_in_new, size: 15, color: AppTheme.primaryLight),
                                            tooltip: 'Open website link',
                                            onPressed: () => openUrlInBrowser(websiteUrl),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.copy, size: 15),
                                            tooltip: 'Copy website URL',
                                            onPressed: () => _copyToClipboard(websiteUrl, 'Website URL'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],

                                  const SizedBox(height: 8),

                                  // Username row with copy
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? AppTheme.darkBackground.withValues(alpha: 0.5)
                                          : AppTheme.background,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.person_outline, size: 16, color: AppTheme.textSecondary),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: SelectableText(
                                            username,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.copy, size: 15),
                                          tooltip: 'Copy username/email',
                                          onPressed: () => _copyToClipboard(username, 'Username'),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 8),

                                  // Password row with show/hide toggle & copy
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? AppTheme.darkBackground.withValues(alpha: 0.5)
                                          : AppTheme.background,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.lock_outline, size: 16, color: AppTheme.textSecondary),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            isRevealed ? password : '••••••••••••',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontFamily: isRevealed ? 'monospace' : null,
                                              fontWeight: isRevealed ? FontWeight.w600 : FontWeight.bold,
                                              letterSpacing: isRevealed ? 0.5 : 2.0,
                                              color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            isRevealed ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                            size: 16,
                                          ),
                                          tooltip: isRevealed ? 'Hide Password' : 'Show Password',
                                          onPressed: () {
                                            if (id == null) return;
                                            setState(() {
                                              if (isRevealed) {
                                                _revealedIds.remove(id);
                                              } else {
                                                _revealedIds.add(id);
                                              }
                                            });
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.copy, size: 15),
                                          tooltip: 'Copy Password',
                                          onPressed: () => _copyToClipboard(password, 'Password'),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Notes snippet (if any)
                                  if (notes.trim().isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.black.withValues(alpha: 0.2)
                                            : Colors.grey.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Icon(Icons.notes, size: 14, color: AppTheme.textSecondary),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              notes,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontStyle: FontStyle.italic,
                                                color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],

                                  const SizedBox(height: 6),

                                  // Created timestamp footer
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      'Created: ${_formatDate(createdAt)}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isDark ? AppTheme.darkTextMuted : AppTheme.textMuted,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),

            // 4. Footer Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : AppTheme.background,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                border: Border(
                  top: BorderSide(
                    color: isDark ? AppTheme.darkCardBorder : AppTheme.cardBorder,
                  ),
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 460;
                  if (isCompact) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.download_rounded, size: 16),
                          label: const Text('Export All Data (.json)', overflow: TextOverflow.ellipsis),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onPressed: _exportAll,
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          child: const Text('Close'),
                        ),
                      ],
                    );
                  }

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.download_rounded, size: 16),
                        label: const Text('Export All Data (.json)'),
                        onPressed: _exportAll,
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
