// Replaced with a content-derived version by scripts/prepare_pwa.mjs.
const ROOT = new URL('./', self.location.href);
const CACHE_PREFIX = ROOT.pathname === '/' ? 'bed-space-' : 'bed-space-app-';
const CACHE = `${CACHE_PREFIX}__PWA_VERSION__`;
const SHELL = new URL('index.html', ROOT).href;
self.addEventListener('message', (event) => {
  if (event.data?.type === 'SKIP_WAITING') self.skipWaiting();
});

async function isAppShell(response) {
  return response?.ok &&
    response.headers.get('content-type')?.includes('text/html') &&
    (await response.clone().text()).includes('flutter_bootstrap.js');
}

function navigationShell(response) {
  // Cached index.html may have followed a host canonical redirect. Returning
  // that response directly to a manual-redirect navigation can cause ERR_FAILED.
  const headers = new Headers(response.headers);
  headers.delete('content-encoding');
  headers.delete('content-length');
  headers.set('Cache-Control', 'no-store');
  return new Response(response.body, { status: 200, headers });
}

self.addEventListener('install', (event) => {
  event.waitUntil((async () => {
    const response = await fetch(new URL('pwa-precache.json', ROOT), { cache: 'no-store' });
    if (!response.ok) throw new Error('Missing release precache manifest');
    const { version, files } = await response.json();
    if (CACHE !== `${CACHE_PREFIX}${version}`) throw new Error('Release changed during installation; retry later');
    // Download and validate everything before writing the new release cache.
    // SPA hosts can return HTML with status 200 for a missing JS/WASM asset.
    const entries = await Promise.all(files.map(async (file) => {
      const url = new URL(file, ROOT).href;
      const asset = await fetch(url, { cache: 'no-store' });
      if (!asset.ok ||
          (file === 'index.html' && !(await isAppShell(asset))) ||
          (!file.endsWith('.html') && asset.headers.get('content-type')?.includes('text/html'))) {
        throw new Error(`Invalid release asset: ${file}`);
      }
      return [url, asset];
    }));
    const cache = await caches.open(CACHE);
    await Promise.all(entries.map(([url, asset]) => cache.put(url, asset)));
    // Activate only after the complete new release has been cached successfully.
    await self.skipWaiting();
  })());
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const names = await caches.keys();
    await Promise.all(names.filter((name) => name.startsWith(CACHE_PREFIX) && name !== CACHE)
      .map((name) => caches.delete(name)));
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);
  // Cache only the public app files listed by the build, never Google API data.
  if (event.request.method !== 'GET' || url.origin !== ROOT.origin ||
      !url.pathname.startsWith(ROOT.pathname)) return;
  event.respondWith((async () => {
    if (event.request.mode === 'navigate') {
      try {
        const cache = await caches.open(CACHE);
        const cached = await cache.match(SHELL);
        if (await isAppShell(cached)) return navigationShell(cached);
      } catch (_) { /* Storage may be unavailable in private/restricted browsers. */ }
      // Keep the browser's callback URL intact, but fetch the root shell when
      // the local cache was evicted. Deep URLs need not exist on the host.
      try {
        const shell = await fetch(new URL('./', ROOT), { cache: 'no-store' });
        if (await isAppShell(shell)) return navigationShell(shell);
      } catch (_) { /* Offer a useful response when the device is offline. */ }
      return new Response('Bedspace is unavailable offline. Reconnect and reload to open your workspace.',
        { status: 503, headers: { 'Content-Type': 'text/plain; charset=utf-8', 'Cache-Control': 'no-store' } });
    }
    try {
      const cache = await caches.open(CACHE);
      const cached = await cache.match(event.request);
      if (cached) return cached;
    } catch (_) { /* A cache failure must not block online app assets. */ }
    return fetch(event.request);
  })());
});
