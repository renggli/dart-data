const CACHE_NAME = 'data-calculator-pwa-v2';
const IS_LOCALHOST =
  self.location.hostname === 'localhost' ||
  self.location.hostname === '127.0.0.1' ||
  self.location.hostname === '[::1]';

const ASSETS = [
  './',
  './index.html',
  './style.css',
  './index.dart.js',
  './worker.dart.js',
  './manifest.webmanifest',
  './icons/icon.svg',
  '../shared/style.css',
];

self.addEventListener('install', (event) => {
  if (!IS_LOCALHOST) {
    event.waitUntil(
      caches.open(CACHE_NAME).then((cache) => cache.addAll(ASSETS))
    );
  }
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) =>
        Promise.all(
          keys
            .filter((k) => IS_LOCALHOST || k !== CACHE_NAME)
            .map((k) => caches.delete(k))
        )
      )
      .then(() => {
        if (IS_LOCALHOST) {
          return self.registration.unregister();
        }
      })
  );
  self.clients.claim();
});

self.addEventListener('fetch', (event) => {
  if (IS_LOCALHOST || event.request.method !== 'GET') return;
  event.respondWith(
    fetch(event.request)
      .then((response) => {
        if (response && response.status === 200) {
          const clone = response.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put(event.request, clone));
        }
        return response;
      })
      .catch(() => caches.match(event.request))
  );
});
