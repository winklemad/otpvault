import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'crypto.dart';
import 'vault.dart';

/// Portable, self-contained backups — independent of the account and the cloud.
///
/// Two forms:
///  1. [exportEncrypted] — the whole vault sealed with a passphrase YOU choose
///     at export time (Argon2id + XChaCha20-Poly1305). Safe to store anywhere.
///  2. [exportOtpauthUris] — plaintext `otpauth://` list for migrating INTO
///     another app. Convenient but unencrypted → warn the user loudly.
class Backup {
  static const _magic = 'TFA1'; // format tag

  /// Encrypted backup file bytes: magic ‖ salt(16) ‖ sealedVault.
  static Future<Uint8List> exportEncrypted(Vault vault, String passphrase) async {
    final salt = VaultCrypto.randomSalt();
    final key = await VaultCrypto.deriveVaultKey(passphrase, salt);
    final sealed = await VaultCrypto.encrypt(key, vault.serialize());

    final out = BytesBuilder();
    out.add(utf8.encode(_magic));
    out.add(salt);
    out.add(sealed);
    return out.toBytes();
  }

  static Future<Vault> importEncrypted(Uint8List file, String passphrase) async {
    if (file.length < 20 || utf8.decode(file.sublist(0, 4)) != _magic) {
      throw const FormatException('Not a valid encrypted backup');
    }
    final salt = Uint8List.fromList(file.sublist(4, 20));
    final sealed = Uint8List.fromList(file.sublist(20));
    final key = await VaultCrypto.deriveVaultKey(passphrase, salt);
    return Vault.deserialize(await VaultCrypto.decrypt(key, sealed)); // throws on wrong passphrase (MAC fail)
  }

  /// ⚠️ PLAINTEXT. Each line is a full secret. Only for one-shot migration
  /// out to another authenticator; never store this unencrypted.
  static List<String> exportOtpauthUris(Vault vault) =>
      vault.entries.map((e) => e.toUri()).toList();
}
