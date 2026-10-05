import { randomUUID } from 'node:crypto';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import pg from 'pg';
import { createApp } from '../src/app.js';
import { migrate } from '../src/store.js';
import { hashPassword } from '../src/security.js';

const address = new URL(process.env.TEST_DATABASE_URL);
if (!['localhost', '127.0.0.1'].includes(address.hostname)) throw new Error('Only a local disposable test database is permitted.');
const pool = new pg.Pool({ connectionString: process.env.TEST_DATABASE_URL });
await migrate(pool);
await pool.query('INSERT INTO accounts(id,username,password_hash) VALUES($1,$2,$3)',
  [randomUUID(), process.env.TEST_USERNAME, await hashPassword('integration-test-only-password')]);
const filesRoot = await mkdtemp(path.join(tmpdir(), 'sv-flutter-http-'));
const server = createApp({ pool, filesRoot, publicOrigin: 'https://test.invalid', requireHttps: false }).listen(0, '127.0.0.1', () => {
  console.log(`READY:${server.address().port}`);
});
for (const signal of ['SIGTERM', 'SIGINT']) process.on(signal, () => {
  server.close(async () => {
    await pool.end();
    await rm(filesRoot, { recursive: true, force: true });
    process.exit(0);
  });
});
