import 'dart:math';
import 'package:flutter/material.dart';

enum PasswordStrength {
  veryWeak,
  weak,
  medium,
  strong,
  veryStrong,
}

class PasswordStrengthResult {
  final PasswordStrength strength;
  final double score; // 0.0 to 1.0
  final String label;
  final Color color;
  final bool hasMinLength;
  final bool hasUppercase;
  final bool hasLowercase;
  final bool hasNumbers;
  final bool hasSymbols;

  const PasswordStrengthResult({
    required this.strength,
    required this.score,
    required this.label,
    required this.color,
    required this.hasMinLength,
    required this.hasUppercase,
    required this.hasLowercase,
    required this.hasNumbers,
    required this.hasSymbols,
  });
}

class PasswordStrengthHelper {
  static PasswordStrengthResult evaluate(String password) {
    if (password.isEmpty) {
      return const PasswordStrengthResult(
        strength: PasswordStrength.veryWeak,
        score: 0.0,
        label: 'Empty',
        color: Colors.grey,
        hasMinLength: false,
        hasUppercase: false,
        hasLowercase: false,
        hasNumbers: false,
        hasSymbols: false,
      );
    }

    final hasMinLength = password.length >= 10;
    final hasGreatLength = password.length >= 16;
    final hasUppercase = RegExp(r'[A-Z]').hasMatch(password);
    final hasLowercase = RegExp(r'[a-z]').hasMatch(password);
    final hasNumbers = RegExp(r'[0-9]').hasMatch(password);
    final hasSymbols = RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+=\[\]\\/;~`]').hasMatch(password);

    int points = 0;
    if (password.length >= 8) points++;
    if (hasMinLength) points++;
    if (hasGreatLength) points++;
    if (hasUppercase) points++;
    if (hasLowercase) points++;
    if (hasNumbers) points++;
    if (hasSymbols) points += 2;

    // Total max points is 8
    double score = (points / 8).clamp(0.0, 1.0);

    PasswordStrength strength;
    String label;
    Color color;

    if (score < 0.25) {
      strength = PasswordStrength.veryWeak;
      label = 'Very Weak';
      color = const Color(0xFFEF4444);
    } else if (score < 0.5) {
      strength = PasswordStrength.weak;
      label = 'Weak';
      color = const Color(0xFFF97316);
    } else if (score < 0.75) {
      strength = PasswordStrength.medium;
      label = 'Moderate';
      color = const Color(0xFFEAB308);
    } else if (score < 0.9) {
      strength = PasswordStrength.strong;
      label = 'Strong';
      color = const Color(0xFF3B82F6);
    } else {
      strength = PasswordStrength.veryStrong;
      label = 'Very Strong';
      color = const Color(0xFF10B981);
    }

    return PasswordStrengthResult(
      strength: strength,
      score: score,
      label: label,
      color: color,
      hasMinLength: hasMinLength,
      hasUppercase: hasUppercase,
      hasLowercase: hasLowercase,
      hasNumbers: hasNumbers,
      hasSymbols: hasSymbols,
    );
  }

  /// Configurable password generator
  static String generate({
    int length = 16,
    bool uppercase = true,
    bool lowercase = true,
    bool numbers = true,
    bool symbols = true,
    bool avoidAmbiguous = true,
  }) {
    String upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    String lower = 'abcdefghijklmnopqrstuvwxyz';
    String nums = '0123456789';
    String syms = '!@#\$%^&*()-_=+[]{}|;:,.<>?';

    if (avoidAmbiguous) {
      // Remove easily confused characters: I, l, 1, O, 0
      upper = upper.replaceAll(RegExp(r'[IO]'), '');
      lower = lower.replaceAll(RegExp(r'[lo]'), '');
      nums = nums.replaceAll(RegExp(r'[01]'), '');
    }

    final pool = StringBuffer();
    final guaranteed = <String>[];
    final rand = Random.secure();

    if (uppercase && upper.isNotEmpty) {
      pool.write(upper);
      guaranteed.add(upper[rand.nextInt(upper.length)]);
    }
    if (lowercase && lower.isNotEmpty) {
      pool.write(lower);
      guaranteed.add(lower[rand.nextInt(lower.length)]);
    }
    if (numbers && nums.isNotEmpty) {
      pool.write(nums);
      guaranteed.add(nums[rand.nextInt(nums.length)]);
    }
    if (symbols && syms.isNotEmpty) {
      pool.write(syms);
      guaranteed.add(syms[rand.nextInt(syms.length)]);
    }

    if (pool.isEmpty) {
      return '';
    }

    final poolString = pool.toString();
    final result = <String>[...guaranteed];

    while (result.length < length) {
      result.add(poolString[rand.nextInt(poolString.length)]);
    }

    // Shuffle so guaranteed chars aren't always at the front
    result.shuffle(rand);
    return result.join();
  }
}
