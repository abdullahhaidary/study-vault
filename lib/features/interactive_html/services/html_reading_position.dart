import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Runs in WebView, WebKit, and the browser. Paths omit the per-open token;
/// the namespace includes the original file's library identity. Nothing is
/// written into the imported HTML or sent to the cloud.
String htmlReadingPositionScript(String identity) =>
    '''
(() => {
const namespace = ${jsonEncode(sha256.convert(utf8.encode(identity)).toString())};
$_script
})();
''';

const _script = r'''
if (window.__studyVaultReadingPosition) return;
window.__studyVaultReadingPosition = true;
const key = 'study-vault-reading-v1:' + namespace + ':' +
  location.pathname.split('/').slice(2).join('/') + location.search;
let saved = null;
try { saved = JSON.parse(localStorage.getItem(key)); } catch (_) {}
const finite = v => typeof v === 'number' && Number.isFinite(v) && v >= 0;
if (!saved || !Array.isArray(saved.window) || saved.window.length !== 2 || !saved.window.every(finite)) saved = null;
const elements = new Map();
for (const item of (saved && Array.isArray(saved.elements) ? saved.elements.slice(-64) : [])) {
  if (item && Array.isArray(item.position) && item.position.length === 2 && item.position.every(finite)) {
    elements.set(JSON.stringify(item.address), item);
  }
}
let restoring = !!saved;
let userActed = false;
let frame = 0;
let resizeObserver;
let mutationObserver;
let deadline;

function address(node) {
  if (node.id) return {id: node.id};
  const steps = [];
  while (node && node !== document.documentElement) {
    const parent = node.parentElement;
    if (!parent) return null;
    steps.unshift(Array.prototype.indexOf.call(parent.children, node));
    node = parent;
  }
  return {steps};
}
function resolve(value) {
  if (!value) return null;
  if (typeof value.id === 'string') return document.getElementById(value.id);
  if (!Array.isArray(value.steps)) return null;
  let node = document.documentElement;
  for (const index of value.steps) {
    if (!Number.isInteger(index) || index < 0) return null;
    node = node && node.children[index];
  }
  return node;
}
function remember() {
  if (restoring && !userActed) return;
  const value = {window: [window.scrollX, window.scrollY], elements: []};
  for (const item of elements.values()) {
    const node = resolve(item.address);
    if (node) item.position = [node.scrollLeft, node.scrollTop];
    value.elements.push(item);
  }
  value.elements = value.elements.slice(-64);
  try { localStorage.setItem(key, JSON.stringify(value)); } catch (_) {}
}
function apply() {
  frame = 0;
  if (!restoring || userActed || !saved) return;
  window.scrollTo(saved.window[0], saved.window[1]);
  for (const item of elements.values()) {
    const node = resolve(item.address);
    if (node) {
      node.scrollLeft = item.position[0];
      node.scrollTop = item.position[1];
    }
  }
}
function queueRestore() {
  if (restoring && !frame) frame = requestAnimationFrame(apply);
}
function stopRestoring() {
  restoring = false;
  if (frame) cancelAnimationFrame(frame);
  frame = 0;
  if (resizeObserver) resizeObserver.disconnect();
  if (mutationObserver) mutationObserver.disconnect();
  clearTimeout(deadline);
}
function intent(event) {
  if (event.type === 'keydown' && !['ArrowDown', 'ArrowUp', 'ArrowLeft', 'ArrowRight',
      'PageDown', 'PageUp', 'Home', 'End', ' '].includes(event.key)) return;
  userActed = true;
  stopRestoring();
}
for (const type of ['pointerdown', 'touchstart', 'wheel', 'keydown']) {
  addEventListener(type, intent, {passive: true, capture: true});
}
addEventListener('scroll', event => {
  if (restoring && !userActed) return;
  const node = event.target;
  if (node instanceof Element && node !== document.scrollingElement &&
      node !== document.documentElement && (node.scrollHeight > node.clientHeight ||
        node.scrollWidth > node.clientWidth)) {
    const value = address(node);
    if (value) elements.set(JSON.stringify(value), {address: value,
      position: [node.scrollLeft, node.scrollTop]});
    while (elements.size > 64) elements.delete(elements.keys().next().value);
  }
  remember();
}, {passive: true, capture: true});
addEventListener('pagehide', remember);
addEventListener('visibilitychange', () => { if (document.hidden) remember(); });
addEventListener('click', remember, {capture: true});

function start() {
  if (!saved) return;
  if ('scrollRestoration' in history) history.scrollRestoration = 'manual';
  if ('ResizeObserver' in window) {
    resizeObserver = new ResizeObserver(queueRestore);
    resizeObserver.observe(document.documentElement);
    if (document.body) resizeObserver.observe(document.body);
  }
  mutationObserver = new MutationObserver(queueRestore);
  mutationObserver.observe(document.documentElement, {childList: true, subtree: true});
  addEventListener('load', queueRestore, {capture: true});
  if (document.fonts && document.fonts.ready) document.fonts.ready.then(queueRestore);
  queueRestore();
  deadline = setTimeout(stopRestoring, 8000);
}
if (document.readyState === 'loading') addEventListener('DOMContentLoaded', start, {once: true});
else start();
''';
