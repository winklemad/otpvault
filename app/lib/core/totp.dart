import 'dart:typed_data';
import 'package:crypto/crypto.dart' as c;

/// RFC 6238 TOTP / RFC 4226 HOTP. Codes are generated entirely on-device.
class Totp {
  /// Generate a TOTP code from a raw secret (already Base32-decoded).
  static String generate(
    Uint8List secret, {
    int digits = 6,
    int period = 30,
    String algorithm = 'SHA1',
    DateTime? at,
  }) {
    final seconds = (at ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
    return _hotp(secret, seconds ~/ period, digits: digits, algorithm: algorithm);
  }

  /// Seconds remaining in the current step, for the countdown ring.
  static int secondsRemaining({int period = 30, DateTime? at}) {
    final seconds = (at ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
    return period - (seconds % period);
  }

  static String _hotp(
    Uint8List secret,
    int counter, {
    required int digits,
    required String algorithm,
  }) {
    final msg = ByteData(8)..setUint64(0, counter);
    final hmac = c.Hmac(_hash(algorithm), secret);
    final digest = hmac.convert(msg.buffer.asUint8List()).bytes;

    // Dynamic truncation (RFC 4226 §5.3).
    final offset = digest[digest.length - 1] & 0x0f;
    final binary = ((digest[offset] & 0x7f) << 24) |
        ((digest[offset + 1] & 0xff) << 16) |
        ((digest[offset + 2] & 0xff) << 8) |
        (digest[offset + 3] & 0xff);

    final code = binary % _pow10(digits);
    return code.toString().padLeft(digits, '0');
  }

  static c.Hash _hash(String algorithm) {
    switch (algorithm.toUpperCase()) {
      case 'SHA256':
        return c.sha256;
      case 'SHA512':
        return c.sha512;
      case 'SHA1':
      default:
        return c.sha1;
    }
  }

  static int _pow10(int n) {
    var r = 1;
    for (var i = 0; i < n; i++) {
      r *= 10;
    }
    return r;
  }
}
