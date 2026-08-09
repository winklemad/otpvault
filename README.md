# 2FA Authenticator (working name)

Open-source, cross-platform TOTP authenticator with **end-to-end-encrypted cloud sync**, running entirely on **Cloudflare's free tier**. No ads, no paid tier — a free, trustworthy utility.

- **[PLAN.md](./PLAN.md)** — full design: positioning, architecture, security model, Cloudflare sizing, roadmap.
- **[backend/](./backend)** — Cloudflare Worker (D1 + R2) sync API. Zero-knowledge: only ciphertext.
- **[app/](./app)** — Flutter client for iOS · Android · macOS · Windows · web (one codebase).

## Zero-knowledge in one line
Codes are generated on-device; the vault is encrypted on-device with a key derived from the master password (Argon2id); the server only ever stores an encrypted blob + salts. A server breach leaks nothing usable.

## Quick start
```bash
# backend
cd backend && npm install && npm run dev

# client
cd app && flutter create . --platforms=ios,android,macos,windows,web --project-name twofa && flutter pub get && flutter run
```

See each folder's README for full setup.

## Status
Planning + scaffold. Phase 0 target: a local-only authenticator (no backend) — useful on its own and the fastest thing to ship.
