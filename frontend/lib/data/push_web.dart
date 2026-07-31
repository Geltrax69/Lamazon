import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';

import 'api.dart';

/// Browser notifications, on top of the email every seller gets anyway.
///
/// ponytail: the Push API directly through js_interop — no Firebase project,
/// no extra packages. FCM for the web wraps this same protocol.
///
/// Reached through push.dart, which swaps in a do-nothing version off the
/// web, so nothing here has to guard for platform.
extension type _Nav(JSObject _) implements JSObject {
  external JSObject get serviceWorker;
}

extension type _Registration(JSObject _) implements JSObject {
  external JSObject get pushManager;
}

@JS('navigator')
external _Nav get _navigator;

@JS('Notification.permission')
external String get _permission;

@JS('Notification.requestPermission')
external JSPromise<JSString> _requestPermission();

@JS('window.isSecureContext')
external bool get _isSecureContext;

@JS('window.location.search')
external String get _searchRaw;

String _search() {
  try {
    return _searchRaw;
  } catch (_) {
    return '';
  }
}

class Push {
  Push._();
  static final Push instance = Push._();

  /// Whether this browser can do notifications at all. False on iOS Safari
  /// until the site is installed to the Home Screen, and false everywhere
  /// that is not the web.
  bool get supported {
    if (!kIsWeb) return false;
    try {
      return _isSecureContext && _navigator.has('serviceWorker');
    } catch (_) {
      return false;
    }
  }

  bool get denied => supported && _permission == 'denied';
  bool get granted => supported && _permission == 'granted';

  /// Fires when the service worker reports the test notification was
  /// answered, or when the app was opened from it (?push=confirmed).
  void onConfirmed(void Function() handler) {
    if (!supported) return;
    try {
      if (_search().contains('push=confirmed')) {
        handler();
        return;
      }
      _navigator.serviceWorker.callMethod(
        'addEventListener'.toJS,
        'message'.toJS,
        ((JSObject event) {
          final data = event.getProperty('data'.toJS);
          if (data != null && _stringify(data as JSObject).contains('push-confirmed')) {
            handler();
          }
        }).toJS,
      );
    } catch (e) {
      logApiFailure('push confirm listener', e);
    }
  }

  /// Asks the backend to send this browser a test notification.
  Future<bool> sendTest() async {
    try {
      await Api.instance.sendTestPush();
      return true;
    } catch (e) {
      logApiFailure('test push', e);
      return false;
    }
  }

  /// Asks for permission and registers this browser with the backend.
  ///
  /// Call it from somewhere the reason is obvious — the seller dashboard —
  /// never on app start, which browsers penalise and users reflexively deny.
  /// Returns false when it did not end up subscribed, for any reason.
  Future<bool> enable() async {
    if (!supported || denied) return false;
    try {
      final key = await Api.instance.pushPublicKey();
      if (key.isEmpty) return false;

      if (!granted) {
        final result = (await _requestPermission().toDart).toDart;
        if (result != 'granted') return false;
      }

      final registration = _Registration(
        (await _register('/push-sw.js').toDart) as JSObject,
      );
      final sub = await _subscribe(
        registration.pushManager,
        _urlBase64ToBytes(key),
      ).toDart;

      // The browser hands back endpoint + keys as a plain object; its own
      // toJSON is the shape the backend expects.
      final json = jsonDecode(_stringify(_toJSON(sub as JSObject))) as Map<String, dynamic>;
      await Api.instance.subscribeToPush(json);
      return true;
    } catch (e) {
      logApiFailure('push subscribe', e);
      return false;
    }
  }
}

@JS('navigator.serviceWorker.register')
external JSPromise _register(String url);

@JS('JSON.stringify')
external String _stringify(JSObject value);

/// `subscription.toJSON()` — reached through a helper because js_interop
/// cannot call an instance method on an opaque object directly.
JSObject _toJSON(JSObject sub) =>
    (sub.callMethod('toJSON'.toJS) as JSObject?) ?? sub;

JSPromise _subscribe(JSObject manager, JSUint8Array key) =>
    manager.callMethod(
      'subscribe'.toJS,
      {'userVisibleOnly': true, 'applicationServerKey': key}.jsify(),
    ) as JSPromise;

/// VAPID keys travel as url-safe base64; the Push API wants raw bytes.
JSUint8Array _urlBase64ToBytes(String value) {
  final padded = value.padRight((value.length + 3) & ~3, '=');
  return base64Url.decode(padded).toJS;
}
