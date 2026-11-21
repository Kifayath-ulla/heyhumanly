import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
const read = (p) => readFileSync(new URL('../' + p, import.meta.url), 'utf8');

test('app, extension and site release versions match', () => {
  const ext = JSON.parse(read('extension/manifest.json')).version;
  const site = JSON.parse(read('site-src/release.json')).version;
  const app = read('Resources/Info.plist').match(/CFBundleShortVersionString<\/key>\s*<string>([^<]+)/)[1];
  assert.equal(ext, site, 'extension/manifest.json vs site-src/release.json');
  assert.equal(app, site, 'Resources/Info.plist vs site-src/release.json');
});

test('extension can only reach Ollama on this computer', () => {
  const m = JSON.parse(read('extension/manifest.json'));
  for (const h of m.host_permissions || []) assert.match(h, /^http:\/\/(localhost|127\.0\.0\.1):11434\/\*$/, h);
  assert.equal(m.content_scripts, undefined, 'no always-on content scripts');
});

test('extension code makes no network calls except to the Ollama endpoint', () => {
  const dir = new URL('../extension/', import.meta.url);
  for (const f of readdirSync(dir).filter((f) => f.endsWith('.js'))) {
    const src = read('extension/' + f);
    assert.doesNotMatch(src, /XMLHttpRequest|sendBeacon|new WebSocket|EventSource|importScripts\(\s*['"]https?:/, f);
    for (const m of src.matchAll(/\bfetch\(\s*([^,)]+)/g)) {
      assert.doesNotMatch(m[1], /^['"`]/, f + ': fetch to a literal URL: ' + m[1]);
    }
  }
});
