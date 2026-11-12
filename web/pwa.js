// Only release builds contain this manifest. Keep development free of caches.
if ('serviceWorker' in navigator && window.isSecureContext) {
  let updating = false;
  let controlled = Boolean(navigator.serviceWorker.controller);
  navigator.serviceWorker.addEventListener('controllerchange', () => {
    // Initial installation needs no reload. Updates replace the entire running
    // build so it cannot keep requesting assets from the previous release.
    if (controlled && !updating) {
      updating = true;
      window.location.reload();
    }
    controlled = true;
  });
  window.addEventListener('load', async () => {
    try {
      const manifest = await fetch(new URL('pwa-precache.json', document.baseURI), { cache: 'no-store' });
      if (!manifest.ok || !manifest.headers.get('content-type')?.includes('json')) return;
      await manifest.json();
      const registration = await navigator.serviceWorker.register(new URL('pwa-sw.js', document.baseURI), {
        scope: new URL('./', document.baseURI).href, updateViaCache: 'none' });
      const checkUpdate = () => registration.update().catch(() => {});
      await checkUpdate();
      window.addEventListener('online', checkUpdate);
      document.addEventListener('visibilitychange', () => {
        if (document.visibilityState === 'visible') checkUpdate();
      });
      window.setInterval(checkUpdate, 60000);
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

window.bedspaceForceUpdate = async () => {
  if (!navigator.onLine || !('serviceWorker' in navigator)) return 'failed';
  try {
    const registration = await navigator.serviceWorker.getRegistration(new URL('./', document.baseURI).href);
    if (!registration) { window.location.reload(); return 'updating'; }
    await registration.update();
    if (registration.waiting) {
      registration.waiting.postMessage({ type: 'SKIP_WAITING' });
      return 'updating';
    }
    if (registration.installing) return 'updating';
    window.location.reload();
    return 'updating';
  } catch (_) { return 'failed'; }
};
