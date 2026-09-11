import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:lamazon/data/season.dart';
import 'package:lamazon/screens/home_screen.dart';
import 'package:lamazon/widgets/campaign_palette.dart';
import 'package:lamazon/widgets/design_system.dart';

/// A season re-skins the shop's chrome for a festival and leaves on its own.
///
/// It has to dress the whole of the chrome — header, hero, department tiles,
/// navigation bar — because repainting only the header produced a navy header
/// bolted to a forest-green page, which reads as a rendering fault rather than
/// as a theme.
///
/// And it has to stop there. A shop that turns maroon everywhere for Diwali is
/// a shop nobody can read prices in, so product cards, prices and stock
/// colours stay in the app's own palette whatever the festival is.

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

/// A second palette with nothing in common with the first, so a propagation
/// test cannot pass by coincidence.
const _navy = {
  'id': 'navy',
  'name': 'Republic Day',
  'startsAt': '2026-09-10T00:00:00Z',
  'endsAt': '2026-09-17T00:00:00Z',
  'ground': '#10204A',
  'accent': '#8FB8FF',
  'ink': '#F2F6FF',
  'hints': ['flags', 'sweets'],
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
    expect(
      s.ground,
      const Color(0xFF143E32),
      reason: 'the forest it always was',
    );
    expect(s.accent, const Color(0xFFC6EE63));
    expect(s.ink, const Color(0xFFFFFDF8));
  });

  test('no season is the normal case, and is not an error', () async {
    await http.runWithClient(() async {
      await Seasons.instance.load();
      expect(Seasons.instance.current, isNull);
    }, () => _api(null));
  });

  test('a failed request leaves the shop in its own colours', () async {
    await http.runWithClient(() async {
      await Seasons.instance.load();
      expect(
        Seasons.instance.current,
        isNull,
        reason: 'a festival must never be why the shop will not open',
      );
    }, () => MockClient((_) async => http.Response('nope', 500)));
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

  /// Two palettes that share nothing, so the assertions cannot be passing on
  /// a colour that happens to match the app's own.
  for (final (label, season, ground, accent) in [
    ('marigold', _ganesh, const Color(0xFF7A1F12), const Color(0xFFF2B441)),
    ('navy', _navy, const Color(0xFF10204A), const Color(0xFF8FB8FF)),
  ]) {
    testWidgets('a $label season dresses the whole of the chrome', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await http.runWithClient(() async {
          await Seasons.instance.load();
          await tester.pumpWidget(
            MaterialApp(theme: LamazonTheme.data, home: const HomeScreen()),
          );
          for (var i = 0; i < 8; i++) {
            await tester.pump(const Duration(milliseconds: 300));
          }

          // Every ground painted on the page, gradient stops included.
          final painted = <Color>{
            for (final d in tester.widgetList<DecoratedBox>(
              find.byType(DecoratedBox),
            ))
              if (d.decoration case final BoxDecoration box) ...[
                if (box.color != null) box.color!,
                ...?(box.gradient as LinearGradient?)?.colors,
              ],
            for (final c in tester.widgetList<AnimatedContainer>(
              find.byType(AnimatedContainer),
            ))
              if (c.decoration case final BoxDecoration box)
                if (box.color != null) box.color!,
            for (final m in tester.widgetList<Material>(find.byType(Material)))
              if (m.color != null) m.color!,
          };
          expect(
            painted,
            contains(ground),
            reason: 'the header and the hero wear the season ground',
          );
          expect(
            painted,
            contains(accent),
            reason: 'the selected department tile wears the season accent',
          );
          expect(
            tester
                .widgetList<NavigationBar>(find.byType(NavigationBar))
                .map((n) => n.indicatorColor)
                .whereType<Color>()
                .map((c) => c.withAlpha(255)),
            contains(accent),
            reason: 'so does the bar floating over it',
          );

          // And the shop below the chrome does not move: a price is still a
          // price, and in stock is still green.
          expect(
            tester
                .widgetList<Text>(find.byType(Text))
                .map((t) => t.style?.color)
                .whereType<Color>(),
            isNot(contains(accent)),
            reason: 'no catalogue text is repainted by a festival',
          );
          await tester.pumpWidget(const SizedBox());
        }, () => _api(season));
      });
    });
  }

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

  testWidgets('a banner with no colour of its own follows the season', (
    tester,
  ) async {
    await http.runWithClient(() async {
      await Seasons.instance.load();
      expect(Seasons.instance.current, isNotNull);

      // The live campaign on this shop stores #F2E8CE, a legacy pastel that
      // has always been translated to the app's forest. It never chose forest
      // — which is why a festival is allowed to dress it.
      for (final hex in ['#F2E8CE', '#143E32', '']) {
        expect(
          CampaignPalette.resolve(hex).background,
          const Color(0xFF7A1F12),
          reason: '$hex is the default, so it wears the season',
        );
      }
      // A colour somebody picked on purpose is left alone.
      expect(
        CampaignPalette.resolve('#2A2160').background,
        const Color(0xFF2A2160),
      );

      await Seasons.instance.load();
    }, () => _api(_ganesh));

    // And out of season everything is back in the app's own palette.
    await http.runWithClient(() async {
      await Seasons.instance.load();
      expect(
        CampaignPalette.resolve('#F2E8CE').background,
        const Color(0xFF143E32),
      );
    }, () => _api(null));
  });
}
