// Service worker for web push. Separate from Flutter's own service worker,
// which handles caching and knows nothing about notifications.
//
// The payload arrives encrypted and is decrypted by the browser before this
// runs, so `data` is the JSON the backend sent.

self.addEventListener('push', (event) => {
  let payload = { title: 'Lamazon', body: '' };
  try {
    if (event.data) payload = event.data.json();
  } catch (_) {
    // A push with no body, or one this version does not understand, should
    // still surface something rather than nothing.
    payload.body = event.data ? event.data.text() : '';
  }

  event.waitUntil(
    self.registration.showNotification(payload.title, {
      body: payload.body,
      icon: '/icons/Icon-192.png',
      badge: '/icons/Icon-192.png',
      // Same tag replaces the previous notification instead of stacking a
      // dozen of them when several orders land together.
      tag: payload.tag || 'lamazon',
      data: { url: payload.url || '/' },
    }),
  );
});

// Tapping the notification should land in the app, reusing the tab that is
// already open rather than piling up new ones.
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const url = (event.notification.data && event.notification.data.url) || '/';
  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((tabs) => {
      for (const tab of tabs) {
        if ('focus' in tab) return tab.focus();
      }
      return self.clients.openWindow(url);
    }),
  );
});
