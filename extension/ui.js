/* Shared result renderer (popup and in-page panel). Returns an HTML string; all text is escaped. */
(function (root) {
  const E = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  function highlight(text, phrases, cls) {
    let h = E(text);
    for (const p of phrases) { if (!p) continue; const re = new RegExp(E(p).replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'i'); h = h.replace(re, (m) => '<mark class="' + cls + '">' + m + '</mark>'); }
    return h;
  }
  function moveCard(m) {
    const change = m.cuts ? '<span class="cut">“' + E(m.before) + '”</span>' + (m.after ? ' → <b>“' + E(m.after) + '”</b>' : ' <i>cut</i>') : '<span>“' + E(m.before) + '”</span>';
    const ev = m.evidence ? '<div class="ev"><b>Research:</b> ' + E(m.evidence) + (m.sourceName ? ' <span>(' + E(m.sourceName) + ')</span>' : '') + (m.sourceURL ? ' <a href="' + E(m.sourceURL) + '" target="_blank" rel="noopener noreferrer" aria-label="Open source">source ↗</a>' : '') + '</div>' : '';
    return '<div class="mv"><div class="tg">' + E(m.habit) + '</div><div class="ch">' + change + '</div><div class="why">' + E(m.why) + '</div>' + ev + '</div>';
  }
  function render(r) {
    if (r.unchanged) return '<div class="ok"><b>This already reads well.</b><br>Nothing worth trimming. ' + (r.casual ? 'It’s clear, and it still sounds like you.' : 'It’s clear and keeps your voice.') + '</div>';
    const s = r.stats, words = s.wordsBefore === s.wordsAfter ? s.wordsAfter + ' words' : s.wordsBefore + ' → ' + s.wordsAfter + ' words';
    const grade = s.gradeBefore === s.gradeAfter ? s.gradeAfter : s.gradeBefore + ' → ' + s.gradeAfter;
    const phrases = r.moves.flatMap((m) => [m.before].concat(m.also || []));
    const note = r.goal === 'sameTone' ? '<div class="note">' + (r.casual ? 'Casual message, so it stays casual. Only filler, repeats and extra words are trimmed, and clear misspellings fixed.' : 'Your voice is kept. Only filler, repeats and extra words are trimmed, and clear misspellings fixed.') + '</div>' : '';
    return '<div class="lab">You wrote</div><div class="orig">' + highlight(r.original, phrases, 'bad') + '</div>' +
      '<div class="better"><div class="lab2"><span>Maybe this reads better' + (r.goal === 'sameTone' ? ' · same tone' : '') + '</span><span>' + E(words) + ' · ' + E(grade) + ' · ' + E(s.read) + ' read</span></div><div class="new" id="hh-new">' + E(r.rewrite) + '</div>' + note + '</div>' +
      (r.moves.length ? '<div class="lab" style="margin-top:12px">What changed, and why</div>' + r.moves.map(moveCard).join('') : '') +
      (r.next ? '<div class="next"><b>Next time</b><br>' + E(r.next) + '</div>' : '');
  }
  function quick(r) {
    return r.moves.length ? '<div class="lab">Checks that need no model</div>' + r.moves.map(moveCard).join('') : '<div class="ok"><b>No style habits found.</b></div>';
  }
  /** Word-level diff (LCS over words and the spaces between them): [{t:'same'|'del'|'add', s}]. */
  function wordDiff(a, b) {
    const tok = (s) => s.match(/\s+|[^\s]+/g) || [];
    const x = tok(a), y = tok(b), n = x.length, m = y.length;
    if (n * m > 400000) return [{ t: 'del', s: a }, { t: 'add', s: b }];
    const L = Array.from({ length: n + 1 }, () => new Uint16Array(m + 1));
    for (let i = n - 1; i >= 0; i--) for (let j = m - 1; j >= 0; j--) L[i][j] = x[i] === y[j] ? L[i + 1][j + 1] + 1 : Math.max(L[i + 1][j], L[i][j + 1]);
    const out = [], push = (t, s) => { const last = out[out.length - 1]; if (last && last.t === t) last.s += s; else out.push({ t, s }); };
    let i = 0, j = 0;
    while (i < n && j < m) {
      if (x[i] === y[j]) { push('same', x[i]); i++; j++; } else if (L[i + 1][j] >= L[i][j + 1]) push('del', x[i++]); else push('add', y[j++]);
    }
    while (i < n) push('del', x[i++]);
    while (j < m) push('add', y[j++]);
    return out;
  }
  /** The rewrite with removed words struck through and new ones highlighted. Whitespace-only edits show as the new text. */
  function diffHTML(original, rewrite) {
    return wordDiff(original, rewrite).map((d) => {
      if (d.t === 'same') return E(d.s);
      if (!d.s.trim()) return d.t === 'add' ? E(d.s) : '';
      return d.t === 'del' ? '<del>' + E(d.s) + '</del>' : '<ins>' + E(d.s) + '</ins>';
    }).join('');
  }
  /** Compact "why" list for the quick panel: what changed and the reason, from the same rule-based moves as the cards. */
  function whyHTML(r) {
    if (!r.moves.length) return '<div class="why-none">' + (r.unchanged ? 'No changes to explain.' : 'Small wording and spelling fixes; no habit to point out.') + '</div>';
    return '<ul class="whys">' + r.moves.slice(0, 8).map((m) => '<li><span class="hb">' + E(m.habit) + '</span> ' +
      (m.cuts ? '<del>' + E(m.before) + '</del>' + (m.after ? ' → <ins>' + E(m.after) + '</ins>' : '') : '“' + E(m.before) + '”') +
      '<div class="wy">' + E(m.why) + (m.sourceURL ? ' <a href="' + E(m.sourceURL) + '" target="_blank" rel="noopener noreferrer">source ↗</a>' : '') + '</div></li>').join('') + '</ul>';
  }
  const PANEL_CSS = `:host{all:initial}*{box-sizing:border-box}
.qp{font:13px/1.5 -apple-system,BlinkMacSystemFont,"Segoe UI",Helvetica,Arial,sans-serif;color:#1d1d1f;background:rgba(250,250,250,.86);-webkit-backdrop-filter:blur(30px) saturate(1.8);backdrop-filter:blur(30px) saturate(1.8);border:.5px solid rgba(0,0,0,.14);border-radius:12px;box-shadow:0 18px 50px -12px rgba(0,0,0,.35);overflow:hidden}
.sty{display:flex;align-items:center;gap:2px;padding:7px 8px}.sty button{all:unset;cursor:pointer;font-size:12px;padding:4px 8px;border-radius:6px;color:#6e6e73}.sty button[aria-pressed=true]{color:#1d1d1f;font-weight:600;background:rgba(0,0,0,.07)}.sty button:focus-visible{outline:2px solid #0a84ff}
.sp{margin-left:auto;width:12px;height:12px;border:2px solid rgba(0,0,0,.15);border-top-color:#6e6e73;border-radius:50%;animation:s 1s linear infinite}@keyframes s{to{transform:rotate(360deg)}}
.hr{height:.5px;background:rgba(0,0,0,.12)}.bd{padding:12px 16px;max-height:min(46vh,340px);overflow:auto}
.tx{font-size:14px;line-height:1.55;white-space:pre-wrap;word-wrap:break-word}.tx.wait{color:#86868b}
del{color:#c9342e;text-decoration:line-through;text-decoration-color:rgba(201,52,46,.6)}ins{text-decoration:none;color:#1f7a34;background:rgba(52,199,89,.16);border-radius:3px;padding:0 1px}
.msg{margin-top:8px;font-size:12.5px;color:#6e6e73}.err{color:#b25000}.msg button{all:unset;cursor:pointer;margin-left:6px;font-weight:600;color:#0a6cdf}
.whys{list-style:none;margin:10px 0 0;padding:0}.whys li{margin-top:6px;font-size:12px;font-weight:500}.hb{font-size:10.5px;text-transform:uppercase;letter-spacing:.04em;color:#86868b;margin-right:4px}.wy{font-weight:400;font-size:11.5px;color:#6e6e73}.wy a{color:inherit}.why-none{margin-top:10px;font-size:12px;color:#6e6e73}
.ft{display:flex;align-items:center;gap:12px;padding:7px 14px;font-size:11px;color:#6e6e73;white-space:nowrap;overflow:hidden}.ft b{font-weight:500;color:rgba(29,29,31,.75);margin-right:3px}.dot{margin-left:auto;flex:none;width:7px;height:7px;border-radius:50%;background:#34c759}.dot.warn{background:#ff9f0a}
@media (prefers-color-scheme:dark){.qp{color:#f5f5f7;background:rgba(40,40,42,.86);border-color:rgba(255,255,255,.16)}.sty button{color:#98989d}.sty button[aria-pressed=true]{color:#f5f5f7;background:rgba(255,255,255,.1)}.hr{background:rgba(255,255,255,.12)}.tx.wait,.ft,.msg,.wy,.why-none,.hb{color:#98989d}.ft b{color:rgba(245,245,247,.75)}del{color:#ff6961}ins{color:#63d97c;background:rgba(48,209,88,.18)}.err{color:#ffb340}.msg button{color:#4aa3ff}.sp{border-color:rgba(255,255,255,.2);border-top-color:#98989d}}`;
  const CSS = `:host{all:initial}*{box-sizing:border-box}
.card{font:14px/1.5 -apple-system,BlinkMacSystemFont,"Segoe UI",Helvetica,Arial,sans-serif;color:#111;background:#fff;border:1px solid rgba(0,0,0,.1);border-radius:16px;box-shadow:0 20px 50px -12px rgba(0,0,0,.28)}
.hd{display:flex;align-items:center;justify-content:space-between;padding:12px 14px;border-bottom:1px solid rgba(0,0,0,.07);font-family:Georgia,"Times New Roman",serif;font-size:17px}
.hd small{font:11px ui-monospace,SFMono-Regular,Menlo,monospace;color:#636360}.bd{padding:14px;max-height:62vh;overflow:auto}
.lab,.lab2{font:10.5px ui-monospace,SFMono-Regular,Menlo,monospace;text-transform:uppercase;letter-spacing:.1em;color:#636360;margin-bottom:6px}.lab2{display:flex;justify-content:space-between;gap:8px;flex-wrap:wrap}
.orig{color:#636360;margin-bottom:12px}mark.bad{background:#FDEBEC;color:#9F2F2D;border-radius:4px;padding:0 2px}
.better{background:#F9F9F8;border:1px solid rgba(0,0,0,.08);border-radius:12px;padding:12px}.new{font-size:15.5px;white-space:pre-wrap}
.note{margin-top:8px;font-size:12px;color:#636360}
.mv{margin-top:8px;border:1px solid rgba(0,0,0,.08);border-radius:12px;padding:10px 12px;background:#fff}.tg{display:inline-block;font:10.5px ui-monospace,Menlo,monospace;text-transform:uppercase;letter-spacing:.05em;background:#FDEBEC;color:#9F2F2D;border-radius:999px;padding:1px 9px;margin-bottom:4px}
.ch{font-weight:500;margin-bottom:3px}.cut{color:#9F2F2D;text-decoration:line-through}.ch b{color:#346538}.why{font-size:13px;color:#636360}
.ev{margin-top:6px;font-size:12px;color:#636360;background:#E1F3FE;color:#1F6C9F;border-radius:8px;padding:6px 8px}.ev a{color:inherit;font-weight:600}
.next{margin-top:12px;background:#111;color:#f7f6f3;border-radius:12px;padding:10px 12px;font-size:13px}.ok{background:#EDF3EC;color:#346538;border-radius:12px;padding:12px}
.err{background:#FBF3DB;color:#956400;border-radius:12px;padding:12px;margin-bottom:10px}.ft{display:flex;gap:8px;padding:12px 14px;border-top:1px solid rgba(0,0,0,.07);flex-wrap:wrap}
button{font:500 13.5px -apple-system,BlinkMacSystemFont,sans-serif;border-radius:9px;padding:8px 14px;cursor:pointer;border:1px solid rgba(0,0,0,.14);background:#fff;color:#111}button.p{background:#111;color:#fff;border-color:#111}button:disabled{opacity:.45;cursor:default}
.sp{display:inline-block;width:12px;height:12px;border:2px solid #ccc;border-top-color:#111;border-radius:50%;animation:s 1s linear infinite;vertical-align:-2px;margin-right:6px}@keyframes s{to{transform:rotate(360deg)}}
select,textarea{font:14px -apple-system,sans-serif;border:1px solid rgba(0,0,0,.14);border-radius:9px;padding:8px;width:100%;background:#fff;color:#111}`;
  root.HHUI = { render, quick, CSS, E, wordDiff, diffHTML, whyHTML, PANEL_CSS };
  if (typeof module !== 'undefined') module.exports = root.HHUI;
})(typeof self !== 'undefined' ? self : globalThis);
