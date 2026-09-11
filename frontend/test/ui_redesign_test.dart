import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamazon/data/cart.dart';
import 'package:lamazon/data/catalog.dart';
import 'package:lamazon/data/csv_export.dart';
import 'package:lamazon/screens/cart_screen.dart';
import 'package:lamazon/screens/details_screen.dart';
import 'package:lamazon/widgets/design_system.dart';
import 'package:network_image_mock/network_image_mock.dart';

void main() {
  test('CSV exports quoted multiline values and neutralizes formulas', () {
    final csv = rowsToCsv([
      {'name': '=SUM(A1)', 'note': 'One, "two"\nthree'},
      {'name': 'Safe', 'note': null},
    ]);
    expect(csv, contains('"\'=SUM(A1)"'));
    expect(csv, contains('"One, ""two""\nthree"'));
    expect(csv, contains('"Safe",""'));
  });
  for (final width in [320.0, 390.0, 800.0, 1400.0]) {
    testWidgets('details and checkout fit $width width with larger text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await mockNetworkImagesFor(() async {
        Widget app(Widget child) => MaterialApp(
          theme: LamazonTheme.data,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: child,
        );
        await tester.pumpWidget(app(DetailsScreen(product: products.first)));
        await tester.pump();
        expect(find.text('Buy Now'), findsOneWidget);
        expect(tester.takeException(), isNull);
        for (final item in Cart.instance.items) {
          Cart.instance.remove(item.product.id);
        }
        Cart.instance.add(products.first, 2);
        await tester.pumpWidget(app(const CartScreen()));
        await tester.pump();
        expect(tester.takeException(), isNull);
        // Signed out, so this is the sign-in label; either way it is the
        // panel's primary action and the thing that must stay reachable.
        final place = find.textContaining('place order');
        await tester.ensureVisible(place);
        await tester.pump();
        expect(tester.takeException(), isNull);
        // Stated, not offered: the cart tells you how you will pay rather
        // than presenting one option as a choice with a tick beside it.
        expect(find.text('Paying by cash on delivery'), findsOneWidget);
        expect(find.byIcon(LucideIcons.circleCheck), findsNothing);
      });
    });
  }
}
