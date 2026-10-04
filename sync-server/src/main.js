import { readFile } from 'node:fs/promises';
import pg from 'pg';
import { createApp } from './app.js';
import { migrate } from './store.js';

const password = (await readFile(process.env.DB_PASSWORD_FILE ?? '/run/secrets/db_password', 'utf8')).trim();
const publicOrigin = process.env.PUBLIC_ORIGIN;
if (!publicOrigin || new URL(publicOrigin).protocol !== 'https:') throw new Error('PUBLIC_ORIGIN must use HTTPS.');
const pool = new pg.Pool({ host: process.env.PGHOST ?? 'db', database: 'study_vault', user: 'study_vault', password,
  max: 10, connectionTimeoutMillis: 10000, idleTimeoutMillis: 30000, statement_timeout: 30000 });
await migrate(pool);
const app = createApp({ pool, filesRoot: process.env.FILES_ROOT ?? '/data/files', publicOrigin });
const server = app.listen(8080, '0.0.0.0', () => console.log('Study Vault API listening on port 8080.'));
server.requestTimeout = 300000;
server.headersTimeout = 15000;
for (const signal of ['SIGTERM', 'SIGINT']) process.on(signal, () => {
  server.close(async () => { await pool.end(); process.exit(0); });
  setTimeout(() => process.exit(1), 15000).unref();
});
