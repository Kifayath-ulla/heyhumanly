/* Service worker: shortcut and context menu inject the panel into the active tab on demand; Ollama calls happen here. */
importScripts('core.js');

async function settings() {
  const s = await chrome.storage.local.get({ endpoint: HH.DEFAULTS.endpoint, model: '', goal: 'sameTone' });
  return s;
}

async function openPanel(tab) {
  if (!tab || !tab.id || /^(chrome|edge|about|chrome-extension):/.test(tab.url || '')) return;
  try {
    await chrome.scripting.executeScript({ target: { tabId: tab.id, allFrames: false }, files: ['ui.js', 'content.js'] });
    await chrome.tabs.sendMessage(tab.id, { type: 'hh:open' });
  } catch (e) { /* page does not allow scripts (store pages, PDF viewer); the popup still works */ }
}

chrome.commands.onCommand.addListener((cmd, tab) => { if (cmd === 'tighten') openPanel(tab); });
chrome.runtime.onInstalled.addListener(() => {
  chrome.contextMenus.create({ id: 'hh-tighten', title: 'Tighten with HeyHumanly', contexts: ['selection', 'editable'] });
});
chrome.contextMenus.onClicked.addListener((info, tab) => { if (info.menuItemId === 'hh-tighten') openPanel(tab); });

chrome.runtime.onMessage.addListener((msg, _sender, reply) => {
  if (msg && msg.type === 'hh:tighten') {
    settings().then((s) => HH.tighten(msg.text, Object.assign({}, s, msg.goal ? { goal: msg.goal } : {})))
      .then((result) => reply({ ok: true, result }))
      .catch((e) => reply({ ok: false, error: e.message, code: e.code || '', quick: HH.quickCheck(msg.text) }));
    return true;
  }
  if (msg && msg.type === 'hh:models') {
    settings().then((s) => HH.listModels(s.endpoint).then((models) => reply({ ok: true, models, current: s.model })))
      .catch((e) => reply({ ok: false, error: e.message }));
    return true;
  }
});
