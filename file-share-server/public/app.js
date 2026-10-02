(() => {
  const fileListEl = document.getElementById('file-list');
  const emptyEl = document.getElementById('empty-state');
  const librarySub = document.getElementById('library-sub');
  const batchBar = document.getElementById('batch-bar');
  const selectAll = document.getElementById('select-all');
  const selectionLabel = document.getElementById('selection-label');
  const zipSelectedBtn = document.getElementById('zip-selected');
  const zipAllBtn = document.getElementById('zip-all');
  const refreshBtn = document.getElementById('refresh-btn');
  const dropzone = document.getElementById('upload-form');
  const fileInput = document.getElementById('file-input');
  const browseBtn = document.getElementById('browse-btn');
  const progressEl = document.getElementById('upload-progress');
  const progressFill = document.getElementById('progress-fill');
  const progressLabel = document.getElementById('progress-label');
  const toastEl = document.getElementById('toast');
  const textForm = document.getElementById('text-form');
  const textTitle = document.getElementById('text-title');
  const textBody = document.getElementById('text-body');
  const textShareBtn = document.getElementById('text-share-btn');
  const textListEl = document.getElementById('text-list');
  const textSub = document.getElementById('text-sub');

  /** @type {{ name: string, size: number, mtime: number }[]} */
  let files = [];
  /** @type {{ id: string, title: string, text: string, createdAt: number }[]} */
  let texts = [];
  let toastTimer = 0;

  function showToast(message) {
    toastEl.hidden = false;
    toastEl.textContent = message;
    requestAnimationFrame(() => toastEl.classList.add('is-visible'));
    clearTimeout(toastTimer);
    toastTimer = window.setTimeout(() => {
      toastEl.classList.remove('is-visible');
      window.setTimeout(() => {
        toastEl.hidden = true;
      }, 280);
    }, 2800);
  }

  function formatBytes(n) {
    if (n < 1024) return `${n} B`;
    const units = ['KB', 'MB', 'GB', 'TB'];
    let v = n;
    let i = -1;
    do {
      v /= 1024;
      i += 1;
    } while (v >= 1024 && i < units.length - 1);
    return `${v.toFixed(v >= 10 || i === 0 ? 0 : 1)} ${units[i]}`;
  }

  function formatWhen(ms) {
    const d = new Date(ms);
    const now = Date.now();
    const diff = Math.max(0, now - ms);
    const mins = Math.floor(diff / 60000);
    if (mins < 1) return 'Just now';
    if (mins < 60) return `${mins}m ago`;
    const hours = Math.floor(mins / 60);
    if (hours < 24) return `${hours}h ago`;
    const days = Math.floor(hours / 24);
    if (days < 7) return `${days}d ago`;
    return d.toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
  }

  function fileKind(name) {
    const ext = (name.split('.').pop() || '').toLowerCase();
    if (['pdf'].includes(ext)) return { kind: 'pdf', label: 'PDF' };
    if (['png', 'jpg', 'jpeg', 'gif', 'webp', 'heic', 'svg'].includes(ext)) {
      return { kind: 'image', label: 'IMG' };
    }
    if (['mp4', 'mov', 'm4v', 'webm', 'mkv', 'avi'].includes(ext)) {
      return { kind: 'video', label: 'VID' };
    }
    if (['mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac'].includes(ext)) {
      return { kind: 'audio', label: 'AUD' };
    }
    if (['zip', 'rar', '7z', 'svbackup'].includes(ext)) {
      return { kind: 'zip', label: 'ZIP' };
    }
    if (['doc', 'docx'].includes(ext)) return { kind: 'doc', label: 'DOC' };
    if (['ppt', 'pptx'].includes(ext)) return { kind: 'doc', label: 'PPT' };
    if (['xls', 'xlsx', 'csv'].includes(ext)) return { kind: 'doc', label: 'XLS' };
    if (['txt', 'md', 'rtf'].includes(ext)) return { kind: 'doc', label: 'TXT' };
    return { kind: 'file', label: (ext || 'FILE').slice(0, 4).toUpperCase() };
  }

  function selectedNames() {
    return [...fileListEl.querySelectorAll('input[name="files"]:checked')].map(
      (el) => el.value,
    );
  }

  function syncSelectionUi() {
    const boxes = [...fileListEl.querySelectorAll('input[name="files"]')];
    const checked = boxes.filter((b) => b.checked);
    const n = checked.length;

    zipSelectedBtn.disabled = n === 0;
    selectionLabel.textContent = n ? `${n} selected` : 'Select all';

    if (selectAll) {
      selectAll.checked = boxes.length > 0 && n === boxes.length;
      selectAll.indeterminate = n > 0 && n < boxes.length;
    }

    boxes.forEach((box) => {
      box.closest('.file-row')?.classList.toggle('is-selected', box.checked);
    });
  }

  function renderFiles() {
    fileListEl.innerHTML = '';

    if (!files.length) {
      emptyEl.hidden = false;
      batchBar.hidden = true;
      librarySub.textContent = 'Ready when you are';
      return;
    }

    emptyEl.hidden = true;
    batchBar.hidden = false;

    const totalBytes = files.reduce((sum, f) => sum + f.size, 0);
    librarySub.textContent = `${files.length} file${files.length === 1 ? '' : 's'} · ${formatBytes(totalBytes)}`;

    files.forEach((file, index) => {
      const { kind, label } = fileKind(file.name);
      const enc = encodeURIComponent(file.name);
      const li = document.createElement('li');
      li.className = 'file-row';
      li.style.animationDelay = `${Math.min(index, 12) * 35}ms`;
      li.innerHTML = `
        <label class="file-check">
          <input type="checkbox" name="files" value="" />
        </label>
        <div class="file-main">
          <span class="file-icon" data-kind="${kind}">${label}</span>
          <div class="file-text">
            <p class="file-name"></p>
            <p class="file-meta"></p>
          </div>
        </div>
        <div class="file-actions">
          <a class="row-btn" href="/download/${enc}">Download</a>
          <a class="row-btn gold" href="/zip/${enc}">ZIP</a>
        </div>
      `;
      const checkbox = li.querySelector('input[name="files"]');
      checkbox.value = file.name;
      li.querySelector('.file-name').textContent = file.name;
      li.querySelector('.file-meta').textContent =
        `${formatBytes(file.size)} · ${formatWhen(file.mtime)}`;
      checkbox.addEventListener('change', syncSelectionUi);
      fileListEl.appendChild(li);
    });

    syncSelectionUi();
  }

  async function loadFiles() {
    librarySub.textContent = 'Loading…';
    try {
      const res = await fetch('/api/files', { cache: 'no-store' });
      if (!res.ok) throw new Error('Could not load files');
      const data = await res.json();
      files = Array.isArray(data.files) ? data.files : [];
      renderFiles();
    } catch (err) {
      librarySub.textContent = 'Could not load files';
      showToast(err.message || 'Failed to load files');
    }
  }

  function postZip(names, all) {
    const form = document.createElement('form');
    form.method = 'POST';
    form.action = '/batch-zip';
    form.style.display = 'none';

    if (all) {
      const input = document.createElement('input');
      input.name = 'all';
      input.value = '1';
      form.appendChild(input);
    } else {
      names.forEach((name) => {
        const input = document.createElement('input');
        input.name = 'files';
        input.value = name;
        form.appendChild(input);
      });
    }

    document.body.appendChild(form);
    form.submit();
    form.remove();
  }

  function uploadFiles(fileList) {
    const list = [...fileList];
    if (!list.length) return;

    const formData = new FormData();
    list.forEach((f) => formData.append('files', f));

    dropzone.classList.add('is-uploading');
    progressEl.hidden = false;
    progressFill.style.width = '0%';
    progressLabel.textContent = `Uploading ${list.length} file${list.length === 1 ? '' : 's'}…`;

    const xhr = new XMLHttpRequest();
    xhr.open('POST', '/upload');

    xhr.upload.addEventListener('progress', (e) => {
      if (!e.lengthComputable) return;
      const pct = Math.round((e.loaded / e.total) * 100);
      progressFill.style.width = `${pct}%`;
      progressLabel.textContent = `Uploading… ${pct}%`;
    });

    xhr.addEventListener('load', async () => {
      dropzone.classList.remove('is-uploading');
      progressEl.hidden = true;
      fileInput.value = '';
      if (xhr.status >= 200 && xhr.status < 300) {
        showToast(
          list.length === 1
            ? 'File shared'
            : `${list.length} files shared`,
        );
        await loadFiles();
      } else {
        showToast('Upload failed');
      }
    });

    xhr.addEventListener('error', () => {
      dropzone.classList.remove('is-uploading');
      progressEl.hidden = true;
      showToast('Upload failed — check the connection');
    });

    xhr.send(formData);
  }

  // Events
  browseBtn.addEventListener('click', (e) => {
    e.preventDefault();
    e.stopPropagation();
    fileInput.click();
  });

  dropzone.addEventListener('click', (e) => {
    if (e.target === browseBtn || browseBtn.contains(e.target)) return;
    if (e.target.closest('button, a, input')) return;
    fileInput.click();
  });

  dropzone.addEventListener('dragenter', (e) => {
    e.preventDefault();
    dropzone.classList.add('is-dragging');
  });

  dropzone.addEventListener('dragover', (e) => {
    e.preventDefault();
    dropzone.classList.add('is-dragging');
  });

  dropzone.addEventListener('dragleave', (e) => {
    if (!dropzone.contains(e.relatedTarget)) {
      dropzone.classList.remove('is-dragging');
    }
  });

  dropzone.addEventListener('drop', (e) => {
    e.preventDefault();
    dropzone.classList.remove('is-dragging');
    if (e.dataTransfer?.files?.length) {
      uploadFiles(e.dataTransfer.files);
    }
  });

  fileInput.addEventListener('change', () => {
    if (fileInput.files?.length) uploadFiles(fileInput.files);
  });

  dropzone.addEventListener('submit', (e) => {
    e.preventDefault();
    if (fileInput.files?.length) uploadFiles(fileInput.files);
  });

  selectAll.addEventListener('change', () => {
    fileListEl.querySelectorAll('input[name="files"]').forEach((box) => {
      box.checked = selectAll.checked;
    });
    syncSelectionUi();
  });

  zipSelectedBtn.addEventListener('click', () => {
    const names = selectedNames();
    if (!names.length) {
      showToast('Select at least one file');
      return;
    }
    postZip(names, false);
  });

  zipAllBtn.addEventListener('click', () => {
    if (!files.length) return;
    postZip([], true);
  });

  refreshBtn.addEventListener('click', () => {
    loadFiles();
    loadTexts();
  });

  function previewText(value) {
    const compact = value.replace(/\s+/g, ' ').trim();
    return compact.length > 160 ? `${compact.slice(0, 157)}…` : compact;
  }

  function renderTexts() {
    textListEl.innerHTML = '';

    if (!texts.length) {
      textSub.textContent = 'No shared text yet';
      return;
    }

    textSub.textContent = `${texts.length} snippet${texts.length === 1 ? '' : 's'}`;

    texts.forEach((item, index) => {
      const li = document.createElement('li');
      li.className = 'text-row';
      li.style.animationDelay = `${Math.min(index, 12) * 30}ms`;
      li.innerHTML = `
        <div class="text-row-top">
          <div>
            <p class="text-row-title"></p>
            <p class="text-row-meta"></p>
          </div>
          <div class="text-row-actions">
            <button type="button" class="row-btn" data-action="copy">Copy</button>
            <button type="button" class="row-btn danger" data-action="delete">Delete</button>
          </div>
        </div>
        <p class="text-row-preview"></p>
      `;
      li.querySelector('.text-row-title').textContent = item.title || 'Untitled';
      li.querySelector('.text-row-meta').textContent =
        `${item.text.length.toLocaleString()} chars · ${formatWhen(item.createdAt)}`;
      li.querySelector('.text-row-preview').textContent = previewText(item.text);

      li.querySelector('[data-action="copy"]').addEventListener('click', async () => {
        try {
          await navigator.clipboard.writeText(item.text);
          showToast('Copied to clipboard');
        } catch {
          showToast('Could not copy — select the text manually');
        }
      });

      li.querySelector('[data-action="delete"]').addEventListener('click', async () => {
        try {
          const res = await fetch(`/api/texts/${encodeURIComponent(item.id)}`, {
            method: 'DELETE',
          });
          if (!res.ok) throw new Error('Delete failed');
          showToast('Text removed');
          await loadTexts();
        } catch (err) {
          showToast(err.message || 'Delete failed');
        }
      });

      textListEl.appendChild(li);
    });
  }

  async function loadTexts() {
    try {
      const res = await fetch('/api/texts', { cache: 'no-store' });
      if (!res.ok) throw new Error('Could not load text');
      const data = await res.json();
      texts = Array.isArray(data.texts) ? data.texts : [];
      renderTexts();
    } catch (err) {
      textSub.textContent = 'Could not load text';
      showToast(err.message || 'Failed to load text');
    }
  }

  textForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    const text = textBody.value;
    if (!text.trim()) {
      showToast('Enter some text first');
      return;
    }

    textShareBtn.disabled = true;
    try {
      const res = await fetch('/api/texts', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
        body: JSON.stringify({
          title: textTitle.value.trim(),
          text,
        }),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) throw new Error(data.error || 'Share failed');
      textBody.value = '';
      textTitle.value = '';
      showToast('Text shared');
      await loadTexts();
    } catch (err) {
      showToast(err.message || 'Share failed');
    } finally {
      textShareBtn.disabled = false;
    }
  });

  loadFiles();
  loadTexts();
})();
