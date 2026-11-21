const $ = (id) => document.getElementById(id);
let endpoint = HH.DEFAULTS.endpoint, pulling = false, timer = null;

function set(id, state, label) {
  const li = $(id); li.dataset.state = state; li.querySelector('.state').textContent = label;
  li.querySelector('.body').hidden = state !== 'bad';
}
function showOS(os) {
  const f = HH.originFix(os); $('os-steps').textContent = f.steps; $('os-cmd').textContent = f.command;
  document.querySelectorAll('[data-os]').forEach((b) => b.setAttribute('aria-pressed', String(b.dataset.os === os)));
}
async function check() {
  const d = await HH.diagnose(endpoint);
  let left = 3;
  if (!d.running) { set('c-run', 'bad', 'Not found'); set('c-allow', 'wait', 'Waiting for step 1'); set('c-model', 'wait', 'Waiting for step 1'); }
  else {
    set('c-run', 'ok', 'Running'); left--;
    if (d.allowed === false) { set('c-allow', 'bad', 'Blocked'); set('c-model', 'wait', 'Waiting for step 2'); }
    else if (d.allowed === null) { set('c-allow', 'wait', 'Checking again…'); set('c-model', 'wait', 'Waiting for step 2'); }
    else {
      set('c-allow', 'ok', 'Allowed'); left--;
      if (d.writing.length) { set('c-model', 'ok', d.writing.slice(0, 3).join(', ')); left--; }
      else if (!pulling) {
        set('c-model', 'bad', 'None yet');
        $('models-note').textContent = d.models.length ? 'Ollama only has ' + d.models.join(', ') + ', which can’t rewrite text.' : '';
      }
    }
  }
  $('done').hidden = left > 0;
  $('summary').textContent = left ? left + (left === 1 ? ' step' : ' steps') + ' left.' : 'Everything works.';
  clearTimeout(timer); if (left) timer = setTimeout(check, 3000);
}
async function pull(name) {
  pulling = true; document.querySelectorAll('[data-pull]').forEach((b) => (b.disabled = true));
  const bar = $('bar'); bar.hidden = false; bar.value = 0; $('pull').textContent = 'Starting the download of ' + name + '…';
  try {
    await HH.pullModel(endpoint, name, (j) => {
      if (j.total) { bar.value = j.completed / j.total || 0; $('pull').textContent = 'Downloading ' + name + ': ' + Math.floor((j.completed / j.total) * 100) + '% of ' + (j.total / 1e9).toFixed(1) + ' GB'; }
      else $('pull').textContent = j.status.charAt(0).toUpperCase() + j.status.slice(1) + '…';
    });
    $('pull').textContent = name + ' is installed.';
  } catch (e) {
    $('pull').textContent = e.code === 'blocked' ? 'Ollama blocked the download. Finish step 2 first.' : 'The download stopped: ' + e.message + '. Check your internet connection and try again, or use the terminal command below.';
  }
  bar.hidden = true; pulling = false; document.querySelectorAll('[data-pull]').forEach((b) => (b.disabled = false)); check();
}

document.querySelectorAll('[data-os]').forEach((b) => (b.onclick = () => showOS(b.dataset.os)));
document.querySelectorAll('[data-pull]').forEach((b) => (b.onclick = () => pull(b.dataset.pull)));
document.querySelectorAll('[data-copy]').forEach((b) => (b.onclick = async () => {
  try { await navigator.clipboard.writeText($(b.dataset.copy).textContent); b.textContent = 'Copied'; } catch (e) { b.textContent = 'Select and copy'; }
  setTimeout(() => (b.textContent = 'Copy'), 1500);
}));
$('origin').textContent = HH.extensionOrigin();
showOS(HH.platform());
chrome.commands.getAll((cmds) => { const c = cmds.find((x) => x.name === 'tighten'); $('key').textContent = (c && c.shortcut) || 'your shortcut (none is set: choose one at chrome://extensions/shortcuts)'; });
chrome.storage.local.get({ endpoint: HH.DEFAULTS.endpoint }, (s) => { endpoint = s.endpoint; $('ep').textContent = s.endpoint; check(); });

// Chrome's built-in model: no Ollama needed when Chrome can run it. Its one-time download must start from a click.
async function builtin() {
  const st = await HH.builtinStatus(), box = $('builtin');
  if (st === 'unsupported' || st === 'unavailable') { box.hidden = true; return; }
  box.hidden = false;
  if (st === 'available') { $('b-note').textContent = 'Ready. HeyHumanly uses it automatically, so you can skip the Ollama steps below.'; $('b-get').hidden = true; $('done').hidden = false; return; }
  $('b-note').textContent = st === 'downloading' ? 'Chrome is downloading its model…' : 'This computer can run Chrome’s own model, so you can skip Ollama. Chrome downloads it once (a few GB, needs 22 GB free disk space).';
  $('b-get').hidden = st === 'downloading';
}
$('b-get').addEventListener('click', async () => {
  $('b-get').disabled = true; $('b-bar').hidden = false;
  try { const s = await HH.builtinSession((f) => { $('b-bar').value = f; }); s.destroy(); }
  catch (e) { $('b-note').textContent = 'Chrome couldn’t download its model (' + (e.message || e) + '). You can use Ollama below instead.'; }
  $('b-get').disabled = false; $('b-bar').hidden = true; builtin();
});
builtin();
