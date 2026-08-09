import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'crypto.dart';

/// Envelope key management ("keybag").
///
/// The vault is encrypted with a random **Data Encryption Key (DEK)**. The DEK
/// is never derived from the password directly — instead it is *wrapped*
/// (encrypted) by several Key-Encryption-Keys (KEKs), any of which can unwrap
/// it:
///
///   • password KEK   = argon2id(password, saltPw)      → normal unlock
///   • recovery KEK   = argon2id(recoveryKey, saltRec)  → forgot-password path
///   • (device KEK)   = key in OS secure store          → biometric quick-unlock
///
/// All wrapped-DEK blobs are ciphertext, so they can be stored on the server
/// (or on device) without weakening zero-knowledge: unwrapping needs a KEK the
/// server never sees. Rotating the password just re-wraps the DEK — the vault
/// itself is never re-encrypted.
class Keybag {
  final SecretKey dek; // use this to VaultCrypto.encrypt / decrypt the vault
  Keybag(this.dek);

  /// New account: fresh DEK + two wrappers (password and recovery).
  static Future<KeybagInit> create(String password, String recoveryKey) async {
    final dekBytes = _random(32);
    final dek = SecretKey(dekBytes);

    final saltPw = VaultCrypto.randomSalt();
    final saltRec = VaultCrypto.randomSalt();
    final pwKek = await VaultCrypto.deriveVaultKey(password, saltPw);
    final recKek = await VaultCrypto.deriveVaultKey(recoveryKey, saltRec);

    return KeybagInit(
      keybag: Keybag(dek),
      wrappedByPassword: await VaultCrypto.encrypt(pwKek, dekBytes),
      wrappedByRecovery: await VaultCrypto.encrypt(recKek, dekBytes),
      saltPw: saltPw,
      saltRec: saltRec,
    );
  }

  static Future<Keybag> unlockWithPassword(
      String password, Uint8List wrappedByPassword, Uint8List saltPw) async {
    final kek = await VaultCrypto.deriveVaultKey(password, saltPw);
    final dekBytes = await VaultCrypto.decrypt(kek, wrappedByPassword);
    return Keybag(SecretKey(dekBytes));
  }

  static Future<Keybag> unlockWithRecovery(
      String recoveryKey, Uint8List wrappedByRecovery, Uint8List saltRec) async {
    final kek = await VaultCrypto.deriveVaultKey(recoveryKey, saltRec);
    final dekBytes = await VaultCrypto.decrypt(kek, wrappedByRecovery);
    return Keybag(SecretKey(dekBytes));
  }

  /// After recovery, set a new password: re-wrap the SAME dek. Upload the
  /// returned blob + salt as the new password wrapper. Vault is untouched.
  Future<(Uint8List wrappedByPassword, Uint8List saltPw)> rewrapForPassword(
      String newPassword) async {
    final saltPw = VaultCrypto.randomSalt();
    final kek = await VaultCrypto.deriveVaultKey(newPassword, saltPw);
    final dekBytes = await dek.extractBytes();
    final wrapped = await VaultCrypto.encrypt(kek, Uint8List.fromList(dekBytes));
    return (wrapped, saltPw);
  }

  /// Proof of DEK possession, sent to authorize a recovery reset.
  /// The server stores this at signup and compares on reset.
  Future<String> resetTag() async {
    final mac = await Hmac.sha256().calculateMac(utf8.encode('reset'), secretKey: dek);
    return mac.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Generate a high-entropy recovery key, formatted for the user to write
  /// down (Base32, grouped in 4s). TODO: swap to a BIP39 mnemonic for nicer UX.
  static String generateRecoveryKey() {
    const b32 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    final bytes = _random(20); // 160 bits
    var bits = 0, value = 0;
    final chars = <String>[];
    for (final byte in bytes) {
      value = (value << 8) | byte;
      bits += 8;
      while (bits >= 5) {
        chars.add(b32[(value >> (bits - 5)) & 31]);
        bits -= 5;
      }
    }
    final code = chars.join();
    return [for (var i = 0; i < code.length; i += 4) code.substring(i, i + 4 > code.length ? code.length : i + 4)]
        .join('-'); // e.g. ABCD-EFGH-IJKL-...
  }

  static Uint8List _random(int n) {
    final rng = SecureRandom.fast;
    return Uint8List.fromList(List.generate(n, (_) => rng.nextInt(256)));
  }
}

class KeybagInit {
  final Keybag keybag;
  final Uint8List wrappedByPassword;
  final Uint8List wrappedByRecovery;
  final Uint8List saltPw;
  final Uint8List saltRec;
  KeybagInit({
    required this.keybag,
    required this.wrappedByPassword,
    required this.wrappedByRecovery,
    required this.saltPw,
    required this.saltRec,
  });
}
