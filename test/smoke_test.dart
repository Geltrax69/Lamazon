import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamazon/data/cart.dart';
import 'package:lamazon/data/catalog.dart';
import 'package:lamazon/main.dart';
import 'package:lamazon/data/wishlist.dart';
import 'package:lamazon/screens/cart_screen.dart';
import 'package:lamazon/screens/compare_screen.dart';
import 'package:lamazon/screens/details_screen.dart';
import 'package:lamazon/screens/profile_screen.dart';
import 'package:lamazon/screens/search_screen.dart';
import 'package:lamazon/screens/shop_screen.dart';
import 'package:lamazon/screens/wishlist_screen.dart';
import 'package:network_image_mock/network_image_mock.dart';

void main() {
  testWidgets('home shows loading then content', (tester) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(const LamazonApp());
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Shop By Shop'), findsOneWidget);
      expect(find.text('New Arrival'), findsOneWidget);
      expect(find.text('Electronics'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.textContaining('₹'), findsWidgets);
    });
  });

  testWidgets('details screen renders product', (tester) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(
        MaterialApp(home: DetailsScreen(product: products.first)),
      );
      expect(find.text(products.first.name), findsOneWidget);
      expect(find.text('Add to Cart'), findsOneWidget);
      expect(find.text('Buy Now'), findsOneWidget);
      expect(find.text('Select Size'), findsOneWidget);
    });
  });

  testWidgets('search filters, wishlist toggles, profile renders',
      (tester) async {
    await mockNetworkImagesFor(() async {
      // Search
      await tester.pumpWidget(const MaterialApp(home: SearchScreen()));
      await tester.enterText(find.byType(TextField), 'milk');
      await tester.pump();
      expect(find.text('Fresh Milk 1L'), findsOneWidget);

      // Wishlist state
      Wishlist.instance.toggle(products.first.id);
      expect(Wishlist.instance.contains(products.first.id), isTrue);
      await tester.pumpWidget(const MaterialApp(home: WishlistScreen()));
      expect(find.text(products.first.name), findsOneWidget);
      Wishlist.instance.toggle(products.first.id);
      await tester.pump();
      expect(find.text('Nothing saved yet'), findsOneWidget);

      // Profile
      await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
      expect(find.text('My Orders'), findsOneWidget);

      // Shop screen shows that vendor's products
      await tester.pumpWidget(MaterialApp(
          home: ShopScreen(shop: shops.firstWhere((s) => s.name == 'GadgetHub'))));
      expect(find.text('Wireless Headphones'), findsOneWidget);
    });
  });

  testWidgets('compare screen ranks vendors cheapest first', (tester) async {
    await mockNetworkImagesFor(() async {
      // Milk: ₹68 at Nature Fresh, ₹66 FreshMart, ₹70 Daily Basket.
      final milk = products.firstWhere((p) => p.name == 'Fresh Milk 1L');
      await tester.pumpWidget(MaterialApp(home: CompareScreen(product: milk)));

      expect(find.text('3 local vendors'), findsOneWidget);
      expect(find.text('BEST PRICE'), findsOneWidget);
      // Cheapest vendor wins the badge and the savings banner.
      expect(find.text('Add from FreshMart'), findsOneWidget);
      expect(find.textContaining('Save ₹4'), findsOneWidget);
    });
  });

  testWidgets('cart adds, updates qty, totals, removes', (tester) async {
    await mockNetworkImagesFor(() async {
      final p = products.first;
      Cart.instance.add(p, 2);
      expect(Cart.instance.count, 2);
      expect(Cart.instance.subtotal, p.price * 2);

      await tester.pumpWidget(const MaterialApp(home: CartScreen()));
      expect(find.text(p.name), findsOneWidget);
      expect(find.text('Make a Payment'), findsOneWidget);

      Cart.instance.setQty(p.id, 1);
      await tester.pump();
      expect(Cart.instance.total, p.price + 15);

      Cart.instance.remove(p.id);
      await tester.pump();
      expect(find.text('Your cart is empty'), findsOneWidget);
    });
  });
}
