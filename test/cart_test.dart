import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamazon/data/cart.dart';
import 'package:lamazon/data/catalog.dart';
import 'package:lamazon/screens/cart_screen.dart';
import 'package:network_image_mock/network_image_mock.dart';

void main() {
  setUp(() {
    for (final item in Cart.instance.items) {
      Cart.instance.remove(item.product.id);
    }
  });

  testWidgets('order summary follows the cart as quantities change',
      (tester) async {
    await mockNetworkImagesFor(() async {
      final p = products.first;
      Cart.instance.add(p);
      await tester.pumpWidget(const MaterialApp(home: CartScreen()));

      final one = p.price + 15;
      expect(find.text('₹${one.toStringAsFixed(0)}'), findsOneWidget);

      // Adding a unit must move the total, not just the row.
      Cart.instance.setQty(p.id, 2);
      await tester.pump();
      final two = p.price * 2 + 15;
      expect(find.text('₹${two.toStringAsFixed(0)}'), findsOneWidget);
      expect(find.text('₹${one.toStringAsFixed(0)}'), findsNothing);

      // Back down again.
      Cart.instance.setQty(p.id, 1);
      await tester.pump();
      expect(find.text('₹${one.toStringAsFixed(0)}'), findsOneWidget);
    });
  });

  testWidgets('emptying the cart drops the summary and shipping',
      (tester) async {
    await mockNetworkImagesFor(() async {
      final p = products.first;
      Cart.instance.add(p);
      await tester.pumpWidget(const MaterialApp(home: CartScreen()));
      expect(find.text('Order Summary'), findsOneWidget);

      Cart.instance.remove(p.id);
      await tester.pump();
      expect(find.text('Your cart is empty'), findsOneWidget);
      expect(find.text('Order Summary'), findsNothing);
      expect(Cart.instance.shipping, 0);
      expect(Cart.instance.total, 0);
    });
  });
}
