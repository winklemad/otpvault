-- D1 schema for the 2FA sync backend.
--
-- Zero-knowledge + envelope key model: the vault is encrypted with a random
-- DEK; the DEK is stored only in *wrapped* (encrypted) form, unwrappable with
-- either the password KEK or the recovery KEK. The server stores these wrapped
-- blobs + salts but holds no KEK, so it can never decrypt anything.

CREATE TABLE IF NOT EXISTS users (
  id               TEXT    PRIMARY KEY,          -- uuid
  handle           TEXT    UNIQUE NOT NULL,      -- email or username

  -- Login authentication (separate from encryption).
  auth_hash        TEXT    NOT NULL,             -- sha256(authVerifier), authVerifier = argon2id(password, salt_auth)
  salt_auth        TEXT    NOT NULL,

  -- Envelope: DEK wrapped by the password KEK and by the recovery KEK.
  wrapped_dek_pw   TEXT    NOT NULL,             -- DEK encrypted by argon2id(password, salt_pw)
  salt_pw          TEXT    NOT NULL,
  wrapped_dek_rec  TEXT    NOT NULL,             -- DEK encrypted by argon2id(recoveryKey, salt_rec)
  salt_rec         TEXT    NOT NULL,
  dek_reset_tag    TEXT    NOT NULL,             -- hmac_sha256(DEK,"reset"); proves DEK possession to authorize a recovery reset

  vault_version    INTEGER NOT NULL DEFAULT 0,   -- optimistic-concurrency for the vault blob
  created_at       INTEGER NOT NULL,
  updated_at       INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_users_handle ON users(handle);
