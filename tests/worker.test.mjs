import { test } from 'node:test';
import assert from 'node:assert/strict';
const worker = (await import('../worker/index.js')).default;
const env = { ASSETS: { fetch: async () => new Response('ok', { status: 200, headers: { 'Content-Type': 'text/html' } }) } };
const get = (url) => worker.fetch(new Request(url), env);

test('http redirects to https', async () => {
  const r = await get('http://heyhumanly.com/extension/?a=1');
  assert.equal(r.status, 301);
  assert.equal(r.headers.get('Location'), 'https://heyhumanly.com/extension/?a=1');
});

test('www redirects to the apex', async () => {
  for (const u of ['https://www.heyhumanly.com/privacy/', 'http://www.heyhumanly.com/privacy/']) {
    const r = await get(u);
    assert.equal(r.status, 301);
    assert.equal(r.headers.get('Location'), 'https://heyhumanly.com/privacy/');
  }
});

test('workers.dev previews are noindex; production is not', async () => {
  assert.equal((await get('https://heyhumanly.example.workers.dev/')).headers.get('X-Robots-Tag'), 'noindex, nofollow');
  const prod = await get('https://heyhumanly.com/');
  assert.equal(prod.status, 200);
  assert.equal(prod.headers.get('X-Robots-Tag'), null);
});

test('/api/ goes to the coaching API, which is off unless enabled', async () => {
  const r = await get('https://heyhumanly.com/api/v1/allowance?install=11111111-2222-4333-8444-555555555555');
  assert.equal(r.status, 503);
  assert.equal((await r.json()).error, 'unavailable');
});

test('HTML pages, including the 404 page, are marked no-transform so no analytics beacon is injected', async () => {
  const html = { ASSETS: { fetch: async () => new Response('missing', { status: 404, headers: { 'Content-Type': 'text/html; charset=utf-8' } }) } };
  const r = await worker.fetch(new Request('https://heyhumanly.com/nope'), html);
  assert.equal(r.status, 404);
  assert.match(r.headers.get('Cache-Control'), /no-transform/);
  const font = { ASSETS: { fetch: async () => new Response('x', { headers: { 'Content-Type': 'font/woff2', 'Cache-Control': 'public, max-age=31536000, immutable' } }) } };
  assert.equal((await worker.fetch(new Request('https://heyhumanly.com/fonts/a.woff2'), font)).headers.get('Cache-Control'), 'public, max-age=31536000, immutable');
});
