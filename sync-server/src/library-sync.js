import { readFileSync } from 'node:fs';
import { canonical, schemaVersion, validateMutations } from './store.js';
import { sha256 } from './security.js';

const schema = JSON.parse(readFileSync(new URL('./library-schema.json', import.meta.url), 'utf8'));
const key = (table, id) => JSON.stringify([table, id]);
const maxBytes = 48 * 1024 * 1024;
const maxRecords = 20000;
const uuid = /^[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}$/;

export function validCommit(body) {
  return body && uuid.test(body.operationId ?? '') && Number.isSafeInteger(body.expectedHead) && body.expectedHead >= 0 &&
    validateMutations(body, maxRecords);
}

async function head(client, owner) {
  const result = await client.query('SELECT COALESCE(MAX(revision),0) AS head FROM changes WHERE account_id=$1', [owner]);
  return Number(result.rows[0].head);
}

async function records(client, owner) {
  const size = await client.query(`SELECT COALESCE(SUM(COALESCE(octet_length(data::text),4)+octet_length(record_id)+128),0) AS bytes,
    COUNT(*) AS count FROM records WHERE account_id=$1`, [owner]);
  if (Number(size.rows[0].bytes) > maxBytes || Number(size.rows[0].count) > maxRecords) {
    const error = new Error('The library exceeds this sync version’s metadata limit.');
    error.status = 413;
    throw error;
  }
  const result = await client.query('SELECT table_name,record_id,revision,data FROM records WHERE account_id=$1 ORDER BY table_name,record_id', [owner]);
  return result.rows.map((r) => ({ table: r.table_name, id: r.record_id, revision: Number(r.revision), data: r.data }));
}

export async function snapshot(pool, owner) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query('SELECT id FROM accounts WHERE id=$1 FOR SHARE', [owner]);
    const result = { schemaVersion, head: await head(client, owner), records: await records(client, owner) };
    await client.query('COMMIT');
    return result;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

function validateLibrary(rows) {
  const live = new Map(rows.filter((r) => r.data !== null).map((r) => [key(r.table, r.id), r]));
  if (rows.length > maxRecords || Buffer.byteLength(JSON.stringify(rows)) > maxBytes) return 'The library metadata exceeds the sync limit.';
  const unique = new Map();
  for (const row of live.values()) {
    const spec = schema.tables[row.table];
    if (row.data.id !== row.id) return 'Record identity mismatch.';
    if (row.table === 'material_files') {
      if (row.id.includes(':') || row.id.includes('\\') || row.id.startsWith('/') || row.id.split('/').some((s) => !s || s === '.' || s === '..')) return 'Invalid material path.';
      continue;
    }
    if (!spec || Object.keys(row.data).length !== Object.keys(spec.columns).length ||
        Object.keys(row.data).some((c) => !Object.hasOwn(spec.columns, c))) return `The record columns do not match schema version ${schemaVersion}.`;
    for (const [column, definition] of Object.entries(spec.columns)) {
      const value = row.data[column];
      if (value === null) {
        if (definition.required) return 'A required value is missing.';
      } else if (definition.type === 'TEXT' ? typeof value !== 'string'
        : definition.type === 'INTEGER' ? !Number.isSafeInteger(value)
        : definition.type === 'REAL' ? typeof value !== 'number' || !Number.isFinite(value) : true) return 'A record contains an invalid value type.';
    }
    for (const foreign of spec.foreignKeys) {
      const id = row.data[foreign.column];
      if (id !== null && !live.has(key(foreign.table, id))) return 'Related records must be synchronized in the same operation.';
    }
    for (const columns of spec.unique) {
      const values = columns.map((c) => row.data[c]);
      if (values.some((v) => v === null)) continue;
      const constraint = canonical([row.table, columns, values]);
      if (unique.has(constraint)) return 'Two records violate a uniqueness constraint.';
      unique.set(constraint, row.id);
    }
    const path = row.table === 'lesson_materials' ? `lessons/${row.data.lesson_id}/${row.data.stored_file_name}`
      : row.table === 'reference_books' ? `books/${row.data.id}/${row.data.stored_file_name}` : null;
    if (path !== null && !live.has(key('material_files', path))) return 'Upload the PDF or image and its manifest before publishing the material.';
  }
  return null;
}

export async function commitLibrary(pool, owner, body) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query('SELECT id FROM accounts WHERE id=$1 FOR UPDATE', [owner]);
    const requestHash = sha256(canonical(body));
    const previous = await client.query('SELECT request_hash,response FROM sync_commits WHERE account_id=$1 AND operation_id=$2', [owner, body.operationId]);
    if (previous.rowCount) {
      await client.query('ROLLBACK');
      return previous.rows[0].request_hash === requestHash ? { status: 200, ...previous.rows[0].response }
        : { status: 409, code: 'operation_reused', error: 'Operation ID was reused with different content.' };
    }
    const currentHead = await head(client, owner);
    if (currentHead !== body.expectedHead) {
      await client.query('ROLLBACK');
      return { status: 409, code: 'head_changed', error: 'The library changed on another device. Refresh and merge again.' };
    }
    const current = new Map((await records(client, owner)).map((r) => [key(r.table, r.id), r]));
    for (const m of body.mutations) {
      if ((current.get(key(m.table, m.id))?.revision ?? 0) !== m.baseRevision) {
        await client.query('ROLLBACK');
        return { status: 409, code: 'record_changed', error: 'A record revision does not match the snapshot.' };
      }
      if (m.table === 'material_files' && m.data !== null) {
        const file = await client.query('SELECT bytes FROM files WHERE account_id=$1 AND digest=$2', [owner, m.data.sha256]);
        if (!file.rowCount || Number(file.rows[0].bytes) !== m.data.bytes) {
          await client.query('ROLLBACK');
          return { status: 422, error: 'The uploaded file is missing or has a different size.' };
        }
      }
      current.set(key(m.table, m.id), { table: m.table, id: m.id, data: m.data, revision: m.baseRevision });
    }
    const invalid = validateLibrary([...current.values()]);
    if (invalid) {
      await client.query('ROLLBACK');
      return { status: 422, error: invalid };
    }
    const accepted = [];
    for (const m of body.mutations) {
      const change = await client.query(`INSERT INTO changes(account_id,table_name,record_id,data,mutation_id,request_hash)
        VALUES($1,$2,$3,$4,$5,$6) RETURNING revision`,
        [owner, m.table, m.id, m.data === null ? null : JSON.stringify(m.data), m.mutationId, sha256(canonical(m))]);
      const revision = Number(change.rows[0].revision);
      await client.query(`INSERT INTO records(account_id,table_name,record_id,revision,data) VALUES($1,$2,$3,$4,$5)
        ON CONFLICT(account_id,table_name,record_id) DO UPDATE SET revision=EXCLUDED.revision,data=EXCLUDED.data`,
        [owner, m.table, m.id, revision, m.data === null ? null : JSON.stringify(m.data)]);
      accepted.push({ mutationId: m.mutationId, revision });
    }
    const response = { head: accepted.at(-1)?.revision ?? currentHead, accepted };
    await client.query('INSERT INTO sync_commits(account_id,operation_id,request_hash,response) VALUES($1,$2,$3,$4)',
      [owner, body.operationId, requestHash, JSON.stringify(response)]);
    await client.query('COMMIT');
    return { status: 200, ...response };
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}
