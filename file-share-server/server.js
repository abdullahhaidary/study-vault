const express = require('express');
const multer = require('multer');
const os = require('os');
const path = require('path');
const fs = require('fs');
const { Readable } = require('stream');
const { pipeline } = require('stream/promises');
const { storeZipChunks } = require('./zip_stream');

const PORT = Number(process.env.PORT) || 3000;
const UPLOADS = path.join(__dirname, 'uploads');
const TEXTS_FILE = path.join(__dirname, 'texts.json');
const PUBLIC = path.join(__dirname, 'public');
const MAX_TEXT_CHARS = 200_000;

if (!fs.existsSync(UPLOADS)) fs.mkdirSync(UPLOADS);

function loadTexts() {
  try {
    if (!fs.existsSync(TEXTS_FILE)) return [];
    const raw = JSON.parse(fs.readFileSync(TEXTS_FILE, 'utf8'));
    return Array.isArray(raw) ? raw : [];
  } catch {
    return [];
  }
}

function saveTexts(items) {
  fs.writeFileSync(TEXTS_FILE, JSON.stringify(items, null, 2), 'utf8');
}

function listTexts() {
  return loadTexts().sort((a, b) => (b.createdAt || 0) - (a.createdAt || 0));
}

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
app.use(express.json({ limit: '1mb' }));
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

async function sendZip(res, entries, zipName) {
  try {
    const files = await Promise.all(entries.map(async ({ name, file }) => ({
      name,
      file,
      size: (await fs.promises.stat(file)).size,
    })));
    const estimatedSize = files.reduce(
      (sum, entry) => sum + entry.size + 200 + Buffer.byteLength(entry.name),
      22,
    );
    if (files.length > 65535 || estimatedSize > 0xffffffff) {
      return res.status(413).send('ZIP is too large to export. Select fewer files.');
    }
    res.writeHead(200, {
      'Content-Type': 'application/zip',
      'Content-Disposition': `attachment; filename*=UTF-8''${encodeURIComponent(zipName)}`,
      'Cache-Control': 'no-store',
    });
    await pipeline(Readable.from(storeZipChunks(files)), res);
  } catch (error) {
    if (res.headersSent) res.destroy(error);
    else res.status(500).send('Could not create ZIP.');
  }
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

app.get('/api/texts', (_req, res) => {
  res.set('Cache-Control', 'no-store');
  res.json({ texts: listTexts() });
});

app.post('/api/texts', (req, res) => {
  const text = typeof req.body?.text === 'string' ? req.body.text : '';
  const title =
    typeof req.body?.title === 'string' ? req.body.title.trim().slice(0, 120) : '';

  if (!text.trim()) {
    return res.status(400).json({ ok: false, error: 'Text is empty' });
  }
  if (text.length > MAX_TEXT_CHARS) {
    return res.status(400).json({
      ok: false,
      error: `Text too long (max ${MAX_TEXT_CHARS} characters)`,
    });
  }

  const items = loadTexts();
  const entry = {
    id: `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
    title: title || text.trim().slice(0, 48).replace(/\s+/g, ' '),
    text,
    createdAt: Date.now(),
  };
  items.push(entry);
  saveTexts(items);
  res.status(201).json({ ok: true, text: entry });
});

app.delete('/api/texts/:id', (req, res) => {
  const id = String(req.params.id || '');
  const items = loadTexts();
  const next = items.filter((t) => t.id !== id);
  if (next.length === items.length) {
    return res.status(404).json({ ok: false, error: 'Not found' });
  }
  saveTexts(next);
  res.json({ ok: true });
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
  sendZip(res, [{ name: base, file }], `${base}.zip`);
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

  const entries = selected.map(({ base, file }) => ({ name: base, file }));

  const stamp = new Date().toISOString().slice(0, 19).replace(/[:T]/g, '-');
  sendZip(res, entries, `files-${stamp}.zip`);
}

app.post('/batch-zip', handleBatchZip);
app.get('/batch-zip', handleBatchZip);

if (require.main === module) {
  app.listen(PORT, '0.0.0.0', () => {
    console.log(`Study Vault Share → http://localhost:${PORT}`);
    for (const ip of lanAddresses()) {
      console.log(`                 → http://${ip}:${PORT}`);
    }
  });
}

