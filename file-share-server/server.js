const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

const PORT = 3000;
const UPLOADS = path.join(__dirname, 'uploads');

if (!fs.existsSync(UPLOADS)) fs.mkdirSync(UPLOADS);

const storage = multer.diskStorage({
  destination: UPLOADS,
  filename: (_req, file, cb) => cb(null, Date.now() + '-' + file.originalname),
});
const upload = multer({ storage });

const app = express();

function safeJoinUploads(name) {
  const base = path.basename(name);
  const file = path.join(UPLOADS, base);
  if (!file.startsWith(UPLOADS) || !fs.existsSync(file)) return null;
  return { base, file };
}

app.get('/', (_req, res) => {
  const files = fs.readdirSync(UPLOADS).filter((f) => !f.startsWith('.'));
  const list = files
    .map((f) => {
      const enc = encodeURIComponent(f);
      return `<li>
        <span class="name">${f}</span>
        <div class="actions">
          <a class="btn" href="/download/${enc}">Download</a>
          <a class="btn secondary" href="/zip/${enc}">ZIP (iPhone)</a>
        </div>
      </li>`;
    })
    .join('') || '<li class="empty">No files yet</li>';

  res.send(`<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>File Share</title>
  <style>
    body { font-family: system-ui, sans-serif; max-width: 560px; margin: 40px auto; padding: 0 16px; }
    form { margin: 24px 0; padding: 16px; border: 1px solid #ddd; border-radius: 8px; }
    ul { list-style: none; padding: 0; margin: 0; }
    li { display: flex; align-items: center; gap: 12px; padding: 12px 0; border-bottom: 1px solid #eee; }
    li.empty { color: #666; }
    .name { flex: 1; word-break: break-all; font-size: 14px; }
    .actions { display: flex; flex-direction: column; gap: 6px; flex-shrink: 0; }
    .btn {
      padding: 8px 12px; background: #1a73e8; color: #fff; text-decoration: none;
      border-radius: 6px; font-size: 13px; white-space: nowrap; text-align: center;
    }
    .btn.secondary { background: #5f6368; }
    .hint { color: #666; font-size: 13px; line-height: 1.45; }
  </style>
</head>
<body>
  <h1>File Share</h1>
  <form action="/upload" method="post" enctype="multipart/form-data">
    <input type="file" name="file" required />
    <button type="submit">Upload</button>
  </form>
  <h2>Files</h2>
  <p class="hint">
    On iPhone, tap <b>ZIP (iPhone)</b> — Safari will save the zip.
    Then open Files and unzip to get the video.
  </p>
  <ul>${list}</ul>
</body>
</html>`);
});

app.post('/upload', upload.single('file'), (_req, res) => {
  res.redirect('/');
});

app.get('/download/:name', (req, res) => {
  const found = safeJoinUploads(req.params.name);
  if (!found) return res.status(404).send('Not found');

  const { base, file } = found;
  const stat = fs.statSync(file);

  res.writeHead(200, {
    'Content-Type': 'application/octet-stream',
    'Content-Length': stat.size,
    'Content-Disposition': `attachment; filename*=UTF-8''${encodeURIComponent(base)}`,
    'X-Content-Type-Options': 'nosniff',
    'Cache-Control': 'no-store',
  });
  fs.createReadStream(file).pipe(res);
});

app.get('/zip/:name', (req, res) => {
  const found = safeJoinUploads(req.params.name);
  if (!found) return res.status(404).send('Not found');

  const { base, file } = found;
  const data = fs.readFileSync(file);
  const zipName = `${base}.zip`;
  const zipBuf = makeStoreZip(base, data);

  res.writeHead(200, {
    'Content-Type': 'application/zip',
    'Content-Length': zipBuf.length,
    'Content-Disposition': `attachment; filename*=UTF-8''${encodeURIComponent(zipName)}`,
    'Cache-Control': 'no-store',
  });
  res.end(zipBuf);
});

function makeStoreZip(filename, data) {
  const nameBuf = Buffer.from(filename, 'utf8');
  const size = data.length;
  const crc = crc32(data);

  const localHeader = Buffer.alloc(30 + nameBuf.length);
  localHeader.writeUInt32LE(0x04034b50, 0);
  localHeader.writeUInt16LE(20, 4);
  localHeader.writeUInt16LE(0, 6);
  localHeader.writeUInt16LE(0, 8);
  localHeader.writeUInt16LE(0, 10);
  localHeader.writeUInt16LE(0, 12);
  localHeader.writeUInt32LE(crc, 14);
  localHeader.writeUInt32LE(size, 18);
  localHeader.writeUInt32LE(size, 22);
  localHeader.writeUInt16LE(nameBuf.length, 26);
  localHeader.writeUInt16LE(0, 28);
  nameBuf.copy(localHeader, 30);

  const centralHeader = Buffer.alloc(46 + nameBuf.length);
  centralHeader.writeUInt32LE(0x02014b50, 0);
  centralHeader.writeUInt16LE(20, 4);
  centralHeader.writeUInt16LE(20, 6);
  centralHeader.writeUInt16LE(0, 8);
  centralHeader.writeUInt16LE(0, 10);
  centralHeader.writeUInt16LE(0, 12);
  centralHeader.writeUInt16LE(0, 14);
  centralHeader.writeUInt32LE(crc, 16);
  centralHeader.writeUInt32LE(size, 20);
  centralHeader.writeUInt32LE(size, 24);
  centralHeader.writeUInt16LE(nameBuf.length, 28);
  centralHeader.writeUInt16LE(0, 30);
  centralHeader.writeUInt16LE(0, 32);
  centralHeader.writeUInt16LE(0, 34);
  centralHeader.writeUInt16LE(0, 36);
  centralHeader.writeUInt32LE(0, 38);
  centralHeader.writeUInt32LE(0, 42);
  nameBuf.copy(centralHeader, 46);

  const end = Buffer.alloc(22);
  end.writeUInt32LE(0x06054b50, 0);
  end.writeUInt16LE(0, 4);
  end.writeUInt16LE(0, 6);
  end.writeUInt16LE(1, 8);
  end.writeUInt16LE(1, 10);
  end.writeUInt32LE(centralHeader.length, 12);
  end.writeUInt32LE(localHeader.length + size, 16);
  end.writeUInt16LE(0, 20);

  return Buffer.concat([localHeader, data, centralHeader, end]);
}

function crc32(buf) {
  let crc = 0xffffffff;
  for (let i = 0; i < buf.length; i++) {
    crc ^= buf[i];
    for (let j = 0; j < 8; j++) {
      crc = (crc >>> 1) ^ (crc & 1 ? 0xedb88320 : 0);
    }
  }
  return (crc ^ 0xffffffff) >>> 0;
}

app.listen(PORT, '0.0.0.0', () => {
  console.log(`File share running at http://localhost:${PORT}`);
});
