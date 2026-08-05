import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamazon/screens/home_screen.dart';
import 'package:network_image_mock/network_image_mock.dart';

/// The store carousel advances on its own and stops when a finger arrives.
/// Driven through HomeScreen because the widget itself is private — this is
/// what a shopper actually sees on the home screen.
void main() {
  Future<void> openHome(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pump(const Duration(milliseconds: 400));
    // The location prompt covers home until it is answered.
    if (find.text('Enable device location').evaluate().isNotEmpty) {
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  PageController controller(WidgetTester tester) =>
      tester.widget<PageView>(find.byType(PageView).first).controller!;

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

  testWidgets('the store row moves on by itself', (tester) async {
    await mockNetworkImagesFor(() async {
      await openHome(tester);
      expect(controller(tester).page?.round(), 0);

      // One dwell plus the animation.
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(seconds: 1));
      expect(controller(tester).page?.round(), 1);

      // Let the pending animation settle so no timer outlives the test.
      await tester.pump(const Duration(seconds: 1));
    });
  });

  testWidgets('a swipe takes it over, and the timer waits', (tester) async {
    await mockNetworkImagesFor(() async {
      await openHome(tester);

      await tester.drag(find.byType(PageView).first, const Offset(-300, 0));
      await tester.pumpAndSettle();
      final afterDrag = controller(tester).page?.round();
      expect(afterDrag, isNot(0)); // the shopper moved it

      // The next tick must not yank the page away from someone reading it.
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(seconds: 1));
      expect(controller(tester).page?.round(), afterDrag);
    });
  });
}
