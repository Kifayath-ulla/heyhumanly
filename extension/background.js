/* Service worker: shortcut and context menu inject the panel into the active tab on demand; Ollama calls happen here. */
importScripts('core.js');

const SETUP_CODES = ['offline', 'blocked', 'nomodel'];

async function settings() {
  const s = await chrome.storage.local.get({ endpoint: HH.DEFAULTS.endpoint, model: '', goal: 'sameTone' });
  return s;
}

function openSetup() { return chrome.tabs.create({ url: chrome.runtime.getURL('setup.html') }); }

/** Pages like chrome:// and the Web Store block extensions; say so on the toolbar button instead of failing silently. */
function cantRunHere(tab) {
  chrome.action.setBadgeBackgroundColor({ tabId: tab.id, color: '#956400' });
  chrome.action.setBadgeText({ tabId: tab.id, text: '!' });
  chrome.action.setTitle({ tabId: tab.id, title: 'HeyHumanly can’t run on this page. Click here and paste your text instead.' });
}

async function openPanel(tab) {
  if (!tab || !tab.id) return;
  if (/^(chrome|edge|about|chrome-extension|devtools|view-source):/.test(tab.url || '')) return cantRunHere(tab);
  try {
    await chrome.scripting.executeScript({ target: { tabId: tab.id, allFrames: false }, files: ['ui.js', 'content.js'] });
    await chrome.tabs.sendMessage(tab.id, { type: 'hh:open' });
  } catch (e) { cantRunHere(tab); }
}

chrome.commands.onCommand.addListener((cmd, tab) => { if (cmd === 'tighten') openPanel(tab); });
chrome.runtime.onInstalled.addListener((details) => {
  chrome.contextMenus.create({ id: 'hh-tighten', title: 'Tighten with HeyHumanly', contexts: ['selection', 'editable'] });
  if (details.reason === 'install') openSetup();
});
chrome.contextMenus.onClicked.addListener((info, tab) => { if (info.menuItemId === 'hh-tighten') openPanel(tab); });

chrome.runtime.onMessage.addListener((msg, _sender, reply) => {
  if (msg && msg.type === 'hh:tighten') {
    settings().then((s) => HH.tighten(msg.text, Object.assign({}, s, msg.goal ? { goal: msg.goal } : {})))
      .then((result) => reply({ ok: true, result }))
      .catch((e) => reply({ ok: false, error: e.message, code: e.code || '', setup: SETUP_CODES.includes(e.code), quick: HH.quickCheck(msg.text.slice(0, HH.MAX_CHARS)) }));
    return true;
  }
  if (msg && msg.type === 'hh:diagnose') {
    settings().then((s) => HH.diagnose(s.endpoint).then((d) => reply(Object.assign({ ok: true, model: s.model }, d))))
      .catch((e) => reply({ ok: false, error: e.message }));
    return true;
  }
  if (msg && msg.type === 'hh:setup') { openSetup(); return false; }
});
