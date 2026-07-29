import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamazon/data/addresses.dart';
import 'package:lamazon/data/session.dart';
import 'package:lamazon/main.dart';
import 'package:lamazon/widgets/app_shell.dart';
import 'package:lamazon/widgets/product_card.dart';
import 'package:network_image_mock/network_image_mock.dart';

void main() {
  testWidgets('product cards keep their size as the window widens',
      (tester) async {
    Session.instance.skip();
    AddressBook.instance.enableLocation();
    await mockNetworkImagesFor(() async {
      // More width should buy more columns, never fatter cards.
      var lastCount = 0;
      for (final width in [600.0, 900.0, 1400.0, 1900.0]) {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1.0;
        await tester.pumpWidget(const LamazonApp());
        await tester.pump(const Duration(seconds: 1));

        final card = tester.getSize(find.byType(ProductCard).first);
        expect(card.width, lessThanOrEqualTo(productTileMax),
            reason: 'card too wide at ${width}px');

        final count = tester.widgetList<ProductCard>(find.byType(ProductCard)).length;
        expect(count, greaterThanOrEqualTo(lastCount),
            reason: 'fewer cards visible at ${width}px');
        lastCount = count;
      }
    });
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
