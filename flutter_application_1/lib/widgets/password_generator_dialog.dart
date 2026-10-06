import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_theme.dart';
import '../utils/password_strength_helper.dart';

class PasswordGeneratorDialog extends StatefulWidget {
  final Function(String generatedPassword) onPasswordSelected;

  const PasswordGeneratorDialog({
    super.key,
    required this.onPasswordSelected,
  });

  @override
  State<PasswordGeneratorDialog> createState() => _PasswordGeneratorDialogState();
}

class _PasswordGeneratorDialogState extends State<PasswordGeneratorDialog> {
  int _length = 16;
  bool _includeUpper = true;
  bool _includeLower = true;
  bool _includeNumbers = true;
  bool _includeSymbols = true;
  bool _avoidAmbiguous = true;

  String _currentPassword = '';

  @override
  void initState() {
    super.initState();
    _regenerate();
  }

  void _regenerate() {
    final pwd = PasswordStrengthHelper.generate(
      length: _length,
      uppercase: _includeUpper,
      lowercase: _includeLower,
      numbers: _includeNumbers,
      symbols: _includeSymbols,
      avoidAmbiguous: _avoidAmbiguous,
    );
    setState(() => _currentPassword = pwd);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strength = PasswordStrengthHelper.evaluate(_currentPassword);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.key_rounded, color: AppTheme.primary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Password Generator',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          'Create a strong, cryptographically secure password',
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
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Generated Password Box with Regenerate & Copy
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCardBorder.withValues(alpha: 0.5) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppTheme.darkCardBorder : AppTheme.cardBorder,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            _currentPassword,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded, color: AppTheme.primary),
                          tooltip: 'Regenerate',
                          onPressed: _regenerate,
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 20),
                          tooltip: 'Copy',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _currentPassword));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Copied to clipboard!'),
                                duration: Duration(seconds: 1),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Strength indicator bar
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: strength.score,
                              minHeight: 6,
                              backgroundColor: isDark ? Colors.white12 : Colors.grey.shade300,
                              valueColor: AlwaysStoppedAnimation<Color>(strength.color),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          strength.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: strength.color,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Length Slider
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Length: $_length characters',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    _length < 12 ? 'Weak' : (_length >= 20 ? 'Max Security' : 'Recommended'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _length < 12 ? AppTheme.error : AppTheme.success,
                    ),
                  ),
                ],
              ),
              Slider(
                value: _length.toDouble(),
                min: 8,
                max: 48,
                divisions: 40,
                activeColor: AppTheme.primary,
                label: '$_length',
                onChanged: (val) {
                  setState(() => _length = val.round());
                  _regenerate();
                },
              ),

              // Character Options Grid
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  FilterChip(
                    label: const Text('Uppercase (A-Z)'),
                    selected: _includeUpper,
                    onSelected: (val) {
                      setState(() => _includeUpper = val);
                      _regenerate();
                    },
                  ),
                  FilterChip(
                    label: const Text('Lowercase (a-z)'),
                    selected: _includeLower,
                    onSelected: (val) {
                      setState(() => _includeLower = val);
                      _regenerate();
                    },
                  ),
                  FilterChip(
                    label: const Text('Numbers (0-9)'),
                    selected: _includeNumbers,
                    onSelected: (val) {
                      setState(() => _includeNumbers = val);
                      _regenerate();
                    },
                  ),
                  FilterChip(
                    label: const Text('Symbols (!@#)'),
                    selected: _includeSymbols,
                    onSelected: (val) {
                      setState(() => _includeSymbols = val);
                      _regenerate();
                    },
                  ),
                  FilterChip(
                    label: const Text('Avoid Ambiguous (O, 0, l, 1)'),
                    selected: _avoidAmbiguous,
                    onSelected: (val) {
                      setState(() => _avoidAmbiguous = val);
                      _regenerate();
                    },
                  ),
                ],
              ),

              const SizedBox(height: 22),

              // Use Password Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text(
                    'Use This Password',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    widget.onPasswordSelected(_currentPassword);
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
