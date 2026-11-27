import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
const HH = createRequire(import.meta.url)('../extension/core.js');

test('isCasual: slang, lowercase start and emoji are casual; formal text is not', () => {
  assert.equal(HH.isCasual('yo gang we going rn'), true);
  assert.equal(HH.isCasual('lowercase start'), true);
  assert.equal(HH.isCasual('Great work 🎉'), true);
  assert.equal(HH.isCasual('Dear Ms Rao, the invoice is attached.'), false);
});

test('cleanRewrite strips think blocks, "Here is" preambles and wrapping quotes', () => {
  assert.equal(HH.cleanRewrite('<think>plan</think>Here is the edited text: "Ship it."'), 'Ship it.');
  assert.equal(HH.cleanRewrite('“Ship it.”'), 'Ship it.');
  assert.equal(HH.cleanRewrite(''), '');
  assert.equal(HH.cleanRewrite(undefined), '');
  assert.equal(HH.cleanRewrite('Here is the diagnosis: it works.', 'Here is teh diagnosis: it works.'), 'Here is the diagnosis: it works.');
  assert.equal(HH.cleanRewrite('“Ship it.”', '“Ship it”'), '“Ship it.”');
  assert.equal(HH.cleanRewrite('Here is the corrected text: Here is the plan: ship it.', 'Here is teh plan: ship it.'), 'Here is the plan: ship it.');
  assert.equal(HH.cleanRewrite('Here is the plan: here’s the gist: ship it.', 'Here is teh plan: here’s the gist: ship it.'), 'Here is the plan: here’s the gist: ship it.');
  assert.equal(HH.cleanRewrite('Here is the edited text: Here is the plan: here’s the gist: ship.', 'Here is the plan: here’s the gist: ship'), 'Here is the plan: here’s the gist: ship.');
  assert.equal(HH.cleanRewrite('Here’s the plan: we ship Friday.', 'Heres the plan: we ship Friday.'), 'Here’s the plan: we ship Friday.');
  assert.equal(HH.cleanRewrite('Corrected text: ship it.'), 'ship it.');
  assert.equal(HH.cleanRewrite('Here is the corrected sentence: we ship Friday.', 'we ship friday'), 'we ship Friday.');
  assert.equal(HH.cleanRewrite('Here’s the final email: Hi Sam, we ship Friday.', 'Heres the final email Hi Sam we ship friday'), 'Here’s the final email: Hi Sam, we ship Friday.');
  assert.equal(HH.cleanRewrite('Here is the edited text: Here is the text: ship it.', 'Here is the text: shp it'), 'Here is the text: ship it.');
  assert.equal(HH.cleanRewrite('Here is the text: Here is the text: ship it.', 'Here is the text: shp it'), 'Here is the text: ship it.');
  assert.equal(HH.cleanRewrite('Rewrite: Rewrite the intro.', 'Rewrite: rewite the intro'), 'Rewrite: Rewrite the intro.');
  assert.equal(HH.cleanRewrite('Here is the email: Here is the email list.', 'Here is the email: Here is teh email list'), 'Here is the email: Here is the email list.');
  assert.equal(HH.cleanRewrite('Here is the text: Here is the text: ship it.', 'Here is the text: Here is the text: shp it'), 'Here is the text: Here is the text: ship it.');
});

test('wordyHits and passiveHits find Lexicon-style patterns', () => {
  assert.deepEqual(HH.wordyHits('In order to win, due to the fact that we can.').map((h) => h.reps[0]), ['to', 'because']);
  assert.deepEqual(HH.passiveHits('The report was written by Priya. We shipped it.'), ['was written']);
  assert.deepEqual(HH.wordyHits('Ship it today.'), []);
});

test('readability counts words and labels a grade', () => {
  const r = HH.readability('The cat sat. The dog ran.');
  assert.equal(r.words, 6);
  assert.match(r.label, /^Grade \d+/);
});

test('analyse explains cuts with checkable sources', () => {
  const r = HH.analyse('So basically I just think that we should meet up tomorrow in order to discuss the plan.', 'We should meet tomorrow to discuss the plan.', false, 'm');
  const habits = r.moves.map((m) => m.habit);
  assert.ok(habits.includes('Filler'));
  assert.ok(habits.includes('Wordy phrases'));
  for (const m of r.moves) if (m.sourceURL) assert.match(m.sourceURL, /^https:\/\//);
  assert.ok(r.stats.wordsAfter < r.stats.wordsBefore);
});

test('analyse treats case/whitespace-only edits as unchanged with no moves', () => {
  const r = HH.analyse('Ship it.', 'ship  it.', false, 'm');
  assert.equal(r.unchanged, true);
  assert.deepEqual(r.moves, []);
});

test('analyse counts a word split ("alot" to "a lot") as a change', () => {
  const r = HH.analyse('it saved me alot of time', 'it saved me a lot of time', true, 'm');
  assert.equal(r.unchanged, false);
});

test('quickCheck runs with no model', () => {
  const habits = HH.quickCheck('So basically the thing is in order to win we must.').moves.map((m) => m.habit);
  assert.ok(habits.includes('Filler') && habits.includes('Wordy phrases'));
});

test('buildPrompt keeps the text verbatim and asks to preserve facts, questions and doubt', () => {
  const p = HH.buildPrompt('idk if we ship thu?', 'sameTone', true);
  assert.ok(p.endsWith('Text:\nidk if we ship thu?'));
  assert.match(p, /keep it casual/);
  assert.match(p, /it stays a question/);
  assert.match(p, /keep that doubt/);
  assert.match(HH.buildPrompt('x', 'shorter', false), /as short as possible/);
});

test('buildPrompt fixes clear misspellings but keeps slang and casing', () => {
  const p = HH.buildPrompt('thx, it realy saved me alot of time', 'sameTone', true);
  assert.match(p, /fix clear spelling mistakes \("realy" becomes "really", "alot" becomes "a lot"\)/);
  assert.match(p, /keep slang, abbreviations and casual spellings/);
});

function mockFetch(routes) {
  const calls = [];
  globalThis.fetch = async (url, opts = {}) => {
    calls.push({ url, opts });
    const path = new URL(url).pathname;
    const h = routes[path];
    if (!h) throw new TypeError('fetch failed');
    const [status, body] = h(opts.body ? JSON.parse(opts.body) : null);
    return new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });
  };
  return calls;
}

test('tighten talks only to the configured local endpoint and returns an analysed rewrite', async () => {
  const calls = mockFetch({
    '/api/tags': () => [200, { models: [{ name: 'nomic-embed-text' }, { name: 'qwen2.5:3b' }] }],
    '/api/show': () => [200, {}],
    '/api/generate': (b) => [200, { response: 'We should meet tomorrow to discuss the plan.', done: true, done_reason: 'stop', model: b.model }],
  });
  const r = await HH.tighten('So basically we should meet up tomorrow in order to discuss the plan.', { endpoint: 'http://localhost:11434' });
  assert.equal(r.model, 'qwen2.5:3b');
  assert.equal(r.rewrite, 'We should meet tomorrow to discuss the plan.');
  for (const c of calls) assert.ok(c.url.startsWith('http://localhost:11434/api/'), c.url);
  const gen = JSON.parse(calls.find((c) => c.url.endsWith('/api/generate')).opts.body);
  assert.equal(gen.stream, false);
  assert.ok(gen.prompt.endsWith('discuss the plan.'));
});

test('tighten reports a blocked origin (403) with code "blocked"', async () => {
  mockFetch({ '/api/tags': () => [200, { models: [{ name: 'qwen2.5:3b' }] }], '/api/show': () => [403, {}], '/api/generate': () => [403, {}] });
  await assert.rejects(HH.tighten('Hello there.', { endpoint: 'http://localhost:11434' }), (e) => e.code === 'blocked');
});

test('tighten reports Ollama offline with code "offline"', async () => {
  mockFetch({});
  await assert.rejects(HH.tighten('Hello there.', { endpoint: 'http://localhost:11434' }), (e) => e.code === 'offline');
});

test('tighten reports no installed models with code "nomodel"', async () => {
  mockFetch({ '/api/tags': () => [200, { models: [] }] });
  await assert.rejects(HH.tighten('Hello there.', { endpoint: 'http://localhost:11434' }), (e) => e.code === 'nomodel');
});

test('tighten rejects empty text', async () => {
  mockFetch({});
  await assert.rejects(HH.tighten('   '));
});

test('restoreCode keeps backtick spans exactly; a lost span returns the original', () => {
  assert.equal(HH.restoreCode('use `i => i*2` here', 'Use `i => i * 2` here.'), 'Use `i => i*2` here.');
  assert.equal(HH.restoreCode('fix `x.lenght` now', 'Fix (x.length now.'), 'fix `x.lenght` now');
  assert.equal(HH.restoreCode('no code here', 'No code here.'), 'No code here.');
  assert.equal(HH.restoreCode('Use `foo` instead of `bar`', '`bar` should be replaced by `foo`.'), '`bar` should be replaced by `foo`.');
});

test('fixTypos: "teh" becomes "the", never a different near word like "tbh"', () => {
  assert.equal(HH.fixTypos('send teh file', 'send tbh file'), 'send the file');
  assert.equal(HH.fixTypos('send teh file', 'send teh file'), 'send the file');
  assert.equal(HH.fixTypos('Teh end', 'The end'), 'The end');
  assert.equal(HH.fixTypos('tbh it is fine', 'tbh it is fine'), 'tbh it is fine');
  assert.equal(HH.fixTypos('send teh file', 'send tbh new file'), 'send the new file');
  assert.equal(HH.fixTypos('tbh i dont think this will work', 'To be honest, I do not think this will work.'), 'To be honest, I do not think this will work.');
  assert.equal(HH.fixTypos('youre late', 'You are late.'), 'You are late.');
  assert.equal(HH.fixTypos('I dont know if youre free', 'I don\'t know, I should have met you earlier.'), 'I don\'t know, I should have met you earlier.');
  assert.equal(HH.fixTypos('youre late', 'Yuore late.'), 'You\'re late.');
  assert.equal(HH.fixTypos('i dont want it. we do not care', 'I dnt want it. We do not care.'), 'I don\'t want it. We do not care.');
  assert.equal(HH.fixTypos('i dont want it, dont worry', 'I dno want it, do not worry.'), 'I don\'t want it, do not worry.');
  assert.equal(HH.fixTypos('i dont know', 'I dno know'), 'I don\'t know');
});

function fakeLM(status, reply, log = []) {
  return { availability: async () => status, create: async (o) => { log.push(o); return { prompt: async (p) => { log.push(p); return reply; }, destroy: () => log.push('destroyed') }; } };
}
test('auto engine uses Chrome’s built-in model when it is available, with no Ollama call', async () => {
  const log = [], realFetch = globalThis.fetch;
  globalThis.LanguageModel = fakeLM('available', 'can you send the report?', log);
  globalThis.fetch = async () => { throw new Error('no network expected'); };
  try {
    const r = await HH.tighten('so basically can you send teh report?', {});
    assert.equal(r.rewrite, 'can you send the report?');
    assert.equal(r.model, 'Chrome built-in model');
    assert.match(log[1], /Text:\nso basically can you send teh report\?$/);
    assert.equal(log.at(-1), 'destroyed');
  } finally { delete globalThis.LanguageModel; globalThis.fetch = realFetch; }
});
test('auto engine falls back to Ollama when Chrome’s model is missing or not downloaded', async () => {
  const realFetch = globalThis.fetch;
  for (const lm of [undefined, fakeLM('downloadable', 'x')]) {
    if (lm) globalThis.LanguageModel = lm; else delete globalThis.LanguageModel;
    const urls = [];
    globalThis.fetch = async (u) => { urls.push(String(u)); return new Response(JSON.stringify(String(u).endsWith('/api/tags') ? { models: [{ name: 'qwen2.5:3b' }] } : { response: 'ok then', done_reason: 'stop' })); };
    try { const r = await HH.tighten('ok so then', {}); assert.equal(r.model, 'qwen2.5:3b'); assert.ok(urls.some((u) => u.endsWith('/api/generate'))); }
    finally { delete globalThis.LanguageModel; globalThis.fetch = realFetch; }
  }
  assert.equal(await HH.builtinStatus(), 'unsupported');
});

test('auto engine falls back to Ollama when Chrome’s availability check never answers', async () => {
  const realFetch = globalThis.fetch;
  globalThis.LanguageModel = { availability: () => new Promise(() => {}), create: () => { throw new Error('should not create'); } };
  globalThis.fetch = async (u) => new Response(JSON.stringify(String(u).endsWith('/api/tags') ? { models: [{ name: 'qwen2.5:3b' }] } : { response: 'ok then', done_reason: 'stop' }));
  try { const r = await HH.tighten('ok so then', {}); assert.equal(r.model, 'qwen2.5:3b'); }
  finally { delete globalThis.LanguageModel; globalThis.fetch = realFetch; }
});

test('style prompts match the Mac app’s WritingStyle instructions', async () => {
  const { readFile } = await import('node:fs/promises');
  const swift = await readFile(new URL('../Sources/WriteCoach/Coaching.swift', import.meta.url), 'utf8');
  for (const [style, text] of Object.entries(HH.STYLES)) {
    const m = swift.match(new RegExp('case \\.' + (style === 'formal' ? 'professional' : style) + ':\\s*return "([^"]+)"', 'g')).map((s) => s.match(/return "([^"]+)"/)[1]);
    assert.ok(m.includes(text), style);
  }
  assert.match(HH.buildStylePrompt('teh plan', 'fixOnly'), /Fix only real mistakes[\s\S]*Text:\nteh plan$/);
});

test('a message typed all in lowercase stays lowercase; normal capitals are left alone', () => {
  assert.equal(HH.keepLowercase('thx, it realy saved me alot of time lol', 'Thx, it really saved me a lot of time lol'), 'thx, it really saved me a lot of time lol');
  assert.equal(HH.keepLowercase('Thanks, Priya', 'Thanks, Priya.'), 'Thanks, Priya.');
  assert.equal(HH.keepLowercase('ok 123', 'OK 123'), 'ok 123');
  assert.equal(HH.keepLowercase('123 !!', 'ABC'), 'ABC');
  assert.equal(HH.keepLowercase('ǅemal says hi', 'ǅemal says hi.'), 'ǅemal says hi.');
  assert.equal(HH.keepLowercase('see chapter Ⅻ', 'See chapter Ⅻ.'), 'See chapter Ⅻ.');
});

test('tighten keeps an all-lowercase message lowercase after the model capitalises it', async () => {
  const realFetch = globalThis.fetch;
  globalThis.fetch = async (u) => new Response(JSON.stringify(String(u).endsWith('/api/tags') ? { models: [{ name: 'qwen2.5:3b' }] } : { response: 'Thx, it really saved me a lot of time lol', done_reason: 'stop' }));
  try { assert.equal((await HH.tighten('thx, it realy saved me alot of time lol', { engine: 'ollama' })).rewrite, 'thx, it really saved me a lot of time lol'); }
  finally { globalThis.fetch = realFetch; }
});

test('Chrome built-in model: an all-lowercase message stays lowercase too', async () => {
  globalThis.LanguageModel = { availability: async () => 'available', create: async () => ({ prompt: async () => 'Thx, it really saved me a lot of time lol', destroy() {} }) };
  try { assert.equal((await HH.tighten('thx, it realy saved me alot of time lol', { engine: 'builtin' })).rewrite, 'thx, it really saved me a lot of time lol'); }
  finally { delete globalThis.LanguageModel; }
});

test('isWritingModel skips embedding models by name, not by tag', () => {
  for (const m of ['nomic-embed-text', 'all-minilm:latest', 'bge-m3', 'llava-clip:7b', 'localhost:5000/nomic-embed-text:latest', 'localhost:5000/bge-m3']) assert.equal(HH.isWritingModel(m), false, m);
  for (const m of ['qwen2.5:3b', 'qwen2.5:clipboard', 'mistral', 'llama3.2:embedded-tuned', 'localhost:5000/clip-lab/qwen2.5:latest']) assert.equal(HH.isWritingModel(m), true, m);
});

test('analyse counts a capitalization-only fix as a change for Fix only', () => {
  assert.equal(HH.analyse('i met john in paris.', 'I met John in Paris.', true, 'm', 'fixOnly').unchanged, false);
  assert.equal(HH.analyse('i met john in paris.', 'I met John in Paris.', true, 'm', 'polish').unchanged, true);
});

test('fixGrammar: slips a small model leaves in are fixed only when the writer made them', () => {
  assert.equal(HH.fixTypos('I has a question and we was late.', 'I has a question and we was late.'), 'I have a question and we were late.');
  assert.equal(HH.fixTypos('Their is a bug, he don\'t know.', 'Their is a bug, he don\'t know.'), 'There is a bug, he doesn\'t know.');
  assert.equal(HH.fixTypos('i should of gone', 'i should of gone'), 'i should have gone');
  assert.equal(HH.fixTypos('Their car is red.', 'Their car is red.'), 'Their car is red.');
  assert.equal(HH.fixGrammar('Fine.', 'I has it'), 'I has it');
  assert.equal(HH.fixTypos('I should of course check', 'I should of course check'), 'I should of course check');
  assert.equal(HH.fixTypos('The last thing I sent you was the draft', 'The last thing I sent you was the draft'), 'The last thing I sent you was the draft');
  assert.equal(HH.fixTypos('He dont know', 'He dont know'), 'He doesn\'t know');
  assert.equal(HH.fixTypos('I should of course check, the thing I sent you was the draft.', 'I should have checked, the thing I sent you was the draft.'), 'I should of course check, the thing I sent you was the draft.');
  assert.equal(HH.fixTypos('I should of gone, I should of course check', 'I should have gone, I should have checked'), 'I should have gone, I should of course check');
  assert.equal(HH.keepOfCourse('I should of course check', 'I should of course check'), 'I should of course check');
  assert.equal(HH.keepOfCourse('I should have checked', 'I should have checked'), 'I should have checked');
  assert.equal(HH.keepOfCourse('I should of course check, and you should have called.', 'Of course, I should check, and you should have called.'), 'Of course, I should check, and you should have called.');
  assert.equal(HH.keepOfCourse('I should of course call, and I should of course check.', 'I should of course call, and I should have checked.'), 'I should of course call, and I should of course check.');
  assert.equal(HH.keepOfCourse('I should of course check', 'Of course I should have checked'), 'Of course I should have checked');
});

test('keepSlang: slang the writer typed stays, except in Professional', () => {
  assert.equal(HH.keepSlang('thx, see u soon', 'Thanks, see you soon'), 'Thx, see u soon');
  assert.equal(HH.keepSlang('idk if it works tbh', 'I don\'t know if it works, to be honest'), 'Idk if it works, tbh');
  assert.equal(HH.keepSlang('rename `msg` in the message handler', 'Rename `message` in the message handler.'), 'Rename `message` in the message handler.');
  assert.equal(HH.keepSlang('use `msg` and send the msg', 'Use `message` and send the message.'), 'Use `message` and send the msg.');
  assert.equal(HH.slangFor('shorter')('Can you send the report today please?', 'Here is a shorter version. Can you send the report today?'), 'Can you send the report today?');
  assert.equal(HH.slangFor('shorter')('Can you send the report today?', 'Here is a shorter version. Sure, the report was sent today.'), 'Can you send the report today?');
  assert.equal(HH.slangFor('polish')('sry, i has a question', 'Sorry to hear that! What is your question?'), 'sry, i have a question');
  assert.equal(HH.slangFor('polish')('sry i cant come cuz im sick, lmk', 'Sorry, I can\'t come because I\'m sick. Let me know.'), 'Sry, I can\'t come cuz I\'m sick. Lmk.');
  assert.equal(HH.keepSlang('thx, thank you all', 'Thanks, thank you all'), 'Thx, thank you all');
  assert.equal(HH.keepSlang('Thanks, see you', 'Thanks, see you'), 'Thanks, see you');
  assert.equal(HH.keepSlang('When ready, could u send the file?', 'When you’re ready, could you send the file?'), 'When you’re ready, could u send the file?');
  assert.equal(HH.keepSlang("she said 'thx' and left", "She said 'thanks' and left."), "She said 'thx' and left.");
  assert.equal(HH.slangFor('formal')('thx', 'Thank you'), 'Thank you');
  assert.equal(HH.slangFor('formal')('ok, lmk rn', 'Yes, please tell me immediately.'), 'Yes, please tell me immediately.');
  assert.equal(HH.dropInvented('check `msg` in the log', 'Check `msg` in the log. The message is confidential.'), 'Check `msg` in the log.');
  assert.equal(HH.slangFor('formal')('sry, cant make it tmrw cuz im sick, lmk if thats ok', 'I am sorry, I cannot make it tomorrow because I am sick. Please let me know if that is okay.'), 'I am sorry, I cannot make it tomorrow because I am sick. Please let me know if that is okay.');
  assert.equal(HH.slangFor('polish')('thx', 'Thanks'), 'Thx');
});

test('Fix only keeps every word: a rewrite that cuts the writer\'s words falls back to the deterministic fixes', () => {
  const o = 'I should of course check, the thing I sent you was the draft.';
  assert.equal(HH.cutsWords(o, 'I should of course check, the draft I sent you.'), true);
  assert.equal(HH.slangFor('fixOnly')(o, 'I should of course check, the draft I sent you.'), o);
  assert.equal(HH.cutsWords('I has went to the store.', 'I went to the store.'), false);
  assert.equal(HH.cutsWords('Ask Zoë and Søren about it today', 'Ask about it today'), true);
  assert.equal(HH.cutsWords('use `a` here and teh `b` there', 'use `a long code span here` here and the `b` there'), false);
  assert.equal(HH.slangFor('fixOnly')('swap `teh` for `the`, thing I sent was teh draft', 'swap `the` for `the`, teh draft'), 'swap `teh` for `the`, thing I sent was teh draft');
  assert.equal(HH.slangFor('polish')(o, 'I should of course check, the draft I sent you.'), 'I should of course check, the draft I sent you.');
});

test('dropReply: answering the message instead of rewriting it falls back to the safe fixes, in every style', () => {
  assert.equal(HH.slangFor('friendly')('thx for the help. i has a question', "No problem at all! Shoot, what's your question?"), 'thx for the help. i have a question');
  assert.equal(HH.slangFor('friendly')('Can you send the report today? we was late, their is a bug', 'Sure, I can send the report today, no worries!'), 'Can you send the report today? we were late, there is a bug');
  assert.equal(HH.slangFor('polish')('Can you send teh report?', 'Of course! I will send the report.'), 'Can you send the report?');
  assert.equal(HH.slangFor('friendly')('Can you send the report today?', 'Hey, could you send the report today?'), 'Hey, could you send the report today?');
  assert.equal(HH.slangFor('friendly')('no worries, i can send it later', 'no worries, i can send it later!'), 'no worries, i can send it later!');
  assert.equal(HH.slangFor('polish')('I should of course check', 'Of course, I should check.'), 'Of course, I should check.');
  assert.equal(HH.slangFor('friendly')('can you check teh reprot? i will send it after', 'can you check the report? i will send it after!'), 'can you check the report? i will send it after!');
  assert.equal(HH.slangFor('polish')("can you help? i can't log in", 'I can help you log in.'), "can you help? i can't log in");
  assert.equal(HH.slangFor('friendly')('Can you check? I will send it after.', "Could you check? I'll send it after."), "Could you check? I'll send it after.");
});

test('a rewrite that swaps who is speaking falls back to the safe fixes', () => {
  const late = 'Im running 10 mins late, start without me', lunch = 'r u free for lunch on thursday? theres a new ramen place near the office';
  assert.equal(HH.slangFor('formal')(late, 'You are running 10 minutes late, and I need to start without you.'), HH.fixGrammar(late, HH.fixTypos(late, late)));
  assert.equal(HH.slangFor('formal')(lunch, "I'm free for lunch on Thursday. There's a new ramen place near the office."), HH.fixGrammar(lunch, HH.fixTypos(lunch, lunch)));
  assert.equal(HH.slangFor('formal')(late, "I'm running 10 minutes late. Start without me."), "I'm running 10 minutes late. Start without me.");
  assert.equal(HH.slangFor('formal')(lunch, "Are you free for lunch on Thursday? There's a new ramen place near the office."), "Are you free for lunch on Thursday? There's a new ramen place near the office.");
  assert.equal(HH.slangFor('formal')('I attached the contract.', 'You will find the contract attached.'), 'You will find the contract attached.');
  assert.equal(HH.slangFor('formal')('do u have the logs? i need them', 'I need the logs. Could you send them?'), 'I need the logs. Could you send them?');
  assert.equal(HH.slangFor('polish')('i think ur right', 'I think you are right.'), 'I think you are right.');
  assert.equal(HH.slangFor('formal')('I can send the file on request.', 'You can ask me to send the file.'), 'You can ask me to send the file.');
  assert.equal(HH.slangFor('formal')('I really need the report today.', 'You really need the report today.'), 'I really need the report today.');
  assert.equal(HH.slangFor('formal')('r u free for lunch on thursday?', "I'm not free for lunch on Thursday."), 'r u free for lunch on thursday?');
  assert.equal(HH.slangFor('formal')('what time works for u?', "I'd like to know what time works for a call."), "I'd like to know what time works for a call.");
  assert.equal(HH.slangFor('formal')(lunch, "Here is a professional version: I'm free for lunch on Thursday. There's a new ramen place near the office."), HH.fixGrammar(lunch, HH.fixTypos(lunch, lunch)));
});

test('a rewrite that thanks the writer for their compliment is a reply', () => {
  const o = 'ngl the new design is way better, nice job';
  assert.equal(HH.slangFor('formal')(o, "Thank you for sharing your feedback on the new design. I'm glad to hear that it has exceeded your expectations, and I appreciate your recognition of the improvements we've made."), HH.fixGrammar(o, HH.fixTypos(o, o)));
  assert.equal(HH.slangFor('formal')(o, 'NGL, the new design is way better! Nice job!'), 'NGL, the new design is way better! Nice job!');
  assert.equal(HH.slangFor('formal')('thx for the feedback, i will fix it', 'Thank you for the feedback. I will fix it.'), 'Thank you for the feedback. I will fix it.');
});

test('dropInvented: no made-up causes or sentences, except in Friendly', () => {
  assert.equal(HH.dropInvented('we was late, their is a bug', 'We were late due to a bug.'), 'we were late, there is a bug');
  assert.equal(HH.dropInvented('We were late because of traffic.', 'We were late because of the traffic.'), 'We were late because of the traffic.');
  assert.equal(HH.dropInvented('Can you send the report today?', 'Could you send the report today? I apologize for any confusion.'), 'Could you send the report today?');
  assert.equal(HH.dropInvented('Send the report. Check the numbers.', 'Please send the report. Check the numbers.'), 'Please send the report. Check the numbers.');
  assert.equal(HH.dropInvented('ok', 'Okay.'), 'Okay.');
  assert.equal(HH.slangFor('polish')('Can you send the report today?', 'Could you send the report today? Ask me again if you need more info.'), 'Could you send the report today?');
  assert.equal(HH.slangFor('friendly')('Can you send the report today?', 'Could you send the report today? Hope you have a great day!'), 'Could you send the report today? Hope you have a great day!');
  assert.equal(HH.slangFor('formal')('we was late, their is a bug', 'We were late due to a bug.'), 'we were late, there is a bug');
  assert.equal(HH.dropInvented('fix `x.lenght` now', 'Fix `x.lenght` now.'), 'Fix `x.lenght` now.');
  assert.equal(HH.dropInvented('It costs $12.50 before tax. Pay today.', 'It costs $12.50 excluding tax. Pay today.'), 'It costs $12.50 excluding tax. Pay today.');
  assert.equal(HH.dropInvented('She said "send it." Then go.', 'She said "send it." Then go. I apologize for any confusion.'), 'She said "send it." Then go.');
  assert.equal(HH.dropInvented('Send teh file. Reply fast.', 'Send the file. Respond quickly.'), 'Send the file. Respond quickly.');
  assert.equal(HH.dropInvented('Send teh file.', 'I apologize. Send the file. Ask me again if you need more info.'), 'Send the file.');
  assert.equal(HH.dropInvented('Dont go. Wait for me.', 'Don\'t go. Wait for me.'), 'Don\'t go. Wait for me.');
  assert.equal(HH.dropInvented('fix `x.lenght` now', 'Fix (x.length now.'), 'Fix (x.length now.');
  assert.equal(HH.dropInvented('...ok so send it', '...Okay, send it. I apologize for any confusion.'), '...Okay, send it.');
  assert.equal(HH.dropInvented('use `a` here, it is slow', 'Use `a` here because it is slow.'), 'use `a` here, it is slow');
});

test('dropInvented: an invented apology or assistant reply never replaces the writer', () => {
  assert.equal(HH.dropInvented('we was late, their is a bug', 'we apologize for the delay.'), 'we were late, there is a bug');
  assert.equal(HH.slangFor('formal')('we was late, their is a bug', 'We apologize for the delay.'), 'we were late, there is a bug');
  assert.equal(HH.slangFor('friendly')('their is a problem with the login page and we was not told',
    "I'm sorry to hear there's an issue with the login page. Let me know if you need any help troubleshooting."),
    'there is a problem with the login page and we were not told');
  assert.equal(HH.slangFor('friendly')('I should of course check the logs before the deploy, thx',
    "Sure, I'd be happy to help you with that. Just let me know what you're deploying."),
    'I should of course check the logs before the deploy, thx');
  assert.equal(HH.slangFor('polish')('send the deck to priya and the board', 'Thanks for reaching out to us today.'), 'send the deck to priya and the board');
  assert.equal(HH.slangFor('friendly')('Could you send the report today?', 'Could you send the report today? Hope you have a great day!'),
    'Could you send the report today? Hope you have a great day!');
  assert.equal(HH.slangFor('friendly')('sorry, i was late', "Sorry, I was late!"), 'Sorry, I was late!');
  assert.equal(HH.slangFor('formal')('Sorry for the delay, the file is attached.', 'I apologize for the delay; the file is attached.'),
    'I apologize for the delay; the file is attached.');
  assert.equal(HH.slangFor('short')('I just wanted to quickly let you know that the meeting tomorrow has been moved', 'Meeting tomorrow moved.'),
    'Meeting tomorrow moved.');
  assert.equal(HH.dropInvented('i shoud of went their', 'I should have gone there'), 'I should have gone there');
  assert.equal(HH.slangFor('friendly')('Please get in touch.', 'Feel free to reach out!'), 'Feel free to reach out!');
  assert.equal(HH.slangFor('formal')('My mistake.', 'I apologize.'), 'I apologize.');
  assert.equal(HH.slangFor('friendly')('the login page is broken and we was not told', 'Thanks for the heads-up! No problem at all, the login page is fine.'),
    'the login page is broken and we were not told');
  assert.equal(HH.slangFor('formal')("It wasn't my fault, the server was down.", 'I apologize, the server was down.'), "It wasn't my fault, the server was down.");
  assert.equal(HH.slangFor('formal')('i did not break it', 'It was not my fault.'), 'It was not my fault.');
  assert.equal(HH.slangFor('short')('I am writing to express my gratitude.', 'Thank you.'), 'Thank you.');
});

test('Professional may spell out the writer’s own slang reason, apology or acknowledgment', () => {
  assert.equal(HH.slangFor('formal')('sry i cant come cuz im sick', 'I apologize, but I cannot come because I am sick.'), 'I apologize, but I cannot come because I am sick.');
  assert.equal(HH.slangFor('formal')('Yep, I’ll send the report', 'Certainly, I’ll send the report.'), 'Certainly, I’ll send the report.');
  assert.equal(HH.slangFor('formal')('i will send the report', 'Certainly, I will send the report.'), 'i will send the report');
  assert.equal(HH.slangFor('formal')('we was late', 'We were late because of traffic.'), 'we were late');
  assert.equal(HH.slangFor('formal')('cant come bc im sick', 'I cannot come because I am sick.'), 'I cannot come because I am sick.');
  assert.equal(HH.slangFor('polish')('met the team in vancouver, we was late', 'met the team in vancouver, bc. we were late'), 'met the team in vancouver, bc. we were late');
  assert.equal(HH.slangFor('formal')('Okay, can you check the report?', 'Certainly, the report looks good.'), 'Okay, can you check the report?');
  assert.equal(HH.slangFor('formal')('Talked to the BC team, we was late', 'I spoke with the British Columbia team; we were late because of traffic.'), 'Talked to the BC team, we were late');
});

test('Fix only: a word swapped for an unrelated one is not a fix; verb agreement and spelling are', () => {
  assert.equal(HH.cutsWords('Great work on the launch everyone', 'Great job on the launch, everyone!'), true);
  assert.equal(HH.slangFor('fixOnly')('Great work on the launch everyone, really proud of this team.', 'Great job on the launch, everyone! Really proud of this team.'), 'Great work on the launch everyone, really proud of this team.');
  assert.equal(HH.cutsWords('the files is ready', 'The files are ready.'), false);
  assert.equal(HH.cutsWords('their going home', "They're going home."), false);
  assert.equal(HH.cutsWords('it realy helped', 'It really helped.'), false);
  assert.equal(HH.cutsWords('I seen it yesterday', 'I saw it yesterday.'), false);
  assert.equal(HH.cutsWords('I gone home early', 'I went home early.'), false);
});

test('"It\'s okay, let\'s try again" answers the message; the writer\'s own "It\'s okay" does not', () => {
  assert.equal(HH.slangFor('friendly')('the login page is broken for me', "It's okay, let's try this again."), 'the login page is broken for me');
  assert.equal(HH.slangFor('polish')("It's okay, we can talk later", "It's okay, we can talk later."), "It's okay, we can talk later.");
});

test('the writer\'s question survives being reworded; an added question does not', () => {
  assert.equal(HH.slangFor('formal')('the api returns 500 when `user_id` is null, can u look?', 'The API returns a 500 error when `user_id` is null. Could you please assist?'),
    'The API returns a 500 error when `user_id` is null. Could you please assist?');
  assert.equal(HH.dropInvented('send the file', 'Send the file. What format do you want?'), 'Send the file.');
  assert.equal(HH.dropInvented('the api returns 500, can u look?', 'The API returns a 500. What time works for you?'), 'the api returns 500, can u look?');
});

test('Fix only: a dropped word, a flipped negation or a changed slang word is not a fix', () => {
  assert.equal(HH.cutsWords('hey r u coming to the standup tmrw?', 'hey, u coming to the standup tmrw?'), true);
  assert.equal(HH.slangFor('fixOnly')('I has finished the slides', HH.fixTypos('I has finished the slides', "I haven't finished the slides")), 'I have finished the slides');
  assert.equal(HH.cutsWords("ngl i'm kinda nervous", "ngg i'm kinda nervous"), true);
  assert.equal(HH.cutsWords('I has went to the store.', 'I went to the store.'), false);
  assert.equal(HH.cutsWords('theres noone to watch her', "there's no one to watch her."), false);
});

test('"their going to" becomes "they\'re going to"; a split-off trailing "tbh" goes back on the sentence', () => {
  assert.equal(HH.fixTypos('Their going to announce it', 'Their going to announce it'), "They're going to announce it");
  assert.equal(HH.fixTypos('we should of tested it tbh', 'We should have tested it. TBH.'), 'We should have tested it tbh.');
  assert.equal(HH.fixTypos('its broken rn', "It's broken. Rn."), "It's broken rn.");
  assert.equal(HH.fixTypos('see you then', 'See you then. Bye.'), 'See you then. Bye.');
});

test('Fix only: adding the apostrophe to "didnt" or fixing "I gone" is not a flipped negation', () => {
  assert.equal(HH.cutsWords('client says they didnt get it', "client says they didn't get it."), false);
  assert.equal(HH.cutsWords('I gone home early', 'I went home early'), false);
});

test('a trailing "tbh" set off by a comma stays as the model wrote it', () => {
  assert.equal(HH.fixTypos('idk if gng can come tbh', 'idk if gng can come, tbh'), 'idk if gng can come, tbh');
});

test('review: names, possessive "their going to the…" and a question before a split-off "lol" stay right', () => {
  assert.equal(HH.fixTypos('ask Peter Noone', 'Ask Peter Noone.'), 'Ask Peter Noone.');
  assert.equal(HH.fixTypos('I appreciate their going to the trouble', 'I appreciate their going to the trouble.'), 'I appreciate their going to the trouble.');
  assert.equal(HH.fixTypos('you are coming too lol', 'You are coming too? LOL.'), 'You are coming too lol?');
  assert.equal(HH.cutsWords('theres noone to watch her', "there's no one to watch her."), false);
});

test('review: "their going to work" is still corrected', () => {
  assert.equal(HH.fixTypos('Their going to work remotely', 'Their going to work remotely.'), "They're going to work remotely.");
});

test('review: "their going to" is only corrected where a clause starts', () => {
  assert.equal(HH.fixTypos('I worry about their going to work sick', 'I worry about their going to work sick.'), 'I worry about their going to work sick.');
  assert.equal(HH.fixTypos('ok, their going to win', 'OK, their going to win.'), "OK, they're going to win.");
  assert.equal(HH.fixTypos('i think their going to win', 'I think their going to win.'), "I think they're going to win.");
});

test('review: "if their going to" is corrected', () => {
  assert.equal(HH.fixTypos('I wonder if their going to announce it', 'I wonder if their going to announce it.'), "I wonder if they're going to announce it.");
});

test('a rewrite that drops the writer\'s request falls back to the safe fixes', () => {
  const o = 'the build is broken again, someone pushed without running tests. pls fix asap';
  assert.equal(HH.slangFor('formal')(o, 'the build is broken again. someone pushed without running tests.'), o);
  assert.equal(HH.slangFor('polish')(o, 'the build is broken again. someone pushed without running tests.'), o);
  assert.equal(HH.slangFor('formal')(o, 'The build is broken again. Could you please fix it as soon as possible?'), 'The build is broken again. Could you please fix it as soon as possible?');
  assert.equal(HH.slangFor('shorter')('can you send me the link again? i lost it', 'can you resend the link? i lost it.'), 'can you resend the link? i lost it.');
});

test('review: a request kept without a marker, or a "can you" statement, is not a dropped request', () => {
  assert.equal(HH.slangFor('shorter')('Please send the revised draft to the team.', 'Send the revised draft to the team, thanks.'), 'Send the revised draft to the team, thanks.');
  assert.equal(HH.slangFor('polish')('Only then can you submit the form.', 'You can submit the form only after that.'), 'You can submit the form only after that.');
});

test('review: a request ending in "please", and a second request, are checked too', () => {
  const o = 'the deploy failed, retry it please';
  assert.equal(HH.slangFor('polish')(o, 'the deploy failed.'), o);
  const two = 'Please send the draft. Can you also book the room?';
  assert.equal(HH.slangFor('shorter')(two, 'Send the draft.'), two);
  assert.equal(HH.slangFor('formal')(two, 'Please send the draft. Could you also reserve the room?'), 'Please send the draft. Could you also reserve the room?');
});

test('a leading "Sure," is filler when a rewrite follows it; a real reply still falls back', () => {
  assert.equal(HH.slangFor('formal')('hey can u send me the report asap, we was late', 'Sure, could you please send me the report as soon as possible? We were late.'),
    'Could you please send me the report as soon as possible? We were late.');
  assert.equal(HH.dropFiller("sry, cant make it tmrw cuz im sick", "Sure, I can't make it tomorrow because I'm sick."), "I can't make it tomorrow because I'm sick.");
  assert.equal(HH.dropFiller('the api returns 500, can u look?', 'Sure, I can help with that. The API returns a 500.'), 'Sure, I can help with that. The API returns a 500.');
  assert.equal(HH.dropFiller('Sure, see you then', 'Sure, see you then.'), 'Sure, see you then.');
});

test('Professional is properly capitalised even for a lowercase message; other styles stay lowercase', () => {
  assert.equal(HH.caseFor('formal')('thx for the help. i has a question', 'Thank you for the help. I have a question.'), 'Thank you for the help. I have a question.');
  assert.equal(HH.caseFor('polish')('thx for the help. i has a question', 'Thx for the help. I have a question.'), 'thx for the help. i have a question.');
});

test('review: "Sure," before an answer to a question stays a reply; a lowercase command keeps its case', () => {
  assert.equal(HH.dropFiller('Is the report ready?', 'Sure, the report is ready.'), 'Sure, the report is ready.');
  assert.equal(HH.dropFiller('how do i run npm install here', 'Sure, npm install is run here.'), 'npm install is run here.');
});

test('review: "??" tidied to "?" after a "Sure," filler still counts as the same question', () => {
  assert.equal(HH.dropFiller('hey can u send me the report??', 'Sure, could you send me the report?'), 'Could you send me the report?');
});

test('a "Sure," before a scrap of the message stays a reply, so the writer\'s words are not lost', () => {
  const o = 'sry, cant make it tmrw cuz im sick, lmk if thats ok';
  assert.equal(HH.dropFiller(o, 'Sure, lmk if thats ok.'), 'Sure, lmk if thats ok.');
  assert.equal(HH.slangFor('polish')(o, 'Sure, lmk if thats ok.'), o);
});

test('Friendly keeps an added friendly line but drops a question the writer never asked', () => {
  const o = 'Their going to announce it monday';
  assert.equal(HH.dropInvented(o, "They're going to announce it on Monday. How about grabbing a coffee together to celebrate this news?", true), "They're going to announce it on Monday.");
  assert.equal(HH.dropInvented('Great work on the launch everyone, really proud of this team.', 'Great work on the launch, everyone! Really proud of this team. Let\'s keep up the great work!', true), 'Great work on the launch, everyone! Really proud of this team. Let\'s keep up the great work!');
});

test('review: Friendly keeps the writer\'s own question even when it is reworded and split off', () => {
  assert.equal(HH.dropInvented('thx for the help, any update on it?', 'Thanks so much for the help! What\'s the latest?', true), 'Thanks so much for the help! What\'s the latest?');
});

test('a statement that rewords the writer\'s last clause stays; an added one with the clause covered still goes', () => {
  assert.equal(HH.dropInvented('ngl the new design is way better, nice job', 'The new design is much better. Well done!'), 'The new design is much better. Well done!');
  assert.equal(HH.dropInvented('The server costs went up 40% this month, we need to look into it.', 'The server costs have increased by 40% this month. We need to investigate this matter further.'),
    'The server costs have increased by 40% this month. We need to investigate this matter further.');
  assert.equal(HH.dropInvented('Thanks for the update! I will review it tonight.', 'Thanks for the update! I will review it tonight. Let me know if you need anything else.'), 'Thanks for the update! I will review it tonight.');
  assert.equal(HH.dropInvented('the deploy broke prod', 'The deploy broke production. We are investigating the issue.'), 'The deploy broke production.');
});

test('Fix only does not turn a statement into a question', () => {
  const o = 'can u send me the slides before the call? i need to review them first';
  assert.equal(HH.cutsWords(o, 'can u send me the slides before the call? i need to review them first?'), true);
  assert.equal(HH.cutsWords(o, 'can u send me the slides before the call? i need to review them first.'), false);
  assert.equal(HH.cutsWords('is it ready??', 'Is it ready?'), false);
});

test('a claim added after the reworded last clause still goes; Fix only may add the "?" a question was missing', () => {
  assert.equal(HH.dropInvented('ngl the new design is way better, nice job', 'The new design is much better. Well done! I will share this with the team.'), 'The new design is much better. Well done!');
  assert.equal(HH.cutsWords('is it ready', 'is it ready?'), false);
  assert.equal(HH.cutsWords('hey, can u check it', 'hey, can u check it?'), false);
  assert.equal(HH.cutsWords('what time works for u', 'what time works for u?'), false);
  assert.equal(HH.cutsWords('i need to review them first', 'i need to review them first?'), true);
});

test('two reworded edge clauses both stay; a "?" added to a statement is caught sentence by sentence', () => {
  assert.equal(HH.dropInvented('the build is fine now. nice job, great effort', 'The build is fine now. Well done! Fantastic work.'), 'The build is fine now. Well done! Fantastic work.');
  assert.equal(HH.cutsWords('Hey can you check? i need to review them first', 'Hey, can you check? i need to review them first?'), true);
  assert.equal(HH.cutsWords('Hey can you check it', 'Hey, can you check it?'), false);
});

test('a reworded question does not keep a place for an invented statement after it', () => {
  assert.equal(HH.dropInvented('the deploy broke prod, can u look?', 'The deploy broke production. Could you please assist? I will share the logs tonight.'), 'The deploy broke production. Could you please assist?');
});
