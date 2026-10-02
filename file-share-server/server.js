const express = require('express');
const multer = require('multer');
const os = require('os');
const path = require('path');
const fs = require('fs');

const PORT = Number(process.env.PORT) || 3000;
const UPLOADS = path.join(__dirname, 'uploads');
const PUBLIC = path.join(__dirname, 'public');

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
app.use(express.static(PUBLIC));

function listUploadNames() {
  return fs.readdirSync(UPLOADS).filter((f) => !f.startsWith('.'));
}

function listUploadsDetailed() {
  return listUploadNames()
    .map((name) => {
      const filePath = path.join(UPLOADS, name);
      try {
        const stat = fs.statSync(filePath);
        if (!stat.isFile()) return null;
        return {
          name,
          size: stat.size,
          mtime: stat.mtimeMs,
        };
      } catch {
        return null;
      }
    })
    .filter(Boolean)
    .sort((a, b) => b.mtime - a.mtime);
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

function lanAddresses() {
  const nets = os.networkInterfaces();
  const out = [];
  for (const entries of Object.values(nets)) {
    if (!entries) continue;
    for (const net of entries) {
      if (net.family === 'IPv4' && !net.internal) out.push(net.address);
    }
  }
  return out;
}

app.get('/api/files', (_req, res) => {
  res.set('Cache-Control', 'no-store');
  res.json({ files: listUploadsDetailed() });
});

app.post('/upload', upload.array('files', 100), (req, res) => {
  const count = req.files?.length ?? 0;
  const wantsJson =
    req.xhr ||
    (req.get('accept') || '').includes('application/json') ||
    req.get('x-requested-with') === 'XMLHttpRequest';

  if (wantsJson || req.get('content-type')?.includes('multipart/form-data')) {
    // XHR uploads from the redesigned UI
    return res.status(200).json({ ok: true, count });
  }
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
    selected = listUploadNames()
      .map((name) => safeJoinUploads(name))
      .filter(Boolean);
  } else {
    selected = resolveSelected(req.body?.files || req.query.files);
  }

  if (!selected.length) {
    return res
      .status(400)
      .send('No files selected. Go back and check at least one file.');
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
  console.log(`Study Vault Share → http://localhost:${PORT}`);
  for (const ip of lanAddresses()) {
    console.log(`                 → http://${ip}:${PORT}`);
  }
});
