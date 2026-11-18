const $ = (id) => document.getElementById(id);
function run(goal) {
  const text = $('t').value.trim(); if (!text) { $('out').innerHTML = '<div class="err">Paste some text first.</div>'; return; }
  $('out').innerHTML = '<span class="sp"></span>Tightening on your computer…';
  ['go', 'shorter', 'formal'].forEach((id) => ($(id).disabled = true));
  chrome.runtime.sendMessage({ type: 'hh:tighten', text, goal }, (res) => {
    ['go', 'shorter', 'formal'].forEach((id) => ($(id).disabled = false));
    if (!res) { $('out').innerHTML = '<div class="err">The extension could not run. Reopen this popup.</div>'; return; }
    if (!res.ok) { $('out').innerHTML = '<div class="err">' + HHUI.E(res.error) + '</div>' + HHUI.quick(res.quick); return; }
    $('status').textContent = res.result.model; $('out').innerHTML = HHUI.render(res.result);
  });
}
$('go').onclick = () => run('sameTone'); $('shorter').onclick = () => run('shorter'); $('formal').onclick = () => run('formal');
chrome.storage.local.get({ endpoint: HH.DEFAULTS.endpoint, model: '' }, (s) => {
  $('endpoint').value = s.endpoint;
  chrome.runtime.sendMessage({ type: 'hh:models' }, (res) => {
    if (res && res.ok) { res.models.forEach((m) => { const o = document.createElement('option'); o.value = m; o.textContent = m; $('model').appendChild(o); }); $('model').value = s.model || ''; $('status').textContent = 'Ollama connected'; }
    else $('status').textContent = 'Ollama not reachable';
  });
});
$('save').onclick = () => chrome.storage.local.set({ endpoint: $('endpoint').value.trim() || HH.DEFAULTS.endpoint, model: $('model').value }, () => { $('save').textContent = 'Saved'; setTimeout(() => ($('save').textContent = 'Save'), 1200); });
