/* Injected on demand (shortcut or context menu). Reads only the text you selected, or the focused text box, shows a
 * small panel next to it, and replaces text only when you press Enter. Same keys and styles as the Mac quick panel. */
(function () {
  if (window.__hhLoaded) return; window.__hhLoaded = true;
  const STYLES = HH.STYLE_LIST, MAC = /Mac/.test(navigator.platform), MOD = MAC ? '⌘' : 'Ctrl+';
  let host = null, shadow = null, target = null, ui = null;

  function grab() {
    const el = document.activeElement;
    if (el && (el.tagName === 'TEXTAREA' || (el.tagName === 'INPUT' && /^(text|search|email|url|)$/i.test(el.type)))) {
      const a = el.selectionStart, b = el.selectionEnd;
      if (a != null && b != null && b > a) return { kind: 'field', el, a, b, text: el.value.slice(a, b) };
      return { kind: 'field', el, a: 0, b: el.value.length, text: el.value };
    }
    const sel = window.getSelection();
    if (sel && sel.rangeCount && String(sel).trim()) {
      const range = sel.getRangeAt(0).cloneRange();
      const editable = el && (el.isContentEditable || (range.commonAncestorContainer.parentElement && range.commonAncestorContainer.parentElement.isContentEditable));
      return { kind: editable ? 'rich' : 'page', range, text: String(sel), snap: String(range) };
    }
    if (el && el.isContentEditable && el.innerText.trim()) { const range = document.createRange(); range.selectNodeContents(el); return { kind: 'rich', range, text: el.innerText, snap: String(range) }; }
    return null;
  }
  function changed() {
    if (target.kind === 'field') return !target.el.isConnected || target.el.value.slice(target.a, target.b) !== target.text;
    if (target.kind === 'rich') return String(target.range) !== target.snap;
    return false;
  }
  function apply(text) {
    if (!target || changed()) return false;
    if (target.kind === 'field') {
      const el = target.el; el.focus(); el.setSelectionRange(target.a, target.b);
      if (!document.execCommand('insertText', false, text)) { el.setRangeText(text, target.a, target.b, 'end'); }
      el.dispatchEvent(new Event('input', { bubbles: true })); return true;
    }
    if (target.kind === 'rich') {
      const sel = window.getSelection(); sel.removeAllRanges(); sel.addRange(target.range);
      return document.execCommand('insertText', false, text);
    }
    return false;
  }
  /** Where the text is: the selection's box, else the text field's box, else null (bottom-right corner). */
  function anchor() {
    try {
      const r = target && target.range ? target.range.getBoundingClientRect() : target && target.el ? target.el.getBoundingClientRect() : null;
      return r && (r.width || r.height) ? r : null;
    } catch (e) { return null; }
  }
  function place() {
    const W = Math.min(480, innerWidth - 16), r = anchor(), card = shadow.querySelector('.qp');
    host.style.width = W + 'px';
    if (!r) { host.style.right = '16px'; host.style.bottom = '16px'; return; }
    const h = card ? card.offsetHeight : 220, below = r.bottom + 8, above = r.top - 8 - h;
    host.style.left = Math.max(8, Math.min(r.left, innerWidth - W - 8)) + 'px';
    host.style.top = (below + h <= innerHeight - 8 || above < 8 ? Math.max(8, Math.min(below, innerHeight - h - 8)) : above) + 'px';
  }
  function mount() {
    if (host) host.remove();
    host = document.createElement('div'); host.style.cssText = 'position:fixed;z-index:2147483647';
    shadow = host.attachShadow({ mode: 'closed' });
    const tabs = STYLES.map((s, i) => '<button data-i="' + i + '" title="' + HHUI.E(s.blurb + ' (' + (i + 1) + ')') + '">' + HHUI.E(s.title) + '</button>').join('');
    const k = (key, label) => '<span><b>' + key + '</b>' + label + '</span>';
    shadow.innerHTML = '<style>' + HHUI.PANEL_CSS + '</style><div class="qp" role="dialog" aria-label="HeyHumanly"><div class="sty" role="toolbar" aria-label="Style">' + tabs + '<span class="sp" id="sp" hidden></span></div><div class="hr"></div>' +
      '<div class="bd"><div class="tx" id="tx" aria-live="polite"></div><div id="msg"></div><div id="why"></div></div><div class="hr"></div>' +
      '<div class="ft">' + k('↩', 'Replace') + k('⇥', 'Style') + k('1–5', '') + k(MOD + '/', 'Why') + k(MOD + 'R', 'Retry') + k(MOD + 'C', 'Copy') + k('esc', '') + '<span class="dot" id="dot"></span></div></div>';
    shadow.querySelectorAll('.sty button').forEach((b) => b.addEventListener('click', () => select(+b.dataset.i)));
    shadow.addEventListener('click', (e) => { const b = e.target.closest && e.target.closest('[data-setup]'); if (b) chrome.runtime.sendMessage({ type: 'hh:setup' }); });
    document.documentElement.appendChild(host);
  }
  const $ = (id) => shadow.getElementById(id);
  function close() { if (host) host.remove(); host = null; ui = null; }
  function draw() {
    if (!host || !ui) return;
    shadow.querySelectorAll('.sty button').forEach((b) => b.setAttribute('aria-pressed', String(+b.dataset.i === ui.i)));
    const r = ui.cache[STYLES[ui.i].goal];
    $('sp').hidden = !ui.busy;
    const tx = $('tx');
    tx.className = 'tx' + (r ? '' : ' wait');
    tx.innerHTML = r ? HHUI.diffHTML(r.original, r.rewrite) : HHUI.E(target.text);
    let msg = '';
    if (ui.error) msg = '<div class="msg err">' + HHUI.E(ui.error.message) + (ui.error.setup ? '<button data-setup>Open setup</button>' : '') + '</div>';
    else if (ui.notice) msg = '<div class="msg">' + HHUI.E(ui.notice) + '</div>';
    else if (r && r.unchanged) msg = '<div class="msg">This already reads well. Nothing to change.</div>';
    $('msg').innerHTML = msg;
    $('why').innerHTML = ui.why && r ? HHUI.whyHTML(r) : '';
    const dot = $('dot'); dot.className = 'dot' + (ui.error ? ' warn' : '');
    dot.title = ui.error ? 'Not ready' : ui.model ? 'On this computer · ' + ui.model : 'On this computer';
    place();
  }
  function run(force) {
    const goal = STYLES[ui.i].goal;
    if (ui.cache[goal] && !force) { ui.error = null; draw(); return; }
    const mine = ui, id = ++ui.req; ui.busy = true; ui.error = null; ui.notice = ''; draw();
    chrome.runtime.sendMessage({ type: 'hh:tighten', text: target.text, goal }, (res) => {
      if (ui !== mine || id !== mine.req) return;
      ui.busy = false;
      if (chrome.runtime.lastError || !res) ui.error = { message: 'The extension could not reach its background worker. Reload the page and try again.' };
      else if (!res.ok) ui.error = { message: res.error, setup: res.setup };
      else { ui.cache[goal] = res.result; ui.model = res.result.model; }
      draw();
    });
  }
  function select(i) { ui.i = (i + STYLES.length) % STYLES.length; run(false); }
  function current() { return ui && ui.cache[STYLES[ui.i].goal]; }
  function copy(text) { navigator.clipboard.writeText(text).then(() => { if (ui) { ui.notice = 'Copied.'; draw(); } }, () => { if (ui) { ui.notice = 'Couldn’t copy. Select the text and copy it yourself.'; draw(); } }); }
  function replace() {
    const r = current();
    if (!r || ui.busy) return;
    if (r.unchanged) return close();
    if (target.kind === 'page') { copy(r.rewrite); ui.notice = 'This text can’t be edited here, so the rewrite is copied. Paste it where you need it.'; return draw(); }
    if (apply(r.rewrite)) return close();
    ui.notice = 'The text changed since you opened HeyHumanly, so nothing was replaced. Copied the rewrite instead.'; copy(r.rewrite); draw();
  }
  chrome.runtime.onMessage.addListener((msg) => {
    if (!msg || msg.type !== 'hh:open') return;
    if (host) return close();
    target = grab(); mount();
    ui = { i: 1, cache: {}, req: 0, busy: false, why: false, error: null, notice: '', model: '' };
    if (!target || !target.text.trim()) { target = { text: '' }; ui.error = { message: 'Select some text, or click into a text box that has text, then try again.' }; draw(); return; }
    run(false);
  });
  document.addEventListener('keydown', (e) => {
    if (!host || !ui || !e.isTrusted) return;
    const mod = MAC ? e.metaKey : e.ctrlKey, key = e.key.toLowerCase();
    let handled = true;
    if (e.key === 'Escape') close();
    else if (e.key === 'Enter' && !e.shiftKey && !e.altKey && !e.metaKey && !e.ctrlKey) replace();
    else if (e.key === 'Tab' && !mod && !e.altKey) select(ui.i + (e.shiftKey ? -1 : 1));
    else if (!e.altKey && !e.shiftKey && /^Digit[1-5]$/.test(e.code)) select(+e.code.slice(5) - 1);
    else if (mod && (key === '/' || e.code === 'Slash')) { ui.why = !ui.why; draw(); }
    else if (mod && key === 'r' && !e.shiftKey) { if (target.text.trim()) run(true); }
    else if (mod && key === 'c' && current()) copy(current().rewrite);
    else handled = false;
    if (handled) { e.preventDefault(); e.stopImmediatePropagation(); }
  }, true);
  document.addEventListener('mousedown', (e) => { if (host && e.isTrusted && !e.composedPath().includes(host)) close(); }, true);
  addEventListener('resize', () => { if (host) place(); });
})();
