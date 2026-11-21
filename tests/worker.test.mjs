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
