import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Thin client for the Cloudflare Worker (see ../backend). Handles only
/// transport of the already-encrypted blob + auth verifier; no plaintext.
class SyncClient {
  final Uri base;
  String? _token;
  SyncClient(String baseUrl) : base = Uri.parse(baseUrl);

  Map<String, String> get _auth =>
      _token == null ? {} : {'Authorization': 'Bearer $_token'};

  Future<SignupResult> signup({
    required String handle,
    required String authVerifier,
    required String saltAuthB64,
    required String saltVaultB64,
  }) async {
    final r = await http.post(base.resolve('/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'handle': handle,
          'authVerifier': authVerifier,
          'saltAuth': saltAuthB64,
          'saltVault': saltVaultB64,
        }));
    _check(r, 201);
    final j = jsonDecode(r.body);
    _token = j['token'];
    return SignupResult(userId: j['userId'], vaultVersion: j['vaultVersion']);
  }

  Future<LoginResult> login({required String handle, required String authVerifier}) async {
    final r = await http.post(base.resolve('/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'handle': handle, 'authVerifier': authVerifier}));
    _check(r, 200);
    final j = jsonDecode(r.body);
    _token = j['token'];
    return LoginResult(
      userId: j['userId'],
      saltVaultB64: j['saltVault'],
      vaultVersion: j['vaultVersion'],
    );
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
      final j = jsonDecode(r.body);
      throw VaultConflict(j['currentVersion'] as int);
    }
    _check(r, 200);
    return jsonDecode(r.body)['vaultVersion'] as int;
  }

  void _check(http.Response r, int expected) {
    if (r.statusCode != expected) {
      throw SyncException(r.statusCode, r.body);
    }
  }
}

class SignupResult {
  final String userId;
  final int vaultVersion;
  SignupResult({required this.userId, required this.vaultVersion});
}

class LoginResult {
  final String userId;
  final String saltVaultB64;
  final int vaultVersion;
  LoginResult({required this.userId, required this.saltVaultB64, required this.vaultVersion});
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
