const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '..');
const read = p => fs.readFileSync(path.join(root, p), 'utf8').replace(/\r\n/g, '\n');
function harness(status = 200, hasSession = true) {
  class Store { constructor() { this.values = new Map(); } getItem(k) { return this.values.get(k) ?? null; } setItem(k,v) { this.values.set(k,String(v)); } removeItem(k) { this.values.delete(k); } }
  const localStorage = new Store(); localStorage.setItem('hop_manager_token', 'old-web-token');
  const calls = []; const listeners = {};
  const window = { __HOP_NATIVE_SESSION__: hasSession, webkit: { messageHandlers: { hopNative: { postMessage: async body => {
    calls.push(body); return { status, contentType: 'application/json', body: Buffer.from(JSON.stringify({ ok: status === 200 })).toString('base64') };
  } } } }, fetch: async () => { throw Error('Unexpected network fallback'); }, addEventListener() {} };
  const context = { window, Storage: Store, localStorage, URL, Request, Response, Uint8Array, atob, DOMException, setTimeout, location: { href:'file:///App/Web/index.html' }, document: { addEventListener(name, fn) { listeners[name] = fn; }, getElementById() { return null; } } };
  vm.runInNewContext(read('Bridge/native.js'), context);
  return { window, localStorage, calls, listeners };
}
test('Native session marker replaces persistent bearer without copying real token', () => {
  const { localStorage } = harness();
  assert.equal(localStorage.getItem('hop_manager_token'), 'native-session');
  assert.equal(localStorage.values.has('hop_manager_token'), false);
  localStorage.setItem('hop_manager_token', 'native-session');
  assert.equal(localStorage.values.has('hop_manager_token'), false);
  assert.equal(localStorage.getItem('hop_command_api_base'), 'https://www.houseofpizzagaffney.com');
});
test('API forwarding preserves method/body; never forwards JS Authorization headers', async () => {
  const { window, calls } = harness();
  const response = await window.fetch('https://www.houseofpizzagaffney.com/api/invoices/example', { method:'PUT', body:'{"note":"test"}', headers:{Authorization:'Bearer not-native'} });
  assert.equal(response.status, 200);
  assert.equal(calls.length, 1); assert.equal(calls[0].method, 'PUT'); assert.equal(calls[0].body, '{"note":"test"}');
  assert.equal(calls[0].headers, undefined);
});
test('401 clears session and preserves authentication error', async () => {
  const { window, localStorage } = harness(401);
  const response = await window.fetch('https://www.houseofpizzagaffney.com/api/employees');
  assert.equal(response.ok, false); assert.equal(response.status,401);
  assert.equal(localStorage.getItem('hop_manager_token'), null);
});
test('409 remains a conflict and mutations are not retried', async () => {
  const { window,calls } = harness(409);
  const response = await window.fetch('https://www.houseofpizzagaffney.com/api/schedules/draft/example/entries', {method:'PUT',body:'{}'});
  assert.equal(response.status,409); assert.equal(calls.length,1);
});
test('Foreign hosts and non API paths cannot use native authenticated transport', async () => {
  const { window,calls } = harness();
  for (const url of ['https://evil.test/api/employees','https://www.houseofpizzagaffney.com/employee/','http://www.houseofpizzagaffney.com/api/employees']) await assert.rejects(window.fetch(url));
  assert.equal(calls.length,0);
});
test('Logout calls native token deletion without persisting a marker', () => {
  const { localStorage,calls } = harness(); localStorage.removeItem('hop_manager_token');
  assert.equal(calls[0].action,'logout'); assert.equal(localStorage.getItem('hop_manager_token'),null);
});
test('No default manager authentication is invented on a new installation', () => {
  assert.equal(harness(200,false).localStorage.getItem('hop_manager_token'),null);
});
test('Desktop JavaScript, print templates, styles, and public assets are an exact snapshot', () => {
  const manifest = JSON.parse(read('Web/source-manifest.json'));
  for (const file of manifest.files) {
    if (file.file === 'index.html') continue;
    const raw = fs.readFileSync(path.join(root,'Web',file.file));
    const data = file.file.endsWith('.png') ? raw : Buffer.from(raw.toString().replace(/\r\n/g,'\n'));
    assert.equal(crypto.createHash('sha256').update(data).digest('hex'),file.sha256,file.file);
  }
  for (const name of ['native.js','ipad.css','ipad-print.css']) assert.equal(read('Web/'+name),read('Bridge/'+name));
});
test('Shell uses iPad target and distinct identity, has no APNs entitlement or simulator step', () => {
  const project = read('HOPCommand.xcodeproj/project.pbxproj');
  assert.match(project,/TARGETED_DEVICE_FAMILY = 2/); assert.match(project,/com.houseofpizza.commandcenter.ipad/);
  assert.doesNotMatch(project,/aps-environment|HOPEmployee/);
  assert.match(read('docs/macos-build-workflow.yml'),/branches: \[hop-command-ipad\]/);
  assert.doesNotMatch(read('scripts/build-ipa.sh'),/simctl|platform=iOS Simulator/);
});
test('Only trusted local frame can access bridge and native token rejects redirects', () => {
  const native = read('Sources/CommandViewController.swift');
  assert.match(native,/message.frameInfo.isMainFrame/); assert.match(native,/CommandPolicy.isBundledPage/);
  assert.match(native,/completionHandler\(nil\)/); assert.match(native,/manager.save\(token\)/);
  assert.match(native,/payload\["access_token"\] = "native-session"/);
  assert.match(read('Sources/ManagerSession.swift'),/kSecAttrAccessibleWhenUnlockedThisDeviceOnly/);
});
test('Portrait documents and landscape wallboards use same PDF for print and share', () => {
  const script = read('Bridge/native.js');
  assert.match(script,/selector: "\.main-site-invoice", landscape: false/);
  assert.match(script,/selector: "\.application-paper", landscape: false/);
  assert.match(script,/selector: "\.task-wallboard-export", landscape: true/);
  assert.match(script,/kind: "Wallboard"/);
  assert.match(read('Sources/CommandViewController.swift'),/printer.printingItem = data/);
  assert.match(read('Sources/DocumentExporter.swift'),/renderer.numberOfPages/);
  assert.match(script,/clone.querySelectorAll\("script,iframe,object,embed,form,input,button"\)/);
});
