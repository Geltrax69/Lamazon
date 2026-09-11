import 'package:flutter/material.dart';
import 'dart:ui' show Tristate;

import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';

import 'package:lamazon/data/cart.dart';
import 'package:lamazon/data/catalog.dart';
import 'package:lamazon/models/product.dart';
import 'package:lamazon/screens/details_screen.dart';
import 'package:lamazon/screens/home_screen.dart';
import 'package:lamazon/screens/search_screen.dart';
import 'package:lamazon/widgets/app_shell.dart';
import 'package:lamazon/widgets/design_system.dart';
import 'package:lamazon/widgets/product_card.dart';

/// The ratchet the palette test is, applied to the tab order.
///
/// A card rework once improved almost everything about the product card —
/// real photography, one clean spoken sentence, a price-first hierarchy — and
/// dropped `tabindex` on every card, tile and chip on the way past. The
/// add-to-cart `+` did not get a worse label; it stopped existing for
/// assistive technology entirely, because `excludeSemantics: true` on the
/// card took the InkWell's focusable node and both overlay buttons with it.
///
/// Nothing in a screenshot catches that, and no test did either. These do:
/// they count what a keyboard can actually reach, and they refuse to go down.

/// Every semantics node under [node], flattened.
Iterable<SemanticsData> _all(SemanticsNode node) sync* {
  yield node.getSemanticsData();
  final children = <SemanticsNode>[];
  node.visitChildren((child) {
    children.add(child);
    return true;
  });
  for (final child in children) {
    yield* _all(child);
  }
}

Iterable<SemanticsData> _tree(WidgetTester tester) => _all(
  // rootPipelineOwner owns no semantics of its own; the tree hangs off this.
  // ignore: deprecated_member_use
  tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!,
);

bool _isButton(SemanticsData d) => d.flagsCollection.isButton;
bool _focusable(SemanticsData d) =>
    d.flagsCollection.isFocused != Tristate.none;

/// What a keyboard user can actually land on: a control that is both a button
/// and in the tab order. A button without the second half is the regression.
int _reachable(WidgetTester tester) =>
    _tree(tester).where((d) => _isButton(d) && _focusable(d)).length;

/// Buttons the pointer can use but the keyboard cannot. Must stay empty.
List<String> _pointerOnly(WidgetTester tester) => _tree(tester)
    .where((d) => _isButton(d) && !_focusable(d) && !d.flagsCollection.isHidden)
    .map((d) => d.label)
    .toList();

Product _burger({int? stock = 5}) => Product(
  id: 'p1',
  name: 'Aloo Tikki Burger',
  category: 'Burger',
  price: 69,
  mrp: 79,
  imageUrl: '',
  description: '',
  store: 'PURE BITES',
  availableStock: stock,
);

Future<void> _phone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(375, 812);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('a product card is a button, and so are the two on top of it', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await mockNetworkImagesFor(() async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: LamazonTheme.data,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: productTileMax,
                height: productTileMax / productTileAspect,
                child: ProductCard(
                  product: _burger(),
                  showAddToCart: true,
                  onTap: () => tapped = true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final buttons = _tree(tester).where(_isButton).toList();
      // The card, the heart, the plus. All three, all keyboard-reachable.
      expect(buttons.length, 3, reason: 'card + save + add to cart');
      expect(
        buttons.every(_focusable),
        isTrue,
        reason:
            'a role="button" with no tab stop is a control a keyboard '
            'user can see and never use: ${_pointerOnly(tester)}',
      );

      final card = buttons.firstWhere((b) => b.label.contains('₹'));
      expect(card.label, contains('Aloo Tikki Burger'));
      expect(card.label, contains('₹69'));
      expect(card.label, contains('13 percent off'));
      expect(
        buttons.map((b) => b.label),
        containsAll(<String>['Save product', 'Add Aloo Tikki Burger to cart']),
      );

      // And Enter reaches the product, without a pointer anywhere near it.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(tapped, isTrue, reason: 'Tab then Enter must open the product');
    });
    handle.dispose();
  });

  testWidgets('Space on the focused + puts the product in the cart', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await mockNetworkImagesFor(() async {
      for (final line in Cart.instance.items.toList()) {
        Cart.instance.remove(line.product.id);
      }
      await tester.pumpWidget(
        MaterialApp(
          theme: LamazonTheme.data,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: productTileMax,
                height: productTileMax / productTileAspect,
                child: ProductCard(
                  product: _burger(),
                  showAddToCart: true,
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Walk the tab order to the add button rather than tapping it.
      var reached = false;
      for (var i = 0; i < 8 && !reached; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        reached =
            primaryFocus?.context
                ?.findAncestorWidgetOfExactType<CartButton>() !=
            null;
      }
      expect(reached, isTrue, reason: 'Tab must land on the + eventually');
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      // The + flips to a tick for 1.4s and toasts; let both finish so the
      // test does not leave a timer behind.
      await tester.pump(const Duration(seconds: 5));

      expect(
        Cart.instance.count,
        greaterThan(0),
        reason: 'a keyboard must be able to fill a basket',
      );
      for (final line in Cart.instance.items.toList()) {
        Cart.instance.remove(line.product.id);
      }
    });
    handle.dispose();
  });

  testWidgets('home keeps its cards and tiles in the tab order', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await mockNetworkImagesFor(() async {
      await _phone(tester);
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }

      expect(
        _pointerOnly(tester),
        isEmpty,
        reason: 'every button on home must be reachable by Tab',
      );
      // Measured at 21 buttons on the live home screen, of which 5 were
      // focusable. The floor is deliberately below what a test window shows
      // so it tracks the defect, not the fixture.
      expect(_reachable(tester), greaterThanOrEqualTo(8));
      await tester.pumpWidget(const SizedBox());
    });
    handle.dispose();
  });

  testWidgets('search results are reachable, and so is their +', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await mockNetworkImagesFor(() async {
      await _phone(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: LamazonTheme.data,
          home: SearchScreen(initialQuery: products.first.name),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(ProductCard), findsWidgets);
      expect(
        _pointerOnly(tester),
        isEmpty,
        reason: 'a result you cannot focus is a result you cannot buy',
      );
      expect(_reachable(tester), greaterThanOrEqualTo(5));
      await tester.pumpWidget(const SizedBox());
    });
    handle.dispose();
  });

  testWidgets('the app has a heading outline to navigate by', (tester) async {
    // The accessibility tree used to carry zero headings, on every screen, so
    // there was no way to skip between sections — a screen reader read the
    // whole page or nothing.
    final handle = tester.ensureSemantics();
    await mockNetworkImagesFor(() async {
      await _phone(tester);

      List<String> headingsOf() => _tree(tester)
          .where((d) => d.headingLevel > 0)
          .map((d) => 'h${d.headingLevel} ${d.label}')
          .toList();

      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      final home = headingsOf();
      expect(
        home.where((h) => h.startsWith('h1')),
        isNotEmpty,
        reason: 'home is the one screen with no ScreenHeader to supply one',
      );
      expect(home.where((h) => h.startsWith('h2')).length, greaterThan(1));

      await tester.pumpWidget(
        MaterialApp(
          theme: LamazonTheme.data,
          home: DetailsScreen(product: products.first),
        ),
      );
      await tester.pump();
      expect(headingsOf().where((h) => h.startsWith('h1')), isNotEmpty);
      // The section titles are further down the page than a phone shows.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
      await tester.pump();
      expect(
        headingsOf().any((h) => h.contains('About this product')),
        isTrue,
        reason: 'the product page sections are headings too',
      );
      await tester.pumpWidget(const SizedBox());
    });
    handle.dispose();
  });

  testWidgets('a focused control draws the ring, not just a wash', (
    tester,
  ) async {
    // The home search field's only focus state was a lime fill measuring
    // 1.10:1 against the surface behind it, against a 3:1 requirement — while
    // every icon button beside it drew a 10:1 outline. Tabbing to the most
    // used control on the shop looked like tabbing to nothing.
    await mockNetworkImagesFor(() async {
      await _phone(tester);
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }

      final search = find.ancestor(
        of: find.text('Search products, shops and more'),
        matching: find.byType(FocusRing),
      );
      expect(
        search,
        findsWidgets,
        reason: 'the search field has to use the same ring as everything else',
      );

      // Tab until it holds focus, then look for the outline it should paint.
      for (var i = 0; i < 12; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final ringed = tester
            .widgetList<DecoratedBox>(
              find.descendant(
                of: search.first,
                matching: find.byType(DecoratedBox),
              ),
            )
            .map((d) => d.decoration)
            .whereType<BoxDecoration>()
            .any((d) => d.border?.top.color == LamazonTheme.focusColour);
        if (ringed) return;
      }
      fail('no focus ring appeared on the search field after 12 tab stops');
    });
  });
}
