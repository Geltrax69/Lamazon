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

  const options = {
    body: payload.body,
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    // Same tag replaces the previous notification instead of stacking a
    // dozen of them when several orders land together.
    tag: payload.tag || 'lamazon',
    data: { url: payload.url || '/', confirm: !!payload.confirm },
  };
  // The test notification carries a button, because the only real proof it
  // arrived is the person answering it.
  if (payload.confirm) {
    options.actions = [{ action: 'confirm', title: 'Yes, got it' }];
    options.requireInteraction = true; // do not vanish before it is answered
  }

  event.waitUntil(self.registration.showNotification(payload.title, options));
});

// Tapping the notification should land in the app, reusing the tab that is
// already open rather than piling up new ones. Tapping "Yes, got it" also
// tells that tab, so the screen can stop waiting and say it worked.
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const data = event.notification.data || {};
  const confirmed = event.action === 'confirm' || data.confirm;

  event.waitUntil(
    self.clients
      .matchAll({ type: 'window', includeUncontrolled: true })
      .then((tabs) => {
        for (const tab of tabs) {
          if (confirmed) tab.postMessage({ type: 'push-confirmed' });
          if ('focus' in tab) return tab.focus();
        }
        // No tab open: carry the answer in the URL instead of losing it.
        return self.clients.openWindow(
          confirmed ? '/?push=confirmed' : data.url || '/',
        );
      }),
  );
});
