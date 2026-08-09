# 2FA Authenticator with Free Cloud Sync — Project Plan

> Working name: **(TBD)** · Status: planning · Last updated: 2026-08-08

An open-source, cross-platform TOTP authenticator with **end-to-end-encrypted cloud sync**, run entirely on **Cloudflare's free tier**. No ads, no paid tier, no lifetime deal — a free, trustworthy utility and a credibility/portfolio project.

---

## 1. What this is (and isn't)

- **Is:** a 2FA app (like Google Authenticator / Aegis) whose encrypted vault syncs across a user's devices through a tiny Cloudflare backend that the maintainer runs for free.
- **Is not:** a business. There is deliberately no revenue. This avoids the two traps that sink most "free 2FA + sync" projects — **ads in a security app** (trust-killer) and **lifetime pricing on a recurring-cost service** (loses money as it grows).

### Honest positioning (read before building)
- **The category is saturated.** Free, open-source, cloud-syncing authenticators already exist — **Ente Auth** (E2E sync, freemium) is almost exactly this idea, plus **2FAS**, **Aegis**, Google/Microsoft Authenticator, Authy.
- **The hard part is distribution and trust, not building.** Migrating 2FA is high-friction and trust-gated; a solo unknown starts with none. Treat this as a *portfolio/credibility* project, not a growth play.
- **If it ever needs a wedge to stand out:** an underserved niche (e.g. team/family *shared* 2FA with an audit log — a real B2B gap) beats "2FA for everyone." Not required for a free hobby launch.

---

## 2. Design principles

1. **Zero-knowledge.** The server never sees a TOTP seed or a generated code — only ciphertext. A breach of the Cloudflare account leaks nothing usable.
2. **Codes are generated on-device**, always. The server is a dumb encrypted-blob store.
3. **Sync on change + on app-open only. Never poll.** Request count is the one real budget on the free tier.
4. **Whole-vault blob, not per-entry rows.** Keeps server CPU trivial and crypto simple.
5. **Open-source client; maintainer-run cloud is optional.** Users can self-host the Worker or use local-only mode.

---

## 3. Architecture

```
 ┌─────────────┐   password ──argon2id──┬─► authVerifier  (sent to server)
 │  Client app │                        └─► vaultKey      (NEVER leaves device)
 │ iOS/Android │
 │ desktop/web │   TOTP codes generated LOCALLY from decrypted seeds
 └──────┬──────┘
        │  encrypt whole vault (XChaCha20-Poly1305) with vaultKey
        │  HTTPS
        ▼
 ┌─────────────┐   auth check + version bump
 │  Workers    │──────────────► D1  (user records, vault version, salts)
 │  (sync API) │
 │  ~5 routes  │──────────────► R2  (vault/{userId} = one encrypted blob ~5–20 KB)
 └─────────────┘
```

### Components (all Cloudflare free tier)
| Layer | Product | Role |
|---|---|---|
| Sync API | **Workers** | ~5 routes; auth check + read/write blob |
| Vault store | **R2** | one encrypted blob per user; **$0 egress** |
| Accounts/metadata | **D1** (SQLite) | user records, auth verifier, vault version |
| Web client + landing | **Pages** | static hosting |
| ❌ avoid | Workers KV (1k writes/day) · Durable Objects (paid) | not needed |

---

## 4. Cloudflare free-tier limits & sizing (verified 2026-08-08)

| Product | Free allowance | Notes |
|---|---|---|
| Workers | **100,000 requests/day**, 10 ms CPU/req | the binding constraint |
| R2 | **10 GB**, 1M Class A (writes)/mo, 10M Class B (reads)/mo, **$0 egress** | blobs are tiny |
| D1 | **5 GB**, 5M rows read/day, 100k rows written/day | metadata only |
| Pages | unlimited static, 100k Functions req/day | web client |

**How far free goes:** with no polling, the ~100k req/day Workers cap supports **tens of thousands of active users indefinitely**. Storage (650k+ vaults fit in 10 GB) and bandwidth ($0 egress) effectively never bite. First wall ≈ 10k–30k daily-actives → fixed by the **$5/month Workers Paid plan**, which ~100×'s every limit.

Sources: developers.cloudflare.com/workers/platform/pricing · /r2/pricing · /d1/platform/pricing

---

## 5. Data model

### D1 — `users` (see `backend/schema.sql` for the source of truth)
| column | purpose |
|---|---|
| `id`, `handle` | user id (uuid) + email/username |
| `auth_hash`, `salt_auth` | login auth: sha256(argon2id(password, salt_auth)); proves password without revealing it |
| `wrapped_dek_pw`, `salt_pw` | DEK wrapped by the password KEK (normal unlock) |
| `wrapped_dek_rec`, `salt_rec` | DEK wrapped by the recovery KEK (forgot-password path) |
| `dek_reset_tag` | hmac(DEK,"reset") — authorizes a recovery reset by proving DEK possession |
| `vault_version` | monotonic; conflict detection |
| `created_at` / `updated_at` | timestamps |

### R2 — object layout
- `vault/{userId}` → encrypted blob: `XChaCha20-Poly1305(nonce ‖ ciphertext ‖ tag)` of the serialized vault.
- Vault plaintext (client-side only): `[{ issuer, label, secret, algo, digits, period, type }]`.

---

## 6. API (the entire backend)

| Route | Method | Body / headers | Action |
|---|---|---|---|
| `/signup` | POST | `{handle, authVerifier, saltAuth, saltVault}` | create user in D1, empty vault |
| `/login` | POST | `{handle, authProof}` | verify, return session token + `vaultVersion` |
| `/vault` | GET | auth token | stream `vault/{userId}` blob from R2 |
| `/vault` | PUT | auth token, `If-Match: <version>`, blob | write blob to R2, bump `vault_version` (reject on version mismatch → client merges) |
| `/account` | DELETE | auth token | delete D1 row + R2 blob |

Auth token: short-lived JWT signed by the Worker (HS256, secret in Worker env). Optionally upgrade login to **passkeys/WebAuthn** later.

---

## 7. Security model & recovery

### Envelope key model (this is what makes recovery possible)
The vault is encrypted with a random **DEK** (Data Encryption Key), *not* with the password directly. The DEK is stored only in **wrapped** (encrypted) forms; any wrapper can unlock it:
- **password KEK** = argon2id(password, saltPw) → normal unlock
- **recovery KEK** = argon2id(recoveryKey, saltRec) → forgot-password path
- **device KEK** (OS secure store, biometric) → quick unlock without retyping

All wrapped-DEK blobs are ciphertext, so the server (or device) can hold them without weakening zero-knowledge. **Rotating the password just re-wraps the DEK** — the vault itself is never re-encrypted. (Implemented in `app/lib/core/keybag.dart`; stored via the D1 columns `wrapped_dek_pw/rec`, `salt_pw/rec`.)

### Three safety nets (all address "I'm risking everything to switch")
1. **Recovery key (mandatory at signup).** A high-entropy code (`ABCD-EFGH-…`, later a BIP39 phrase), shown **once**. It wraps the DEK, so a forgotten password is recoverable — enter the recovery key → unwrap DEK → set a new password. Reset is authorized by proving DEK possession (`dekResetTag = hmac(DEK,"reset")`), never by the server knowing the key.
2. **Encrypted export/backup (anytime).** `app/lib/core/backup.dart` seals the whole vault into a portable file with a **passphrase you choose at export time** (Argon2id + XChaCha20). Store it anywhere; import restores. Plus a **plaintext `otpauth://` export** (loud warning) for one-shot migration to another app.
3. **Biometric quick-unlock** via the device-stored wrapper (Keychain/Keystore/DPAPI) so day-to-day you never retype the master password.

### On "store the recovery key in the app itself" — the honest tradeoff
Yes, keep a copy on-device (in the secure store) for biometric convenience — but **it must not be the ONLY copy.** If you wipe/lose every device (exactly the switching-phones case), the on-device copy is gone with it. So: store it on-device **and** force the user to save it externally once (or take the encrypted export). Also be blunt in the UI: a recovery key is a *second* full credential — anyone who gets it decrypts everything, so guard it like the master password. **More recoverability = more attack surface; that's unavoidable.** The design above gives the user the choice of where on that spectrum to sit (paranoid: recovery key on paper only; convenient: also on-device behind biometrics).

### Other
- **Threat handled:** server/DB compromise, network interception → attacker gets only ciphertext.
- **Not handled (say so):** a compromised *device* or a weak master password + weak recovery key. Push a strong passphrase; the recovery key is generated with 160 bits of entropy.
- Rate-limit `/login`, `/signup`, `/recovery/*` at the Worker (per-IP KV counter or Cloudflare Rate Limiting) to blunt brute force, handle-enumeration, and free-tier abuse.
- **TODO before launch:** `/recovery/material` should return a dummy blob for unknown handles to prevent enumeration; consider email verification on `/recovery/reset` so a stolen DB tag alone can't lock a user out.

---

## 8. Cross-platform strategy (iOS · Android · macOS · Windows · web)

**Principle: one shared core, thin native shells.** All logic lives in a single codebase; each platform only supplies the OS-specific integrations.

### What is shared (write once)
- TOTP engine (RFC 6238: SHA1/256/512, 6–8 digits, custom periods)
- Vault model + `otpauth://` URI parse/serialize (interop with other apps)
- E2E crypto (argon2id KDF, XChaCha20-Poly1305)
- Sync client (talks to the Worker)
- UI (if using a cross-platform UI framework — see below)

### What is platform-specific (thin shell per OS)
| Concern | iOS | Android | macOS | Windows |
|---|---|---|---|---|
| Secure key storage | Keychain (Secure Enclave) | Keystore | Keychain | Credential Manager / DPAPI |
| Biometric unlock | Face ID / Touch ID | BiometricPrompt | Touch ID | Windows Hello |
| Camera / QR scan | AVFoundation | CameraX | AVFoundation | MediaCapture |
| Packaging / signing | App Store | Play Store | notarized DMG or App Store | MSIX + code-sign |
| OTP autofill (nice-to-have) | ASCredentialProvider | Autofill framework | — | — |

### Framework choice — **recommended: Flutter**
One Dart codebase compiles to **iOS, Android, macOS, Windows** (and web) with mature plugins for every 2FA-critical need: `mobile_scanner` (QR), `flutter_secure_storage` (Keychain/Keystore/DPAPI), `local_auth` (biometrics). Best breadth-to-effort for a solo dev; cost is learning Dart.

**Alternatives:**
- **Tauri 2.0** — reuse web/TS for UI + a Rust core (ideal for crypto, matches existing Rust skill); tiny, hardened desktop binaries, mobile supported since 2.0 (newer/less battle-tested).
- **Kotlin Multiplatform + Compose Multiplatform** — shares logic + UI across all targets; iOS UI still maturing.
- **Avoid as the sole solution:** React Native (Windows/macOS are second-class) and PWA-only (no App-Store trust presence; iOS may evict local storage — risky for a security app). A PWA is still a great *early* build and stays as the web target.

### TOTP interop
Support QR + `otpauth://` import **and** export so users can migrate in from (and out to) Aegis/2FAS/Google Authenticator — lowers the trust barrier.

## 9. Repository structure (monorepo)

```
2fa-authenticator/
├── PLAN.md
├── backend/            # Cloudflare Worker (framework-agnostic, scaffolded now)
│   ├── wrangler.toml
│   ├── schema.sql      # D1
│   └── src/index.ts    # Hono routes
├── core/               # shared TOTP + crypto + sync client (language follows client framework)
└── app/                # the cross-platform client (Flutter | Tauri | KMP — pending decision)
```

---

## 10. Roadmap (phased)

**Phase 0 — Local-only MVP (no cloud)**
- QR scan / `otpauth://` import, TOTP code generation, local encrypted storage, export/backup. *Ship this first — it's useful and trust-building with zero backend.*

**Phase 1 — Encrypted sync**
- Worker + D1 + R2, signup/login, whole-vault E2E sync, version-based conflict handling.

**Phase 2 — Multi-device polish**
- New-device onboarding flow, conflict-merge UX, recovery key, WebAuthn/passkey login.

**Phase 3 — Reach & trust**
- Public repo, README with the security model, reproducible builds, optional self-host guide, then (only if pursued) a niche wedge like shared/team vaults.

---

## 11. Rules to keep it free forever

1. **Blobs in R2, metadata in D1** — never Workers KV for the vault (1k writes/day kills it).
2. **No polling** — sync on change and app-open only.
3. **E2E whole-vault blob** — trivial server CPU *and* removes breach liability.
4. **Watch the Workers request count** — it's the only limit you'll approach; everything else has massive headroom.

---

## Open questions / decisions to make
- [ ] Project name + license (MIT or GPL-3.0?).
- [ ] Password-only auth vs. passkeys from day one.
- [ ] Web/PWA-first vs. mobile-first client.
- [ ] Offer a recovery key, or rely on the standard export/backup?
- [ ] Self-host docs at launch, or after?
