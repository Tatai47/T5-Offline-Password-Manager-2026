import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../main.dart';
import '../models/user_model.dart';
import '../utils/app_theme.dart';
import '../utils/file_helper.dart';
import '../widgets/user_avatar.dart';
import 'admin_panel_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';

/// The SettingsScreen provides options for:
/// 1. Dark Theme vs Light Theme switcher
/// 2. Downloading passwords as a .json file (Backup)
/// 3. Uploading a .json file to restore passwords
/// 4. Navigating to edit user profile
/// 5. Signing out
class SettingsScreen extends StatefulWidget {
  final UserModel currentUser;
  final Function(UserModel updatedUser) onUserUpdated;
  final VoidCallback onDataChanged;

  const SettingsScreen({
    super.key,
    required this.currentUser,
    required this.onUserUpdated,
    required this.onDataChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late UserModel _user;
  int _passwordCount = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _user = widget.currentUser;
    _loadStats();
  }

  Future<void> _loadStats() async {
    final count = await DatabaseHelper.instance.getPasswordCount(_user.id!);
    if (mounted) {
      setState(() => _passwordCount = count);
    }
  }

  /// Exports passwords by downloading a .json file directly
  Future<void> _handleExport() async {
    if (_passwordCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No passwords to export yet. Add some first!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final jsonString = await DatabaseHelper.instance.exportPasswordsToJson(_user.id!);
      final date = DateTime.now().toIso8601String().substring(0, 10);
      final fileName = 'passwords_backup_${_user.name.trim().replaceAll(' ', '_')}_$date.json';

      final saved = await FileHelper.downloadJsonFile(
        fileName: fileName,
        content: jsonString,
      );

      if (!mounted) return;

      if (saved != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('Backup file ready: "$fileName"')),
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
          SnackBar(
            content: Text('Export error: $e'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Imports passwords by picking/uploading a .json file from the device
  Future<void> _handleImport() async {
    try {
      final jsonContent = await FileHelper.pickAndReadJsonFile();
      if (jsonContent == null) return; // User cancelled file picker

      setState(() => _isLoading = true);

      final count = await DatabaseHelper.instance.importPasswordsFromJson(
        _user.id!,
        jsonContent,
      );

      widget.onDataChanged();
      _loadStats();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Successfully imported $count password(s) from JSON file!'),
              ),
            ],
          ),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Import error: $e'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Opens a dialog to set or change the 4-digit PIN
  void _handlePinSetup() {
    final pinController = TextEditingController(text: _user.pin ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final hasExistingPin = _user.pin != null && _user.pin!.isNotEmpty;

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: const [
              Icon(Icons.pin_outlined, color: AppTheme.primary),
              SizedBox(width: 8),
              Text('4-Digit PIN Lock'),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Set a 4-digit PIN so you can quickly unlock your vault without typing your master password each time.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: pinController,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  obscureText: true,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    hintText: '••••',
                    counterText: '',
                  ),
                  validator: (val) {
                    if (val == null || val.length != 4 || int.tryParse(val) == null) {
                      return 'Please enter exactly 4 digits';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            if (hasExistingPin)
              TextButton(
                style: TextButton.styleFrom(foregroundColor: AppTheme.error),
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);
                  await DatabaseHelper.instance.setUserPin(_user.id!, '');
                  await DatabaseHelper.instance.clearUserSession();
                  setState(() {
                    _user = _user.copyWith(pin: '');
                  });
                  widget.onUserUpdated(_user);
                  navigator.pop();
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('PIN removed. Master password will be required on launch.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: const Text('Remove PIN'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                final newPin = pinController.text.trim();
                await DatabaseHelper.instance.setUserPin(_user.id!, newPin);
                await DatabaseHelper.instance.saveUserSession(_user.id!);
                setState(() {
                  _user = _user.copyWith(pin: newPin);
                });
                widget.onUserUpdated(_user);
                navigator.pop();
                messenger.showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Expanded(child: Text('4-digit PIN saved! App will unlock with PIN on startup.')),
                      ],
                    ),
                    backgroundColor: AppTheme.success,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text('Save PIN'),
            ),
          ],
        );
      },
    );
  }

  /// Sign out confirmation
  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out? You will need to enter your email and password to log back in.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () async {
              final navigator = Navigator.of(context);
              navigator.pop();
              await DatabaseHelper.instance.clearUserSession();
              // Keep last changed theme in localDB (do not reset to light)
              navigator.pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppTheme.darkCardBorder : AppTheme.cardBorder,
                ),
              ),
              child: Row(
                children: [
                  UserAvatar(
                    base64Image: _user.profileImage,
                    displayName: _user.name,
                    radius: 28,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _user.name,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          _user.email,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: const Size(60, 34),
                      side: const BorderSide(color: AppTheme.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProfileScreen(
                            currentUser: _user,
                            onUserUpdated: (updatedUser) {
                              setState(() => _user = updatedUser);
                              widget.onUserUpdated(updatedUser);
                            },
                          ),
                        ),
                      ).then((_) => _loadStats());
                    },
                    child: const Text(
                      'Edit',
                      style: TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

            if (_user.isAdmin) ...[
              const SizedBox(height: 24),
              Text(
                'ADMINISTRATION',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: isDark ? Colors.amber : AppTheme.primary,
                ),
              ),
              const SizedBox(height: 10),
              _buildSettingsTile(
                icon: Icons.admin_panel_settings,
                iconColor: Colors.amber,
                title: 'Admin Console',
                subtitle: 'Manage all users, credentials, and system metrics',
                isDark: isDark,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AdminPanelScreen(currentUser: _user),
                    ),
                  );
                },
              ),
            ],

            const SizedBox(height: 24),

            // Section: Appearance (Dark/Light Switcher)
            Text(
              'APPEARANCE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: isDark ? AppTheme.darkTextMuted : AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 10),

            // Theme Switcher Tile
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? AppTheme.darkCardBorder : AppTheme.cardBorder,
                ),
              ),
              child: Material(
                color: isDark ? AppTheme.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(14),
                clipBehavior: Clip.antiAlias,
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.amber : AppTheme.primary).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isDark ? Icons.dark_mode : Icons.light_mode,
                      color: isDark ? Colors.amber : AppTheme.primary,
                      size: 22,
                    ),
                  ),
                  title: Text(
                    isDark ? 'Dark Theme' : 'Light Theme',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    isDark ? 'Sleek dark theme enabled' : 'Clean white theme enabled',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                    ),
                  ),
                  value: isDark,
                  activeThumbColor: AppTheme.primaryLight,
                  onChanged: (bool value) async {
                    final selectedTheme = value ? 'dark' : 'light';
                    themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
                    await DatabaseHelper.instance.setLocalTheme(selectedTheme);
                    await DatabaseHelper.instance.setUserTheme(_user.id!, selectedTheme);
                    setState(() {
                      _user = _user.copyWith(themeMode: selectedTheme);
                    });
                    widget.onUserUpdated(_user);
                  },
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Section: Security & PIN Lock
            Text(
              'SECURITY & QUICK UNLOCK',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: isDark ? AppTheme.darkTextMuted : AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 10),

            _buildSettingsTile(
              icon: Icons.pin_outlined,
              iconColor: AppTheme.primaryLight,
              title: '4-Digit Quick Unlock PIN',
              subtitle: _user.pin != null && _user.pin!.isNotEmpty
                  ? 'PIN is active (Tap to change or remove)'
                  : 'Tap to set a 4-digit PIN for instant access',
              isDark: isDark,
              onTap: _handlePinSetup,
            ),

            const SizedBox(height: 24),

            // Section: Data & Backup
            Text(
              'BACKUP & RESTORE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: isDark ? AppTheme.darkTextMuted : AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 10),

            // Download File (Export) Tile
            _buildSettingsTile(
              icon: Icons.download_rounded,
              iconColor: AppTheme.primary,
              title: 'Download Backup (.json)',
              subtitle: 'Save a .json backup file with your $_passwordCount passwords',
              isDark: isDark,
              onTap: _isLoading ? null : _handleExport,
            ),

            const SizedBox(height: 10),

            // Upload File (Import) Tile
            _buildSettingsTile(
              icon: Icons.upload_file_rounded,
              iconColor: AppTheme.accent,
              title: 'Upload Backup (.json)',
              subtitle: 'Select and upload a .json file to restore passwords',
              isDark: isDark,
              onTap: _isLoading ? null : _handleImport,
            ),

            const SizedBox(height: 24),

            // Section: App Info
            Text(
              'APPLICATION',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: isDark ? AppTheme.darkTextMuted : AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 10),

            _buildSettingsTile(
              icon: Icons.info_outline,
              iconColor: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
              title: 'App Version',
              subtitle: '2.0.0 (Local SQLite Storage)',
              isDark: isDark,
              onTap: null,
            ),

            const SizedBox(height: 10),

            _buildSettingsTile(
              icon: Icons.lock_clock_outlined,
              iconColor: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
              title: 'Vault Status',
              subtitle: '$_passwordCount passwords secured locally',
              isDark: isDark,
              onTap: null,
            ),

            const SizedBox(height: 32),

            // Sign Out Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: AppTheme.error),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _confirmSignOut,
                icon: const Icon(Icons.logout, color: AppTheme.error),
                label: const Text(
                  'Sign Out',
                  style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);
}

  Widget _buildSettingsTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isDark,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppTheme.darkCardBorder : AppTheme.cardBorder,
        ),
      ),
      child: Material(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
            ),
          ),
          trailing: onTap != null
              ? Icon(
                  Icons.chevron_right,
                  color: isDark ? AppTheme.darkTextMuted : AppTheme.textMuted,
                  size: 20,
                )
              : null,
          onTap: onTap,
        ),
      ),
    );
  }
}
