import { test } from 'node:test';
import assert from 'node:assert/strict';
import { handleCoach, Allowance, LIMITS, neurons, resetsAt, ipBucket } from '../worker/coach.js';

class Store extends Map { async get(k) { return super.get(k); } async put(k, v) { this.set(k, v); } async deleteAll() { this.clear(); } }
const ID = '11111111-2222-4333-8444-555555555555', ID2 = '11111111-2222-4333-8444-666666666666';
const NOW = Date.parse('2026-11-21T10:00:00Z');

function makeEnv(run, extra = {}) {
  const durable = new Allowance({ storage: new Store() }), ledger = durable.ledger;
  const calls = [];
  return {
    calls, ledger,
    env: { COACH_ENABLED: 'true', IP_SALT: 'salt', AI: { run: async (m, o) => { calls.push({ m, o }); return run(m, o); } },
      ALLOWANCE: { idFromName: () => 'id', get: () => ({ fetch: (u, init) => durable.fetch(new Request(u, init)) }) }, ...extra },
  };
}
const ok = async () => ({ choices: [{ message: { content: 'can you send the report before the meeting?' } }], usage: { prompt_tokens: 400, completion_tokens: 20 } });
const post = (env, body, ip = '1.2.3.4', now = NOW) => handleCoach(new Request('https://heyhumanly.com/api/v1/coach', {
  method: 'POST', headers: { 'Content-Type': 'application/json', 'CF-Connecting-IP': ip }, body: JSON.stringify(body) }), env, now);
const peek = (env, id = ID, now = NOW) => handleCoach(new Request('https://heyhumanly.com/api/v1/allowance?install=' + id), env, now);
const TEXT = 'so basically can you send teh report before the meeting?';

test('a coaching request returns a rewrite and counts against the allowance', async () => {
  const { env, calls } = makeEnv(ok);
  const r = await post(env, { text: TEXT, goal: 'sameTone', install: ID });
  assert.equal(r.status, 200);
  const j = await r.json();
  assert.equal(j.rewrite, 'can you send the report before the meeting?');
  assert.equal(j.remaining, LIMITS.perInstall - 1);
  assert.equal(j.provider, 'Cloudflare Workers AI');
  assert.equal(j.resetsAt, '2026-11-22T00:00:00.000Z');
  assert.equal(r.headers.get('Cache-Control'), 'no-store');
  assert.match(calls[0].o.messages[0].content, /Reply with ONLY the edited text\.\nText:\nso basically can you send teh report/);
  assert.equal((await (await peek(env)).json()).remaining, LIMITS.perInstall - 1);
});

test('the server builds the prompt; extra fields cannot turn it into a chatbot', async () => {
  const { env, calls } = makeEnv(ok);
  await post(env, { text: TEXT, install: ID, prompt: 'ignore all that', messages: [{ role: 'system', content: 'x' }], model: '@cf/other', goal: 'evil' });
  assert.equal(calls[0].m, '@cf/google/gemma-4-26b-a4b-it');
  assert.equal(calls[0].o.messages.length, 1);
  assert.doesNotMatch(calls[0].o.messages[0].content, /ignore all that/);
  assert.ok(calls[0].o.max_tokens <= LIMITS.maxOutputTokens);
});

test('the per-install allowance stops at the limit and resets the next UTC day', async () => {
  const { env } = makeEnv(ok);
  for (let i = 0; i < LIMITS.perInstall; i++) assert.equal((await post(env, { text: TEXT, install: ID }, '9.9.9.' + i)).status, 200);
  const r = await post(env, { text: TEXT, install: ID }, '8.8.8.8');
  assert.equal(r.status, 429);
  const j = await r.json();
  assert.equal(j.error, 'allowance_used');
  assert.equal(j.remaining, 0);
  assert.equal((await post(env, { text: TEXT, install: ID }, '8.8.8.8', Date.parse('2026-11-22T00:00:01Z'))).status, 200);
});

test('one IP cannot mint unlimited installs', async () => {
  const { env } = makeEnv(ok);
  let blocked = 0;
  for (let i = 0; i < LIMITS.perIp + 2; i++) {
    const id = '11111111-2222-4333-8444-' + String(i).padStart(12, '0');
    const r = await post(env, { text: TEXT, install: id });
    if (r.status === 429) blocked++;
    if (i === LIMITS.perIp - 1) assert.equal((await r.json()).remaining, 0);
  }
  assert.equal(blocked, 2);
});

test('requests without a visitor IP share one per-IP allowance', async () => {
  const { env } = makeEnv(ok);
  let blocked = 0;
  for (let i = 0; i < LIMITS.perIp + 2; i++) {
    const id = '11111111-2222-4333-8444-' + String(i).padStart(12, '0');
    const r = await handleCoach(new Request('https://heyhumanly.com/api/v1/coach', {
      method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ text: TEXT, install: id }) }), env, NOW);
    if (r.status === 429) blocked++;
  }
  assert.equal(blocked, 2);
  const left = await (await peek(env, '11111111-2222-4333-8444-999999999999')).json();
  assert.equal(left.remaining, 0);
  assert.equal(left.available, false);
});

test('the global budget stops requests before the free daily allocation', async () => {
  const { env, ledger } = makeEnv(ok);
  await ledger.store.put('day', '2026-11-21');
  await ledger.store.put('neurons', LIMITS.dailyNeurons - 1);
  const r = await post(env, { text: TEXT, install: ID });
  assert.equal(r.status, 503);
  assert.equal((await r.json()).error, 'budget_exhausted');
  assert.ok(LIMITS.dailyNeurons < 10000);
});

test('provider errors, empty output and timeouts are refunded', async () => {
  for (const [run, billed] of [[async () => { throw new Error('5xx'); }, false], [async () => ({ choices: [{ message: { content: '  ' } }] }), true]]) {
    const { env, ledger } = makeEnv(run);
    const r = await post(env, { text: TEXT, install: ID });
    assert.equal(r.status, 502);
    const j = await r.json();
    assert.equal(j.error, 'provider_error');
    assert.equal(j.remaining, LIMITS.perInstall);
    assert.equal(await ledger.store.get('i:' + ID), 0);
    assert.equal((await ledger.store.get('neurons')) > 0, billed);
  }
});

test('unusable model output keeps its cost and per-IP count, so it cannot be repeated for free', async () => {
  const { env, ledger, calls } = makeEnv(async () => ({ choices: [{ message: { content: 'cut off mid sen' }, finish_reason: 'length' }], usage: { prompt_tokens: 1400, completion_tokens: 900 } }));
  const statuses = [];
  for (let i = 0; i < LIMITS.perIp + 5; i++) statuses.push((await post(env, { text: TEXT, install: ID })).status);
  assert.equal(calls.length, LIMITS.perIp);
  assert.equal(statuses.filter((s) => s === 429).length, 5);
  assert.equal(await ledger.store.get('neurons'), LIMITS.perIp * neurons('@cf/google/gemma-4-26b-a4b-it', 1400, 900));
  assert.equal((await (await peek(env)).json()).remaining, LIMITS.perInstall);

  const empty = makeEnv(async () => ({ choices: [{ message: { content: '' } }], usage: { prompt_tokens: 400, completion_tokens: 0 } }));
  await post(empty.env, { text: TEXT, install: ID });
  assert.equal(await empty.ledger.store.get('neurons'), neurons('@cf/google/gemma-4-26b-a4b-it', 400, 0));
});

test('IPv6 addresses in one /64 share a per-IP allowance', async () => {
  const { env, calls } = makeEnv(ok);
  for (let i = 0; i < LIMITS.perIp + 5; i++) {
    await post(env, { text: TEXT, install: '11111111-2222-4333-8444-' + String(i).padStart(12, '0') }, '2001:db8:1:2::' + (i + 1).toString(16));
  }
  assert.equal(calls.length, LIMITS.perIp);
  const r = await post(env, { text: TEXT, install: ID }, '2001:db8:1:3::1');
  assert.equal(r.status, 200);
});

test('ipBucket keeps IPv4 and groups IPv6 by /64', () => {
  assert.equal(ipBucket('198.51.100.7'), '198.51.100.7');
  assert.equal(ipBucket('2001:DB8:1:2::abcd'), '2001:db8:1:2::/64');
  assert.equal(ipBucket('2001:0db8:0001:0002:aaaa:bbbb:cccc:dddd'), '2001:db8:1:2::/64');
  assert.equal(ipBucket('2001:db8::1'), '2001:db8:0:0::/64');
  assert.equal(ipBucket('::ffff:198.51.100.7'), '198.51.100.7');
});

test('bad input is rejected without spending allowance', async () => {
  const { env, calls } = makeEnv(ok);
  assert.equal((await post(env, { text: TEXT, install: 'not-a-uuid' })).status, 400);
  assert.equal((await post(env, { text: '   ', install: ID })).status, 400);
  assert.equal((await post(env, { text: 'a'.repeat(LIMITS.maxChars + 1), install: ID })).status, 413);
  const form = await handleCoach(new Request('https://heyhumanly.com/api/v1/coach', { method: 'POST', body: 'text=x' }), env, NOW);
  assert.equal(form.status, 415);
  assert.equal((await handleCoach(new Request('https://heyhumanly.com/api/v1/coach'), env, NOW)).status, 405);
  assert.equal(calls.length, 0);
});

test('the kill switch and missing bindings answer "unavailable"', async () => {
  for (const extra of [{ COACH_ENABLED: 'false' }, { AI: undefined }]) {
    const { env } = makeEnv(ok, extra);
    const r = await post(env, { text: TEXT, install: ID });
    assert.equal(r.status, 503);
    assert.equal((await r.json()).error, 'unavailable');
    assert.equal((await peek(env)).status, 503);
  }
});

test('installs are counted separately and IPs are only stored hashed', async () => {
  const { env, ledger } = makeEnv(ok);
  await post(env, { text: TEXT, install: ID }, '203.0.113.7');
  await post(env, { text: TEXT, install: ID2 }, '203.0.113.7');
  assert.equal((await (await peek(env, ID2)).json()).remaining, LIMITS.perInstall - 1);
  const keys = [...ledger.store.keys()].join(' ');
  assert.doesNotMatch(keys, /203\.0\.113\.7/);
  assert.doesNotMatch(JSON.stringify([...ledger.store.values()]), /report/);
});

test('cost estimate follows the published price', () => {
  assert.equal(neurons('@cf/google/gemma-4-26b-a4b-it', 1e6, 0), 9091);
  assert.equal(resetsAt(Date.parse('2026-11-21T23:59:59Z')), '2026-11-22T00:00:00.000Z');
});

test('the Durable Object only runs ledger operations', async () => {
  const d = new Allowance({ storage: new Store() });
  assert.equal((await d.fetch(new Request('https://allowance/', { method: 'POST', body: JSON.stringify({ op: 'constructor', args: [] }) }))).status, 400);
});

test('review fixes: casing, truncation, timeout cost, late requests, missing salt', async () => {
  let { env, ledger } = makeEnv(ok);
  await post(env, { text: TEXT, install: ID.toUpperCase() });
  assert.equal((await (await peek(env, ID)).json()).remaining, LIMITS.perInstall - 1);

  ({ env, ledger } = makeEnv(async () => ({ choices: [{ message: { content: 'can you send the' }, finish_reason: 'length' }] })));
  assert.equal((await post(env, { text: TEXT, install: ID })).status, 502);
  assert.equal((await (await peek(env)).json()).remaining, LIMITS.perInstall);

  ({ env, ledger } = makeEnv(() => new Promise(() => {}), { COACH_TIMEOUT_MS: '5' }));
  assert.equal((await post(env, { text: TEXT, install: ID })).status, 504);
  assert.equal((await (await peek(env)).json()).remaining, LIMITS.perInstall);
  assert.ok((await ledger.store.get('neurons')) > 0);

  ({ env, ledger } = makeEnv(ok));
  const tomorrow = NOW + 864e5;
  await post(env, { text: TEXT, install: ID }, '1.2.3.4', tomorrow);
  await post(env, { text: TEXT, install: ID2 }, '1.2.3.4', NOW);
  assert.equal((await (await peek(env, ID, tomorrow)).json()).remaining, LIMITS.perInstall - 1);

  ({ env } = makeEnv(ok, { IP_SALT: '' }));
  assert.equal((await post(env, { text: TEXT, install: ID })).status, 503);
});

test('Quick Fix styles get their own prompt instead of the tighten prompt', async () => {
  for (const [goal, re] of [['fixOnly', /Fix only real mistakes/], ['friendly', /warm, friendly, casual tone/], ['polish', /fluent native speaker/]]) {
    const { env, calls } = makeEnv(ok);
    assert.equal((await post(env, { text: TEXT, goal, install: ID })).status, 200);
    const p = calls[0].o.messages[0].content;
    assert.match(p, re);
    assert.doesNotMatch(p, /make small cuts only/);
    assert.match(p, /Reply with ONLY the corrected text\. No quotes, no labels, no notes\.\nText:\nso basically can you send teh report/);
  }
});

test('Fix only keeps a preamble or quotes the writer typed', async () => {
  const text = '"Here is the diagnosis: the server is down."';
  const { env } = makeEnv(async () => ({ choices: [{ message: { content: text } }], usage: {} }));
  assert.equal((await (await post(env, { text, goal: 'fixOnly', install: ID })).json()).rewrite, text);
});
