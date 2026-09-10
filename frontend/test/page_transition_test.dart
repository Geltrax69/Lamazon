import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamazon/widgets/design_system.dart';

/// One transition, every platform. The defaults disagree — Android zooms the
/// incoming page behind a scrim, iOS and macOS slide the whole screen in from
/// the right — so which one a shopper got depended on the browser they opened
/// the app in, and on a wide screen the slide read as a phone gesture that had
/// wandered onto a desktop.
void main() {
  Future<void> pushInto(
    WidgetTester tester, {
    required TargetPlatform platform,
    bool reduceMotion = false,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: LamazonTheme.data.copyWith(platform: platform),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: reduceMotion),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(body: Text('arrived')),
                ),
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
  }

  for (final platform in TargetPlatform.values) {
    testWidgets('$platform fades rather than sliding or zooming', (
      tester,
    ) async {
      await pushInto(tester, platform: platform);
      await tester.tap(find.text('go'));
      // Part-way through, where the transition is actually on screen.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      expect(find.byType(FadeTransition), findsWidgets);
      // The default this most visibly replaces: a full-width horizontal slide.
      expect(find.byType(CupertinoPageTransition), findsNothing);

      await tester.pumpAndSettle();
      expect(find.text('arrived'), findsOneWidget);
    });
  }

  testWidgets('reduced motion arrives with no animation of ours', (
    tester,
  ) async {
    await pushInto(
      tester,
      platform: TargetPlatform.android,
      reduceMotion: true,
    );
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    // The builder hands the page straight back rather than animating it.
    expect(find.text('arrived'), findsOneWidget);
    await tester.pumpAndSettle();
  });
}
