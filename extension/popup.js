const $ = (id) => document.getElementById(id);
const openSetup = () => chrome.runtime.sendMessage({ type: 'hh:setup' });
function run(goal) {
  const text = $('t').value.trim(); if (!text) { $('out').innerHTML = '<div class="err">Paste some text first.</div>'; return; }
  $('out').innerHTML = '<span class="sp"></span>Tightening on your computer…';
  ['go', 'shorter', 'formal'].forEach((id) => ($(id).disabled = true));
  chrome.runtime.sendMessage({ type: 'hh:tighten', text, goal }, (res) => {
    ['go', 'shorter', 'formal'].forEach((id) => ($(id).disabled = false));
    if (!res) { $('out').innerHTML = '<div class="err">The extension could not run. Reopen this popup.</div>'; return; }
    if (!res.ok) {
      $('out').innerHTML = '<div class="err">' + HHUI.E(res.error) + (res.setup ? ' <button class="p" data-setup>Open setup</button>' : '') + '</div>' + HHUI.quick(res.quick);
      const b = $('out').querySelector('[data-setup]'); if (b) b.onclick = openSetup;
      return;
    }
    $('status').textContent = res.result.model; $('out').innerHTML = HHUI.render(res.result);
  });
}
function showStatus(d) {
  let problem = '';
  if (!d || !d.ok || !d.running) problem = 'Ollama isn’t running, or isn’t installed yet.';
  else if (d.allowed === false) problem = 'Ollama is blocking this extension. One command fixes it.';
  else if (!d.writing.length) problem = 'Ollama has no writing model yet.';
  $('status').textContent = problem ? 'Not ready' : 'Ready · ' + (d.model && d.models.includes(d.model) ? d.model : 'auto model');
  $('setup').hidden = !problem; $('setup-msg').textContent = problem;
  if (d && d.ok) d.writing.forEach((m) => { const o = document.createElement('option'); o.value = m; o.textContent = m; $('model').appendChild(o); });
}
$('go').onclick = () => run('sameTone'); $('shorter').onclick = () => run('shorter'); $('formal').onclick = () => run('formal');
$('setup-go').onclick = openSetup;
chrome.storage.local.get({ endpoint: HH.DEFAULTS.endpoint, model: '' }, (s) => {
  $('endpoint').value = s.endpoint;
  chrome.runtime.sendMessage({ type: 'hh:diagnose' }, (d) => { showStatus(d); $('model').value = s.model || ''; });
});
$('save').onclick = () => {
  const endpoint = $('endpoint').value.trim() || HH.DEFAULTS.endpoint;
  if (!HH.isLocalEndpoint(endpoint)) { $('ep-msg').textContent = 'Use http://localhost:11434 or http://127.0.0.1:11434. The extension only talks to Ollama on this computer.'; return; }
  $('ep-msg').textContent = '';
  chrome.storage.local.set({ endpoint: endpoint.replace(/\/+$/, ''), model: $('model').value }, () => { $('save').textContent = 'Saved'; setTimeout(() => ($('save').textContent = 'Save'), 1200); });
};
