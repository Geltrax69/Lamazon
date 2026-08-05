import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamazon/data/catalog.dart';
import 'package:lamazon/screens/search_screen.dart';
import 'package:lamazon/widgets/product_card.dart';
import 'package:network_image_mock/network_image_mock.dart';

/// An empty search is the page most people land on, so it has to be worth
/// looking at rather than a magnifier on a blank field.
void main() {
  testWidgets('shows real products before anything is typed', (tester) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(const MaterialApp(home: SearchScreen()));
      await tester.pump();

      expect(find.text('Shop by department'), findsOneWidget);

      // Everything below the departments is off-screen in a test-sized
      // window, and a ListView does not build what it cannot show.
      await tester.drag(find.byType(ListView).first, const Offset(0, -700));
      await tester.pump();
      // Something you can look at and tap into, not only names to read.
      expect(find.byType(NetImage), findsWidgets);
      await tester.drag(find.byType(ListView).first, const Offset(0, -700));
      await tester.pump();
      expect(find.byType(ProductCard), findsWidgets);
    });
  });

  testWidgets('scoped to a department, it shows that department',
      (tester) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(
        const MaterialApp(home: SearchScreen(tab: 'Grocery')),
      );
      await tester.pump();

      // Inside a department the department grid is redundant — you are
      // already in one.
      expect(find.text('Shop by department'), findsNothing);
      expect(find.text('Browse Grocery'), findsOneWidget);

      await tester.drag(find.byType(ListView).first, const Offset(0, -700));
      await tester.pump();
      final cards = tester.widgetList<ProductCard>(find.byType(ProductCard));
      expect(cards, isNotEmpty);
      for (final card in cards) {
        expect(card.product.tab, 'Grocery');
      }
    });
  });

  testWidgets('it fits a narrow phone', (tester) async {
    await mockNetworkImagesFor(() async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(home: SearchScreen()));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  test('the bundled catalogue can actually fill it', () {
    // Guards the fixture the two widget tests lean on.
    expect(shownCatalog, isNotEmpty);
    expect(shownCatalog.where((p) => p.imageUrl.isNotEmpty), isNotEmpty);
  });
}
