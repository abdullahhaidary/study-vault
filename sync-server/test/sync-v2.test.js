import assert from 'node:assert/strict';
import { before, after, test } from 'node:test';
import { randomUUID } from 'node:crypto';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import pg from 'pg';
import { createApp } from '../src/app.js';
import { migrate } from '../src/store.js';
import { sha256, sessionToken } from '../src/security.js';

let pool, server, root, origin, token, owner;
const classId = randomUUID();
const row = { id: classId, name: 'Library', description: null, created_at: 1, updated_at: 1 };
const mutation = (data, revision = 0, table = 'classes', id = classId) => ({
  table, id, data, baseRevision: revision, mutationId: randomUUID(),
});
const batch = (mutations, expectedHead = 0) => ({ schemaVersion: 18, operationId: randomUUID(), expectedHead, mutations });
const request = (route, body, auth = token) => fetch(`${origin}${route}`, {
  method: body ? 'POST' : 'GET', headers: { ...(auth ? { authorization: `Bearer ${auth}` } : {}), 'content-type': 'application/json' },
  body: body ? JSON.stringify(body) : undefined,
});
let committed;
let first;

before(async () => {
  assert.ok(process.env.TEST_DATABASE_URL);
  pool = new pg.Pool({ connectionString: process.env.TEST_DATABASE_URL });
  await migrate(pool);
  owner = randomUUID();
  token = sessionToken();
  await pool.query('INSERT INTO accounts(id,username,password_hash) VALUES($1,$2,$3)', [owner, owner, 'not-a-login-password']);
  await pool.query("INSERT INTO sessions(token_hash,account_id,device_name,expires_at) VALUES($1,$2,'test',now()+interval '1 day')", [sha256(token), owner]);
  root = await mkdtemp(path.join(tmpdir(), 'sv-v2-'));
  server = createApp({ pool, filesRoot: root, publicOrigin: 'https://example.invalid', requireHttps: false }).listen(0, '127.0.0.1');
  await new Promise((resolve) => server.once('listening', resolve));
  origin = `http://127.0.0.1:${server.address().port}`;
});
after(async () => {
  if (server) await new Promise((resolve) => server.close(resolve));
  await pool?.end();
  if (root) await rm(root, { recursive: true, force: true });
});

test('v2 snapshots require authentication and start empty', async () => {
  assert.equal((await request('/v2/snapshot', null, null)).status, 401);
  const result = await (await request('/v2/snapshot')).json();
  assert.deepEqual(result, { schemaVersion: 18, head: 0, records: [] });
});

test('library commits are atomic and safely replayable', async () => {
  first = batch([mutation(row)]);
  const response = await request('/v2/sync', first);
  assert.equal(response.status, 200);
  committed = await response.json();
  assert.ok(committed.head > 0);
  assert.deepEqual(await (await request('/v2/sync', first)).json(), committed);
  const snapshot = await (await request('/v2/snapshot')).json();
  assert.equal(snapshot.head, committed.head);
  assert.deepEqual(snapshot.records[0].data, row);
});

test('unseen changes on another record reject an entire stale library commit', async () => {
  const id = randomUUID();
  const stale = batch([mutation({ ...row, id }, 0, 'classes', id)], 0);
  assert.equal((await request('/v2/sync', stale)).status, 409);
  const snapshot = await (await request('/v2/snapshot')).json();
  assert.equal(snapshot.records.length, 1);
});

test('an operation ID cannot be reused to write different data', async () => {
  const reused = { ...first, mutations: [mutation({ ...row, name: 'Changed' })] };
  assert.equal((await request('/v2/sync', reused)).status, 409);
});

test('invalid local column types and dangling foreign keys are rejected', async () => {
  const malformed = batch([mutation({ ...row, created_at: 'invalid' }, committed.head)], committed.head);
  assert.equal((await request('/v2/sync', malformed)).status, 422);
  const id = randomUUID();
  const note = { id, subject_id: randomUUID(), lesson_id: null, title: 'Orphan', content: 'Text',
    plain_text_content: 'Text', sort_order: 0, created_at: 1, updated_at: 1, deleted_at: null };
  const orphan = batch([mutation(note, 0, 'study_notes', id)], committed.head);
  assert.equal((await request('/v2/sync', orphan)).status, 422);
  assert.equal((await (await request('/v2/snapshot')).json()).head, committed.head);
});

test('multiple tables commit together and parent-only deletion cannot orphan a child', async () => {
  const subjectId = randomUUID();
  const subject = { id: subjectId, class_id: classId, subject_group_id: null, name: 'Subject',
    description: null, sort_order: 0, created_at: 1, updated_at: 1 };
  const result = await request('/v2/sync', batch([mutation(subject, 0, 'subjects', subjectId)], committed.head));
  assert.equal(result.status, 200);
  const latest = await result.json();
  const parentDelete = batch([mutation(null, committed.head)], latest.head);
  assert.equal((await request('/v2/sync', parentDelete)).status, 422);
  const deletion = batch([mutation(null, committed.head), mutation(null, latest.head, 'subjects', subjectId)], latest.head);
  assert.equal((await request('/v2/sync', deletion)).status, 200);
  const snapshot = await (await request('/v2/snapshot')).json();
  assert.equal(snapshot.records.filter((r) => r.data !== null).length, 0);
  assert.equal(snapshot.records.length, 2);
});

test('reference books require their uploaded PDF manifest', async () => {
  const { head } = await (await request('/v2/snapshot')).json();
  const id = randomUUID();
  const book = { id, title: 'Book', author: null, original_file_name: 'b.pdf', stored_file_name: 'b.pdf',
    page_count: 10, created_at: 1, updated_at: 1 };
  const response = await request('/v2/sync', batch([mutation(book, 0, 'reference_books', id)], head));
  assert.equal(response.status, 422);
  assert.match((await response.json()).error, /Upload the PDF/);
});
