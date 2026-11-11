// Run after npm run build --prefix landing.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';
import { gzipSync } from 'node:zlib';

test('Static landing contains the design and app links without loading Flutter', () => {
  const html = readFileSync(new URL('../landing/out/index.html', import.meta.url), 'utf8');
  for (const heading of ['Shared space management', 'A clearer view of every space',
    'Built around your working day', 'A simple plan for your spaces', 'Make yourself at home']) {
    assert.ok(html.includes(heading), heading);
  }
  assert.ok(html.includes('href="/app/?view=login"'));
  assert.ok(html.includes('href="/app/?view=signup'));
  assert.ok(html.includes('billing=annual'));
  assert.ok(html.includes('<details>'));
  assert.doesNotMatch(html, /flutter_bootstrap\.js|main\.dart\.js|canvaskit/);
  assert.doesNotMatch(html, /rel="(?:prefetch|preload)"[^>]+href="\/app\//);
});
test('Legacy worker retires only old app-file caches and preserves callback URLs', async () => {
  const events = {};
  const deleted = [];
  const navigated = [];
  let claimed = false, unregistered = false;
  runInNewContext(readFileSync(new URL('../landing/public/pwa-sw.js', import.meta.url), 'utf8'), {
    self: {
      addEventListener: (name, fn) => { events[name] = fn; },
      registration: { unregister: async () => { unregistered = true; } },
      clients: { claim: async () => { claimed = true; },
        matchAll: async () => [{ url: 'https://example.com/?code=private', navigate: async url => navigated.push(url) }] },
    },
    caches: {
      keys: async () => ['bed-space-old', 'bed-space-app-current', 'other-cache'],
      delete: async name => deleted.push(name),
    },
  });
  let pending;
  events.activate({ waitUntil: p => { pending = p; } });
  await pending;
  assert.deepEqual(deleted, ['bed-space-old']);
  assert.deepEqual(navigated, ['https://example.com/?code=private']);
  assert.equal(claimed && unregistered, true);
});
test('Landing stays within its JavaScript and hero image budgets', () => {
  const html = readFileSync(new URL('../landing/out/index.html', import.meta.url), 'utf8');
  const scripts = new Set([...html.matchAll(/<script[^>]+src="([^"]+)"/g)].map(match => match[1]));
  let javascriptBytes = 0;
  for (const script of scripts) {
    javascriptBytes += gzipSync(readFileSync(new URL('../landing/out' + script, import.meta.url))).length;
  }
  assert.ok(javascriptBytes < 256 * 1024, `Initial JS exceeded 256 KB gzip: ${javascriptBytes}`);
  assert.ok(readFileSync(new URL('../landing/out/media/landscape.webp', import.meta.url)).length < 100 * 1024);
  assert.ok(readFileSync(new URL('../landing/out/media/landscape-small.webp', import.meta.url)).length < 30 * 1024);
});
