import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamazon/main.dart';
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
}
