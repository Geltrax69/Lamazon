import 'package:lamazon/data/money.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:lamazon/data/app_info.dart';
import 'package:lamazon/data/catalog.dart';
import 'package:lamazon/models/product.dart';
import 'package:lamazon/screens/details_screen.dart';
import 'package:lamazon/screens/search_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('money displays paise without changing whole-rupee prices', () {
    expect(69.moneyText, '69');
    expect(69.5.moneyText, '69.50');
    expect(0.1.moneyText, '0.10');
  });
  test(
    'full-bleed Cloudinary images are optimized without rewriting other hosts',
    () {
      const image =
          'https://res.cloudinary.com/demo/image/upload/v1/product.png';
      final optimized = optimizedImage(image);
      expect(optimized, contains('f_auto,q_auto,c_limit,w_1024/'));
      expect(optimizedImage(optimized), optimized);
      expect(
        optimizedImage('https://example.com/image/upload/file.png'),
        'https://example.com/image/upload/file.png',
      );
      expect(padded(image, 1, 1024), contains('w_1024,h_1024'));
    },
  );
  test('version comes from the bundled pubspec', () async {
    await AppInfo.load();
    expect(AppInfo.version, matches(RegExp(r'^\d+\.\d+\.\d+$')));
  });
  testWidgets('add confirmation stays on the product details route', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DetailsScreen(
                      product: Product(
                        id: 'test-detail',
                        name: 'Test product',
                        category: 'Test',
                        price: 20,
                        imageUrl: '',
                        description: 'Description',
                      ),
                    ),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add to Cart'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.descendant(
          of: find.byType(DetailsScreen),
          matching: find.text('Added to Cart!'),
        ),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 2));
    });
  });
  testWidgets('search department can be cleared', (tester) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(
        const MaterialApp(home: SearchScreen(tab: 'Stationery & Games')),
      );
      expect(find.text('In Stationery & Games'), findsOneWidget);
      tester.widget<InputChip>(find.byType(InputChip)).onDeleted!();
      await tester.pump();
      expect(find.text('In Stationery & Games'), findsNothing);
    });
  });
}
