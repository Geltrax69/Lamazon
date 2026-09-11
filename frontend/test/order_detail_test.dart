import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamazon/data/orders.dart';
import 'package:lamazon/screens/order_detail_screen.dart';
import 'package:lamazon/widgets/design_system.dart';

/// This screen was rebuilt from bare Text widgets, and it carries the two
/// things a buyer needs after paying: the code they read out at the door, and
/// a way out while the shop has not started yet. Neither had ever been
/// exercised, by QA or by me.
MyOrder _order({
  required OrderStatus status,
  String code = '',
  String rejectReason = '',
}) => MyOrder(
  id: 'order-6',
  itemTitle: 'Masala Chai',
  storeName: 'Campus Canteen',
  units: 2,
  amount: 65,
  placedAt: DateTime(2026, 9, 10),
  status: status,
  rejectReason: rejectReason,
  address: 'Hostel BH-9, Room 214',
  deliveryCode: code,
);

Widget _screen(MyOrder o) => MaterialApp(
  theme: LamazonTheme.data,
  home: OrderDetailScreen(order: o),
);

/// A surface tall enough to build the whole screen.
///
/// The body is a ListView, so at the default 800x600 test size the controls at
/// the bottom are never built — which made "there is no Cancel button" pass
/// for a delivered order whether or not the button was correctly hidden. An
/// absence only means something when the thing would have been built.
void _tall(WidgetTester tester, {double width = 800}) {
  tester.view.physicalSize = Size(width, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('a live order shows its progress, its code and a way out', (
    tester,
  ) async {
    _tall(tester);
    await tester.pumpWidget(
      _screen(_order(status: OrderStatus.placed, code: '4821')),
    );
    await tester.pump();

    // The id reads as a reference, not a database key.
    expect(find.text('Order #0006'), findsOneWidget);
    expect(find.textContaining('order-6'), findsNothing);

    // Progress, spelled out rather than left as one sentence.
    expect(find.text('Waiting for the shop'), findsOneWidget);
    for (final step in ['Placed', 'Accepted', 'On the way', 'Delivered']) {
      expect(find.text(step), findsOneWidget);
    }

    // The code, spaced so it can be read aloud, and announced digit by digit.
    expect(find.text('4  8  2  1'), findsOneWidget);
    expect(find.text('Your delivery code'), findsOneWidget);

    // "1 item(s)" was the old copy.
    expect(find.text('2 items'), findsOneWidget);
    expect(find.text('₹65'), findsOneWidget);
    expect(find.text('Hostel BH-9, Room 214'), findsOneWidget);

    // Cancellable only while the shop has not accepted it.
    expect(find.text('Cancel order'), findsOneWidget);
    expect(
      find.text('You can cancel until the shop accepts it.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a delivered order offers no cancel and no code', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_screen(_order(status: OrderStatus.delivered)));
    await tester.pump();

    expect(find.text('Delivered'), findsWidgets);
    expect(
      find.text('Cancel order'),
      findsNothing,
      reason: 'the API refuses it, so the button must not be offered',
    );
    expect(find.text('Your delivery code'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a cancelled order says so instead of drawing a broken track', (
    tester,
  ) async {
    _tall(tester);
    await tester.pumpWidget(
      _screen(
        _order(
          status: OrderStatus.rejected,
          rejectReason: 'Cancelled by customer',
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('You cancelled this order. Nothing was charged.'),
      findsOneWidget,
    );
    // An order that left the happy path gets a notice, not a progress line
    // with a hole in it.
    expect(find.text('On the way'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a rejected order repeats the shop\'s reason', (tester) async {
    _tall(tester);
    await tester.pumpWidget(
      _screen(
        _order(status: OrderStatus.rejected, rejectReason: 'Kitchen closed'),
      ),
    );
    await tester.pump();

    expect(
      find.text('The shop could not take this order: Kitchen closed'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('it fits a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _screen(_order(status: OrderStatus.accepted, code: '4821')),
    );
    await tester.pump();
    expect(tester.takeException(), isNull, reason: 'no overflow at 320px');
  });
}
