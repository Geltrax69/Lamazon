import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamazon/main.dart';
import 'package:lamazon/data/addresses.dart';
import 'package:lamazon/data/session.dart';
import 'package:network_image_mock/network_image_mock.dart';

void main() {
  testWidgets('home lays out more columns as the window widens',
      (tester) async {
    Session.instance.skip();
    AddressBook.instance.enableLocation();
    await mockNetworkImagesFor(() async {
      for (final entry in {600.0: 2, 800.0: 3, 1200.0: 4, 1600.0: 5}.entries) {
        tester.view.physicalSize = Size(entry.key, 1000);
        tester.view.devicePixelRatio = 1.0;
        await tester.pumpWidget(const LamazonApp());
        await tester.pump(const Duration(seconds: 1));
        final grid = tester.widget<GridView>(find.byType(GridView));
        final delegate =
            grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
        expect(delegate.crossAxisCount, entry.value,
            reason: 'at ${entry.key}px wide');
      }
    });
    tester.view.resetPhysicalSize();
  });
}
