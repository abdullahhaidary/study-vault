const assert = require('node:assert/strict');
const { execFileSync } = require('node:child_process');
const fs = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');

const { storeZipChunks } = require('./zip_stream');

test('streams a valid multi-file ZIP with intact content', async () => {
  const dir = await fs.mkdtemp(path.join(os.tmpdir(), 'sv-zip-test-'));
  try {
    const files = [
      { name: 'notes.txt', content: Buffer.from('Study notes\n') },
      { name: 'empty.txt', content: Buffer.alloc(0) },
      { name: 'large.bin', content: Buffer.alloc(200000, 42) },
    ];
    const entries = [];
    for (const { name, content } of files) {
      const file = path.join(dir, name);
      await fs.writeFile(file, content);
      entries.push({ name, file, size: content.length });
    }
    const chunks = [];
    for await (const chunk of storeZipChunks(entries)) chunks.push(chunk);
    const archive = path.join(dir, 'files.zip');
    await fs.writeFile(archive, Buffer.concat(chunks));

    execFileSync('unzip', ['-t', archive]);
    for (const { name, content } of files) {
      assert.deepEqual(execFileSync('unzip', ['-p', archive, name]), content);
    }
  } finally {
    await fs.rm(dir, { recursive: true, force: true });
  }
});
