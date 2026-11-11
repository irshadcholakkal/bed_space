import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';

const shell = () => new Response('<html><script src="flutter_bootstrap.js"></script></html>',
  { headers: { 'Content-Type': 'text/html' } });
function worker(fetcher, cached) {
  const events = {};
  const stored = new Map(cached ? [['https://example.com/index.html', cached]] : []);
  const cache = { match: async (url) => stored.get(url), put: async (url, value) => stored.set(url, value) };
  runInNewContext(readFileSync(new URL('../web/pwa-sw.js', import.meta.url), 'utf8')
    .replace('__PWA_VERSION__', 'test'), {
    self: { location: { href: 'https://example.com/pwa-sw.js' },
      addEventListener: (name, callback) => { events[name] = callback; } },
    URL, Response, fetch: fetcher, caches: { open: async () => cache },
  });
  return {
    stored,
    install() { let result; events.install({ waitUntil: (p) => { result = p; } }); return result; },
    navigate(url = 'https://example.com/auth/callback?code=example') {
      let result;
      events.fetch({ request: { url, method: 'GET', mode: 'navigate' },
        respondWith: (p) => { result = p; } });
      return result;
    },
  };
}

test('Navigation uses the cached release shell without a network request', async () => {
  const w = worker(() => { throw new Error('Unexpected network'); }, shell());
  assert.equal((await w.navigate()).status, 200);
});
test('Evicted cache fetches the root shell instead of a missing callback route', async () => {
  const requested = [];
  const w = worker(async (url) => { requested.push(String(url)); return shell(); });
  assert.equal((await w.navigate()).status, 200);
  assert.deepEqual(requested, ['https://example.com/']);
});
test('Cached error page is ignored and recovered online', async () => {
  const w = worker(async () => shell(), new Response('Not Found', { status: 404 }));
  assert.equal((await w.navigate()).status, 200);
});
test('Offline cache loss returns a helpful uncached response', async () => {
  const w = worker(async () => { throw new Error('offline'); });
  const response = await w.navigate();
  assert.equal(response.status, 503);
  assert.match(await response.text(), /Reconnect and reload/);
  assert.equal(response.headers.get('cache-control'), 'no-store');
});
test('A deployment race cannot install another release manifest', async () => {
  const w = worker(async () => Response.json({ version: 'other', files: [] }));
  await assert.rejects(w.install(), /Release changed/);
  assert.equal(w.stored.size, 0);
});
test('A missing JS asset served as HTML cannot poison the release cache', async () => {
  const w = worker(async (url) => String(url).endsWith('pwa-precache.json')
    ? Response.json({ version: 'test', files: ['index.html', 'main.dart.js'] }) : shell());
  await assert.rejects(w.install(), /Invalid release asset: main.dart.js/);
  assert.equal(w.stored.size, 0);
});
test('A complete valid release is cached', async () => {
  const w = worker(async (url) => String(url).endsWith('pwa-precache.json')
    ? Response.json({ version: 'test', files: ['index.html', 'main.dart.js'] })
    : String(url).endsWith('index.html') ? shell()
    : new Response('app()', { headers: { 'Content-Type': 'text/javascript' } }));
  await w.install();
  assert.equal(w.stored.size, 2);
});
