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
const row = { id: classId, name: 'Library', description: null, sort_order: 0, created_at: 1, updated_at: 1 };
const mutation = (data, revision = 0, table = 'classes', id = classId) => ({
  table, id, data, baseRevision: revision, mutationId: randomUUID(),
});
const batch = (mutations, expectedHead = 0) => ({ schemaVersion: 24, operationId: randomUUID(), expectedHead, mutations });
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
  assert.deepEqual(result, { schemaVersion: 24, head: 0, records: [] });
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
    description: null, sort_order: 0, exam_date: null, created_at: 1, updated_at: 1 };
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

test('revision checks and deltas require authentication and validate cursors', async () => {
  assert.equal((await request('/v2/status', null, null)).status, 401);
  assert.equal((await request('/v2/changes?after=0', null, null)).status, 401);
  for (const query of ['', '?after=-1', '?after=1.5', '?after=no', '?after=9007199254740992', '?after=1&after=2']) {
    assert.equal((await request(`/v2/changes${query}`)).status, 400);
  }
  const status = await (await request('/v2/status')).json();
  assert.equal(status.head, (await (await request('/v2/snapshot')).json()).head);
  assert.deepEqual(await (await request(`/v2/changes?after=${status.head}`)).json(), {
    schemaVersion: 24, head: status.head, records: [],
  });
  assert.equal((await request(`/v2/changes?after=${status.head + 1}`)).status, 409);
});

test('deltas return only latest changed records and retain deletion tombstones', async () => {
  const start = await (await request('/v2/status')).json();
  const id = randomUUID(), subjectId = randomUUID();
  const parent = { ...row, id };
  const child = { id: subjectId, class_id: id, subject_group_id: null, name: 'Subject',
    description: null, sort_order: 0, exam_date: null, created_at: 1, updated_at: 1 };
  const response = await request('/v2/sync', batch([
    mutation(parent, 0, 'classes', id), mutation(child, 0, 'subjects', subjectId),
  ], start.head));
  assert.equal(response.status, 200);
  const created = await response.json();
  const parentRevision = created.accepted[0].revision;
  const childRevision = created.accepted[1].revision;
  const updatedResponse = await request('/v2/sync', batch([
    mutation({ ...parent, name: 'Latest' }, parentRevision, 'classes', id),
  ], created.head));
  assert.equal(updatedResponse.status, 200);
  const updated = await updatedResponse.json();
  const delta = await (await request(`/v2/changes?after=${start.head}`)).json();
  assert.equal(delta.records.length, 2);
  assert.equal(delta.head, updated.head);
  assert.equal(delta.records.find((r) => r.id === id).data.name, 'Latest');
  const one = await (await request(`/v2/changes?after=${created.head}`)).json();
  assert.equal(one.records.length, 1);
  assert.equal(one.records[0].id, id);
  const deletionResponse = await request('/v2/sync', batch([
    mutation(null, updated.head, 'classes', id), mutation(null, childRevision, 'subjects', subjectId),
  ], updated.head));
  assert.equal(deletionResponse.status, 200);
  const deleted = await deletionResponse.json();
  const tombstones = await (await request(`/v2/changes?after=${updated.head}`)).json();
  assert.equal(tombstones.head, deleted.head);
  assert.equal(tombstones.records.length, 2);
  assert.ok(tombstones.records.every((r) => r.data === null));
});

test('revision checks and deltas are account scoped', async () => {
  const otherOwner = randomUUID(), otherToken = sessionToken();
  await pool.query('INSERT INTO accounts(id,username,password_hash) VALUES($1,$2,$3)', [otherOwner, otherOwner, 'test-only']);
  await pool.query("INSERT INTO sessions(token_hash,account_id,device_name,expires_at) VALUES($1,$2,'test',now()+interval '1 day')", [sha256(otherToken), otherOwner]);
  assert.deepEqual(await (await request('/v2/status', null, otherToken)).json(), { schemaVersion: 24, head: 0 });
  assert.deepEqual(await (await request('/v2/changes?after=0', null, otherToken)).json(), {
    schemaVersion: 24, head: 0, records: [],
  });
});
