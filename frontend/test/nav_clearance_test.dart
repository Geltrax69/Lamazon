import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';

import 'package:lamazon/screens/home_screen.dart';
import 'package:lamazon/screens/search_screen.dart';
import 'package:lamazon/widgets/app_nav.dart';
import 'package:lamazon/widgets/design_system.dart';
import 'package:lamazon/widgets/product_card.dart';

/// The bar floats over the content instead of reserving a strip beneath it,
/// which is a fine way to draw a navigation bar and a bad way to end a list.
/// Every scroll view behind it has to stop above it, or the last row of the
/// page — the row with the price and the add button on it — can never be
/// scrolled into view. Measured at 375x812 it was hiding 84 to 175px.
void main() {
  const phone = Size(375, 812);

  /// The page's own scroll view: the outermost vertical one. Anything inside
  /// it is a shelf that scrolls sideways or a grid that does not scroll at all.
  Finder pageScroll() =>
      find.byWidgetPredicate((w) => w is Scrollable && w.axis == Axis.vertical);

  Future<void> scrollToEnd(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.drag(pageScroll().first, const Offset(0, -600));
      await tester.pump();
    }
  }

  /// Where the floating bar's top edge sits, in screen coordinates.
  double navTop(WidgetTester tester) {
    final context = tester.element(pageScroll().first);
    return phone.height - bottomNavInset(context);
  }

  Future<void> expectClearOfTheBar(WidgetTester tester, String screen) async {
    await scrollToEnd(tester);
    final limit = navTop(tester);
    final cards = find.byType(ProductCard);
    expect(cards, findsWidgets, reason: '$screen should be showing products');
    var lowest = 0.0;
    for (final card in cards.evaluate()) {
      final box = card.renderObject! as RenderBox;
      final bottom = box.localToGlobal(Offset.zero).dy + box.size.height;
      if (bottom > lowest) lowest = bottom;
    }
    expect(
      lowest,
      lessThanOrEqualTo(limit),
      reason:
          '$screen: ${(lowest - limit).toStringAsFixed(0)}px of the last '
          'card is stuck behind the navigation bar with nowhere left to scroll',
    );
  }

  Future<void> open(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = phone;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(theme: LamazonTheme.data, home: screen),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  testWidgets('home scrolls its last product clear of the bar', (tester) async {
    await mockNetworkImagesFor(() async {
      await open(tester, const HomeScreen());
      await expectClearOfTheBar(tester, 'home');
      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets('search results scroll clear of the bar', (tester) async {
    await mockNetworkImagesFor(() async {
      await open(tester, const SearchScreen());
      await expectClearOfTheBar(tester, 'search');
      await tester.pumpWidget(const SizedBox());
    });
  });
}
