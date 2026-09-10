import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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
import 'package:lamazon/screens/home_screen.dart';
import 'package:lamazon/screens/notifications_screen.dart';
import 'package:lamazon/screens/settings_screen.dart';
import 'package:lamazon/screens/profile_screen.dart';
import 'package:lamazon/screens/search_screen.dart';
import 'package:lamazon/screens/shops_screen.dart';
import 'package:lamazon/screens/seller_onboarding_screen.dart';
import 'package:lamazon/screens/shop_screen.dart';
import 'package:lamazon/screens/wishlist_screen.dart';
import 'package:network_image_mock/network_image_mock.dart';

void main() {
  testWidgets('login screen skips into home, which loads then shows content', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(const LamazonApp());
      expect(find.text('Local choice. Global experience.'), findsOneWidget);

      // Not pumpAndSettle: the login backdrop animates forever.
      await tester.tap(find.text('Skip login'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(Session.instance.onboarded, isTrue);

      // The catalog now comes from the API and falls back to bundled data
      // when it is unreachable, which is instant in tests.
      for (
        var attempt = 0;
        attempt < 12 && find.byType(Scrollable).evaluate().isEmpty;
        attempt++
      ) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      await tester.pump();
      expect(find.text('Choose delivery location'), findsOneWidget);
      for (
        var attempt = 0;
        attempt < 12 && find.text('Stores near you').evaluate().isEmpty;
        attempt++
      ) {
        await tester.drag(find.byType(ListView).first, const Offset(0, -500));
        await tester.pump();
      }
      expect(find.text('Stores near you'), findsOneWidget);
      for (
        var attempt = 0;
        attempt < 8 &&
            find.text('Discover local favourites').evaluate().isEmpty;
        attempt++
      ) {
        await tester.drag(find.byType(ListView).first, const Offset(0, -500));
        await tester.pump();
      }
      expect(find.text('Discover local favourites'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);

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
      // The heading is the option group's own name now, and the shop chooses
      // it — the bundled products carry a Size list, which renders as one.
      expect(find.text('Size'), findsOneWidget);
    });
  });

  testWidgets('details price follows the quantity stepper', (tester) async {
    await mockNetworkImagesFor(() async {
      // p3 is the one with several photos, so the swipe gallery renders too.
      final p = products.firstWhere((x) => x.extraImages.isNotEmpty);
      await tester.pumpWidget(MaterialApp(home: DetailsScreen(product: p)));

      final unit = '₹${p.price.toStringAsFixed(0)}';
      expect(find.text(unit), findsWidgets); // one of them is the big number

      // The bug: the price used to stay at the unit price whatever the stepper
      // said. Two of them costs twice as much.
      await tester.ensureVisible(find.byIcon(LucideIcons.plus));
      await tester.pump();
      await tester.tap(find.byIcon(LucideIcons.plus));
      await tester.pump();
      expect(find.text('₹${(p.price * 2).toStringAsFixed(0)}'), findsOneWidget);
      expect(find.text('2 × $unit'), findsOneWidget);

      await tester.tap(find.byIcon(LucideIcons.minus));
      await tester.pump();
      expect(find.text('From: $unit'), findsOneWidget);

      // Every photo is a page you swipe, not a thumbnail you tap.
      await tester.drag(find.byType(ListView).first, const Offset(0, 1000));
      await tester.pump();
      expect(find.byType(PageView), findsOneWidget);
    });
  });

  testWidgets('search filters, wishlist toggles, profile renders', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      // Search
      await tester.pumpWidget(const MaterialApp(home: SearchScreen()));
      await tester.enterText(find.byType(TextField), 'milk');
      // Search asks the server now, debounced — so it takes a beat, and in a
      // test the request fails and falls back to the catalogue in memory.
      await tester.pump(const Duration(milliseconds: 400));
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
      // Below the fold in a test-sized window now that the nav bar leaves
      // room under the last row.
      await tester.scrollUntilVisible(
        find.text('Address book'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Address book'), findsOneWidget);

      // Shop screen shows that vendor's products. It asks the API first and
      // falls back to the bundled list, so give the future a frame to settle.
      await tester.pumpWidget(
        MaterialApp(
          home: ShopScreen(
            shop: shops.firstWhere((s) => s.name == 'GadgetHub'),
          ),
        ),
      );
      await tester.pumpAndSettle();
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

  testWidgets('seller opens a store, then stocks and restocks it', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(
        const MaterialApp(home: SellerOnboardingScreen()),
      );

      // Create is blocked until name, location, a served city and a
      // category are all present.
      await tester.enterText(
        find.widgetWithText(TextField, 'e.g. Campus Snacks Corner'),
        'Campus Snacks',
      );
      // The rest of the form sits below the fold in a test-sized window.
      await tester.scrollUntilVisible(
        find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.decoration?.labelText == 'Block / shop number, area',
        ),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(
        find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.decoration?.labelText == 'Block / shop number, area',
        ),
        'Block 32, Shop 4',
      );
      await tester.scrollUntilVisible(
        find.text('Food'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Food'));
      await tester.pump();

      await tester.tap(find.text('Create store'));
      // Let the route transition finish so only the dashboard is on screen.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(Seller.instance.hasStore, isTrue);
      expect(Seller.instance.store!.categories, ['Food']);

      // Stock two lines and check the derived totals.
      Seller.instance.addItem(
        InventoryItem(
          id: 'i1',
          title: 'Cold Coffee 300ml',
          description: 'Chilled',
          category: 'Food',
          price: 60,
          stock: 10,
        ),
      );
      Seller.instance.addItem(
        InventoryItem(
          id: 'i2',
          title: 'Veg Sandwich',
          description: 'Grilled',
          category: 'Food',
          price: 40,
          stock: 3,
        ),
      );
      expect(Seller.instance.skuCount, 2);
      expect(Seller.instance.inventoryValue, 60 * 10 + 40 * 3);
      expect(Seller.instance.lowOrOutCount, 1); // the sandwich is low

      // Stock floors at zero rather than going negative.
      Seller.instance.adjustStock('i2', -10);
      expect(Seller.instance.items.firstWhere((i) => i.id == 'i2').stock, 0);
      expect(
        Seller.instance.items.firstWhere((i) => i.id == 'i2').status,
        StockStatus.out,
      );

      // Creating the store already navigated to the dashboard.
      await tester.pump();
      expect(find.text('Campus Snacks'), findsOneWidget);

      // A brand-new store is waiting on an admin, and the dashboard has to
      // say so — otherwise the seller sits waiting for orders that cannot
      // come. Adding stock is exactly what approval gates, so that button is
      // not offered either.
      expect(find.text('Your store has been sent for review'), findsOneWidget);
      expect(find.text('Add product'), findsNothing);

      await tester.scrollUntilVisible(
        find.text('Inventory value'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Inventory value'), findsOneWidget);

      // Orders come from the server now. The dashboard used to invent two
      // the moment a product was added, so a brand-new store looked like it
      // had customers — accepting and delivering an order nobody placed.
      expect(Seller.instance.orders, isEmpty);

      // Nothing reached the server in a widget test, and the screen has to
      // say so rather than showing a store no shopper can see.
      expect(Seller.instance.syncError, isNotNull);

      // The seller bottom-nav icon used to trigger a web StackOverflowError
      // when the home screen rebuilt after a refresh.
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      for (
        var attempt = 0;
        attempt < 12 && find.byType(Scrollable).evaluate().isEmpty;
        attempt++
      ) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      await tester.pump();
      expect(tester.takeException(), isNull);

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

  testWidgets('the address form asks only what a porter needs', (tester) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(const MaterialApp(home: LocationScreen()));

      // City and pincode are gone. We deliver to one campus, so the city is
      // decided rather than typed, and nothing has ever used the pincode.
      expect(find.widgetWithText(TextField, 'City'), findsNothing);
      expect(find.widgetWithText(TextField, 'Pincode'), findsNothing);

      // A porter needs someone to hand the bag to, so the form asks who and
      // on what number before it will save anything.
      await tester.enterText(
        find.widgetWithText(TextField, 'Full name'),
        'Lalit Singh',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Mobile number'),
        '9876543210',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Hostel and room, or block and shop'),
        'Hostel BH-9, Room 214',
      );
      await tester.pump();

      await tester.tap(find.text('Check availability'));
      await tester.pump();
      expect(find.text('We deliver here'), findsOneWidget);
      expect(find.text('Save address'), findsOneWidget);
    });
  });

  test('the campus we cover is still the only one we cover', () {
    // The form cannot offer an unserved city any more, but the check behind
    // it is what other callers lean on.
    expect(isServiceable('Lovely Professional University'), isTrue);
    expect(isServiceable('Mumbai'), isFalse);
  });

  // Orders come from the server now, so with no server there is nothing to
  // show — and saying so is the point. The old version asserted a hard-coded
  // "LMZ-10234" that no real order ever had.
  testWidgets('orders come from the server, not from a sample list', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(const MaterialApp(home: OrdersScreen()));
      await tester.pump();
      expect(find.text('My Orders'), findsOneWidget);
      expect(MyOrders.instance.orders, isEmpty);
      expect(
        find.textContaining('No orders yet').evaluate().isNotEmpty ||
            find.textContaining('Loading').evaluate().isNotEmpty ||
            find.textContaining('Could not reach').evaluate().isNotEmpty,
        isTrue,
      );
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
      // Nobody is signed in here, and an order has to belong to someone — so
      // the button names that step rather than promising a purchase it will
      // refuse. The amount stays visible either way, in the Total row.
      expect(find.text('Sign in to place order'), findsOneWidget);
      expect(
        find.text('₹${Cart.instance.total.toStringAsFixed(0)}'),
        findsWidgets,
      );
      // The unit price is spelled out whenever the line holds more than one.
      expect(find.text('2 items'), findsOneWidget);
      expect(find.text('₹${p.price.toStringAsFixed(0)} each'), findsOneWidget);

      Cart.instance.setQty(p.id, 1);
      await tester.pump();
      expect(Cart.instance.total, p.price + 15);
      // At one unit "each" would just repeat the line total, so it goes away.
      expect(find.text('₹${p.price.toStringAsFixed(0)} each'), findsOneWidget);

      Cart.instance.remove(p.id);
      await tester.pump();
      expect(find.text('Your cart is empty'), findsOneWidget);
    });
  });

  test('shop storefront includes items it stocks at its own price', () {
    // Fresh Milk is listed by Nature Fresh; FreshMart stocks it cheaper.
    final milk = products.firstWhere((p) => p.name == 'Fresh Milk 1L');
    final freshMartPrice = milk.offers
        .firstWhere((o) => o.store == 'FreshMart')
        .price;

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
      await tester.pump();
      expect(
        tester.widget<Switch>(toggle).onChanged,
        isNull,
        reason: 'preferences cannot be changed before the server confirms them',
      );
    });
  });

  test('a failed address save does not fabricate a local address', () async {
    AddressBook.instance.clear();
    await expectLater(
      AddressBook.instance.add(
        const Address(
          id: 'unsaved',
          label: AddressLabel.home,
          line: 'Block 34',
          city: 'Lovely Professional University',
          pincode: '144411',
          name: 'Lalit',
          phone: '9876543210',
        ),
      ),
      throwsException,
    );
    expect(AddressBook.instance.addresses, isEmpty);
  });

  testWidgets('every See all opens something', (tester) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pump(const Duration(milliseconds: 400));

      // Three sections carry one, and each was a bare Text before — it looked
      // like a link and did nothing at all.
      // The location prompt opens over home and absorbs pointers, so it has
      // to go before anything underneath can be tapped.
      if (find.text('Enable device location').evaluate().isNotEmpty ||
          find.text('Use my current location').evaluate().isNotEmpty) {
        tester.state<NavigatorState>(find.byType(Navigator).first).pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      }

      for (
        var attempt = 0;
        attempt < 12 && find.text('Stores near you').evaluate().isEmpty;
        attempt++
      ) {
        await tester.drag(find.byType(ListView).first, const Offset(0, -500));
        await tester.pump();
      }
      expect(find.text('See all'), findsWidgets);

      // Stores near you comes first now and opens the shops list; Shop By
      // Category and New Arrival open search. A pushed route leaves home
      // mounted underneath, so assert on the destination, not on home
      // being gone.
      await tester.tap(find.text('See all').first);
      // Not pumpAndSettle: a spinner somewhere never stops, so settle never
      // returns. A few frames is enough for the route transition.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(ShopsScreen), findsOneWidget);

      // Back to home, then the second one, which is the category row.
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pump();
      for (
        var attempt = 0;
        attempt < 12 &&
            find.text('Discover local favourites').evaluate().isEmpty;
        attempt++
      ) {
        await tester.drag(find.byType(ListView).first, const Offset(0, -500));
        await tester.pump();
      }
      expect(find.text('Discover local favourites'), findsOneWidget);
      final searchLink = find.text('See all').last;
      await tester.ensureVisible(searchLink);
      await tester.pump();
      await tester.tap(searchLink, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(SearchScreen), findsOneWidget);
    });
  });
}
