import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// Helper to generate Time-based One-Time Passwords (TOTP) compatible with Google Authenticator,
/// Microsoft Authenticator, Bitwarden, etc. (RFC 6238 / RFC 4226).
class TotpHelper {
  static const String _base32Chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

  /// Decodes a Base32 string into a Uint8List of bytes.
  static Uint8List? _base32Decode(String input) {
    try {
      final cleanInput = input.toUpperCase().replaceAll(RegExp(r'[^A-Z2-7]'), '');
      if (cleanInput.isEmpty) return null;

      int buffer = 0;
      int bitsLeft = 0;
      final List<int> output = [];

      for (int i = 0; i < cleanInput.length; i++) {
        final val = _base32Chars.indexOf(cleanInput[i]);
        if (val < 0) return null;

        buffer = (buffer << 5) | val;
        bitsLeft += 5;

        if (bitsLeft >= 8) {
          bitsLeft -= 8;
          output.add((buffer >> bitsLeft) & 0xFF);
        }
      }

      return Uint8List.fromList(output);
    } catch (_) {
      return null;
    }
  }

  /// Validates whether a secret key is a valid Base32 string.
  static bool isValidSecret(String secret) {
    final clean = secret.trim().toUpperCase().replaceAll(' ', '');
    if (clean.length < 8) return false;
    final decoded = _base32Decode(clean);
    return decoded != null && decoded.isNotEmpty;
  }

  /// Computes the current 6-digit TOTP code for the given secret key.
  /// Returns null if secret key is invalid.
  static String? generateCode(String secret, {DateTime? time, int period = 30, int digits = 6}) {
    try {
      final cleanSecret = secret.trim().toUpperCase().replaceAll(' ', '');
      final keyBytes = _base32Decode(cleanSecret);
      if (keyBytes == null || keyBytes.isEmpty) return null;

      final now = (time ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
      final counter = now ~/ period;

      // Encode counter as 8-byte big-endian
      final counterBytes = Uint8List(8);
      final byteData = ByteData.view(counterBytes.buffer);
      byteData.setUint64(0, counter, Endian.big);

      // Compute HMAC-SHA1
      final hmac = Hmac(sha1, keyBytes);
      final hash = hmac.convert(counterBytes).bytes;

      // Dynamic truncation (RFC 4226)
      final offset = hash[hash.length - 1] & 0x0F;
      final binaryCode = ((hash[offset] & 0x7F) << 24) |
          ((hash[offset + 1] & 0xFF) << 16) |
          ((hash[offset + 2] & 0xFF) << 8) |
          (hash[offset + 3] & 0xFF);

      final otp = binaryCode % pow(10, digits).toInt();
      return otp.toString().padLeft(digits, '0');
    } catch (_) {
      return null;
    }
  }

  /// Returns remaining seconds until the current code expires (0 to 29).
  static int getRemainingSeconds({int period = 30}) {
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final elapsed = nowSeconds % period;
    return period - elapsed;
  }

  /// Generates a random Base32 secret key (16 or 32 characters) for testing or setup.
  static String generateRandomSecret({int length = 16}) {
    final rand = Random.secure();
    final chars = _base32Chars;
    final buffer = StringBuffer();
    for (int i = 0; i < length; i++) {
      buffer.write(chars[rand.nextInt(chars.length)]);
    }
    return buffer.toString();
  }
}
