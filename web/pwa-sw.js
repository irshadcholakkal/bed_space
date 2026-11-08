// Replaced with a content-derived version by scripts/prepare_pwa.mjs.
const CACHE = 'bed-space-__PWA_VERSION__';
const ROOT = new URL('./', self.location.href);

self.addEventListener('install', (event) => {
  event.waitUntil((async () => {
    const response = await fetch(new URL('pwa-precache.json', ROOT), { cache: 'no-store' });
    if (!response.ok) throw new Error('Missing release precache manifest');
    const { files } = await response.json();
    const cache = await caches.open(CACHE);
    await cache.addAll(files.map((file) => new URL(file, ROOT).href));
    // Updates activate after all existing app windows close, avoiding mixed builds.
  })());
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const names = await caches.keys();
    await Promise.all(names.filter((name) => name.startsWith('bed-space-') && name !== CACHE)
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
    const cache = await caches.open(CACHE);
    if (event.request.mode === 'navigate') {
      return (await cache.match(new URL('index.html', ROOT).href)) || fetch(event.request);
    }
    return (await cache.match(event.request)) || fetch(event.request);
  })());
});
