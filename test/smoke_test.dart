import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamazon/data/cart.dart';
import 'package:lamazon/data/catalog.dart';
import 'package:lamazon/main.dart';
import 'package:lamazon/data/addresses.dart';
import 'package:lamazon/data/orders.dart';
import 'package:lamazon/data/seller.dart';
import 'package:lamazon/data/session.dart';
import 'package:lamazon/data/wishlist.dart';
import 'package:lamazon/screens/location_screen.dart';
import 'package:lamazon/screens/orders_screen.dart';
import 'package:lamazon/screens/cart_screen.dart';
import 'package:lamazon/screens/compare_screen.dart';
import 'package:lamazon/screens/details_screen.dart';
import 'package:lamazon/screens/help_screen.dart';
import 'package:lamazon/screens/notifications_screen.dart';
import 'package:lamazon/screens/settings_screen.dart';
import 'package:lamazon/screens/profile_screen.dart';
import 'package:lamazon/screens/search_screen.dart';
import 'package:lamazon/screens/seller_onboarding_screen.dart';
import 'package:lamazon/screens/shop_screen.dart';
import 'package:lamazon/screens/wishlist_screen.dart';
import 'package:network_image_mock/network_image_mock.dart';

void main() {
  testWidgets('login screen skips into home, which loads then shows content',
      (tester) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(const LamazonApp());
      expect(find.text('Local choice. Global experience.'), findsOneWidget);

      // Not pumpAndSettle: the login backdrop animates forever.
      await tester.tap(find.text('Skip login'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(Session.instance.onboarded, isTrue);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Shop By Category'), findsOneWidget);
      expect(find.text('Stores near you'), findsOneWidget);
      expect(find.text('New Arrival'), findsOneWidget);
      expect(find.text('Electronics'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      // The location prompt covers home until it is answered.
      await tester.tap(find.text('Enable device location'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Prices sit below the fold now, so scroll the product grid into view.
      await tester.drag(find.byType(ListView).first, const Offset(0, -400));
      await tester.pump();
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
      expect(find.text('Your account'), findsOneWidget);
      expect(find.text('Your orders'), findsOneWidget);
      expect(find.text('Address book'), findsOneWidget);

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

  testWidgets('seller opens a store, then stocks and restocks it',
      (tester) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(
          const MaterialApp(home: SellerOnboardingScreen()));

      // Create is blocked until name, location, a served city and a
      // category are all present.
      await tester.enterText(
          find.widgetWithText(TextField, 'e.g. Campus Snacks Corner'),
          'Campus Snacks');
      // The rest of the form sits below the fold in a test-sized window.
      await tester.scrollUntilVisible(
          find.widgetWithText(TextField, 'Block / shop number, area'), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.enterText(
          find.widgetWithText(TextField, 'Block / shop number, area'),
          'Block 32, Shop 4');
      await tester.scrollUntilVisible(find.text('Food'), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Food'));
      await tester.pump();

      await tester.tap(find.text('Create store'));
      // Let the route transition finish so only the dashboard is on screen.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(Seller.instance.hasStore, isTrue);
      expect(Seller.instance.store!.categories, ['Food']);

      // Stock two lines and check the derived totals.
      Seller.instance.addItem(InventoryItem(
        id: 'i1',
        title: 'Cold Coffee 300ml',
        description: 'Chilled',
        category: 'Food',
        price: 60,
        stock: 10,
      ));
      Seller.instance.addItem(InventoryItem(
        id: 'i2',
        title: 'Veg Sandwich',
        description: 'Grilled',
        category: 'Food',
        price: 40,
        stock: 3,
      ));
      expect(Seller.instance.skuCount, 2);
      expect(Seller.instance.inventoryValue, 60 * 10 + 40 * 3);
      expect(Seller.instance.lowOrOutCount, 1); // the sandwich is low

      // Stock floors at zero rather than going negative.
      Seller.instance.adjustStock('i2', -10);
      expect(Seller.instance.items.firstWhere((i) => i.id == 'i2').stock, 0);
      expect(
          Seller.instance.items.firstWhere((i) => i.id == 'i2').status,
          StockStatus.out);

      // Creating the store already navigated to the dashboard.
      await tester.pump();
      expect(find.text('Campus Snacks'), findsOneWidget);
      expect(find.text('Inventory value'), findsOneWidget);

      // The first product brings demo orders: one new, one accepted.
      expect(Seller.instance.countAt(OrderStage.received), 1);
      expect(Seller.instance.countAt(OrderStage.accepted), 1);
      expect(Seller.instance.openOrders, 2);

      // Accepting then delivering takes the units out of stock.
      final before =
          Seller.instance.items.firstWhere((i) => i.id == 'i1').stock;
      Seller.instance.acceptOrder('o1');
      expect(Seller.instance.countAt(OrderStage.accepted), 2);
      Seller.instance.deliverOrder('o1');
      expect(Seller.instance.countAt(OrderStage.delivered), 1);
      expect(Seller.instance.items.firstWhere((i) => i.id == 'i1').stock,
          before - 2);
      expect(Seller.instance.openOrders, 1);

      // The stock lines sit below the store header and stats.
      await tester.drag(find.byType(ListView).last, const Offset(0, -500));
      await tester.pump();
      expect(find.text('Cold Coffee 300ml'), findsOneWidget);
      expect(find.text('Sold out'), findsOneWidget);
    });
  });

  test('email validation accepts real addresses, rejects junk', () {
    expect(Session.isValidEmail('lalit@example.com'), isTrue);
    expect(Session.isValidEmail('  a.b+tag@mail.co.in '), isTrue);
    expect(Session.isValidEmail('lalit@example'), isFalse);
    expect(Session.isValidEmail('lalit.example.com'), isFalse);
    expect(Session.isValidEmail('@example.com'), isFalse);
    expect(Session.isValidEmail(''), isFalse);
  });

  test('only LPU is serviceable, case and alias tolerant', () {
    expect(isServiceable('Lovely Professional University'), isTrue);
    expect(isServiceable('  lpu '), isTrue);
    expect(isServiceable('LPU, Phagwara'), isTrue);
    expect(isServiceable('Jalandhar'), isFalse);
    expect(isServiceable('Mumbai'), isFalse);
    expect(isServiceable(''), isFalse);
  });

  testWidgets('location screen blocks unserved city, saves served one',
      (tester) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(const MaterialApp(home: LocationScreen()));

      // Fill an address in a city we do not cover.
      await tester.enterText(
          find.widgetWithText(TextField, 'House / Flat, street, area'),
          '5 MG Road');
      await tester.enterText(
          find.widgetWithText(TextField, 'City'), 'Mumbai');
      await tester.enterText(
          find.widgetWithText(TextField, 'Pincode'), '400001');
      await tester.pump();

      await tester.tap(find.text('Check availability'));
      await tester.pump();
      expect(find.text('Not available in your location'), findsOneWidget);

      // Switch to the covered campus and it becomes saveable.
      await tester.enterText(find.widgetWithText(TextField, 'City'), 'LPU');
      await tester.pump();
      await tester.tap(find.text('Check availability'));
      await tester.pump();
      expect(find.text('We deliver here'), findsOneWidget);
      expect(find.text('Save address'), findsOneWidget);
    });
  });

  testWidgets('orders list and tracking render', (tester) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(const MaterialApp(home: OrdersScreen()));
      expect(find.text('LMZ-10234'), findsOneWidget);
      expect(find.text('On the way'), findsOneWidget);

      await tester.pumpWidget(MaterialApp(
          home: OrderDetailScreen(order: sampleOrders.first)));
      expect(find.text('Packed'), findsOneWidget);
      expect(find.text('Delivery address'), findsOneWidget);
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

  test('shop storefront includes items it stocks at its own price', () {
    // Fresh Milk is listed by Nature Fresh; FreshMart stocks it cheaper.
    final milk = products.firstWhere((p) => p.name == 'Fresh Milk 1L');
    final freshMartPrice =
        milk.offers.firstWhere((o) => o.store == 'FreshMart').price;

    final stock = productsAtShop('FreshMart');
    final listed = stock.firstWhere((p) => p.name == 'Fresh Milk 1L');

    expect(listed.price, freshMartPrice);
    expect(listed.store, 'FreshMart');
    // It still compares against the original vendor.
    expect(listed.offers.any((o) => o.store == milk.store), isTrue);
  });

  testWidgets('notifications, help and settings render', (tester) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(const MaterialApp(home: NotificationsScreen()));
      expect(find.text('Notifications'), findsOneWidget);

      await tester.pumpWidget(const MaterialApp(home: HelpScreen()));
      expect(find.text('Help & Support'), findsOneWidget);
      expect(find.text('Where is my order?'), findsOneWidget);

      await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
      expect(find.text('Settings'), findsOneWidget);
      final toggle = find.byType(Switch).first;
      final before = tester.widget<Switch>(toggle).value;
      await tester.tap(toggle);
      await tester.pump();
      expect(tester.widget<Switch>(find.byType(Switch).first).value,
          isNot(before));
    });
  });
}
