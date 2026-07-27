import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamazon/data/catalog.dart';
import 'package:lamazon/main.dart';
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
}
