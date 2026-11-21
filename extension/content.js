/* Injected on demand (shortcut or context menu). Reads only the text you selected, or the focused text box,
 * shows a panel, and replaces text only when you press Apply. */
(function () {
  if (window.__hhLoaded) return; window.__hhLoaded = true;
  let host = null, shadow = null, target = null, state = null;

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
      return { kind: editable ? 'rich' : 'page', range, text: String(sel) };
    }
    if (el && el.isContentEditable && el.innerText.trim()) { const range = document.createRange(); range.selectNodeContents(el); return { kind: 'rich', range, text: el.innerText }; }
    return null;
  }
  function changed() {
    if (target.kind === 'field') return !target.el.isConnected || target.el.value.slice(target.a, target.b) !== target.text;
    if (target.kind === 'rich') return String(target.range) !== target.text;
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
  function mount() {
    if (host) host.remove();
    host = document.createElement('div'); host.style.cssText = 'position:fixed;right:16px;bottom:16px;width:min(440px,calc(100vw - 32px));z-index:2147483647';
    shadow = host.attachShadow({ mode: 'closed' });
    shadow.innerHTML = '<style>' + HHUI.CSS + '</style><div class="card" role="dialog" aria-label="HeyHumanly"><div class="hd"><span>HeyHumanly</span><small id="st"></small></div><div class="bd" id="bd"></div><div class="ft" id="ft"></div></div>';
    document.documentElement.appendChild(host);
  }
  const $ = (id) => shadow.getElementById(id);
  function footer(buttons) {
    const ft = $('ft'); ft.innerHTML = '';
    buttons.forEach(([label, cls, fn, disabled]) => { const b = document.createElement('button'); b.textContent = label; if (cls) b.className = cls; b.disabled = !!disabled; b.addEventListener('click', fn); ft.appendChild(b); });
  }
  function close() { if (host) host.remove(); host = null; }
  function run(goal) {
    $('bd').innerHTML = '<span class="sp"></span>Tightening on your computer…'; footer([['Close', '', close]]);
    chrome.runtime.sendMessage({ type: 'hh:tighten', text: target.text, goal }, (res) => {
      if (chrome.runtime.lastError || !res) { $('bd').innerHTML = '<div class="err">The extension could not run. Reload the page and try again.</div>'; footer([['Close', '', close]]); return; }
      if (!res.ok) { $('bd').innerHTML = '<div class="err">' + HHUI.E(res.error) + '</div>' + HHUI.quick(res.quick); footer((res.setup ? [['Open setup', 'p', () => chrome.runtime.sendMessage({ type: 'hh:setup' })]] : []).concat([['Try again', res.setup ? '' : 'p', () => run(goal)], ['Close', '', close]])); return; }
      state = res.result; $('st').textContent = state.model; $('bd').innerHTML = HHUI.render(state);
      const canApply = target.kind !== 'page' && !state.unchanged;
      footer([
        ['Apply', 'p', () => { const ok = apply(state.rewrite); if (ok) close(); else { navigator.clipboard.writeText(state.rewrite); $('st').textContent = changed() ? 'text changed, copied instead' : 'copied instead'; } }, !canApply],
        ['Copy', '', () => { navigator.clipboard.writeText(state.rewrite); $('st').textContent = 'copied'; }, state.unchanged],
        ['Shorter', '', () => run('shorter')], ['More formal', '', () => run('formal')], ['Close', '', close]]);
    });
  }
  chrome.runtime.onMessage.addListener((msg) => {
    if (!msg || msg.type !== 'hh:open') return;
    target = grab(); mount();
    if (!target || !target.text.trim()) { $('bd').innerHTML = '<div class="err">Select some text, or click into a text box that has text, then try again.</div>'; footer([['Close', '', close]]); return; }
    run('sameTone');
  });
  document.addEventListener('keydown', (e) => { if (e.key === 'Escape' && host) close(); }, true);
})();
