import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';
import { randomUUID } from 'node:crypto';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import pg from 'pg';
import { createApp } from '../src/app.js';
import { hashPassword, sha256, verifyPassword } from '../src/security.js';
import { migrate, validateMutations } from '../src/store.js';

const password = 'test-only-not-a-real-secret';
let pool;
let server;
let origin;
let filesRoot;
let token;
let secondToken;
const username = `test-${randomUUID()}`;
const secondUser = `test-${randomUUID()}`;
const account = randomUUID();
const otherAccount = randomUUID();
const record = randomUUID();
const fileContent = Buffer.from('private file test content');
const digest = sha256(fileContent);
let firstRevision;
let mutation;

async function request(route, { method = 'GET', body, auth = token, headers = {} } = {}) {
  return fetch(`${origin}${route}`, { method, headers: {
    ...(auth ? { authorization: `Bearer ${auth}` } : {}),
    ...(body ? { 'content-type': 'application/json' } : {}), ...headers,
  }, body: body ? JSON.stringify(body) : undefined });
}
const batch = (mutations) => ({ schemaVersion: 17, mutations });
const change = (id = randomUUID(), data = { id }, baseRevision = 0) => ({
  table: 'study_notes', id, data, baseRevision, mutationId: randomUUID(),
});

before(async () => {
  assert.ok(process.env.TEST_DATABASE_URL, 'Use a dedicated test database.');
  pool = new pg.Pool({ connectionString: process.env.TEST_DATABASE_URL });
  await migrate(pool);
  const hash = await hashPassword(password);
  await pool.query('INSERT INTO accounts(id,username,password_hash) VALUES($1,$2,$3),($4,$5,$3)',
    [account, username, hash, otherAccount, secondUser]);
  filesRoot = await mkdtemp(path.join(tmpdir(), 'sv-sync-test-'));
  server = createApp({ pool, filesRoot, publicOrigin: 'https://127.0.0.1', requireHttps: false,
    maxFileBytes: 128, quotaBytes: 64 }).listen(0, '127.0.0.1');
  await new Promise((resolve) => server.once('listening', resolve));
  origin = `http://127.0.0.1:${server.address().port}`;
});

after(async () => {
  if (server) await new Promise((resolve) => server.close(resolve));
  await pool?.end();
  if (filesRoot) await rm(filesRoot, { recursive: true, force: true });
});

test('password hashes are salted and reject incorrect passwords', async () => {
  const first = await hashPassword(password);
  const second = await hashPassword(password);
  assert.notEqual(first, second);
  assert.equal(await verifyPassword(password, first), true);
  assert.equal(await verifyPassword('incorrect', first), false);
  await assert.rejects(hashPassword('short'));
});

test('authentication is required and public registration does not exist', async () => {
  assert.equal((await request('/v1/me', { auth: null })).status, 401);
  assert.equal((await request('/v1/signup', { method: 'POST', auth: null })).status, 401);
  const wrong = await request('/v1/login', { method: 'POST', auth: null,
    body: { username, password: 'incorrect', deviceName: 'test' } });
  assert.equal(wrong.status, 401);
  const response = await request('/v1/login', { method: 'POST', auth: null,
    body: { username, password, deviceName: 'Linux test' } });
  assert.equal(response.status, 200);
  const result = await response.json();
  token = result.token;
  assert.equal(result.account.id, account);
  const sessions = await pool.query('SELECT token_hash FROM sessions WHERE account_id=$1', [account]);
  assert.equal(sessions.rows[0].token_hash, sha256(token));
  assert.notEqual(sessions.rows[0].token_hash, token);
  const other = await request('/v1/login', { method: 'POST', auth: null,
    body: { username: secondUser, password, deviceName: 'other' } });
  secondToken = (await other.json()).token;
});

test('untrusted origins and invalid batches are rejected', async () => {
  assert.equal((await request('/v1/me', { headers: { origin: 'https://untrusted.invalid' } })).status, 403);
  const invalid = change();
  invalid.table = 'accounts';
  assert.equal((await request('/v1/changes', { method: 'POST', body: batch([invalid]) })).status, 400);
  const valid = change();
  assert.equal(validateMutations(batch([valid, valid])), false);
  assert.equal(validateMutations({ schemaVersion: 18, mutations: [valid] }), false);
  assert.equal(validateMutations(batch([{ ...valid, data: { id: 'wrong' } }])), false);
});

test('sync preserves payloads and retries are idempotent', async () => {
  mutation = change(record, { id: record, title: 'Unicode فارسی', content: '**Content**' });
  const response = await request('/v1/changes', { method: 'POST', body: batch([mutation]) });
  assert.equal(response.status, 200);
  firstRevision = (await response.json()).accepted[0].revision;
  const retry = await request('/v1/changes', { method: 'POST', body: batch([mutation]) });
  assert.equal((await retry.json()).accepted[0].revision, firstRevision);
  const pulled = await (await request('/v1/changes?after=0')).json();
  assert.equal(pulled.changes.length, 1);
  assert.deepEqual(pulled.changes[0].data, mutation.data);
  const reused = { ...mutation, data: { ...mutation.data, title: 'different' } };
  assert.equal((await request('/v1/changes', { method: 'POST', body: batch([reused]) })).status, 409);
});

test('one conflicting edit rejects the entire batch and preserves both versions', async () => {
  const other = change();
  const stale = change(record, { id: record, content: 'offline edit' }, 0);
  const response = await request('/v1/changes', { method: 'POST', body: batch([other, stale]) });
  assert.equal(response.status, 409);
  const conflict = (await response.json()).conflicts[0];
  assert.equal(conflict.revision, firstRevision);
  assert.deepEqual(conflict.data, mutation.data);
  const missing = await pool.query('SELECT * FROM records WHERE account_id=$1 AND record_id=$2', [account, other.id]);
  assert.equal(missing.rowCount, 0);
  const updated = change(record, { id: record, content: 'resolved edit' }, firstRevision);
  assert.equal((await request('/v1/changes', { method: 'POST', body: batch([updated]) })).status, 200);
  const history = await pool.query('SELECT data FROM changes WHERE account_id=$1 AND record_id=$2 ORDER BY revision', [account, record]);
  assert.deepEqual(history.rows.map((r) => r.data), [mutation.data, updated.data]);
});

test('concurrent edits serialize and exactly one wins its base revision', async () => {
  const id = randomUUID();
  const responses = await Promise.all(['one', 'two'].map((title) => request('/v1/changes', {
    method: 'POST', body: batch([change(id, { id, title })]),
  })));
  assert.deepEqual(responses.map((r) => r.status).sort(), [200, 409]);
});

test('deletions are durable tombstones and pagination does not skip changes', async () => {
  const current = await pool.query('SELECT revision FROM records WHERE account_id=$1 AND record_id=$2', [account, record]);
  const deletion = change(record, null, Number(current.rows[0].revision));
  assert.equal((await request('/v1/changes', { method: 'POST', body: batch([deletion]) })).status, 200);
  let cursor = 0;
  const seen = [];
  let hasMore;
  do {
    const page = await (await request(`/v1/changes?after=${cursor}&limit=1`)).json();
    seen.push(...page.changes);
    assert.ok(page.cursor >= cursor);
    cursor = page.cursor;
    hasMore = page.hasMore;
  } while (hasMore);
  assert.equal(seen.filter((c) => c.id === record).at(-1).data, null);
  const count = await pool.query('SELECT COUNT(*) FROM changes WHERE account_id=$1', [account]);
  assert.equal(seen.length, Number(count.rows[0].count));
});

test('another account cannot read changes or private files', async () => {
  assert.deepEqual((await (await request('/v1/changes', { auth: secondToken })).json()).changes, []);
  assert.equal((await request(`/v1/files/${digest}`, { auth: secondToken })).status, 404);
});

test('private uploads verify hashes and downloads preserve bytes', async () => {
  const response = await fetch(`${origin}/v1/files/${digest}`, { method: 'PUT',
    headers: { authorization: `Bearer ${token}`, 'content-type': 'application/octet-stream' }, body: fileContent });
  assert.equal(response.status, 201);
  const download = await request(`/v1/files/${digest}`);
  assert.equal(download.status, 200);
  assert.deepEqual(Buffer.from(await download.arrayBuffer()), fileContent);
  assert.equal((await request(`/v1/files/${digest}`, { auth: secondToken })).status, 404);
  const wrong = await fetch(`${origin}/v1/files/${'a'.repeat(64)}`, { method: 'PUT',
    headers: { authorization: `Bearer ${token}`, 'content-type': 'application/octet-stream' }, body: fileContent });
  assert.equal(wrong.status, 422);
  const large = Buffer.alloc(65, 1);
  const overQuota = await fetch(`${origin}/v1/files/${sha256(large)}`, { method: 'PUT',
    headers: { authorization: `Bearer ${token}`, 'content-type': 'application/octet-stream' }, body: large });
  assert.equal(overQuota.status, 413);
});

test('file manifests require uploaded bytes and cannot escape the local directory', async () => {
  const data = { id: 'lessons/test/lecture.pdf', sha256: digest, bytes: fileContent.length };
  const manifest = { ...change(data.id, data), table: 'material_files' };
  assert.equal((await request('/v1/changes', { method: 'POST', body: batch([manifest]) })).status, 200);
  assert.equal(validateMutations(batch([{ ...manifest, id: '../escape', data: { ...data, id: '../escape' } }])), false);
  const missing = { ...manifest, id: 'missing.pdf', mutationId: randomUUID(), data: { ...data, id: 'missing.pdf', sha256: 'f'.repeat(64) } };
  assert.equal((await request('/v1/changes', { method: 'POST', body: batch([missing]) })).status, 422);
});

test('logout revokes the device session', async () => {
  assert.equal((await request('/v1/logout', { method: 'POST' })).status, 204);
  assert.equal((await request('/v1/me')).status, 401);
  assert.equal((await request('/v1/me', { auth: secondToken })).status, 200);
});

test('production refuses non-HTTPS login', async () => {
  const secure = createApp({ pool, filesRoot, publicOrigin: 'https://127.0.0.1' }).listen(0, '127.0.0.1');
  await new Promise((resolve) => secure.once('listening', resolve));
  try {
    const response = await fetch(`http://127.0.0.1:${secure.address().port}/v1/login`, { method: 'POST' });
    assert.equal(response.status, 400);
  } finally {
    await new Promise((resolve) => secure.close(resolve));
  }
});
