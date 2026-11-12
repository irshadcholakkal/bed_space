import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';
function app({ standalone = false, ios = false } = {}) {
  const events = {};
  const window = { matchMedia: () => ({ matches: standalone }),
    addEventListener: (name, handler) => { events[name] = handler; } };
  const navigator = { userAgent: ios ? 'iPhone' : 'Chrome', platform: '', maxTouchPoints: 0 };
  runInNewContext(readFileSync(new URL('../web/pwa.js', import.meta.url), 'utf8'), { window, navigator });
  return { window, events };
}
test('Settings install action triggers and consumes the captured install prompt', async () => {
  const { window, events } = app();
  let prompted = 0, prevented = 0;
  events.beforeinstallprompt({ preventDefault() { prevented++; },
    async prompt() { prompted++; }, userChoice: Promise.resolve({ outcome: 'accepted' }) });
  assert.equal(await window.bedspaceInstallApp(), 'accepted');
  assert.equal(prompted, 1);
  assert.equal(prevented, 1);
  assert.equal(await window.bedspaceInstallApp(), 'manual_browser');
});
test('Installed apps and Safari have appropriate install outcomes', async () => {
  assert.equal(await app({ standalone: true }).window.bedspaceInstallApp(), 'installed');
  assert.equal(await app({ ios: true }).window.bedspaceInstallApp(), 'manual_ios');
});
test('Dismissing installation does not mark the app installed', async () => {
  const { window, events } = app();
  events.beforeinstallprompt({ preventDefault() {}, async prompt() {}, userChoice: Promise.resolve({ outcome: 'dismissed' }) });
  assert.equal(await window.bedspaceInstallApp(), 'dismissed');
  assert.equal(window.bedspaceIsInstalled(), false);
});

test('New controller reloads an existing app once, but not first installation', async () => {
  for (const initialController of [null, {}]) {
    const handlers = {};
    let reloads = 0;
    const serviceWorker = { controller: initialController,
      addEventListener(name, callback) { handlers[name] = callback; } };
    const window = { isSecureContext: true,
      addEventListener() {}, location: { reload() { reloads++; } } };
    runInNewContext(readFileSync(new URL('../web/pwa.js', import.meta.url), 'utf8'), {
      window, navigator: { serviceWorker },
    });
    handlers.controllerchange();
    assert.equal(reloads, initialController ? 1 : 0);
    handlers.controllerchange();
    handlers.controllerchange();
    assert.equal(reloads, 1);
  }
});

test('Force update checks the service worker without clearing offline data', async () => {
  let checked = 0, reloaded = 0;
  const window = { addEventListener() {}, location: { reload() { reloaded++; } } };
  const navigator = { onLine: true, serviceWorker: {
    addEventListener() {}, async getRegistration() { return { async update() { checked++; } }; }
  } };
  runInNewContext(readFileSync(new URL('../web/pwa.js', import.meta.url), 'utf8'), {
    window, navigator, URL, document: { baseURI: 'https://example.com/app/' },
  });
  assert.equal(await window.bedspaceForceUpdate(), 'updating');
  assert.equal(checked, 1);
  assert.equal(reloaded, 1);
  navigator.onLine = false;
  assert.equal(await window.bedspaceForceUpdate(), 'failed');
  assert.equal(reloaded, 1);
});
