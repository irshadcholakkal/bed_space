// Only release builds contain this manifest. Keep development free of caches.
if ('serviceWorker' in navigator && window.isSecureContext) {
  window.addEventListener('load', async () => {
    try {
      const manifest = await fetch(new URL('pwa-precache.json', document.baseURI), { cache: 'no-store' });
      if (!manifest.ok || !manifest.headers.get('content-type')?.includes('json')) return;
      await manifest.json();
      await navigator.serviceWorker.register(new URL('pwa-sw.js', document.baseURI), {
        scope: new URL('./', document.baseURI).href, updateViaCache: 'none' });
    } catch (error) {
      console.warn('Offline installation unavailable. The app can still run online.', error);
    }
  });
}
