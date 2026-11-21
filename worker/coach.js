// Online coaching allowance: POST /api/v1/coach rewrites text with Cloudflare Workers AI.
// The server builds the prompt (this is not a general chatbot), never logs or stores the text,
// and stops below the free daily Workers AI allocation so it cannot run up a bill.
import HH from '../extension/core.js';

export const LIMITS = { perInstall: 10, perIp: 30, warnAt: 3, dailyNeurons: 8000, maxChars: 4000, maxOutputTokens: 900, timeoutMs: 30000 };
export const PROVIDER = 'Cloudflare Workers AI';
const DEFAULT_MODEL = '@cf/google/gemma-4-26b-a4b-it';
// Published unit prices (USD per million tokens) converted to neurons at $0.011 per 1,000 neurons.
const PRICES = {
  '@cf/google/gemma-4-26b-a4b-it': [0.10, 0.30],
  '@cf/ibm-granite/granite-4.0-h-micro': [0.017, 0.112],
  '@cf/zai-org/glm-4.7-flash': [0.0605, 0.40],
};
const GOALS = new Set(['sameTone', 'shorter', 'formal']);
const INSTALL = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function neurons(model, inTokens, outTokens) {
  const [pin, pout] = PRICES[model] || PRICES[DEFAULT_MODEL];
  return Math.ceil(((inTokens * pin + outTokens * pout) / 1e6 / 0.011) * 1000);
}
export const today = (now = Date.now()) => new Date(now).toISOString().slice(0, 10);
export const resetsAt = (now = Date.now()) => { const d = new Date(now); d.setUTCHours(24, 0, 0, 0); return d.toISOString(); };

// Pure allowance ledger over a key/value store (Durable Object storage in production, a Map in tests).
// Single-threaded per Durable Object, so check-and-increment is atomic.
export class Ledger {
  constructor(store) { this.store = store; }
  async roll(day) {
    if ((await this.store.get('day')) !== day) { await this.store.deleteAll(); await this.store.put('day', day); }
  }
  async peek(install, day) {
    await this.roll(day);
    const used = (await this.store.get('i:' + install)) || 0, spent = (await this.store.get('neurons')) || 0;
    return { used, remaining: Math.max(0, LIMITS.perInstall - used), budgetLeft: spent < LIMITS.dailyNeurons };
  }
  async reserve(install, ipKey, est, day) {
    await this.roll(day);
    const used = (await this.store.get('i:' + install)) || 0;
    if (used >= LIMITS.perInstall) return { ok: false, reason: 'allowance_used', remaining: 0 };
    const ipUsed = ipKey ? (await this.store.get('p:' + ipKey)) || 0 : 0;
    if (ipKey && ipUsed >= LIMITS.perIp) return { ok: false, reason: 'allowance_used', remaining: LIMITS.perInstall - used };
    const spent = (await this.store.get('neurons')) || 0;
    if (spent + est > LIMITS.dailyNeurons) return { ok: false, reason: 'budget_exhausted', remaining: LIMITS.perInstall - used };
    await this.store.put('i:' + install, used + 1);
    if (ipKey) await this.store.put('p:' + ipKey, ipUsed + 1);
    await this.store.put('neurons', spent + est);
    return { ok: true, remaining: LIMITS.perInstall - used - 1 };
  }
  // Failed, timed-out and provider-error requests are refunded; successful ones are charged their real cost.
  async settle(install, ipKey, est, actual, success, day) {
    if ((await this.store.get('day')) !== day) return;
    const spent = (await this.store.get('neurons')) || 0;
    if (success) { await this.store.put('neurons', Math.max(0, spent - est + actual)); return; }
    await this.store.put('neurons', Math.max(0, spent - est));
    const used = (await this.store.get('i:' + install)) || 0;
    await this.store.put('i:' + install, Math.max(0, used - 1));
    if (ipKey) { const p = (await this.store.get('p:' + ipKey)) || 0; await this.store.put('p:' + ipKey, Math.max(0, p - 1)); }
  }
}

// Durable Object holding the ledger. Called with stub.fetch (no RPC) so the module also loads in Node tests.
const OPS = new Set(['peek', 'reserve', 'settle']);
export class Allowance {
  constructor(ctx) { this.ledger = new Ledger(ctx.storage); }
  async fetch(request) {
    const { op, args } = await request.json();
    if (!OPS.has(op) || !Array.isArray(args)) return new Response('bad op', { status: 400 });
    return Response.json((await this.ledger[op](...args)) ?? null);
  }
}

const json = (body, status = 200) => new Response(JSON.stringify(body), {
  status, headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' },
});
function ledgerOf(env) {
  const stub = env.ALLOWANCE.get(env.ALLOWANCE.idFromName('global'));
  const call = async (op, ...args) => {
    const r = await stub.fetch('https://allowance/', { method: 'POST', body: JSON.stringify({ op, args }) });
    if (!r.ok) throw new Error('ledger ' + r.status);
    return r.json();
  };
  return { peek: (...a) => call('peek', ...a), reserve: (...a) => call('reserve', ...a), settle: (...a) => call('settle', ...a) };
}

async function ipKey(request, env, day) {
  const ip = request.headers.get('CF-Connecting-IP');
  if (!ip || !env.IP_SALT) return null;
  const buf = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(env.IP_SALT + '|' + day + '|' + ip));
  return [...new Uint8Array(buf).slice(0, 12)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

function base(env, remaining, now) {
  return { provider: PROVIDER, limit: LIMITS.perInstall, remaining, warnAt: LIMITS.warnAt, resetsAt: resetsAt(now) };
}

export async function handleCoach(request, env, now = Date.now()) {
  const url = new URL(request.url);
  const enabled = env.COACH_ENABLED === 'true' && env.AI && env.ALLOWANCE && env.IP_SALT;
  const day = today(now);
  if (request.method === 'GET' && url.pathname === '/api/v1/allowance') {
    const install = url.searchParams.get('install') || '';
    if (!INSTALL.test(install)) return json({ error: 'bad_request' }, 400);
    if (!enabled) return json({ ...base(env, 0, now), available: false, error: 'unavailable' }, 503);
    const p = await ledgerOf(env).peek(install, day);
    return json({ ...base(env, p.remaining, now), available: p.budgetLeft && p.remaining > 0 });
  }
  if (url.pathname !== '/api/v1/coach') return json({ error: 'not_found' }, 404);
  if (request.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);
  if (!(request.headers.get('Content-Type') || '').startsWith('application/json')) return json({ error: 'bad_request' }, 415);
  let body; try { body = await request.json(); } catch { return json({ error: 'bad_request' }, 400); }
  const text = typeof body?.text === 'string' ? body.text.trim() : '', goal = GOALS.has(body?.goal) ? body.goal : 'sameTone';
  const install = typeof body?.install === 'string' ? body.install : '';
  if (!INSTALL.test(install) || !text) return json({ error: 'bad_request' }, 400);
  if (text.length > LIMITS.maxChars) return json({ error: 'too_long', maxChars: LIMITS.maxChars }, 413);
  if (!enabled) return json({ ...base(env, 0, now), error: 'unavailable' }, 503);

  const model = env.COACH_MODEL || DEFAULT_MODEL;
  const casual = HH.isCasual(text), prompt = HH.buildPrompt(text, goal, casual);
  const maxOut = Math.min(LIMITS.maxOutputTokens, Math.max(120, Math.ceil(text.length / 2) + 80));
  const est = neurons(model, Math.ceil(prompt.length / 3), maxOut);
  const key = await ipKey(request, env, day), ledger = ledgerOf(env);
  const r = await ledger.reserve(install, key, est, day);
  if (!r.ok) return json({ ...base(env, r.remaining, now), error: r.reason }, r.reason === 'budget_exhausted' ? 503 : 429);

  let timer;
  try {
    const out = await Promise.race([
      env.AI.run(model, { messages: [{ role: 'user', content: prompt }], max_tokens: maxOut, temperature: 0.2, chat_template_kwargs: { enable_thinking: false } }),
      new Promise((_, rej) => { timer = setTimeout(() => rej(new Error('timeout')), Number(env.COACH_TIMEOUT_MS) || LIMITS.timeoutMs); }),
    ]);
    const raw = out?.choices?.[0]?.message?.content ?? out?.response ?? '';
    const cleaned = HH.cleanRewrite(raw);
    const rewrite = cleaned && HH.restoreCode(text, HH.fixTypos(text, cleaned));
    if (!rewrite) throw new Error('empty');
    const u = out?.usage || {};
    const actual = neurons(model, u.prompt_tokens || Math.ceil(prompt.length / 3), u.completion_tokens || Math.ceil(rewrite.length / 3));
    await ledger.settle(install, key, est, actual, true, day);
    return json({ ...base(env, r.remaining, now), rewrite, casual, model });
  } catch (e) {
    await ledger.settle(install, key, est, 0, false, day);
    const timeout = String(e?.message) === 'timeout';
    return json({ ...base(env, r.remaining + 1, now), error: timeout ? 'timeout' : 'provider_error' }, timeout ? 504 : 502);
  } finally { clearTimeout(timer); }
}
