// RemoteFlow Max - PWA Service Worker
const CACHE_NAME = 'remoteflow-pwa-v1';

self.addEventListener('install', (event) => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(self.clients.claim());
});

self.addEventListener('fetch', (event) => {
  // Let network handle dynamic API and WebSocket requests directly
  if (event.request.url.includes('/api/') || event.request.url.includes(':5056')) {
    return;
  }
  event.respondWith(
    fetch(event.request).catch(() => caches.match(event.request))
  );
});
