import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the derived vault key behind the OS secure store
/// (Keychain / Android Keystore / Windows DPAPI / macOS Keychain), so the
/// user unlocks with biometrics instead of retyping the master password.
class SecureStore {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );

  static Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
  static Future<String?> read(String key) => _storage.read(key: key);
  static Future<void> delete(String key) => _storage.delete(key: key);
}
