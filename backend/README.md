# twofa-sync — backend

A zero-knowledge encrypted-vault sync API on Cloudflare Workers + D1 + R2. Runs on the free tier (see `../PLAN.md` §4).

## Setup

```bash
npm install

# 1. Create the D1 database and paste its id into wrangler.toml
wrangler d1 create twofa

# 2. Create the R2 bucket
wrangler r2 bucket create twofa-vaults

# 3. Initialise the schema
npm run db:init:local     # local dev
npm run db:init           # remote (production)

# 4. Set the JWT secret
cp .dev.vars.example .dev.vars   # local: put a random secret in it
wrangler secret put JWT_SECRET   # production

# 5. Run / deploy
npm run dev
npm run deploy
```

## Contract (what the client does)

Envelope model — the vault is encrypted with a random **DEK**; the DEK is stored only wrapped. All done **on-device** (see `app/lib/core/keybag.dart`):

```
DEK          = random 32 bytes                     # encrypts the vault
authVerifier = argon2id(password, saltAuth)        # sent; server stores sha256(it)
pwKEK        = argon2id(password, saltPw)           # NEVER sent
recKEK       = argon2id(recoveryKey, saltRec)       # NEVER sent
wrappedDekPw  = XChaCha20(pwKEK,  DEK)
wrappedDekRec = XChaCha20(recKEK, DEK)
dekResetTag  = hmac_sha256(DEK, "reset")
blob         = XChaCha20(DEK, serialize(vault))
```

- **Signup:** POST `{handle, authVerifier, saltAuth, wrappedDekPw, saltPw, wrappedDekRec, saltRec, dekResetTag}`.
- **Login:** POST `{handle, authVerifier}` → `{token, wrappedDekPw, saltPw, vaultVersion}`; derive `pwKEK`, unwrap `DEK`.
- **Pull / Push:** `GET`/`PUT /vault` (`If-Match: <version>`) — encrypted blob + `X-Vault-Version`; `409` on conflict → pull, merge, retry.
- **Recovery (forgot password):** POST `/recovery/material {handle}` → `{wrappedDekRec, saltRec}`; unwrap DEK with the recovery key; then POST `/recovery/reset {handle, dekResetTag, newAuthVerifier, newSaltAuth, newWrappedDekPw, newSaltPw}`.

## Notes / TODO
- Auth here is a simple hashed-verifier scheme. For a stronger PAKE (server never sees a password-equivalent even in transit), consider OPAQUE/SRP later.
- Add per-IP rate limiting on `/login` and `/signup` (Cloudflare Rate Limiting rules or a KV counter) before public launch.
- TOTP seeds and code generation never touch this service — they live entirely in the client.
