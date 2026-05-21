// build: 2026-05-21T19:22:41Z-e12ee08bb2562a1cf35d9bd0c668f3fd1a92cdc7
'use strict';

self.addEventListener('install', () => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      try {
        await self.registration.unregister();
      } catch (e) {
        console.warn('Failed to unregister the service worker:', e);
      }

      try {
        const clients = await self.clients.matchAll({
          type: 'window',
        });
        // Reload clients to ensure they are not using the old service worker.
        clients.forEach((client) => {
          if (client.url && 'navigate' in client) {
            client.navigate(client.url);
          }
        });
      } catch (e) {
        console.warn('Failed to navigate some service worker clients:', e);
      }
    })()
  );
});
