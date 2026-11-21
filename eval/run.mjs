#!/usr/bin/env node
// Rewrite-quality eval: runs eval/cases.json through the extension's exact prompt on local Ollama models and scores the output.
// Usage: node eval/run.mjs --models qwen2.5:3b,llama3.2 [--endpoint http://localhost:11434] [--out eval/results]
import { createRequire } from 'node:module';
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
const here = dirname(fileURLToPath(import.meta.url));
const HH = createRequire(import.meta.url)(join(here, '../extension/core.js'));
const arg = (k, d) => { const i = process.argv.indexOf('--' + k); return i > 0 ? process.argv[i + 1] : d; };
const endpoint = arg('endpoint', 'http://localhost:11434');
const models = arg('models', 'qwen2.5:3b').split(',');
const out = arg('out', join(here, 'results'));
const only = arg('case', '');
const cases = JSON.parse(readFileSync(join(here, 'cases.json'), 'utf8')).filter((c) => !only || c.id === only);

const words = (s) => s.split(/[^\p{L}\p{N}'%$#@.:/`-]+/u).filter(Boolean);
const FORMAL = /\b(dear|regards|sincerely|furthermore|additionally|kindly|i would like to|please be advised|at your earliest convenience)\b/i;
const ENGLISH = /\b(the|tomorrow|meeting|sorry|wanted|can't|cannot)\b/i;

function score(c, original, rewrite) {
  const checks = {};
  const lo = rewrite.toLowerCase();
  checks.nonEmpty = rewrite.trim().length > 0;
  checks.keepsFacts = (c.keep || []).every((k) => lo.includes(k.toLowerCase()));
  if (c.cut) checks.removesFiller = c.cut.every((k) => !new RegExp('(^|[^\\p{L}])' + k.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + '($|[^\\p{L}])', 'iu').test(rewrite));
  if (c.question) checks.keepsQuestion = (rewrite.match(/\?/g) || []).length >= (c.minQuestions || 1);
  if (c.question === false) checks.noNewQuestion = !/\?/.test(rewrite) || /\?/.test(original);
  if (c.doubt) checks.keepsDoubt = c.doubt.some((d) => lo.includes(d)) || /\b(unsure|not certain|might|maybe|perhaps|probably|possibly)\b/i.test(rewrite);
  const goal = c.goal || 'sameTone';
  if (goal !== 'formal') {
    checks.noAddedFormality = !FORMAL.test(rewrite) || FORMAL.test(original);
    if (/^\p{Ll}/u.test(original.trim())) checks.keepsLowercase = /^\p{Ll}/u.test(rewrite.trim());
    if (c.slang) checks.keepsSlang = c.slang.every((s) => new RegExp('\\b' + s + '\\b', 'i').test(rewrite));
  }
  if (c.notEnglish) checks.keepsLanguage = !ENGLISH.test(rewrite);
  if (c.script === 'Arabic') checks.keepsScript = (rewrite.match(/\p{Script=Arabic}/gu) || []).length > rewrite.replace(/\s/g, '').length * 0.7;
  const wb = words(original).length, wa = words(rewrite).length, cut = (wb - wa) / wb;
  if (c.minCut) checks.cutsEnough = cut >= c.minCut;
  if (c.maxChange) checks.lightTouch = Math.abs(cut) <= c.maxChange;
  if (goal === 'sameTone') checks.noBloat = wa <= wb * 1.1;
  const ow = new Set(words(original.toLowerCase())), novel = words(lo).filter((w) => w.length > 3 && !ow.has(w));
  if (goal === 'sameTone') checks.noInvention = novel.length <= Math.max(2, wa * 0.15);
  if (c.expectSplit) checks.splitsLongSentence = (rewrite.match(/[.!?](\s|$)/g) || []).length >= 2;
  const passed = Object.values(checks).filter(Boolean).length, total = Object.keys(checks).length;
  return { checks, passed, total, cut: Math.round(cut * 100), novel };
}

async function run(model, c) {
  const casual = HH.isCasual(c.text), goal = c.goal || 'sameTone';
  const ctl = new AbortController(); const t = setTimeout(() => ctl.abort(), 600000);
  const t0 = Date.now();
  try {
    const r = await fetch(endpoint + '/api/generate', { method: 'POST', signal: ctl.signal, headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ model, prompt: HH.buildPrompt(c.text, goal, casual), stream: false, think: false, keep_alive: '30m',
        options: { temperature: 0.2, seed: 7, num_predict: Math.min(700, Math.max(120, Math.floor(c.text.length / 2) + 80)) } }) });
    const j = await r.json(); if (j.error) throw new Error(j.error);
    const rewrite = HH.cleanRewrite(j.response);
    return { model, id: c.id, casual, rewrite, ms: Date.now() - t0, ...score(c, c.text, rewrite) };
  } catch (e) { return { model, id: c.id, casual, error: String(e.message || e), ms: Date.now() - t0, passed: 0, total: 1, checks: {} }; }
  finally { clearTimeout(t); }
}

mkdirSync(out, { recursive: true });
const all = [];
for (const model of models) {
  for (const c of cases) { const r = await run(model, c); all.push(r); console.error(`${model} ${c.id} ${r.passed}/${r.total} ${r.ms}ms ${r.error || ''}`); }
}
const stamp = (models.join('+') + (only ? '--' + only : '')).replace(/[:/]/g, '_');
writeFileSync(join(out, stamp + '.json'), JSON.stringify(all, null, 2));
let md = '| model | score | cases fully passed | median latency | failed checks |\n|---|---|---|---|---|\n';
for (const model of models) {
  const rs = all.filter((r) => r.model === model), p = rs.reduce((a, r) => a + r.passed, 0), t = rs.reduce((a, r) => a + r.total, 0);
  const lat = rs.map((r) => r.ms).sort((a, b) => a - b)[Math.floor(rs.length / 2)];
  const fails = rs.flatMap((r) => r.error ? [r.id + ':error'] : Object.entries(r.checks).filter(([, v]) => !v).map(([k]) => r.id + ':' + k));
  md += `| ${model} | ${Math.round(100 * p / t)}% | ${rs.filter((r) => r.passed === r.total).length}/${rs.length} | ${(lat / 1000).toFixed(1)}s | ${fails.join(', ') || '-'} |\n`;
}
writeFileSync(join(out, stamp + '.md'), md);
console.log(md);
