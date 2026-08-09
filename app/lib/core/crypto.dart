import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

/// All key derivation and vault encryption. Nothing here ever leaves the
/// device except the [authVerifier] (which the server stores only as a hash)
/// and the resulting ciphertext blob.
class VaultCrypto {
  // Argon2id parameters. Tune memory up on desktop; keep modest for low-end phones.
  static final _argon2 = Argon2id(
    memory: 19456, // KiB (~19 MB)
    parallelism: 1,
    iterations: 3,
    hashLength: 32,
  );

  /// Vault key = argon2id(password, saltVault). NEVER sent to the server.
  static Future<SecretKey> deriveVaultKey(String password, Uint8List saltVault) {
    return _argon2.deriveKeyFromPassword(password: password, nonce: saltVault);
  }

  /// Auth verifier = argon2id(password, saltAuth), hex-encoded. Sent to the
  /// server, which stores only sha256 of it.
  static Future<String> deriveAuthVerifier(String password, Uint8List saltAuth) async {
    final key = await _argon2.deriveKeyFromPassword(password: password, nonce: saltAuth);
    final bytes = await key.extractBytes();
    return _hex(bytes);
  }

  /// Encrypt the serialized vault. Output = nonce ‖ ciphertext ‖ MAC.
  static Future<Uint8List> encrypt(SecretKey key, Uint8List plaintext) async {
    final algo = Xchacha20.poly1305Aead();
    final box = await algo.encrypt(plaintext, secretKey: key);
    return Uint8List.fromList(box.concatenation());
  }

  static Future<Uint8List> decrypt(SecretKey key, Uint8List blob) async {
    final algo = Xchacha20.poly1305Aead();
    final box = SecretBox.fromConcatenation(blob, nonceLength: 24, macLength: 16);
    final clear = await algo.decrypt(box, secretKey: key);
    return Uint8List.fromList(clear);
  }

  static Uint8List randomSalt([int length = 16]) {
    final rng = SecureRandom.fast; // fine for salts (non-secret, unique)
    return Uint8List.fromList(List.generate(length, (_) => rng.nextInt(256)));
  }

  static String _hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
