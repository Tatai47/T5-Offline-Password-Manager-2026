import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/db_helper.dart';
import '../models/user_model.dart';
import '../utils/app_theme.dart';
import '../widgets/user_avatar.dart';
import 'admin_panel_screen.dart';
import 'home_screen.dart';
import 'login_screen.dart';

/// Screen displayed when an active user returns to the app.
///
/// Instead of typing email + password every time, the user simply enters
/// their 4-digit passcode to quickly unlock their vault.
class PinLockScreen extends StatefulWidget {
  final UserModel currentUser;

  const PinLockScreen({
    super.key,
    required this.currentUser,
  });

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  String _enteredPin = '';
  String? _errorMessage;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.backspace) {
        _onBackspacePressed();
        return KeyEventResult.handled;
      }
      final char = event.character;
      if (char != null && RegExp(r'^[0-9]$').hasMatch(char)) {
        _onDigitPressed(char);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void _onDigitPressed(String digit) {
    if (_enteredPin.length < 4) {
      setState(() {
        _errorMessage = null;
        _enteredPin += digit;
      });

      // When all 4 digits are entered, verify the PIN
      if (_enteredPin.length == 4) {
        _verifyPin();
      }
    }
  }

  void _onBackspacePressed() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _errorMessage = null;
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
    }
  }

  Future<void> _verifyPin() async {
    final correctPin = widget.currentUser.pin;

    if (correctPin == null || correctPin.isEmpty) {
      // If user has no PIN configured yet, allow entry and encourage setting one
      _unlockApp();
      return;
    }

    if (_enteredPin == correctPin) {
      _unlockApp();
    } else {
      setState(() {
        _errorMessage = 'Incorrect PIN. Try again.';
        _enteredPin = '';
      });
    }
  }

  void _unlockApp() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => widget.currentUser.isAdmin
            ? AdminPanelScreen(currentUser: widget.currentUser)
            : HomeScreen(currentUser: widget.currentUser),
      ),
    );
  }

  /// Switch account or login with master password
  Future<void> _switchAccount() async {
    await DatabaseHelper.instance.clearUserSession();
    // Keep last changed theme in localDB (do not reset to light)
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Focus(
          focusNode: _focusNode,
          autofocus: true,
          onKeyEvent: _handleKeyEvent,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top Space
                    const SizedBox(height: 10),

                    // User Info & Greeting
                    Column(
                      children: [
                        UserAvatar(
                          base64Image: widget.currentUser.profileImage,
                          displayName: widget.currentUser.name,
                          radius: 46,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Welcome back, ${widget.currentUser.name}!',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Enter your 4-digit PIN to unlock',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // 4 Dots Display
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(4, (index) {
                            final isFilled = index < _enteredPin.length;
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 10),
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isFilled
                                    ? AppTheme.primary
                                    : (isDark ? AppTheme.darkCardBorder : const Color(0xFFCBD5E1)),
                                border: Border.all(
                                  color: isFilled
                                      ? AppTheme.primary
                                      : (isDark ? AppTheme.darkCardBorder : AppTheme.cardBorder),
                                  width: 2,
                                ),
                              ),
                            );
                          }),
                        ),

                        // Error message (if wrong PIN)
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 14),
                          Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: AppTheme.error,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),

                    // Numeric Keypad (1 to 9, 0, Backspace)
                    Container(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: Column(
                        children: [
                          _buildKeypadRow(['1', '2', '3'], isDark),
                          const SizedBox(height: 14),
                          _buildKeypadRow(['4', '5', '6'], isDark),
                          const SizedBox(height: 14),
                          _buildKeypadRow(['7', '8', '9'], isDark),
                          const SizedBox(height: 14),
                          // Bottom Row: Empty space, '0', Backspace
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              const SizedBox(width: 72, height: 72),
                              _buildKeyButton('0', isDark),
                              SizedBox(
                                width: 72,
                                height: 72,
                                child: InkWell(
                                  onTap: _onBackspacePressed,
                                  borderRadius: BorderRadius.circular(36),
                                  child: Center(
                                    child: Icon(
                                      Icons.backspace_outlined,
                                      size: 24,
                                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Switch Account Option at bottom
                    TextButton(
                      onPressed: _switchAccount,
                      child: Text(
                        'Switch Account / Sign In with Password',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppTheme.primaryLight : AppTheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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

  Widget _buildKeypadRow(List<String> digits, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((d) => _buildKeyButton(d, isDark)).toList(),
    );
  }

  Widget _buildKeyButton(String digit, bool isDark) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark ? AppTheme.darkSurface : Colors.white,
        border: Border.all(
          color: isDark ? AppTheme.darkCardBorder : AppTheme.cardBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => _onDigitPressed(digit),
          child: Center(
            child: Text(
              digit,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w600,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
