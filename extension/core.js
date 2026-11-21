/* HeyHumanly core: tone-keeping rewrite via a local Ollama model, plus rule-based habit detection.
 * Wordy-phrase list, passive-voice check, repeated-opener check and the Flesch-Kincaid formula are adapted from
 * Lexicon by Aashish Harishchandre (https://github.com/AashishH15/Lexicon, MIT License). */
(function (root) {
  'use strict';
  const DEFAULTS = { endpoint: 'http://localhost:11434', model: '', goal: 'sameTone' };

  // ---------- helpers ----------
  const words = (s) => s.split(/[^\p{L}\p{N}']+/u).filter(Boolean).map((w) => w.toLowerCase());
  const esc = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const find = (re, text) => { const out = []; let m; const g = new RegExp(re.source, re.flags.includes('g') ? re.flags : re.flags + 'g'); while ((m = g.exec(text))) { out.push(m[0]); if (m[0] === '') g.lastIndex++; } return out; };
  const uniq = (arr) => { const seen = new Set(); return arr.filter((x) => { const k = x.toLowerCase(); if (seen.has(k)) return false; seen.add(k); return true; }); };
  const list = (items) => uniq(items.map((s) => s.replace(/^[ ,.]+|[ ,.]+$/g, ''))).slice(0, 4).map((s) => '“' + s + '”').join(', ');

  // ---------- register ----------
  const SLANG = /\b(yo|gang|bro|bruh|dude|lol|lmao|haha+|gonna|wanna|gotta|ya|u|ur|idk|tbh|omg|nah|yeah|yep|hey|hmm|bet|fr|rn|btw|sup|what's up|whats up)\b/gi;
  function isCasual(text) {
    const startsLower = /^\p{Ll}/u.test(text.trim());
    const emoji = /\p{Extended_Pictographic}/u.test(text);
    return (text.match(SLANG) || []).length >= 1 || startsLower || emoji;
  }

  // ---------- research notes (only for tips with a real, checkable source) ----------
  const EV = {
    concise: { note: 'In a study of web readers, cutting the word count made text measurably easier to use (about 58% better in Nielsen Norman Group’s test), because most people skim instead of reading every word.', name: 'Nielsen Norman Group', url: 'https://www.nngroup.com/articles/concise-scannable-and-objective-how-to-write-for-the-web' },
    plain: { note: 'Text that is easy to read makes readers judge the writer as more intelligent. Hard-to-process wording does the opposite.', name: 'Oppenheimer, 2006, Applied Cognitive Psychology', url: 'https://doi.org/10.1002/acp.1178' },
    hedge: { note: 'In studies of speech style, hedges lowered how authoritative a speaker seemed, though not how likable they seemed. Effects on persuasion were mixed.', name: 'Hosman, hedges and hesitations', url: 'https://aquila.usm.edu/fac_pubs/16291' },
    scan: { note: 'Nielsen Norman Group found 79% of users scan new pages and only 16% read word by word. Evidence on the best order for news-style text is mixed.', name: 'Nielsen Norman Group', url: 'https://www.nngroup.com/alertbox/9710a.html' },
  };
  const EVIDENCE = { 'Filler': EV.concise, 'Repetition': EV.concise, 'Wordy phrases': EV.concise, 'Vague wording': EV.plain, 'Too much in one sentence': EV.plain, 'Hedging': EV.hedge, 'Buried the point': EV.scan };
  const TIPS = {
    'Filler': 'Pause silently instead of saying “um” or “you know”. A pause sounds confident.',
    'Hedging': 'Say it plainly, or name the condition: “If the design isn’t fixed by Thursday, we push.”',
    'Vague wording': 'Replace “thing” with the noun you’d use if someone asked “which one?”.',
    'Too much in one sentence': 'One idea per sentence. Start a new one whenever the subject changes.',
    'Repetition': 'Say it once, in the strongest place.',
    'Buried the point': 'Before you write or speak, finish the sentence “What I need from you is…” and start with that.',
    'Wordy phrases': 'Reach for the short word: “to” beats “in order to”, “because” beats “due to the fact that”.',
    'Passive voice': 'Put who does the action first: “Priya reviewed it”, not “it was reviewed”.',
    'Repeated openers': 'Start the next sentence with a different word or fold two sentences together.',
  };
  const CUTS = new Set(['Filler', 'Hedging', 'Vague wording', 'Repetition', 'Wordy phrases']);

  // ---------- prose quality (adapted from Lexicon) ----------
  const WORDY = [
    ['at the end of the day', ['ultimately', 'finally']], ['in order to', ['to']], ['due to the fact that', ['because']], ['in the event that', ['if']],
    ['in spite of the fact that', ['although', 'despite']], ['the reason why is that', ['because']], ['on a daily basis', ['daily']], ['on a weekly basis', ['weekly']],
    ['on a monthly basis', ['monthly']], ['by means of', ['by', 'via']], ['in the vicinity of', ['near', 'about']], ['until such time as', ['until']],
    ['all things considered', ['overall']], ['the bottom line is that', ['essentially']], ['in a nutshell', ['briefly', 'in short']], ['as a matter of fact', ['in fact']],
    ['the fact of the matter is', ['the truth is']], ['it goes without saying', ['clearly']], ['last but not least', ['finally']], ['but at the same time', ['however', 'yet']],
    ['each and every', ['each', 'every']], ['first and foremost', ['first']], ['at this point in time', ['now']], ['for the purpose of', ['for', 'to']],
    ['with regard to', ['about']], ['in the near future', ['soon']], ['a large number of', ['many']], ['has the ability to', ['can']], ['is able to', ['can']],
    ['in my opinion', ['']], ['needless to say', ['']],
  ];
  function wordyHits(text) {
    const out = [];
    for (const [phrase, reps] of WORDY) for (const m of find(new RegExp('\\b' + esc(phrase) + '\\b', 'i'), text)) out.push({ text: m, reps });
    return out;
  }
  const IRREGULAR = 'built|made|written|taken|broken|given|driven|known|shown|spoken|bought|caught|taught|thought|brought|kept|left|sent|lost|met|said|seen|told|understood|won|begun|chosen|drawn|eaten|fallen|forgotten|frozen|grown|hidden|held|led|meant|stolen|found|spent|sold';
  function passiveHits(text) {
    const re = new RegExp('\\b(am|is|are|was|were|be|been|being)\\s+(\\w+ed|' + IRREGULAR + ')\\b', 'gi');
    const out = []; let m;
    while ((m = re.exec(text))) {
      const after = text.slice(m.index + m[0].length), before = text.slice(Math.max(0, m.index - 15), m.index);
      const compound = /\b(being|been)\s+$/i.test(before), agent = /^\s+by\s+[a-z]+/i.test(after), stative = /^\s+(about|in|with|at|of|for|to)\b/i.test(after);
      if (stative && !compound && !agent) continue;
      out.push(m[0]);
    }
    return out;
  }
  function repeatedOpener(text) {
    const s = text.split(/[.!?]+/).map((x) => x.trim()).filter(Boolean);
    if (s.length < 3) return null;
    const f = s.map((x) => (x.split(/\s+/)[0] || '').replace(/[^\p{L}]/gu, '').toLowerCase());
    for (let i = 0; i <= f.length - 3; i++) if (f[i] && f[i] === f[i + 1] && f[i] === f[i + 2]) return s[i].split(/\s+/)[0];
    return null;
  }
  function syllables(word) {
    const w = word.toLowerCase().replace(/[^a-z]/g, '');
    if (w.length <= 3) return w ? 1 : 0;
    const v = w.match(/[aeiouy]+/g); let c = v ? v.length : 0;
    if (w.endsWith('e') && !w.endsWith('le') && c > 1) c--;
    return Math.max(1, c);
  }
  function readability(text) {
    const ws = text.trim().split(/\s+/).filter(Boolean);
    if (!ws.length) return { words: 0, grade: null, label: '-', readSeconds: 0 };
    const sentences = Math.max(1, (text.match(/[^.!?]+[.!?]+/g) || []).length);
    const syl = ws.reduce((a, w) => a + syllables(w), 0);
    const g = 0.39 * ws.length / sentences + 11.8 * syl / ws.length - 15.59;
    const label = g <= 12 ? 'Grade ' + Math.max(1, Math.round(g)) : g <= 16 ? 'College' : 'Graduate';
    return { words: ws.length, grade: g, label, readSeconds: Math.round(ws.length / 250 * 60) };
  }
  const clock = (s) => Math.floor(s / 60) + ':' + String(s % 60).padStart(2, '0');

  // ---------- habit detection ----------
  function detect(original, rewrite, casual) {
    const out = [], wc = Math.max(1, words(original).length);
    const mv = (habit, before, after, why, also) => out.push({ habit, before, after: after || '', why, also: also || [] });

    // buried point
    const lead = (rewrite.split(/[.?!]/)[0] || '');
    const leadWords = new Set(words(lead).filter((w) => w.length > 3));
    if (!casual && leadWords.size) {
      let best = null, idx = 0;
      for (const clause of original.split(/[,;.?!]/)) {
        const at = original.indexOf(clause, idx); if (at >= 0) idx = at + clause.length;
        const cw = new Set(words(clause).filter((w) => w.length > 3)); if (!cw.size) continue;
        let hit = 0; cw.forEach((w) => { if (leadWords.has(w)) hit++; });
        const score = hit / leadWords.size;
        if (score > (best ? best.score : 0.5) && at >= 0) best = { score, start: at, text: clause.trim() };
      }
      if (best) {
        const before = original.slice(0, best.start).split(/\s+/).filter(Boolean).length;
        if (before / wc > 0.3 && before >= 12) mv('Buried the point', best.text.split(/\s+/).slice(0, 6).join(' '), lead.slice(0, 40),
          'Your main point doesn’t appear until word ' + (before + 1) + ' of ' + wc + '. Most people skim, so leading with the point is standard advice. The research on this is mixed, so treat it as a guideline: “' + lead.trim() + '”.');
      }
    }
    // too long
    for (const s of original.split(/[.?!]/)) {
      const n = words(s).length;
      if (n >= 32) { mv('Too much in one sentence', s.trim().split(/\s+/).slice(0, 6).join(' '), '', 'This sentence runs ' + n + ' words and carries several separate ideas joined by “and”, “but” and “so”. Each idea is easier to follow as its own sentence. Split it where the subject changes.'); break; }
    }
    // hedging (not in casual messages)
    const hedges = find(/\b(maybe|probably|perhaps|i think|i guess|i feel like|not sure|might|sort of|kind of)\b/i, original);
    if (hedges.length >= 3 && !casual) mv('Hedging', hedges[0], '', 'You hedged ' + hedges.length + ' times (' + list(hedges) + '). Each one can make you sound less sure of the point. If you’re unsure, say what you’d need to know; if you’re sure, say it plainly.', hedges.slice(1));
    // filler
    const fillers = find(/\b(um+|uh+|you know|basically|i mean|literally|so basically|kind of|sort of)\b|,\s*like,/i, original).map((s) => s.replace(/^[ ,]+|[ ,]+$/g, ''));
    if (fillers.length) mv('Filler', fillers[0], '', fillers.length + ' filler ' + (fillers.length === 1 ? 'phrase' : 'phrases') + ' in ' + wc + ' words (' + list(fillers) + '). They add no information, and the reader has to get through them to reach the point.', fillers.slice(1));
    // vague
    const vague = find(/\b(the |a |some )?(things?|stuff)\b( about| with| on)?( the)?( \w+)?/i, original);
    if (vague.length && !casual) mv('Vague wording', vague[0].trim(), '', '“' + vague[0].trim() + '” makes the reader guess what you mean. Name the actual thing (the plan, the design, the deadline) so nobody has to ask.');
    // repetition
    const w = words(original);
    if (w.length > 8) {
      const seen = {}; for (let i = 0; i < w.length - 2; i++) { const g = w.slice(i, i + 3).join(' '); seen[g] = (seen[g] || 0) + 1; }
      const rep = Object.entries(seen).find(([g, n]) => n >= 2 && !['i think we', 'you know the'].includes(g));
      if (rep) mv('Repetition', rep[0], '', '“' + rep[0] + '” appears ' + rep[1] + ' times. Say it once, in the strongest place.');
    }
    if (!casual) {
      const wh = wordyHits(original);
      if (wh.length) {
        const pairs = wh.slice(0, 3).map((h) => h.reps[0] ? '“' + h.text + '” → “' + h.reps[0] + '”' : '“' + h.text + '” (cut it)').join(', ');
        mv('Wordy phrases', wh[0].text, wh[0].reps[0] || '', wh.length + ' wordy ' + (wh.length === 1 ? 'phrase' : 'phrases') + ': ' + pairs + '. The short version says the same thing in fewer words.', wh.slice(1).map((h) => h.text));
      }
      const ps = passiveHits(original);
      if (ps.length >= 2) mv('Passive voice', ps[0], '', ps.length + ' passive constructions (' + list(ps) + '). Passive voice hides who does what. Name the doer first when it matters.', ps.slice(1));
      const op = repeatedOpener(original);
      if (op) mv('Repeated openers', op, '', 'Three sentences in a row start with “' + op + '”. Vary the start of one, or join two.');
    }
    const order = ['Buried the point', 'Too much in one sentence', 'Hedging', 'Filler', 'Wordy phrases', 'Vague wording', 'Repetition', 'Passive voice', 'Repeated openers'];
    return out.map((m) => { const e = EVIDENCE[m.habit]; return Object.assign(m, e ? { evidence: e.note, sourceName: e.name, sourceURL: e.url } : {}, { cuts: CUTS.has(m.habit), tip: TIPS[m.habit] || '' }); })
      .sort((a, b) => order.indexOf(a.habit) - order.indexOf(b.habit)).slice(0, 5);
  }

  // ---------- model ----------
  const GOALS = {
    sameTone: 'Edit as lightly as possible. When there is filler or repetition, aim for roughly 10 to 30 percent fewer words; if the text is already tight, return it nearly unchanged.',
    shorter: 'Make it as short as possible while keeping the writer’s voice, slang and every fact.',
    formal: 'The writer asked for a more formal register for this one message: make it polite and professional, still short.',
  };
  function buildPrompt(text, goal, casual) {
    return 'You are HeyHumanly, a writing coach that edits lightly. The text may be typed or transcribed speech.\n' +
      'Step 1: notice the writer’s register (slang, casual, blunt, warm, formal, emoji, lowercase). Keep it. Same energy, same slang, same contractions, same punctuation style. Never make the text more formal, polite or corporate than the writer made it' + (casual ? '. This one is casual: keep it casual' : '') + '.\n' +
      'Keep the writer’s capitalization and punctuation habits as they are (a message written in lowercase stays lowercase; a message with normal capitals keeps normal capitals; "!!" and "..." stay). Leave anything between backticks (`like this`) exactly as written. ' +
      'Step 2: make small cuts only. If a sentence runs past about 25 words, split it into shorter sentences using the writer’s own words. Remove filler and false starts (um, you know, basically, like, so basically), repeated words or ideas, and extra words that add nothing. Keep the original order of ideas unless a sentence is truly tangled.\n' +
      'Never add new content. Keep every fact, name, number, plan and question, and never remove a place, person, time or object ("your house" stays "your house"). Also cut opening filler such as "So basically". If the writer asks something, it stays a question. If the writer is unsure ("I\'m not sure", "maybe"), keep that doubt; never drop it and never turn it into a decision. ' + (GOALS[goal] || GOALS.sameTone) + '\n' +
      'Reply with ONLY the edited text.\nText:\n' + text;
  }
  function cleanRewrite(raw) {
    let s = (raw || '').replace(/<think>[\s\S]*?<\/think>/g, '').trim();
    s = s.replace(/^(here(?:'|’)s|here is)[^\n:]*:\s*/i, '').trim();
    if (/^["“].*["”]$/s.test(s)) s = s.slice(1, -1).trim();
    return s;
  }
  // Same clean-ups as TextSafety.swift: code in backticks stays as written, known typos get the intended word.
  const TYPOS = { teh: 'the', hte: 'the', adn: 'and', nad: 'and', taht: 'that', thta: 'that', wiht: 'with', whit: 'with', becuase: 'because', becasue: 'because',
    recieve: 'receive', recieved: 'received', seperate: 'separate', definately: 'definitely', occured: 'occurred', untill: 'until', wich: 'which', thier: 'their',
    freind: 'friend', beleive: 'believe', tommorow: 'tomorrow', tomorow: 'tomorrow', alot: 'a lot', youre: 'you\'re', dont: 'don\'t' };
  const CODE = /`[^`\n]+`/g;
  function restoreCode(original, rewrite) {
    const spans = original.match(CODE) || []; if (!spans.length) return rewrite;
    const target = rewrite.match(CODE) || []; if (target.length !== spans.length) return original;
    // Each rewrite span gets the closest original span, so reordered code keeps its own text.
    const unused = spans.slice();
    return rewrite.replace(CODE, (s) => {
      let best = 0;
      unused.forEach((o, k) => { if (editDistance(o, s) < editDistance(unused[best], s)) best = k; });
      return unused.splice(best, 1)[0];
    });
  }
  function matchCase(word, like) { return like[0] && like[0] !== like[0].toLowerCase() ? (like.length > 1 && like === like.toUpperCase() ? word.toUpperCase() : word[0].toUpperCase() + word.slice(1)) : word; }
  function editDistance(a, b) {
    let prev = Array.from({ length: b.length + 1 }, (_, j) => j);
    for (let i = 1; i <= a.length; i++) { const cur = [i]; for (let j = 1; j <= b.length; j++) cur[j] = Math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1)); prev = cur; }
    return prev[b.length];
  }
  function fixTypos(original, rewrite) {
    let out = rewrite;
    const had = new Set(words(original));
    for (const [typo, right] of Object.entries(TYPOS)) {
      const re = new RegExp('\\b' + typo + '\\b', 'gi'), hits = original.match(re);
      if (!hits) continue;
      if (re.test(out)) { out = out.replace(re, (m) => matchCase(right, m)); continue; }
      // The model swapped the typo for a different near word ("teh" → "tbh"): use the intended one.
      // Only a new word with the same first letter, once per typo, so unrelated new words are left alone.
      if (!new RegExp('\\b' + right + '\\b', 'i').test(out)) {
        let left = hits.length;
        out = out.replace(/[A-Za-z']+/g, (w) => {
          const l = w.toLowerCase();
          if (left > 0 && !had.has(l) && l[0] === typo[0] && editDistance(l, typo) <= 2) { left--; return matchCase(right, w); }
          return w;
        });
      }
    }
    return out;
  }
  async function listModels(endpoint) {
    const r = await fetch(endpoint.replace(/\/$/, '') + '/api/tags'); if (!r.ok) throw httpError(r.status);
    return ((await r.json()).models || []).map((m) => m.name);
  }
  function httpError(status) {
    const e = new Error(status === 403 ? 'Ollama blocked the extension. In the HeyHumanly Mac app press Settings, Chrome extension, Allow. Or run: launchctl setenv OLLAMA_ORIGINS "chrome-extension://*", then quit and reopen Ollama.' : 'Ollama returned an error (' + status + ').');
    e.code = status === 403 ? 'blocked' : 'http'; return e;
  }
  async function pickModel(endpoint, wanted) {
    const models = await listModels(endpoint);
    if (wanted && models.includes(wanted)) return wanted;
    for (const pref of ['qwen2.5:7b', 'qwen2.5:3b', 'gemma4:12b', 'llama3.2', 'mistral']) if (models.includes(pref)) return pref;
    if (!models.length) { const e = new Error('No models are installed in Ollama yet. Run: ollama pull qwen2.5:3b'); e.code = 'nomodel'; throw e; }
    return models[0];
  }
  async function tighten(text, opts) {
    const o = Object.assign({}, DEFAULTS, opts || {});
    text = text.trim(); if (!text) throw new Error('Select some text first.');
    const casual = isCasual(text);
    let model; try { model = await pickModel(o.endpoint, o.model); } catch (e) { if (e.code) throw e; const err = new Error('Can’t reach Ollama at ' + o.endpoint + '. Is it running?'); err.code = 'offline'; throw err; }
    let res; try {
      res = await fetch(o.endpoint.replace(/\/$/, '') + '/api/generate', { method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ model, prompt: buildPrompt(text, o.goal, casual), stream: false, think: false, keep_alive: '30m', options: { temperature: 0.2, num_predict: Math.min(700, Math.max(120, Math.floor(text.length / 2) + 80)) } }) });
    } catch (e) { const err = new Error('Can’t reach Ollama at ' + o.endpoint + '. Is it running?'); err.code = 'offline'; throw err; }
    if (!res.ok) throw httpError(res.status);
    const j = await res.json(); if (j.error) { const err = new Error(/not found/i.test(j.error) ? 'Model “' + model + '” isn’t installed. Run: ollama pull ' + model : j.error); err.code = 'model'; throw err; }
    const cleaned = cleanRewrite(j.response); if (!cleaned) throw new Error('The model returned nothing. Try again.');
    const rewrite = restoreCode(text, fixTypos(text, cleaned));
    return analyse(text, rewrite, casual, model, o.goal);
  }
  function analyse(original, rewrite, casual, model, goal) {
    const norm = (s) => s.replace(/\s+/g, '').toLowerCase();
    const unchanged = norm(original) === norm(rewrite);
    const ra = readability(original), rb = readability(rewrite);
    const moves = unchanged ? [] : detect(original, rewrite, casual);
    return { original, rewrite, casual, model, goal: goal || 'sameTone', unchanged, moves,
      next: moves.length && moves[0].tip ? 'Next time, work on one thing: ' + moves[0].habit.toLowerCase() + '. ' + moves[0].tip : '',
      stats: { wordsBefore: ra.words, wordsAfter: rb.words, gradeBefore: ra.label, gradeAfter: rb.label, read: clock(rb.readSeconds) } };
  }
  /** Rule-based checks only (no model), used when Ollama is off. */
  function quickCheck(text) {
    const casual = isCasual(text);
    return { original: text, casual, moves: detect(text, text, casual), stats: readability(text) };
  }

  root.HH = { DEFAULTS, isCasual, detect, tighten, analyse, quickCheck, restoreCode, fixTypos, listModels, readability, buildPrompt, cleanRewrite, wordyHits, passiveHits, repeatedOpener, clock };
  if (typeof module !== 'undefined') module.exports = root.HH;
})(typeof self !== 'undefined' ? self : globalThis);
