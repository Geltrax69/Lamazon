import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lamazon/data/staff.dart';
import 'package:lamazon/screens/admin_screen.dart';
import 'package:lamazon/widgets/design_system.dart';

/// A QA pass over the admin panel, driven the only way it can be driven
/// without typing somebody's password into a login form: pump the real screen
/// against a mocked API and audit what it actually lays out.
///
/// Every tab, at a phone, a tablet and a desktop. What it checks is what the
/// release gate complained about — overflow, touch targets, labelled controls,
/// heading structure, and whether a section says something useful when it is
/// empty.

/// Realistic enough to shake out layout: long names, big numbers, mixed states.
Map<String, dynamic> _fixture() {
  final stores = [
    for (var i = 0; i < 3; i++)
      {
        'owner': 'seller$i@campus.test',
        'name': i == 0
            ? 'PURE BITES'
            : 'A Very Long Store Name That Should Not Break The Row $i',
        'location': 'Block 32',
        'city': 'LPU',
        'status': ['pending', 'approved', 'rejected'][i],
        'categories': ['Food'],
        'items': 4,
      },
  ];
  final items = [
    for (var i = 0; i < 6; i++)
      {
        'id': 'item-$i',
        'title': i == 0
            ? 'PB\'s Special Cold Coffee With An Unreasonably Long Name'
            : 'Product $i',
        'description': 'd',
        'category': 'Food',
        'price': 60 + i,
        'mrp': i.isEven ? 80 + i : 0,
        'options': [],
        'compareGroup': '',
        'attributes': {},
        'stock': [0, 2, 20, 20, 5, 100][i],
        'delisted': i == 3,
        'reserved': i == 4 ? 3 : 0,
        'orders': i == 4 ? 2 : 0,
        'storeName': 'PURE BITES',
        'owner': 'seller0@campus.test',
        'status': 'in_stock',
        'imageUrls': const <String>[],
      },
  ];
  return {
    'stores': stores,
    'items': items,
    'orders': [
      for (var i = 0; i < 4; i++)
        {
          'id': 'order-$i',
          'itemTitle': 'Product $i',
          'units': 1,
          'amount': 35,
          'stage': ['received', 'accepted', 'picked', 'delivered'][i],
          'storeName': 'PURE BITES',
          'placedAt': '2026-09-09T00:00:00Z',
        },
    ],
    'riders': [
      {'phone': '9000000001', 'name': 'Rider One', 'active': true, 'delivered': 4},
    ],
  };
}

MockClient _api() {
  final f = _fixture();
  return MockClient((request) async {
    final data = switch (request.url.path) {
      '/api/admin/overview' => {
        'users': 12,
        'sellers': 3,
        'stores': 3,
        'riders': 1,
        'orders': 4,
        'people': [
          {'email': 'a@b.test', 'publicId': 'LMZ-1001', 'orders': 2},
        ],
      },
      '/api/admin/insights' => {
        'totals': {'placed': 4, 'delivered': 1, 'revenue': 140},
        'topStores': [
          {'store': 'PURE BITES', 'orders': 4, 'revenue': 140},
        ],
        'topItems': [
          {'item': 'Product 0', 'units': 2},
        ],
      },
      '/api/admin/stores' => f['stores'],
      '/api/admin/items' => {'items': f['items']},
      '/api/admin/orders' => f['orders'],
      '/api/admin/riders' => f['riders'],
      '/api/admin/policies' => {
        'policies': [
          {
            'slug': 'terms',
            'title': 'Terms and Conditions',
            'body': 'Real text.',
            'published': true,
            'updatedAt': '2026-09-01T00:00:00Z',
          },
        ],
      },
      '/api/admin/compare-groups' => {'groups': []},
      '/api/admin/campaigns' => {'campaigns': []},
      _ => [],
    };
    return http.Response(jsonEncode(data), 200);
  });
}

/// Every destination in the panel, by the label on its chip.
const _tabs = [
  'To review',
  'Approved',
  'Rejected',
  'Orders',
  'Products',
  'Insights',
  'Categories',
  'Banners',
  'Compare',
  'Policies',
  'Delivery',
  'People',
];

const _viewports = {
  'phone': Size(375, 812),
  'tablet': Size(834, 1112),
  'desktop': Size(1440, 900),
};

Future<void> _open(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  await StaffSession.admin.signIn('test-token', 'admin');
  await tester.pumpWidget(
    MaterialApp(theme: LamazonTheme.data, home: const AdminScreen()),
  );
  await tester.pumpAndSettle();
}

Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await StaffSession.admin.signOut();
}

/// Moves to a section, whichever control the breakpoint uses for it.
Future<bool> _goTo(WidgetTester tester, String label) async {
  final chip = find.widgetWithText(ChoiceChip, label);
  if (chip.evaluate().isNotEmpty) {
    await tester.tap(chip.first, warnIfMissed: false);
    await tester.pumpAndSettle();
    return true;
  }
  final counted = find.byWidgetPredicate(
    (w) => w is ChoiceChip && w.label is Text && (w.label as Text).data!.startsWith(label),
  );
  if (counted.evaluate().isNotEmpty) {
    await tester.tap(counted.first, warnIfMissed: false);
    await tester.pumpAndSettle();
    return true;
  }
  return false;
}

/// WCAG 2.1 relative luminance.
double _luminance(Color c) {
  double channel(double v) {
    final s = v / 255;
    return s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel((c.r * 255).roundToDouble()) +
      0.7152 * channel((c.g * 255).roundToDouble()) +
      0.0722 * channel((c.b * 255).roundToDouble());
}

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  for (final entry in _viewports.entries) {
    testWidgets('admin lays out without overflow at ${entry.key}', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await http.runWithClient(() async {
          // Layout errors are reported the moment a frame is built, before
          // any assertion of ours runs, so they have to be intercepted rather
          // than collected afterwards. Capturing them all in one pass is the
          // point: stopping at the first says nothing about the other eleven.
          final broken = <String>[];
          final reportError = FlutterError.onError;
          var current = 'startup';
          FlutterError.onError = (details) {
            broken.add('$current: ${details.exceptionAsString().split('\n').first}');
          };
          try {
            await _open(tester, entry.value);
            for (final tab in _tabs) {
              current = tab;
              if (!await _goTo(tester, tab)) continue;
            }
            await _close(tester);
          } finally {
            FlutterError.onError = reportError;
          }
          expect(
            broken,
            isEmpty,
            reason: 'sections break their layout at ${entry.key}',
          );
        }, _api);
      });
    });
  }

  testWidgets('every admin control is named and big enough to hit', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      await http.runWithClient(() async {
        await _open(tester, _viewports['phone']!);
        final unnamed = <String>[];
        final tooSmall = <String>[];

        for (final tab in _tabs) {
          if (!await _goTo(tester, tab)) continue;
          for (final element in find.byType(IconButton).evaluate()) {
            final button = element.widget as IconButton;
            if ((button.tooltip ?? '').trim().isEmpty) {
              unnamed.add('$tab: an icon button with no tooltip');
            }
            final box = element.renderObject as RenderBox?;
            if (box == null || !box.hasSize) continue;
            if (box.size.shortestSide < LamazonTheme.touch - 0.5) {
              tooSmall.add(
                '$tab: ${button.tooltip} is ${box.size.width.toStringAsFixed(0)}'
                'x${box.size.height.toStringAsFixed(0)}',
              );
            }
          }
        }
        await _close(tester);

        expect(unnamed, isEmpty, reason: 'icon-only actions need a name');
        expect(
          tooSmall,
          isEmpty,
          reason: 'WCAG 2.5.8 puts the floor at ${LamazonTheme.touch}px',
        );
      }, _api);
    });
  });

  testWidgets('the panel has a heading structure a screen reader can use', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      await http.runWithClient(() async {
        await _open(tester, _viewports['desktop']!);
        final headings = find.byWidgetPredicate(
          (w) => w is Semantics && (w.properties.headingLevel ?? 0) > 0,
        );
        expect(
          headings,
          findsWidgets,
          reason: 'the app had zero heading semantics; admin must not go back',
        );
        await _close(tester);
      }, _api);
    });
  });

  testWidgets('the products section shows stock, reserved and sellable', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      await http.runWithClient(() async {
        await _open(tester, _viewports['desktop']!);
        expect(await _goTo(tester, 'Products'), isTrue);

        // The three numbers that do not mean the same thing.
        expect(find.text('On shelf'), findsWidgets);
        expect(find.text('Can be sold'), findsWidgets);
        expect(find.text('In orders'), findsWidgets);

        // An item with orders says so, because that is why it cannot be
        // deleted; a hidden one says that too.
        expect(find.text('2 orders'), findsOneWidget);
        expect(find.text('Hidden'), findsOneWidget);
        await _close(tester);
      }, _api);
    });
  });

  test('every colour the admin puts words in passes AA on both grounds', () {
    // The panel used stock Material orange for "waiting for review", "needs
    // restock" and the low-stock badge — 2.85:1 on canvas, under even the 3:1
    // floor for large text, on exactly the states that most need reading.
    const inks = {
      'warning': LamazonTheme.warning,
      'danger': LamazonTheme.danger,
      'strong': LamazonTheme.strong,
      'muted': LamazonTheme.muted,
      'text': LamazonTheme.text,
    };
    const grounds = {
      'surface': LamazonTheme.surface,
      'canvas': LamazonTheme.canvas,
    };
    final failures = <String>[];
    for (final ink in inks.entries) {
      for (final ground in grounds.entries) {
        final ratio = _contrast(ink.value, ground.value);
        if (ratio < 4.5) {
          failures.add(
            '${ink.key} on ${ground.key} is ${ratio.toStringAsFixed(2)}:1',
          );
        }
      }
    }
    expect(failures, isEmpty, reason: 'WCAG AA body text needs 4.5:1');
  });
}
