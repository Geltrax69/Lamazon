import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamazon/data/cart.dart';
import 'package:lamazon/data/catalog.dart';
import 'package:lamazon/main.dart';
import 'package:lamazon/screens/cart_screen.dart';
import 'package:lamazon/screens/details_screen.dart';
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
