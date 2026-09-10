import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:lamazon/data/season.dart';
import 'package:lamazon/screens/home_screen.dart';
import 'package:lamazon/widgets/design_system.dart';

/// A season re-skins the shop's chrome for a festival and leaves on its own.
///
/// The rule it has to keep is the one that makes it safe: it repaints the
/// service header and nothing below it. A shop that turns maroon everywhere
/// for Diwali is a shop nobody can read prices in.

const _ganesh = {
  'id': 'ganesh',
  'name': 'Ganesh Chaturthi',
  'startsAt': '2026-09-10T00:00:00Z',
  'endsAt': '2026-09-17T00:00:00Z',
  'ground': '#7A1F12',
  'accent': '#F2B441',
  'ink': '#FFF6E8',
  'hints': ['ganesh idol', 'modak & snacks', 'decorative lights'],
  'enabled': true,
  'active': true,
};

MockClient _api(Object? season) => MockClient((request) async {
  if (request.url.path == '/api/storefront/season') {
    return http.Response(jsonEncode({'season': season}), 200);
  }
  return http.Response(jsonEncode(const []), 200);
});

void main() {
  test('a season parses into colours the header can paint', () {
    final s = Season.fromJson(Map<String, dynamic>.from(_ganesh));
    expect(s.ground, const Color(0xFF7A1F12));
    expect(s.accent, const Color(0xFFF2B441));
    expect(s.ink, const Color(0xFFFFF6E8));
    expect(s.hints.first, 'ganesh idol');
  });

  test('a malformed palette falls back rather than painting nothing', () {
    // The server validates, but the app must not be one bad row away from a
    // blank header.
    final s = Season.fromJson({
      'id': 'x',
      'name': 'x',
      'ground': 'maroon',
      'accent': '',
      'ink': '#GGGGGG',
    });
    expect(s.ground, const Color(0xFF143E32), reason: 'the forest it always was');
    expect(s.accent, const Color(0xFFC6EE63));
    expect(s.ink, const Color(0xFFFFFDF8));
  });

  test('no season is the normal case, and is not an error', () async {
    await http.runWithClient(
      () async {
        await Seasons.instance.load();
        expect(Seasons.instance.current, isNull);
      },
      () => _api(null),
    );
  });

  test('a failed request leaves the shop in its own colours', () async {
    await http.runWithClient(
      () async {
        await Seasons.instance.load();
        expect(
          Seasons.instance.current,
          isNull,
          reason: 'a festival must never be why the shop will not open',
        );
      },
      () => MockClient((_) async => http.Response('nope', 500)),
    );
  });

  testWidgets('the header takes the season, and the catalogue below does not', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      await http.runWithClient(() async {
        await Seasons.instance.load();
        expect(Seasons.instance.current, isNotNull);

        await tester.pumpWidget(
          MaterialApp(theme: LamazonTheme.data, home: const HomeScreen()),
        );
        await tester.pump();

        // The service header is painted in the festival ground.
        final grounds = tester
            .widgetList<DecoratedBox>(find.byType(DecoratedBox))
            .map((d) => d.decoration)
            .whereType<BoxDecoration>()
            .expand((d) => (d.gradient as LinearGradient?)?.colors ?? const [])
            .toList();
        expect(
          grounds,
          contains(const Color(0xFF7A1F12)),
          reason: 'the header should be wearing the season',
        );

        // And the season sells through the search field.
        expect(find.textContaining('Search "'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
      }, () => _api(_ganesh));
    });
  });

  testWidgets('outside a season the search field says what it does', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      await http.runWithClient(() async {
        await Seasons.instance.load();
        await tester.pumpWidget(
          MaterialApp(theme: LamazonTheme.data, home: const HomeScreen()),
        );
        await tester.pump();

        expect(find.text('Search products, shops and more'), findsOneWidget);
        expect(find.textContaining('Search "'), findsNothing);

        await tester.pumpWidget(const SizedBox());
      }, () => _api(null));
    });
  });
}
