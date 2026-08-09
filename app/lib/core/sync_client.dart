import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Thin client for the Cloudflare Worker (see ../backend). Transports only the
/// already-encrypted blobs, salts and verifiers — never plaintext. Binary
/// fields are base64-encoded on the wire.
class SyncClient {
  final Uri base;
  String? _token;
  SyncClient(String baseUrl) : base = Uri.parse(baseUrl);

  Map<String, String> get _auth =>
      _token == null ? {} : {'Authorization': 'Bearer $_token'};
  static String _b64(Uint8List b) => base64Encode(b);

  Future<String> signup({
    required String handle,
    required String authVerifier, // hex
    required Uint8List saltAuth,
    required Uint8List wrappedDekPw,
    required Uint8List saltPw,
    required Uint8List wrappedDekRec,
    required Uint8List saltRec,
    required String dekResetTag, // hex
  }) async {
    final r = await http.post(base.resolve('/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'handle': handle,
          'authVerifier': authVerifier,
          'saltAuth': _b64(saltAuth),
          'wrappedDekPw': _b64(wrappedDekPw),
          'saltPw': _b64(saltPw),
          'wrappedDekRec': _b64(wrappedDekRec),
          'saltRec': _b64(saltRec),
          'dekResetTag': dekResetTag,
        }));
    _check(r, 201);
    final j = jsonDecode(r.body);
    _token = j['token'];
    return j['userId'] as String;
  }

  /// Returns the password-wrapper material so the client can unwrap the DEK.
  Future<LoginResult> login({required String handle, required String authVerifier}) async {
    final r = await http.post(base.resolve('/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'handle': handle, 'authVerifier': authVerifier}));
    _check(r, 200);
    final j = jsonDecode(r.body);
    _token = j['token'];
    return LoginResult(
      userId: j['userId'],
      wrappedDekPw: base64Decode(j['wrappedDekPw']),
      saltPw: base64Decode(j['saltPw']),
      vaultVersion: j['vaultVersion'],
    );
  }

  /// Forgot-password step 1: fetch the recovery-wrapped DEK (ciphertext).
  Future<RecoveryMaterial> recoveryMaterial(String handle) async {
    final r = await http.post(base.resolve('/recovery/material'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'handle': handle}));
    _check(r, 200);
    final j = jsonDecode(r.body);
    return RecoveryMaterial(
        wrappedDekRec: base64Decode(j['wrappedDekRec']), saltRec: base64Decode(j['saltRec']));
  }

  /// Forgot-password step 2: prove DEK possession + set a new password wrapper.
  Future<void> recoveryReset({
    required String handle,
    required String dekResetTag,
    required String newAuthVerifier,
    required Uint8List newSaltAuth,
    required Uint8List newWrappedDekPw,
    required Uint8List newSaltPw,
  }) async {
    final r = await http.post(base.resolve('/recovery/reset'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'handle': handle,
          'dekResetTag': dekResetTag,
          'newAuthVerifier': newAuthVerifier,
          'newSaltAuth': _b64(newSaltAuth),
          'newWrappedDekPw': _b64(newWrappedDekPw),
          'newSaltPw': _b64(newSaltPw),
        }));
    _check(r, 200);
    _token = jsonDecode(r.body)['token'];
  }

  /// Returns (blob, version). blob is null if the vault is empty (204).
  Future<(Uint8List?, int)> pull() async {
    final r = await http.get(base.resolve('/vault'), headers: _auth);
    if (r.statusCode == 204) {
      return (null, int.tryParse(r.headers['x-vault-version'] ?? '0') ?? 0);
    }
    _check(r, 200);
    return (r.bodyBytes, int.tryParse(r.headers['x-vault-version'] ?? '0') ?? 0);
  }

  /// Push a new encrypted blob based on [expectedVersion]. Throws
  /// [VaultConflict] on 409 (caller should pull, merge, retry).
  Future<int> push(Uint8List blob, int expectedVersion) async {
    final r = await http.put(base.resolve('/vault'),
        headers: {..._auth, 'If-Match': '$expectedVersion', 'Content-Type': 'application/octet-stream'},
        body: blob);
    if (r.statusCode == 409) {
      throw VaultConflict(jsonDecode(r.body)['currentVersion'] as int);
    }
    _check(r, 200);
    return jsonDecode(r.body)['vaultVersion'] as int;
  }

  void _check(http.Response r, int expected) {
    if (r.statusCode != expected) throw SyncException(r.statusCode, r.body);
  }
}

class LoginResult {
  final String userId;
  final Uint8List wrappedDekPw;
  final Uint8List saltPw;
  final int vaultVersion;
  LoginResult({required this.userId, required this.wrappedDekPw, required this.saltPw, required this.vaultVersion});
}

class RecoveryMaterial {
  final Uint8List wrappedDekRec;
  final Uint8List saltRec;
  RecoveryMaterial({required this.wrappedDekRec, required this.saltRec});
}

class VaultConflict implements Exception {
  final int currentVersion;
  VaultConflict(this.currentVersion);
}

class SyncException implements Exception {
  final int status;
  final String body;
  SyncException(this.status, this.body);
  @override
  String toString() => 'SyncException($status): $body';
}
