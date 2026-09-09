import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lamazon/data/staff.dart';
import 'package:lamazon/screens/admin_screen.dart';
import 'package:lamazon/widgets/design_system.dart';

void main() {
  testWidgets('admin search and pagination operate on the loaded records', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await StaffSession.admin.signIn('test-token', 'admin');
    final orders = [
      for (var i = 0; i < 30; i++)
        {
          'id': 'order-$i',
          'itemTitle': 'Product $i',
          'units': 1,
          'amount': 35,
          'stage': i.isEven ? 'delivered' : 'received',
          'storeName': 'Local store',
          'placedAt': '2026-09-09T00:00:00Z',
        },
    ];
    final client = MockClient((request) async {
      final data = switch (request.url.path) {
        '/api/admin/overview' => {
          'users': 0,
          'stores': 0,
          'riders': 0,
          'orders': 30,
          'people': [],
        },
        '/api/admin/insights' => {
          'totals': {},
          'topStores': [],
          'topItems': [],
        },
        '/api/admin/orders' => orders,
        '/api/admin/policies' => {'policies': []},
        _ => [],
      };
      return http.Response(jsonEncode(data), 200);
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(theme: LamazonTheme.data, home: const AdminScreen()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Orders (30)'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Search orders'),
        'Product 29',
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Product 29'), findsWidgets);
      expect(find.textContaining('Product 28'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('1–1 of 1'),
        220,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      expect(find.text('1–1 of 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await StaffSession.admin.signOut();
    }, () => client);
  });
}
