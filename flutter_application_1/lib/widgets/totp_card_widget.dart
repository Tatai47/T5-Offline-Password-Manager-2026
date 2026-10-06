import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_theme.dart';
import '../utils/totp_helper.dart';

class TotpLiveCard extends StatefulWidget {
  final String secret;
  final bool compact;

  const TotpLiveCard({
    super.key,
    required this.secret,
    this.compact = false,
  });

  @override
  State<TotpLiveCard> createState() => _TotpLiveCardState();
}

class _TotpLiveCardState extends State<TotpLiveCard> {
  Timer? _timer;
  String _currentCode = '------';
  int _secondsLeft = 30;

  @override
  void initState() {
    super.initState();
    _updateCode();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        _updateCode();
      }
    });
  }

  @override
  void didUpdateWidget(covariant TotpLiveCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.secret != widget.secret) {
      _updateCode();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateCode() {
    final code = TotpHelper.generateCode(widget.secret) ?? '------';
    final remaining = TotpHelper.getRemainingSeconds();
    setState(() {
      _currentCode = code;
      _secondsLeft = remaining;
    });
  }

  void _copyCode() {
    if (_currentCode != '------') {
      Clipboard.setData(ClipboardData(text: _currentCode));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Copied 2FA code $_currentCode'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = _secondsLeft / 30.0;
    final isExpiringSoon = _secondsLeft <= 5;
    final timerColor = isExpiringSoon ? AppTheme.error : AppTheme.primary;

    // Format code as "123 456"
    final formattedCode = _currentCode.length == 6
        ? '${_currentCode.substring(0, 3)} ${_currentCode.substring(3)}'
        : _currentCode;

    if (widget.compact) {
      return InkWell(
        onTap: _copyCode,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: isDark ? 0.2 : 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(timerColor),
                  backgroundColor: isDark ? Colors.white12 : Colors.grey.shade300,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formattedCode,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  letterSpacing: 1.1,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.copy_rounded, size: 14, color: AppTheme.primary),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBorder.withValues(alpha: 0.4) : Colors.indigo.shade50.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: isDark ? 0.3 : 0.2),
        ),
      ),
      child: Row(
        children: [
          // Circular timer with seconds left
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(timerColor),
                  backgroundColor: isDark ? Colors.white12 : Colors.grey.shade300,
                ),
              ),
              Text(
                '$_secondsLeft',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: timerColor,
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),

          // Code label & number
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.timer_outlined, size: 13, color: AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      'ONE-TIME 2FA CODE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  formattedCode,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    fontFamily: 'monospace',
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
          ),

          // Copy button
          IconButton.filledTonal(
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
              foregroundColor: AppTheme.primary,
            ),
            icon: const Icon(Icons.copy_rounded, size: 18),
            tooltip: 'Copy 2FA Code',
            onPressed: _copyCode,
          ),
        ],
      ),
    );
  }
}
