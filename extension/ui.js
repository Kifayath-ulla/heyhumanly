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
    const note = r.goal === 'sameTone' ? '<div class="note">' + (r.casual ? 'Casual message, so it stays casual. Only filler, repeats and extra words are trimmed.' : 'Your voice is kept. Only filler, repeats and extra words are trimmed.') + '</div>' : '';
    return '<div class="lab">You wrote</div><div class="orig">' + highlight(r.original, phrases, 'bad') + '</div>' +
      '<div class="better"><div class="lab2"><span>Maybe this reads better' + (r.goal === 'sameTone' ? ' · same tone' : '') + '</span><span>' + E(words) + ' · ' + E(grade) + ' · ' + E(s.read) + ' read</span></div><div class="new" id="hh-new">' + E(r.rewrite) + '</div>' + note + '</div>' +
      (r.moves.length ? '<div class="lab" style="margin-top:12px">What changed, and why</div>' + r.moves.map(moveCard).join('') : '') +
      (r.next ? '<div class="next"><b>Next time</b><br>' + E(r.next) + '</div>' : '');
  }
  function quick(r) {
    return r.moves.length ? '<div class="lab">Checks that need no model</div>' + r.moves.map(moveCard).join('') : '<div class="ok"><b>No style habits found.</b></div>';
  }
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
  root.HHUI = { render, quick, CSS, E };
  if (typeof module !== 'undefined') module.exports = root.HHUI;
})(typeof self !== 'undefined' ? self : globalThis);
