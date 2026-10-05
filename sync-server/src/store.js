import { readFile } from 'node:fs/promises';
import { sha256 } from './security.js';

export const tables = new Set([
  'classes', 'subject_groups', 'subjects', 'lesson_groups', 'lessons',
  'lesson_materials', 'study_pin_categories', 'study_pins', 'study_pin_text_ranges',
  'favorites', 'study_review_sessions', 'study_review_events', 'material_bookmarks',
  'study_notes', 'flashcards', 'ai_chats', 'ai_chat_messages', 'ai_message_context_refs',
  'annotation_ai_generations', 'pdf_ai_materials', 'question_sets', 'quiz_questions',
  'quiz_question_options', 'quiz_attempts', 'quiz_answers', 'material_files',
]);
export const schemaVersion = 17;

export function canonical(value) {
  if (Array.isArray(value)) return `[${value.map(canonical).join(',')}]`;
  if (value !== null && typeof value === 'object') {
    return `{${Object.keys(value).sort().map((key) => `${JSON.stringify(key)}:${canonical(value[key])}`).join(',')}}`;
  }
  return JSON.stringify(value);
}

export function validateMutations(body, maximum = 100) {
  if (body?.schemaVersion !== schemaVersion || !Array.isArray(body.mutations) ||
      body.mutations.length < 1 || body.mutations.length > maximum) return false;
  const ids = new Set();
  const mutations = new Set();
  return body.mutations.every((m) => {
    if (!m || !tables.has(m.table) || typeof m.id !== 'string' || !m.id || m.id.length > 500 ||
        !Number.isSafeInteger(m.baseRevision) || m.baseRevision < 0 ||
        typeof m.mutationId !== 'string' || !/^[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}$/.test(m.mutationId) ||
        (m.data !== null && (typeof m.data !== 'object' || Array.isArray(m.data) || m.data.id !== m.id))) return false;
    const id = JSON.stringify([m.table, m.id]);
    if (ids.has(id) || mutations.has(m.mutationId) || Buffer.byteLength(JSON.stringify(m.data)) > 1024 * 1024) return false;
    if (m.table === 'material_files' && m.data !== null) {
      if (!/^[a-f0-9]{64}$/.test(m.data.sha256) || !Number.isSafeInteger(m.data.bytes) || m.data.bytes < 0 ||
          m.id.startsWith('/') || m.id.includes('\\') || m.id.split('/').some((part) => !part || part === '.' || part === '..')) return false;
    }
    ids.add(id);
    mutations.add(m.mutationId);
    return true;
  });
}

export async function migrate(pool) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query('SELECT pg_advisory_xact_lock(174829301)');
    await client.query(await readFile(new URL('./schema.sql', import.meta.url), 'utf8'));
    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

export async function push(pool, accountId, mutations) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query('SELECT id FROM accounts WHERE id=$1 FOR UPDATE', [accountId]);
    const accepted = [];
    const pending = [];
    const conflicts = [];
    for (const m of mutations) {
      const hash = sha256(canonical(m));
      const previous = await client.query('SELECT revision, request_hash FROM changes WHERE account_id=$1 AND mutation_id=$2', [accountId, m.mutationId]);
      if (previous.rowCount) {
        if (previous.rows[0].request_hash !== hash) {
          await client.query('ROLLBACK');
          return { status: 409, error: 'Mutation ID was reused with different content.' };
        }
        accepted.push({ mutationId: m.mutationId, revision: Number(previous.rows[0].revision) });
        continue;
      }
      const current = await client.query('SELECT revision, data FROM records WHERE account_id=$1 AND table_name=$2 AND record_id=$3', [accountId, m.table, m.id]);
      const revision = Number(current.rows[0]?.revision ?? 0);
      if (revision !== m.baseRevision) {
        conflicts.push({ table: m.table, id: m.id, revision, data: current.rows[0]?.data ?? null });
      } else {
        if (m.table === 'material_files' && m.data !== null) {
          const file = await client.query('SELECT bytes FROM files WHERE account_id=$1 AND digest=$2', [accountId, m.data.sha256]);
          if (!file.rowCount || Number(file.rows[0].bytes) !== m.data.bytes) {
            await client.query('ROLLBACK');
            return { status: 422, error: 'Upload the matching file before syncing its metadata.' };
          }
        }
        pending.push({ m, hash });
      }
    }
    if (conflicts.length) {
      await client.query('ROLLBACK');
      return { status: 409, error: 'Conflicting edits require resolution.', conflicts };
    }
    for (const { m, hash } of pending) {
      const change = await client.query(`INSERT INTO changes(account_id, table_name, record_id, data, mutation_id, request_hash)
        VALUES($1,$2,$3,$4,$5,$6) RETURNING revision`, [accountId, m.table, m.id, m.data === null ? null : JSON.stringify(m.data), m.mutationId, hash]);
      const revision = change.rows[0].revision;
      await client.query(`INSERT INTO records(account_id,table_name,record_id,revision,data) VALUES($1,$2,$3,$4,$5)
        ON CONFLICT(account_id,table_name,record_id) DO UPDATE SET revision=EXCLUDED.revision,data=EXCLUDED.data`,
        [accountId, m.table, m.id, revision, m.data === null ? null : JSON.stringify(m.data)]);
      accepted.push({ mutationId: m.mutationId, revision: Number(revision) });
    }
    await client.query('COMMIT');
    return { status: 200, accepted };
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}
