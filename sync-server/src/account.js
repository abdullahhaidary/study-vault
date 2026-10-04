import { readFile } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';
import { Writable } from 'node:stream';
import readline from 'node:readline/promises';
import pg from 'pg';
import { hashPassword } from './security.js';
import { migrate } from './store.js';

const [action, rawUsername] = process.argv.slice(2);
if (!['create', 'password'].includes(action) || !/^[a-z0-9_.@-]{1,100}$/i.test(rawUsername ?? '')) {
  throw new Error('Usage: npm run account -- create|password USERNAME');
}
if (!process.stdin.isTTY) throw new Error('Run this command in an interactive terminal.');
const output = new Writable({ write(_chunk, _encoding, done) { done(); } });
const input = readline.createInterface({ input: process.stdin, output, terminal: true });
let password;
try {
  process.stdout.write('New app password (14–256 characters, hidden): ');
  password = await input.question('');
  process.stdout.write('\nConfirm app password (hidden): ');
  const confirmation = await input.question('');
  process.stdout.write('\n');
  if (password !== confirmation) throw new Error('Passwords do not match.');
} finally {
  input.close();
}
const passwordHash = await hashPassword(password);
password = undefined;
const dbPassword = (await readFile(process.env.DB_PASSWORD_FILE ?? '/run/secrets/db_password', 'utf8')).trim();
const pool = new pg.Pool({ host: process.env.PGHOST ?? 'db', database: 'study_vault', user: 'study_vault', password: dbPassword });
try {
  await migrate(pool);
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query('SELECT pg_advisory_xact_lock(174829302)');
    if (action === 'create') {
      const existing = await client.query('SELECT id FROM accounts LIMIT 1');
      if (existing.rowCount) throw new Error('The private account already exists. Use password to reset it.');
      await client.query('INSERT INTO accounts(id,username,password_hash) VALUES($1,$2,$3)', [randomUUID(), rawUsername.toLowerCase(), passwordHash]);
    } else {
      const result = await client.query('UPDATE accounts SET password_hash=$1 WHERE username=$2 RETURNING id', [passwordHash, rawUsername.toLowerCase()]);
      if (!result.rowCount) throw new Error('Account not found.');
      await client.query('DELETE FROM sessions WHERE account_id=$1', [result.rows[0].id]);
    }
    await client.query('COMMIT');
    console.log(action === 'create' ? 'Private account created.' : 'Password changed; all sessions revoked.');
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
} finally {
  await pool.end();
}
