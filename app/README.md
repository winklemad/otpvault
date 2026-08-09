# twofa — Flutter client

One Dart codebase for **iOS · Android · macOS · Windows · web**. The `lib/core`
modules are platform-agnostic and fully implemented; `lib/platform` holds the
thin OS-specific shells.

## Turn this into a runnable project

```bash
# from app/
flutter create . --platforms=ios,android,macos,windows,web --project-name twofa
flutter pub get
flutter run -d macos      # or windows / chrome / <device-id>
```

`flutter create .` generates the native runner folders (ios/, android/, macos/,
windows/, web/) around these lib/ files without overwriting them.

## Layout

```
lib/
├── main.dart                 # Phase 0 skeleton: local-only live codes
├── core/                     # shared, platform-agnostic (done)
│   ├── totp.dart             #   RFC 6238 code generation
│   ├── vault.dart            #   entry model + otpauth:// parse/serialize + base32
│   ├── crypto.dart           #   Argon2id KDF + XChaCha20-Poly1305 primitives
│   ├── keybag.dart           #   envelope keys: DEK wrapped by password + recovery key
│   ├── backup.dart           #   encrypted export/import + otpauth migration export
│   └── sync_client.dart      #   talks to ../backend
└── platform/
    └── secure_store.dart     # Keychain/Keystore/DPAPI wrapper
```

## Build order (matches PLAN.md §10)
1. **Phase 0 (local-only):** QR scan (`mobile_scanner`) → `TotpEntry.fromUri`; persist the encrypted vault locally; biometric unlock (`local_auth`). No backend yet.
2. **Phase 1 (sync):** signup/login + push/pull via `SyncClient`; derive keys with `VaultCrypto`.
3. **Phase 2:** new-device onboarding, conflict-merge UX, recovery key.

## Platform notes
- **Camera (QR):** add usage strings — iOS `NSCameraUsageDescription`, macOS camera entitlement, Android `CAMERA` permission.
- **Biometrics:** iOS `NSFaceIDUsageDescription`; Android `USE_BIOMETRIC`.
- **Signing/packaging:** App Store / Play Store / notarized DMG / MSIX — see PLAN.md §8.
- The sync backend URL is configured where you construct `SyncClient('https://twofa-sync.<you>.workers.dev')`.
