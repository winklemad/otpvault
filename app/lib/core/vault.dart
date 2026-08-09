import 'dart:convert';
import 'dart:typed_data';

/// A single 2FA account (a TOTP secret + its parameters).
class TotpEntry {
  final String issuer;
  final String label;
  final String secretBase32; // stored Base32-encoded, as in otpauth:// URIs
  final int digits;
  final int period;
  final String algorithm; // SHA1 | SHA256 | SHA512

  TotpEntry({
    required this.issuer,
    required this.label,
    required this.secretBase32,
    this.digits = 6,
    this.period = 30,
    this.algorithm = 'SHA1',
  });

  Uint8List get secretBytes => base32Decode(secretBase32);

  Map<String, dynamic> toJson() => {
        'issuer': issuer,
        'label': label,
        'secret': secretBase32,
        'digits': digits,
        'period': period,
        'algorithm': algorithm,
      };

  factory TotpEntry.fromJson(Map<String, dynamic> j) => TotpEntry(
        issuer: j['issuer'] ?? '',
        label: j['label'] ?? '',
        secretBase32: j['secret'],
        digits: j['digits'] ?? 6,
        period: j['period'] ?? 30,
        algorithm: j['algorithm'] ?? 'SHA1',
      );

  /// Parse an `otpauth://totp/...` URI (from a scanned QR or an import).
  static TotpEntry fromUri(String uri) {
    final u = Uri.parse(uri);
    if (u.scheme != 'otpauth' || u.host != 'totp') {
      throw FormatException('Not a TOTP otpauth URI: $uri');
    }
    final labelPath = Uri.decodeComponent(u.path.replaceFirst('/', ''));
    final parts = labelPath.split(':');
    final issuer = u.queryParameters['issuer'] ??
        (parts.length > 1 ? parts.first.trim() : '');
    final label = (parts.length > 1 ? parts.sublist(1).join(':') : labelPath).trim();
    final secret = u.queryParameters['secret'];
    if (secret == null) throw FormatException('otpauth URI missing secret');
    return TotpEntry(
      issuer: issuer,
      label: label,
      secretBase32: secret,
      digits: int.tryParse(u.queryParameters['digits'] ?? '') ?? 6,
      period: int.tryParse(u.queryParameters['period'] ?? '') ?? 30,
      algorithm: (u.queryParameters['algorithm'] ?? 'SHA1').toUpperCase(),
    );
  }

  /// Serialize back to an `otpauth://` URI (for export / migration out).
  String toUri() {
    final labelEnc = Uri.encodeComponent(
        issuer.isNotEmpty ? '$issuer:$label' : label);
    final q = {
      'secret': secretBase32,
      if (issuer.isNotEmpty) 'issuer': issuer,
      'algorithm': algorithm,
      'digits': '$digits',
      'period': '$period',
    };
    final query =
        q.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    return 'otpauth://totp/$labelEnc?$query';
  }
}

/// The full vault. This object is what gets encrypted into the single blob.
class Vault {
  final List<TotpEntry> entries;
  Vault(this.entries);

  Uint8List serialize() =>
      utf8.encode(jsonEncode({'v': 1, 'entries': entries.map((e) => e.toJson()).toList()}));

  static Vault deserialize(Uint8List bytes) {
    final j = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    final list = (j['entries'] as List).cast<Map<String, dynamic>>();
    return Vault(list.map(TotpEntry.fromJson).toList());
  }
}

// --- Base32 (RFC 4648, no padding required) --------------------------------

const _b32 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

Uint8List base32Decode(String input) {
  final clean = input.toUpperCase().replaceAll('=', '').replaceAll(' ', '');
  var bits = 0, value = 0;
  final out = <int>[];
  for (final ch in clean.split('')) {
    final idx = _b32.indexOf(ch);
    if (idx < 0) continue; // skip stray characters
    value = (value << 5) | idx;
    bits += 5;
    if (bits >= 8) {
      out.add((value >> (bits - 8)) & 0xff);
      bits -= 8;
    }
  }
  return Uint8List.fromList(out);
}
