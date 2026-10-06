import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/user_model.dart';
import '../utils/app_theme.dart';
import '../widgets/user_avatar.dart';
import 'admin_panel_screen.dart';
import 'home_screen.dart';
import 'pin_lock_screen.dart';
import 'register_screen.dart';

/// The LoginScreen allows existing users to sign in.
///
/// Features:
/// 1. Master password login (email + password).
/// 2. Option to save credentials to local database for fast 4-digit PIN unlock.
/// 3. Seamless setup dialog to set a 4-digit PIN right after login if not yet configured.
/// 4. Direct 1-tap jump to PinLockScreen if a remembered user with PIN exists.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // GlobalKey is used to validate all TextFormFields inside the Form widget
  final _formKey = GlobalKey<FormState>();

  // Controllers allow us to listen to and retrieve input text
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // State variables for UI
  bool _isPasswordHidden = true;
  bool _isLoading = false;
  bool _saveCredentialsLocally = true;
  UserModel? _quickPinUser;

  @override
  void initState() {
    super.initState();
    _checkQuickPinUser();
  }

  Future<void> _checkQuickPinUser() async {
    try {
      final user = await DatabaseHelper.instance.getActiveSessionUser();
      if (user != null && user.pin != null && user.pin!.isNotEmpty && mounted) {
        setState(() => _quickPinUser = user);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    // Always dispose controllers when the widget is removed to avoid memory leaks
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Prompts the user to set a 4-digit PIN to save credentials locally
  Future<bool> _showSetPinDialog(UserModel user) async {
    final pinController = TextEditingController();
    final confirmPinController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isObscured = true;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.pin_outlined, color: AppTheme.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quick PIN Unlock Setup',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Save credentials to local database',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.shield_outlined, size: 18, color: AppTheme.primary),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Save credentials locally in this device\'s SQLite database. Whenever you open the software, simply enter this 4-digit PIN to access your vault instantly.',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Create 4-Digit PIN',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: pinController,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        obscureText: isObscured,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          hintText: '••••',
                          counterText: '',
                          suffixIcon: IconButton(
                            icon: Icon(
                              isObscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              size: 18,
                            ),
                            onPressed: () => setDialogState(() => isObscured = !isObscured),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.length != 4 || int.tryParse(val) == null) {
                            return 'Please enter exactly 4 digits';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Confirm 4-Digit PIN',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: confirmPinController,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        obscureText: isObscured,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                          hintText: '••••',
                          counterText: '',
                        ),
                        validator: (val) {
                          if (val != pinController.text) {
                            return 'PINs do not match';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Skip for Now'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Save & Enable PIN'),
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    final newPin = pinController.text.trim();
                    await DatabaseHelper.instance.setUserPin(user.id!, newPin);
                    await DatabaseHelper.instance.saveUserSession(user.id!);
                    if (ctx.mounted) {
                      Navigator.pop(ctx, true);
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );

    return result ?? false;
  }

  /// Attempts to log the user in using DatabaseHelper
  Future<void> _handleLogin() async {
    // 1. Check if form fields pass validation rules
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      // 2. Query our SQLite database
      final UserModel? user = await DatabaseHelper.instance.loginUser(email, password);

      if (!mounted) return;

      if (user != null) {
        if (_saveCredentialsLocally) {
          if (user.pin == null || user.pin!.isEmpty) {
            // Prompt to set a 4-digit PIN for quick unlock
            final pinSaved = await _showSetPinDialog(user);
            if (!mounted) return;
            if (!pinSaved) {
              await DatabaseHelper.instance.clearUserSession();
            }
          } else {
            // User already has a 4-digit PIN; save session to local DB
            await DatabaseHelper.instance.saveUserSession(user.id!);
          }
        } else {
          // User chose not to remember credentials locally
          await DatabaseHelper.instance.clearUserSession();
        }

        if (!mounted) return;

        // Fetch refreshed user object in case PIN was set
        final refreshedUser = (await DatabaseHelper.instance.getUserById(user.id!)) ?? user;
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _saveCredentialsLocally && refreshedUser.pin != null && refreshedUser.pin!.isNotEmpty
                        ? 'Welcome, ${refreshedUser.name}! Quick 4-digit PIN unlock is active on this device.'
                        : 'Welcome, ${refreshedUser.name}!',
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Navigate to AdminPanelScreen if admin, otherwise to HomeScreen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => refreshedUser.isAdmin
                ? AdminPanelScreen(currentUser: refreshedUser)
                : HomeScreen(currentUser: refreshedUser),
          ),
        );
      } else {
        // 4. Incorrect credentials
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Invalid email or password. Please try again.'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Login error: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Icon / Logo
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.primaryLight, AppTheme.primary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        color: Colors.white,
                        size: 44,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Header Texts
                  Text(
                    'Welcome Back',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to your T5 Offline Password Manager',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                    ),
                  ),

                  const SizedBox(height: 36),

                  // Quick PIN Unlock Banner if a user session with PIN is detected
                  if (_quickPinUser != null) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          UserAvatar(
                            base64Image: _quickPinUser!.profileImage,
                            displayName: _quickPinUser!.name,
                            radius: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Welcome back, ${_quickPinUser!.name}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '4-Digit PIN Unlock is available',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          FilledButton.tonalIcon(
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            icon: const Icon(Icons.pin, size: 16),
                            label: const Text('Enter PIN'),
                            onPressed: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PinLockScreen(currentUser: _quickPinUser!),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Email Field
                  Text(
                    'Email Address',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'name@example.com',
                      prefixIcon: Icon(
                        Icons.email_outlined,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your email or admin';
                      }
                      final trimmed = value.trim().toLowerCase();
                      if (trimmed != 'admin' && (!value.contains('@') || !value.contains('.'))) {
                        return 'Please enter a valid email address';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 20),

                  // Password Field
                  Text(
                    'Master Password',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _isPasswordHidden,
                    decoration: InputDecoration(
                      hintText: 'Enter your password',
                      prefixIcon: Icon(
                        Icons.lock_outline,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordHidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordHidden = !_isPasswordHidden;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Option to Save Credentials to Local DB for 4-Digit PIN Unlock
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _saveCredentialsLocally
                            ? AppTheme.primary.withValues(alpha: 0.5)
                            : (isDark ? AppTheme.darkCardBorder : AppTheme.cardBorder),
                      ),
                    ),
                    child: CheckboxListTile(
                      value: _saveCredentialsLocally,
                      onChanged: (val) {
                        setState(() => _saveCredentialsLocally = val ?? true);
                      },
                      activeColor: AppTheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      title: Row(
                        children: [
                          const Icon(Icons.pin_outlined, size: 18, color: AppTheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Save credentials to local database',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        'Whenever you open the software, just enter your 4-digit PIN to unlock',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Sign In Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text('Sign In'),
                  ),

                  const SizedBox(height: 24),

                  // Navigate to Register Screen
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: TextStyle(
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const RegisterScreen(),
                            ),
                          );
                        },
                        child: Text(
                          'Create Account',
                          style: TextStyle(
                            color: isDark ? AppTheme.primaryLight : AppTheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
}
