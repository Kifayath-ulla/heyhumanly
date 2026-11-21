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
