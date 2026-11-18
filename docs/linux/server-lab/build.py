"""Build the offline Lecture 3 lab using the established Lecture 2 visual style."""
import html
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
source = (ROOT.parent / 'lesson 3.md').read_text()
previous = (ROOT.parent / 'admin-lab/index.html').read_text()
style = previous.split('<style>', 1)[1].split('</style>', 1)[0]
style += '''
textarea{width:100%;min-height:260px;resize:vertical;background:#080d14;color:var(--ink);border:1px solid var(--line);border-radius:8px;padding:14px;font:14px/1.6 ui-monospace,monospace}
.notice{border-left:3px solid var(--accent);padding:8px 16px}.metric{font-size:32px;color:var(--accent)}.reference pre{margin:0}.reference summary{font-weight:600}input[type=number]{width:90px;background:var(--bg);color:var(--ink);padding:8px;border:1px solid var(--line)}.diagram{display:flex;gap:10px;flex-wrap:wrap;align-items:center}.node{padding:14px;border:1px solid var(--line);border-radius:8px}.node.bad{border-color:#f5ad9d;color:#f5ad9d}footer{max-width:1400px;margin:auto;padding:24px;color:var(--muted)}#editor{border:1px solid var(--accent)}.row a{margin-left:auto}#ticket-picker{display:none}@media(max-width:850px){#lab-list{display:none}#ticket-picker{display:block;width:100%;max-width:100%;font-size:14px}aside h3{margin:0 0 10px}aside .status{margin:10px 0}}@media print{nav,aside,.terminal,#tools,#lab,#learn,footer{display:none!important}#reference{display:block!important}.reference{display:block!important}.reference>pre{display:block!important}body{background:white;color:black}.reference pre{color:black}}
'''
# Parse headings outside fences; a shebang inside code must never become a heading.
sections = []
heading = 'Course overview'
lines = []
fence = False
for line in source.splitlines(keepends=True):
    if line.lstrip().startswith('```'):
        fence = not fence
    if not fence and line.startswith(('# ', '## ')):
        if lines:
            sections.append((heading, ''.join(lines)))
        heading, lines = line.lstrip('#').strip(), []
    else:
        lines.append(line)
if lines:
    sections.append((heading, ''.join(lines)))
reference = ''.join('<details class="reference"><summary>' + html.escape(h) + '</summary><pre>' + html.escape(b) + '</pre></details>' for h, b in sections)
shell = '''<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Linux Server Engineering • Lecture 3 Operations Lab</title><style>STYLE</style></head><body>
<header><div class="eyebrow">LECTURE 03 / FINAL FIELD PRACTICE</div><h1>Linux Server Engineering Lab</h1><p>Harden a server. Diagnose an outage. Ship a release. Prove you can recover.</p><span class="tag">Offline • browser simulation • no host access</span><nav aria-label="Sections"><button data-view="learn" class="active">Field guide</button><button data-view="lab">Terminal labs</button><button data-view="tools">Interactive tools</button><button data-view="reference">Full lesson</button></nav></header>
<main>
<section id="learn"><div class="row"><h2>Your production operations playbook</h2><span class="tag">15 areas · 14 practice tickets</span></div><p>Continue from Lecture 2 with the same practice-first format. Read an area, investigate its ticket, then check the resulting server state. The complete original lecture, all 35 experiments, capstone code, exams, and assignment are in Full lesson.</p><div class="card"><div class="row"><span class="metric" id="overall">0 / 14</span><span>tickets completed</span><button id="continue">Continue practice →</button></div><progress id="overall-progress" max="14" value="0" aria-label="Completed tickets"></progress></div><div id="guides" class="grid"></div></section>
<section id="lab" hidden><div class="layout"><aside><h3>Practice tickets</h3><select id="ticket-picker" aria-label="Choose practice ticket"></select><div id="lab-list"></div><p class="status" id="saved"></p><button id="export">Export transcript</button></aside><div><div class="card"><div class="row"><span class="tag" id="lab-number"></span><span id="completion" class="status"></span></div><h2 id="lab-title"></h2><p id="scenario"></p><ol id="tasks" class="tasks"></ol><progress id="progress" max="100" value="0" aria-label="Current ticket completion"></progress><div class="row"><button id="check">Check work</button><button id="reset">Reset this lab</button></div><details><summary>Hints and supported solution</summary><p id="hint"></p><pre id="solution"></pre></details></div>
<div id="editor" class="card" hidden><h3>Training file editor</h3><p id="editor-path"></p><p class="status">Change the simulated file, save, then validate and activate it in the terminal. Only this ticket's virtual server changes.</p><textarea id="editor-text" aria-label="Simulated file contents" spellcheck="false"></textarea><div class="row"><button id="save-file">Save file</button><button id="close-editor">Close</button><span id="editor-status" role="status"></span></div></div>
<div class="terminal"><div class="bar">● ● ● &nbsp; student@server-lab — simulated operations shell</div><div id="output" class="output" role="log" aria-label="Terminal output" aria-live="polite"></div><form id="shell"><span class="prompt">student@ops:~ $</span><input id="command" aria-label="Terminal command" autocomplete="off" autocapitalize="off" spellcheck="false" placeholder="Type help for supported commands"><button>Run ↵</button></form></div><p class="status">↑ / ↓: command history · Ctrl+L: clear display · edit PATH: open the training editor. This limited simulator models listed commands, not a complete Bash interpreter. No real service, firewall, file, or network is changed.</p></div></div></section>
<section id="tools" hidden><h2>Explore the mechanics</h2><div class="grid">
<div class="card"><h3>Follow an HTTP request</h3><label>Fault <select id="fault"><option value="healthy">Healthy</option><option value="firewall">Firewall blocks HTTPS</option><option value="tls">Expired certificate</option><option value="proxy">Wrong upstream port</option><option value="app">Backend stopped</option><option value="data">Data unreadable</option></select></label><div id="request-path" class="diagram"></div><p id="request-explanation"></p></div>
<div class="card"><h3>Bash argument boundaries</h3><p>Compare the arguments passed from an array containing two elements. Quoting preserves each element as one argument.</p><label>Expansion <select id="quoting"><option value="quoted">"${releases[@]}"</option><option value="unquoted">${releases[@]}</option><option value="star">"${releases[*]}"</option></select></label><pre id="quote-result"></pre><p class="status">Example values: release candidate, stable. Unquoted expansion can also perform pathname expansion.</p></div>
<div class="card"><h3>Namespaces versus cgroups</h3><label>Control <select id="isolation"><option value="network">Network namespace</option><option value="pid">PID namespace</option><option value="mount">Mount namespace</option><option value="cgroup">Memory cgroup</option></select></label><pre id="isolation-result"></pre><p>A container shares the host kernel. Isolation and resource limits solve different problems.</p></div>
<div class="card"><h3>Recovery objectives</h3><label>Backup interval (hours) <input id="interval" type="number" min="1" max="168" value="6"></label><label>Restore time (minutes) <input id="restore-time" type="number" min="1" max="1440" value="20"></label><label>Detection + preparation (minutes) <input id="detect-time" type="number" min="0" max="1440" value="10"></label><pre id="recovery-result"></pre><p>Compare measured recovery with the business RTO. Assumes every backup succeeds; job failure can increase the data-loss window. Keep independent off-host copies.</p></div>
</div></section>
<section id="reference" hidden><div class="row"><h2>Complete original Lecture 3</h2><button id="download-source">Download lecture Markdown</button></div><p>Original source preserved, including the full Python application, Bash scripts, hardened units, Nginx examples, 35 experiments, examination, and assignment. Code blocks remain verbatim. Examples here are for your practice VM.</p><input type="search" id="search" placeholder="Search: pipefail, experiment, Nginx, capstone…" aria-label="Search original lecture"><p id="search-count" class="status" role="status"></p><div id="reference-content">REFERENCE</div></section>
</main><footer>Lecture 3 of 3 · Based on your existing Linux course source. Supplementary guides: <a href="https://www.gnu.org/software/bash/manual/">Bash manual</a> · <a href="https://www.freedesktop.org/software/systemd/man/latest/systemd.exec.html">systemd sandboxing</a> · <a href="https://nginx.org/en/docs/http/ngx_http_proxy_module.html">Nginx proxy documentation</a>. External documentation links need internet; all learning activities work offline.</footer>
<script id="lecture-source" type="application/json">@@LECTURE_JSON@@</script><script>@@APP@@</script></body></html>'''
out = shell.replace('STYLE', style).replace('REFERENCE', reference).replace('@@LECTURE_JSON@@', json.dumps(source).replace('<', '\\u003c')).replace('@@APP@@', (ROOT / 'app.js').read_text().replace('</script', '<\\/script'))
(ROOT / 'index.html').write_text(out)
print(f'Built {ROOT / "index.html"}: {len(out):,} characters; {len(sections)} source sections')
