/**
 * 2FA sync backend — a zero-knowledge encrypted-blob store on Cloudflare.
 *
 * The server only ever handles ciphertext. All crypto (argon2id KDF, vault
 * encryption, TOTP code generation) happens on the client. A breach of this
 * Worker / its D1 / R2 leaks encrypted vaults and salts only — never a seed.
 *
 * Routes:
 *   POST   /signup      create account (client sends authVerifier + salts)
 *   POST   /login       exchange authVerifier for a short-lived JWT
 *   GET    /vault       download the encrypted vault blob
 *   PUT    /vault       upload a new encrypted vault (If-Match: <version>)
 *   DELETE /account     delete the user and their vault
 *   GET    /health      liveness
 */
import { Hono } from 'hono'
import { cors } from 'hono/cors'
import { sign, verify } from 'hono/jwt'

type Bindings = {
  DB: D1Database
  VAULTS: R2Bucket
  JWT_SECRET: string
}

const app = new Hono<{ Bindings: Bindings }>()
app.use('*', cors({ origin: '*', allowMethods: ['GET', 'POST', 'PUT', 'DELETE'] }))

// --- helpers ---------------------------------------------------------------

const now = () => Math.floor(Date.now() / 1000)
const uuid = () => crypto.randomUUID()

async function sha256Hex(input: string): Promise<string> {
  const buf = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(input))
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, '0')).join('')
}

// Constant-time-ish compare for equal-length hex strings.
function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false
  let out = 0
  for (let i = 0; i < a.length; i++) out |= a.charCodeAt(i) ^ b.charCodeAt(i)
  return out === 0
}

async function issueToken(secret: string, userId: string): Promise<string> {
  return sign({ sub: userId, exp: now() + 60 * 60 * 24 * 7 }, secret) // 7-day session
}

async function requireUser(c: any): Promise<string | null> {
  const auth = c.req.header('Authorization') || ''
  const token = auth.startsWith('Bearer ') ? auth.slice(7) : ''
  if (!token) return null
  try {
    const payload = await verify(token, c.env.JWT_SECRET)
    return typeof payload.sub === 'string' ? payload.sub : null
  } catch {
    return null
  }
}

// --- routes ----------------------------------------------------------------

app.get('/health', (c) => c.json({ ok: true }))

app.post('/signup', async (c) => {
  const b = await c.req.json().catch(() => ({}))
  const { handle, authVerifier, saltAuth, wrappedDekPw, saltPw, wrappedDekRec, saltRec, dekResetTag } = b
  if (!handle || !authVerifier || !saltAuth || !wrappedDekPw || !saltPw || !wrappedDekRec || !saltRec || !dekResetTag) {
    return c.json({ error: 'missing required signup fields (see backend/README.md)' }, 400)
  }
  const existing = await c.env.DB.prepare('SELECT id FROM users WHERE handle = ?').bind(handle).first()
  if (existing) return c.json({ error: 'handle already taken' }, 409)

  const id = uuid()
  const authHash = await sha256Hex(authVerifier)
  const t = now()
  await c.env.DB.prepare(
    `INSERT INTO users (id, handle, auth_hash, salt_auth, wrapped_dek_pw, salt_pw,
                        wrapped_dek_rec, salt_rec, dek_reset_tag, vault_version, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?)`
  ).bind(id, handle, authHash, saltAuth, wrappedDekPw, saltPw, wrappedDekRec, saltRec, dekResetTag, t, t).run()

  const token = await issueToken(c.env.JWT_SECRET, id)
  return c.json({ token, userId: id, vaultVersion: 0 }, 201)
})

app.post('/login', async (c) => {
  const { handle, authVerifier } = await c.req.json().catch(() => ({}))
  if (!handle || !authVerifier) return c.json({ error: 'handle and authVerifier required' }, 400)

  const row = await c.env.DB.prepare(
    'SELECT id, auth_hash, wrapped_dek_pw, salt_pw, vault_version FROM users WHERE handle = ?'
  ).bind(handle).first<any>()
  if (!row) return c.json({ error: 'invalid credentials' }, 401)

  const authHash = await sha256Hex(authVerifier)
  if (!timingSafeEqual(authHash, row.auth_hash)) return c.json({ error: 'invalid credentials' }, 401)

  const token = await issueToken(c.env.JWT_SECRET, row.id)
  // Client derives the password KEK from (password, salt_pw) and unwraps the DEK.
  return c.json({
    token,
    userId: row.id,
    wrappedDekPw: row.wrapped_dek_pw,
    saltPw: row.salt_pw,
    vaultVersion: row.vault_version,
  })
})

// --- recovery (forgot password) --------------------------------------------

// Unauthenticated: return the recovery-wrapped DEK by handle. Safe — it's
// ciphertext, useless without the user's recovery key. Rate-limit in prod.
app.post('/recovery/material', async (c) => {
  const { handle } = await c.req.json().catch(() => ({}))
  if (!handle) return c.json({ error: 'handle required' }, 400)
  const row = await c.env.DB.prepare(
    'SELECT wrapped_dek_rec, salt_rec FROM users WHERE handle = ?'
  ).bind(handle).first<any>()
  if (!row) return c.json({ error: 'not found' }, 404) // TODO: return a dummy blob to avoid handle enumeration
  return c.json({ wrappedDekRec: row.wrapped_dek_rec, saltRec: row.salt_rec })
})

// Reset password + auth using proof of DEK possession (client recovered the
// DEK with the recovery key, then computes dekResetTag = hmac(DEK,"reset")).
app.post('/recovery/reset', async (c) => {
  const { handle, dekResetTag, newAuthVerifier, newSaltAuth, newWrappedDekPw, newSaltPw } =
    await c.req.json().catch(() => ({}))
  if (!handle || !dekResetTag || !newAuthVerifier || !newSaltAuth || !newWrappedDekPw || !newSaltPw) {
    return c.json({ error: 'missing reset fields' }, 400)
  }
  const row = await c.env.DB.prepare('SELECT id, dek_reset_tag FROM users WHERE handle = ?')
    .bind(handle).first<any>()
  if (!row) return c.json({ error: 'invalid' }, 401)
  if (!timingSafeEqual(dekResetTag, row.dek_reset_tag)) return c.json({ error: 'invalid recovery' }, 401)

  const authHash = await sha256Hex(newAuthVerifier)
  await c.env.DB.prepare(
    'UPDATE users SET auth_hash = ?, salt_auth = ?, wrapped_dek_pw = ?, salt_pw = ?, updated_at = ? WHERE id = ?'
  ).bind(authHash, newSaltAuth, newWrappedDekPw, newSaltPw, now(), row.id).run()

  const token = await issueToken(c.env.JWT_SECRET, row.id)
  return c.json({ token, userId: row.id })
})

app.get('/vault', async (c) => {
  const userId = await requireUser(c)
  if (!userId) return c.json({ error: 'unauthorized' }, 401)

  const row = await c.env.DB.prepare('SELECT vault_version FROM users WHERE id = ?').bind(userId).first<any>()
  const obj = await c.env.VAULTS.get(`vault/${userId}`)
  if (!obj) return c.body(null, 204, { 'X-Vault-Version': String(row?.vault_version ?? 0) })

  return c.body(obj.body, 200, {
    'Content-Type': 'application/octet-stream',
    'X-Vault-Version': String(row?.vault_version ?? 0),
  })
})

app.put('/vault', async (c) => {
  const userId = await requireUser(c)
  if (!userId) return c.json({ error: 'unauthorized' }, 401)

  // Optimistic concurrency: client sends the version it based this write on.
  const expected = Number(c.req.header('If-Match') ?? 'NaN')
  const row = await c.env.DB.prepare('SELECT vault_version FROM users WHERE id = ?').bind(userId).first<any>()
  if (!row) return c.json({ error: 'user not found' }, 404)
  if (!Number.isNaN(expected) && expected !== row.vault_version) {
    return c.json({ error: 'version conflict', currentVersion: row.vault_version }, 409)
  }

  const body = await c.req.arrayBuffer()
  if (!body || body.byteLength === 0) return c.json({ error: 'empty body' }, 400)
  if (body.byteLength > 1_000_000) return c.json({ error: 'vault too large' }, 413) // 1 MB guardrail

  await c.env.VAULTS.put(`vault/${userId}`, body)
  const next = row.vault_version + 1
  await c.env.DB.prepare('UPDATE users SET vault_version = ?, updated_at = ? WHERE id = ?')
    .bind(next, now(), userId).run()

  return c.json({ vaultVersion: next })
})

app.delete('/account', async (c) => {
  const userId = await requireUser(c)
  if (!userId) return c.json({ error: 'unauthorized' }, 401)
  await c.env.VAULTS.delete(`vault/${userId}`)
  await c.env.DB.prepare('DELETE FROM users WHERE id = ?').bind(userId).run()
  return c.json({ ok: true })
})

export default app
