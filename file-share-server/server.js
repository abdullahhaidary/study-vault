const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

const PORT = 3000;
const UPLOADS = path.join(__dirname, 'uploads');

if (!fs.existsSync(UPLOADS)) fs.mkdirSync(UPLOADS);

let uploadSeq = 0;
const storage = multer.diskStorage({
  destination: UPLOADS,
  filename: (_req, file, cb) => {
    uploadSeq += 1;
    cb(null, `${Date.now()}-${uploadSeq}-${file.originalname}`);
  },
});
const upload = multer({
  storage,
  limits: { files: 100, fileSize: 2 * 1024 * 1024 * 1024 }, // 2GB each
});

const app = express();
app.use(express.urlencoded({ extended: false }));

function listUploads() {
  return fs.readdirSync(UPLOADS).filter((f) => !f.startsWith('.'));
}

function safeJoinUploads(name) {
  const base = path.basename(name);
  const file = path.join(UPLOADS, base);
  if (!file.startsWith(UPLOADS) || !fs.existsSync(file)) return null;
  return { base, file };
}

function resolveSelected(names) {
  const raw = Array.isArray(names) ? names : names ? [names] : [];
  const files = [];
  for (const name of raw) {
    const found = safeJoinUploads(name);
    if (found) files.push(found);
  }
  return files;
}

function sendZip(res, entries, zipName) {
  const zipBuf = makeStoreZip(entries);
  res.writeHead(200, {
    'Content-Type': 'application/zip',
    'Content-Length': zipBuf.length,
    'Content-Disposition': `attachment; filename*=UTF-8''${encodeURIComponent(zipName)}`,
    'Cache-Control': 'no-store',
  });
  res.end(zipBuf);
}

app.get('/', (_req, res) => {
  const files = listUploads();
  const list = files
    .map((f) => {
      const enc = encodeURIComponent(f);
      return `<li>
        <label class="pick">
          <input type="checkbox" name="files" value="${f.replace(/"/g, '&quot;')}" />
          <span class="name">${f}</span>
        </label>
        <div class="actions">
          <a class="btn" href="/download/${enc}">Download</a>
          <a class="btn secondary" href="/zip/${enc}">ZIP (iPhone)</a>
        </div>
      </li>`;
    })
    .join('') || '<li class="empty">No files yet</li>';

  const batchBar = files.length
    ? `<div class="batch">
        <label><input type="checkbox" id="select-all" /> Select all</label>
        <button type="submit" formaction="/batch-zip" formmethod="post">Download selected (ZIP)</button>
        <a class="btn secondary" href="/batch-zip?all=1">Download all (ZIP)</a>
      </div>`
    : '';

  res.send(`<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>File Share</title>
  <style>
    body { font-family: system-ui, sans-serif; max-width: 560px; margin: 40px auto; padding: 0 16px; }
    form.upload { margin: 24px 0; padding: 16px; border: 1px solid #ddd; border-radius: 8px; display: grid; gap: 10px; }
    form.upload .row { display: flex; flex-wrap: wrap; gap: 10px; align-items: center; }
    #upload-status { color: #666; font-size: 13px; }
    ul { list-style: none; padding: 0; margin: 0; }
    li { display: flex; align-items: center; gap: 12px; padding: 12px 0; border-bottom: 1px solid #eee; }
    li.empty { color: #666; }
    .pick { display: flex; align-items: flex-start; gap: 10px; flex: 1; min-width: 0; cursor: pointer; }
    .pick input { margin-top: 3px; flex-shrink: 0; }
    .name { flex: 1; word-break: break-all; font-size: 14px; }
    .actions { display: flex; flex-direction: column; gap: 6px; flex-shrink: 0; }
    .btn, button {
      padding: 8px 12px; background: #1a73e8; color: #fff; text-decoration: none;
      border-radius: 6px; font-size: 13px; white-space: nowrap; text-align: center;
      border: none; cursor: pointer; font: inherit;
    }
    .btn.secondary, a.btn.secondary { background: #5f6368; display: inline-block; }
    .hint { color: #666; font-size: 13px; line-height: 1.45; }
    .batch {
      display: flex; flex-wrap: wrap; align-items: center; gap: 10px;
      margin: 12px 0 8px; padding: 12px; background: #f6f8fa; border-radius: 8px;
    }
  </style>
</head>
<body>
  <h1>File Share</h1>
  <form class="upload" action="/upload" method="post" enctype="multipart/form-data">
    <div class="row">
      <input type="file" name="files" id="files" multiple required />
      <button type="submit">Upload</button>
    </div>
    <div id="upload-status">Select one or many files, then Upload.</div>
  </form>
  <h2>Files</h2>
  <p class="hint">
    Upload accepts multiple files. For download: select files → <b>Download selected (ZIP)</b>,
    or <b>Download all</b>. On iPhone, single-file <b>ZIP (iPhone)</b> still works best for videos.
  </p>
  <form id="batch">
    ${batchBar}
    <ul>${list}</ul>
  </form>
  <script>
    const all = document.getElementById('select-all');
    if (all) {
      all.addEventListener('change', () => {
        document.querySelectorAll('#batch input[name="files"]').forEach((c) => { c.checked = all.checked; });
      });
    }
    const picker = document.getElementById('files');
    const status = document.getElementById('upload-status');
    if (picker && status) {
      picker.addEventListener('change', () => {
        const n = picker.files ? picker.files.length : 0;
        status.textContent = n ? n + ' file(s) ready to upload' : 'Select one or many files, then Upload.';
      });
    }
  </script>
</body>
</html>`);
});

app.post('/upload', upload.array('files', 100), (_req, res) => {
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
  sendZip(res, [{ name: base, data }], `${base}.zip`);
});

function handleBatchZip(req, res) {
  let selected;
  if (req.query.all === '1' || req.body?.all === '1') {
    selected = listUploads().map((name) => safeJoinUploads(name)).filter(Boolean);
  } else {
    selected = resolveSelected(req.body?.files || req.query.files);
  }

  if (!selected.length) {
    return res.status(400).send('No files selected. Go back and check at least one file.');
  }

  const entries = selected.map(({ base, file }) => ({
    name: base,
    data: fs.readFileSync(file),
  }));

  const stamp = new Date().toISOString().slice(0, 19).replace(/[:T]/g, '-');
  sendZip(res, entries, `files-${stamp}.zip`);
}

app.post('/batch-zip', handleBatchZip);
app.get('/batch-zip', handleBatchZip);

/** Build a store-only (no compression) ZIP from one or more entries. */
function makeStoreZip(entries) {
  const locals = [];
  const centrals = [];
  let offset = 0;

  for (const entry of entries) {
    const nameBuf = Buffer.from(entry.name, 'utf8');
    const data = entry.data;
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
    centralHeader.writeUInt32LE(offset, 42);
    nameBuf.copy(centralHeader, 46);

    locals.push(localHeader, data);
    centrals.push(centralHeader);
    offset += localHeader.length + size;
  }

  const centralSize = centrals.reduce((n, b) => n + b.length, 0);
  const end = Buffer.alloc(22);
  end.writeUInt32LE(0x06054b50, 0);
  end.writeUInt16LE(0, 4);
  end.writeUInt16LE(0, 6);
  end.writeUInt16LE(entries.length, 8);
  end.writeUInt16LE(entries.length, 10);
  end.writeUInt32LE(centralSize, 12);
  end.writeUInt32LE(offset, 16);
  end.writeUInt16LE(0, 20);

  return Buffer.concat([...locals, ...centrals, end]);
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
  console.log(`LAN: http://192.168.0.103:${PORT}`);
});
