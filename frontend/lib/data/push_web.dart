import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';

import 'api.dart';

/// Browser notifications, on top of the email every seller gets anyway.
///
/// Reached through push.dart, which swaps in a do-nothing version off the
/// web, so nothing here has to guard for platform.
extension type _Nav(JSObject _) implements JSObject {
  external JSObject get serviceWorker;
}

@JS('navigator')
external _Nav get _navigator;

@JS('Notification.permission')
external String get _permission;

@JS('Notification.requestPermission')
external JSPromise<JSString> _requestPermission();

@JS('window.lamazonFirebaseMessagingToken')
external JSFunction? get _firebaseMessagingToken;

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
  ///
  /// [onDelivered] fires earlier, when the notification was drawn — proof the
  /// push arrived even if nobody taps the button.
  void onConfirmed(void Function() handler, {void Function()? onDelivered}) {
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
          if (data == null) return;
          final message = _stringify(data as JSObject);
          if (message.contains('push-confirmed')) {
            handler();
          } else if (message.contains('push-delivered')) {
            onDelivered?.call();
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
      if (key.isEmpty) {
        logApiFailure('push', 'FIREBASE_WEB_PUSH_PUBLIC_KEY is not configured');
        return false;
      }

      if (!granted) {
        final result = (await _requestPermission().toDart).toDart;
        if (result != 'granted') return false;
      }

      final token = await _fcmToken(key);
      if (token.isEmpty) {
        logApiFailure('push', 'Firebase Messaging did not return a token');
        return false;
      }

      await Api.instance.subscribeToPush({'token': token});
      return true;
    } catch (e) {
      logApiFailure('push subscribe', e);
      return false;
    }
  }
}

Future<String> _fcmToken(String vapidKey) async {
  final fn = _firebaseMessagingToken;
  if (fn == null) return '';
  final promise = fn.callAsFunction(
    globalContext,
    vapidKey.toJS,
  ) as JSPromise<JSString>?;
  if (promise == null) return '';
  return (await promise.toDart).toDart;
}

@JS('JSON.stringify')
external String _stringify(JSObject value);
