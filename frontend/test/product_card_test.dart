import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:lamazon/models/product.dart';
import 'package:lamazon/widgets/app_shell.dart';
import 'package:lamazon/widgets/design_system.dart';
import 'package:lamazon/widgets/product_card.dart';

/// The card's order is its design, and it used to be backwards: the store,
/// then the name in the largest type on the card, then "In stock", then the
/// price last and smallest beside a button louder than any of it.
///
/// In a shop the price is the decision.

Product _p({
  String id = 'p1',
  String name = 'Aloo Tikki Burger',
  String store = 'PURE BITES',
  double price = 69,
  double mrp = 0,
  int? stock,
}) => Product(
  id: id,
  name: name,
  category: 'Burger',
  price: price,
  mrp: mrp,
  imageUrl: '',
  description: '',
  store: store,
  availableStock: stock,
);

Widget _card(Product p, {bool showStore = true}) => MaterialApp(
  theme: LamazonTheme.data,
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: productTileMax,
        height: productTileMax / productTileAspect,
        child: ProductCard(product: p, showStore: showStore, onTap: () {}),
      ),
    ),
  ),
);

double _sizeOf(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style!.fontSize!;

void main() {
  testWidgets('the price is the largest thing on the card', (tester) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(_card(_p(mrp: 79)));
      await tester.pump();

      final price = _sizeOf(tester, '₹69');
      final name = _sizeOf(tester, 'Aloo Tikki Burger');
      final store = _sizeOf(tester, 'PURE BITES');
      expect(
        price,
        greaterThan(name),
        reason: 'the number a shopper decides on must outrank the label',
      );
      expect(name, greaterThan(store));

      // And the price comes first in reading order.
      final priceY = tester.getTopLeft(find.text('₹69')).dy;
      final nameY = tester.getTopLeft(find.text('Aloo Tikki Burger')).dy;
      expect(priceY, lessThan(nameY));
    });
  });

  testWidgets('the saving reads beside the price, not over the food', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(_card(_p(price: 69, mrp: 79)));
      await tester.pump();

      expect(find.text('₹79'), findsOneWidget, reason: 'the struck MRP');
      expect(find.text('13% off'), findsOneWidget);
      // The badge that used to sit on the photograph is gone from the card.
      expect(find.byType(DiscountBadge), findsNothing);
    });
  });

  testWidgets('"In stock" is not a line, but running out is', (tester) async {
    await mockNetworkImagesFor(() async {
      // The default state says nothing, so it gets no room.
      await tester.pumpWidget(_card(_p(stock: 20)));
      await tester.pump();
      expect(find.text('In stock'), findsNothing);

      // The exceptions are the whole point of the row.
      await tester.pumpWidget(_card(_p(stock: 2)));
      await tester.pump();
      expect(find.text('Only 2 left'), findsOneWidget);

      await tester.pumpWidget(_card(_p(stock: 0)));
      await tester.pump();
      expect(find.text('Out of stock'), findsOneWidget);
    });
  });

  testWidgets('the store is named only where it tells you something', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(_card(_p(), showStore: false));
      await tester.pump();
      expect(
        find.text('PURE BITES'),
        findsNothing,
        reason: 'one shop\'s grid repeats the same word down the page',
      );

      await tester.pumpWidget(_card(_p(), showStore: true));
      await tester.pump();
      expect(find.text('PURE BITES'), findsOneWidget);
    });
  });

  test('a single-store list is detected, a mixed one is not', () {
    expect(mixesStores([_p(id: 'a'), _p(id: 'b')]), isFalse);
    expect(
      mixesStores([_p(id: 'a'), _p(id: 'b', store: 'Lalit Computer Tech.')]),
      isTrue,
    );
    expect(mixesStores(const <Product>[]), isFalse);
  });

  /// Builds the real grid at a real width, because the column count and
  /// whether the contents fit are both decided by the delegate, not by
  /// arithmetic in a comment.
  Future<int> buildGrid(
    WidgetTester tester,
    double width,
    List<Product> items,
  ) async {
    tester.view.physicalSize = Size(width, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: LamazonTheme.data,
        home: Scaffold(
          body: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: productTileMax,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: productTileAspect,
            ),
            itemCount: items.length,
            itemBuilder: (_, i) => ProductCard(
              product: items[i],
              showAddToCart: true,
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    // Count the cards sharing the top row's y.
    final tops = tester
        .widgetList<ProductCard>(find.byType(ProductCard))
        .map((c) => tester.getTopLeft(find.byWidget(c)).dy)
        .toList();
    final first = tops.first;
    return tops.where((y) => (y - first).abs() < 1).length;
  }

  testWidgets('three cards fit across a phone, and nothing overflows', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      final items = [
        for (var i = 0; i < 9; i++)
          _p(
            id: 'p$i',
            // A long name and a discount, which is the worst case for height.
            name: i.isEven
                ? 'PB\'s Special Cold Coffee With A Long Name'
                : 'Fries',
            price: 1299,
            mrp: 1499,
            stock: i == 0 ? 2 : 20,
          ),
      ];
      final columns = await buildGrid(tester, 375, items);
      expect(columns, 3, reason: 'two cards on a phone read as placeholders');
      expect(
        tester.takeException(),
        isNull,
        reason: 'the card must fit the height the grid gives it',
      );
    });
  });

  testWidgets('the grid stays sane on a desktop', (tester) async {
    await mockNetworkImagesFor(() async {
      final items = [for (var i = 0; i < 12; i++) _p(id: 'p$i', mrp: 79)];
      final columns = await buildGrid(tester, 1280, items);
      expect(columns, greaterThanOrEqualTo(5));
      expect(columns, lessThanOrEqualTo(9));
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('the card announces itself once, as one thing', (tester) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(_card(_p(price: 69, mrp: 79, stock: 2)));
      await tester.pump();

      // One node carrying the whole card, rather than five nodes a screen
      // reader has to assemble.
      final node = tester.getSemantics(find.byType(ProductCard));
      expect(node.label, contains('Aloo Tikki Burger'));
      expect(node.label, contains('₹69'));
      expect(node.label, contains('13 percent off'));
      expect(node.label, contains('Only 2 left'));
    });
  });

  testWidgets('the controls stay hittable while looking secondary', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: LamazonTheme.data,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: productTileMax,
                height: productTileMax / productTileAspect,
                child: ProductCard(
                  product: _p(),
                  showAddToCart: true,
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Nine cards means eighteen of these on one screen. They were 40 and
      // 44px filled discs with layered shadows, louder than the photography
      // they sat on. They are quieter now — but WCAG 2.5.8 does not care how
      // a control looks, so the target itself may not shrink with it.
      for (final control in [
        find.byType(WishlistHeart),
        find.byType(CartButton),
      ]) {
        expect(control, findsOneWidget);
        final size = tester.getSize(control);
        expect(
          size.shortestSide,
          greaterThanOrEqualTo(LamazonTheme.touch - 0.5),
          reason: 'the drawing shrank, the tap target must not have',
        );
      }
    });
  });
}
