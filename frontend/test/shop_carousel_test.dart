import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamazon/screens/home_screen.dart';
import 'package:network_image_mock/network_image_mock.dart';

/// The store row on the home screen. It used to be a PageView advancing on a
/// timer, and the two tests that guarded that timer went with it; it is now a
/// rail the shopper pushes. What is left worth guarding is that the cards fit
/// a narrow phone.
void main() {
  Future<void> openHome(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    for (
      var attempt = 0;
      attempt < 12 && find.byType(Scrollable).evaluate().isEmpty;
      attempt++
    ) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    await tester.pump();
  }

  testWidgets('the store cards fit a narrow phone', (tester) async {
    await mockNetworkImagesFor(() async {
      // The card used to be a hard 246 wide whatever slot the carousel gave
      // it, so a narrow screen overflowed by the difference. An overflow is
      // reported as an exception in a test, which is what this catches.
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await openHome(tester);
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    });
  });
}
