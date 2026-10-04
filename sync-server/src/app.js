import express from 'express';
import { createHash, randomUUID } from 'node:crypto';
import { createReadStream, createWriteStream } from 'node:fs';
import { mkdir, rename, stat, unlink } from 'node:fs/promises';
import path from 'node:path';
import { Transform } from 'node:stream';
import { pipeline } from 'node:stream/promises';
import { rateLimit, sessionToken, sha256, verifyPassword } from './security.js';
import { push, schemaVersion, validateMutations } from './store.js';

export function createApp({ pool, filesRoot, publicOrigin, requireHttps = true,
  maxFileBytes = 256 * 1024 * 1024, quotaBytes = 10 * 1024 * 1024 * 1024 }) {
  const app = express();
  app.disable('x-powered-by');
  app.set('trust proxy', 1);
  app.use((req, res, next) => {
    res.set({ 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff',
      'Content-Security-Policy': "default-src 'none'; frame-ancestors 'none'" });
    if (req.path !== '/healthz' && requireHttps && !req.secure) return res.status(400).json({ error: 'HTTPS is required.' });
    if (req.get('origin') && req.get('origin') !== publicOrigin) return res.status(403).json({ error: 'Origin not permitted.' });
    next();
  });
  app.get('/healthz', async (_req, res) => {
    await pool.query('SELECT 1');
    res.json({ status: 'ok', schemaVersion });
  });
  app.use(rateLimit({ maximum: 600, windowMs: 60000 }));
  app.use(express.json({ limit: '4mb', strict: true }));
  let passwordChecks = 0;
  app.post('/v1/login', rateLimit({ maximum: 10, windowMs: 15 * 60000 }), async (req, res) => {
    const { username, password, deviceName } = req.body ?? {};
    if (typeof username !== 'string' || !/^[a-z0-9_.@-]{1,100}$/i.test(username) ||
        typeof password !== 'string' || password.length > 256 || typeof deviceName !== 'string' || !deviceName.trim() || deviceName.length > 100) {
      return res.status(400).json({ error: 'Invalid login fields.' });
    }
    if (passwordChecks >= 4) return res.status(429).json({ error: 'Please retry later.' });
    passwordChecks++;
    let account;
    let valid;
    try {
      const result = await pool.query('SELECT id, username, password_hash FROM accounts WHERE username=$1', [username.toLowerCase()]);
      account = result.rows[0];
      const dummy = `scrypt:${'0'.repeat(32)}:${'0'.repeat(128)}`;
      valid = await verifyPassword(password, account?.password_hash ?? dummy);
    } finally {
      passwordChecks--;
    }
    if (!account || !valid) return res.status(401).json({ error: 'Invalid username or password.' });
    const token = sessionToken();
    const expiresAt = new Date(Date.now() + 30 * 86400000);
    await pool.query('DELETE FROM sessions WHERE expires_at < now()');
    await pool.query('INSERT INTO sessions(token_hash,account_id,device_name,expires_at) VALUES($1,$2,$3,$4)',
      [sha256(token), account.id, deviceName.trim(), expiresAt]);
    res.json({ token, expiresAt: expiresAt.toISOString(), account: { id: account.id, username: account.username } });
  });
  app.use('/v1', async (req, res, next) => {
    const match = /^Bearer ([A-Za-z0-9_-]{43})$/.exec(req.get('authorization') ?? '');
    if (!match) return res.status(401).json({ error: 'Sign in required.' });
    req.tokenHash = sha256(match[1]);
    const result = await pool.query('SELECT account_id FROM sessions WHERE token_hash=$1 AND expires_at>now()', [req.tokenHash]);
    if (!result.rowCount) return res.status(401).json({ error: 'Session expired or revoked.' });
    req.accountId = result.rows[0].account_id;
    next();
  });
  app.get('/v1/me', async (req, res) => {
    const result = await pool.query('SELECT id,username FROM accounts WHERE id=$1', [req.accountId]);
    res.json({ account: result.rows[0], schemaVersion, maxFileBytes, quotaBytes });
  });
  app.post('/v1/logout', async (req, res) => {
    await pool.query('DELETE FROM sessions WHERE token_hash=$1', [req.tokenHash]);
    res.status(204).end();
  });
  app.post('/v1/logout-all', async (req, res) => {
    await pool.query('DELETE FROM sessions WHERE account_id=$1', [req.accountId]);
    res.status(204).end();
  });
  app.get('/v1/changes', async (req, res) => {
    const after = Number(req.query.after ?? 0);
    const limit = Number(req.query.limit ?? 100);
    if (!Number.isSafeInteger(after) || after < 0 || !Number.isInteger(limit) || limit < 1 || limit > 100) {
      return res.status(400).json({ error: 'Invalid cursor or page size.' });
    }
    const result = await pool.query(`SELECT revision,table_name,record_id,data FROM changes
      WHERE account_id=$1 AND revision>$2 ORDER BY revision LIMIT $3`, [req.accountId, after, limit + 1]);
    const rows = result.rows.slice(0, limit);
    res.json({ schemaVersion, changes: rows.map((r) => ({ revision: Number(r.revision), table: r.table_name, id: r.record_id, data: r.data })),
      cursor: Number(rows.at(-1)?.revision ?? after), hasMore: result.rows.length > limit });
  });
  app.post('/v1/changes', async (req, res) => {
    if (!validateMutations(req.body)) return res.status(400).json({ error: 'Invalid sync batch or unsupported schema version.' });
    const { status, ...result } = await push(pool, req.accountId, req.body.mutations);
    res.status(status).json(result);
  });
  const uploads = new Map();
  app.param('digest', (req, res, next, digest) => {
    if (!/^[a-f0-9]{64}$/.test(digest)) return res.status(400).json({ error: 'Invalid file digest.' });
    next();
  });
  app.put('/v1/files/:digest', async (req, res) => {
    const bytes = Number(req.get('content-length'));
    if (!req.get('content-length') || !Number.isSafeInteger(bytes) || bytes < 0 || bytes > maxFileBytes) {
      return res.status(413).json({ error: 'A valid Content-Length within the file limit is required.' });
    }
    if (req.get('content-type') !== 'application/octet-stream') return res.status(415).json({ error: 'Use application/octet-stream.' });
    const active = uploads.get(req.accountId) ?? 0;
    if (active >= 2) return res.status(429).json({ error: 'Too many concurrent uploads.' });
    uploads.set(req.accountId, active + 1);
    const directory = path.join(filesRoot, req.accountId);
    const temp = path.join(directory, `upload-${randomUUID()}`);
    try {
      await mkdir(directory, { recursive: true, mode: 0o700 });
      let received = 0;
      const hash = createHash('sha256');
      const meter = new Transform({ transform(chunk, _encoding, callback) {
        received += chunk.length;
        if (received > bytes) return callback(new Error('Upload exceeds declared size.'));
        hash.update(chunk);
        callback(null, chunk);
      } });
      await pipeline(req, meter, createWriteStream(temp, { flags: 'wx', mode: 0o600 }));
      if (received !== bytes || hash.digest('hex') !== req.params.digest) return res.status(422).json({ error: 'File checksum mismatch.' });
      const client = await pool.connect();
      try {
        await client.query('BEGIN');
        await client.query('SELECT id FROM accounts WHERE id=$1 FOR UPDATE', [req.accountId]);
        const existing = await client.query('SELECT bytes FROM files WHERE account_id=$1 AND digest=$2', [req.accountId, req.params.digest]);
        const usage = await client.query('SELECT COALESCE(SUM(bytes),0) AS bytes FROM files WHERE account_id=$1', [req.accountId]);
        if (!existing.rowCount && Number(usage.rows[0].bytes) + bytes > quotaBytes) {
          await client.query('ROLLBACK');
          return res.status(413).json({ error: 'Private storage quota exceeded.' });
        }
        await rename(temp, path.join(directory, req.params.digest));
        await client.query('INSERT INTO files(account_id,digest,bytes) VALUES($1,$2,$3) ON CONFLICT DO NOTHING', [req.accountId, req.params.digest, bytes]);
        await client.query('COMMIT');
      } catch (error) {
        await client.query('ROLLBACK');
        throw error;
      } finally {
        client.release();
      }
      res.status(201).json({ sha256: req.params.digest, bytes });
    } finally {
      uploads.set(req.accountId, (uploads.get(req.accountId) ?? 1) - 1);
      await unlink(temp).catch((error) => { if (error.code !== 'ENOENT') throw error; });
    }
  });
  app.get('/v1/files/:digest', async (req, res) => {
    const found = await pool.query('SELECT bytes FROM files WHERE account_id=$1 AND digest=$2', [req.accountId, req.params.digest]);
    if (!found.rowCount) return res.status(404).json({ error: 'File not found.' });
    const file = path.join(filesRoot, req.accountId, req.params.digest);
    const metadata = await stat(file);
    if (metadata.size !== Number(found.rows[0].bytes)) throw new Error('Stored file is incomplete.');
    res.set({ 'Content-Type': 'application/octet-stream', 'Content-Length': String(metadata.size),
      'Content-Disposition': 'attachment', 'X-Checksum-Sha256': req.params.digest });
    await pipeline(createReadStream(file), res);
  });
  app.use((_req, res) => res.status(404).json({ error: 'Not found.' }));
  app.use((error, _req, res, _next) => {
    if (res.headersSent) return res.destroy();
    const status = error.type === 'entity.too.large' ? 413 : error.type === 'entity.parse.failed' ? 400 : 500;
    res.status(status).json({ error: status === 500 ? 'Request failed. Please retry.' : 'Invalid request body.' });
  });
  return app;
}
