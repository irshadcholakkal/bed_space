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

// Capture the browser's install event before Flutter starts.
let bedspaceInstallPrompt = null;
window.addEventListener('beforeinstallprompt', (event) => {
  event.preventDefault();
  bedspaceInstallPrompt = event;
});
window.addEventListener('appinstalled', () => { bedspaceInstallPrompt = null; });
window.bedspaceIsInstalled = () => window.matchMedia('(display-mode: standalone)').matches || navigator.standalone === true;
window.bedspaceInstallApp = async () => {
  if (window.bedspaceIsInstalled()) return 'installed';
  if (bedspaceInstallPrompt) {
    const prompt = bedspaceInstallPrompt;
    bedspaceInstallPrompt = null;
    await prompt.prompt();
    return (await prompt.userChoice).outcome === 'accepted' ? 'accepted' : 'dismissed';
  }
  return /iPad|iPhone|iPod/.test(navigator.userAgent) ||
    (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1) ? 'manual_ios' : 'manual_browser';
};
