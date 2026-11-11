// Retirement worker for installations that previously cached Flutter at /.
// The management app now has an independent worker scoped to /app/.
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', event => event.waitUntil((async () => {
  await Promise.all((await caches.keys())
    .filter(name => name.startsWith('bed-space-') && !name.startsWith('bed-space-app-'))
    .map(name => caches.delete(name)));
  await self.clients.claim();
  await self.registration.unregister();
  const clients = await self.clients.matchAll({ type: 'window' });
  await Promise.all(clients.map(client => client.navigate(client.url)));
})()));
