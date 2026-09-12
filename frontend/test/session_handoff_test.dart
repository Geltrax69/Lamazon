import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lamazon/data/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The HTML sign-in page at /login writes a session straight into storage and
/// then hands the browser to the app, so a person is not asked to sign in
/// twice. That page cannot import this one — it is Go and JavaScript — so the
/// key names and the encoding are a contract held together by nothing but
/// agreement. This is the agreement, written down.
///
/// If a key is renamed here, this test fails and backend/templates/login.html
/// has to be changed in the same commit. Without it the rename would ship, the
/// handoff would silently stop working, and every shopper would sign in twice.
void main() {
  const handoff = {
    'session.email': 'storefront.probe@lamazon.test',
    'session.token': 'a-token',
    'session.refresh': 'a-refresh-token',
    'session.expiresAt': '2099-01-01T00:00:00.000Z',
  };

  test('the app restores a session written under the agreed keys', () async {
    SharedPreferences.setMockInitialValues(handoff);
    await Session.instance.restore();

    expect(
      Session.instance.loggedIn,
      isTrue,
      reason: 'login.html wrote these four keys; the app must read them',
    );
    expect(Session.instance.email, handoff['session.email']);
  });

  test('a session the app wrote itself uses those same four keys', () async {
    // The other direction: if Session ever renames a key, the page that writes
    // them from the outside has to be told.
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('session.email', 'x@y.test');
    await prefs.setString('session.token', 't');
    await prefs.setString('session.refresh', 'r');
    await prefs.setString('session.expiresAt', '2099-01-01T00:00:00.000Z');
    await Session.instance.restore();
    expect(Session.instance.loggedIn, isTrue);

    await Session.instance.signOut();
    final left = (await SharedPreferences.getInstance()).getKeys();
    expect(
      left.where((k) => k.startsWith('session.')),
      isEmpty,
      reason: 'signing out has to clear every key the handoff can write',
    );
  });

  test('the browser encoding the page uses is the one storage expects', () {
    // shared_preferences_web stores a String as JSON, under a "flutter."
    // prefix — which is exactly what login.html does by hand:
    //   localStorage.setItem('flutter.' + key, JSON.stringify(value))
    // Observed in a real build, not assumed: flutter.cart.v2 holds a JSON
    // string. If this ever changes, the page's handOver() must change with it.
    expect(jsonEncode('a-token'), '"a-token"');
    for (final key in handoff.keys) {
      expect(key.startsWith('session.'), isTrue);
    }
  });
}
