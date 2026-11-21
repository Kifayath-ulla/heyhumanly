#!/usr/bin/env node
// Local stand-in for the online coaching API: runs the real worker/coach.js handler on Node,
// with Workers AI replaced by local Ollama. For testing the app's online mode without a Cloudflare account.
// Usage: node scripts/coach-dev.mjs [--port 8789] [--model qwen2.5:3b] [--fail]   (--fail makes every model call error)
import { createServer } from 'node:http';
import { handleCoach, Allowance } from '../worker/coach.js';
const arg = (k, d) => { const i = process.argv.indexOf('--' + k); return i > 0 ? process.argv[i + 1] : d; };
const port = Number(arg('port', 8789)), model = arg('model', 'qwen2.5:3b'), failAll = process.argv.includes('--fail');
class Store extends Map { async get(k) { return super.get(k); } async put(k, v) { this.set(k, v); } async deleteAll() { this.clear(); } }
const durable = new Allowance({ storage: new Store() });
const env = {
  COACH_ENABLED: 'true', IP_SALT: 'dev', COACH_TIMEOUT_MS: '180000',
  ALLOWANCE: { idFromName: () => 'global', get: () => ({ fetch: (u, init) => durable.fetch(new Request(u, init)) }) },
  AI: { run: async (_m, o) => {
    if (failAll) throw new Error('simulated provider error');
    const r = await fetch('http://localhost:11434/api/chat', { method: 'POST', body: JSON.stringify({ model, messages: o.messages, stream: false, think: false, options: { temperature: o.temperature, num_predict: o.max_tokens } }) });
    const j = await r.json(); if (j.error) throw new Error(j.error);
    return { choices: [{ message: { content: j.message.content } }], usage: { prompt_tokens: j.prompt_eval_count, completion_tokens: j.eval_count } };
  } },
};
createServer(async (req, res) => {
  const chunks = []; for await (const c of req) chunks.push(c);
  const body = req.method === 'GET' || req.method === 'HEAD' ? undefined : Buffer.concat(chunks);
  const headers = { ...req.headers, 'cf-connecting-ip': req.socket.remoteAddress };
  const r = await handleCoach(new Request('http://localhost:' + port + req.url, { method: req.method, headers, body }), env);
  res.writeHead(r.status, Object.fromEntries(r.headers)); res.end(Buffer.from(await r.arrayBuffer()));
}).listen(port, '127.0.0.1', () => console.log('coach-dev on http://localhost:' + port + ' (model ' + model + (failAll ? ', failing' : '') + ')'));
