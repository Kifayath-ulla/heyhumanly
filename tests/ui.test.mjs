import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const HH = require('../extension/core.js'), UI = require('../extension/ui.js');

test('E escapes HTML', () => {
  assert.equal(UI.E('<img src=x onerror=1>"&'), '&lt;img src=x onerror=1&gt;&quot;&amp;');
});

test('render never injects HTML from the text or the model output', () => {
  const evil = '<img src=x onerror=alert(1)>';
  const state = HH.analyse('So basically ' + evil + ' in order to win.', evil + ' to win.', false, '<b>model</b>');
  const html = UI.render(state);
  assert.ok(!html.includes('<img'), html);
  assert.ok(html.includes('&lt;img'));
});

test('quick renders the no-model checks safely', () => {
  const html = UI.quick(HH.quickCheck('So basically <script>x</script> in order to go.'));
  assert.ok(!html.includes('<script>'));
});

test('wordDiff marks removed and added words and keeps the rest', () => {
  const d = UI.wordDiff('I has a dog', 'I have a dog');
  assert.deepEqual(d.filter((x) => x.t !== 'same').map((x) => x.t + ':' + x.s), ['del:has', 'add:have']);
  assert.equal(d.filter((x) => x.t !== 'del').map((x) => x.s).join(''), 'I have a dog');
});

test('diffHTML escapes text from the page and the model', () => {
  const html = UI.diffHTML('<img src=x onerror=1> hi', '<img src=x onerror=2> hi');
  assert.ok(!html.includes('<img'), html);
  assert.ok(html.includes('<del>') && html.includes('<ins>'));
});

test('the five styles match the Mac quick panel and every goal has a prompt', () => {
  assert.deepEqual(HH.STYLE_LIST.map((s) => s.title), ['Fix only', 'Polish', 'Shorter', 'Friendly', 'Professional']);
  for (const s of HH.STYLE_LIST) assert.ok(HH.promptFor('hello there', s.goal, false).includes('hello there'));
  assert.equal(HH.promptFor('x', 'polish', false), HH.buildStylePrompt('x', 'polish'));
  assert.equal(HH.promptFor('x', 'formal', false), HH.buildPrompt('x', 'formal', false));
});
