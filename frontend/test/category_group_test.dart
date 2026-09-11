import 'package:flutter_test/flutter_test.dart';
import 'package:lamazon/data/categories.dart';
import 'package:lamazon/screens/seller_product_screen.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

void main() {
  test('the department index answers what the walk did', () {
    _departmentIndexMatchesTheWalk();
  });

  test('sellable names stay under their section', () {
    departments = const [
      allDepartment,
      Department('Food', LucideIcons.utensils, null, [
        CategoryNode('Breakfast', [
          CategoryNode('Poori Bhaji'),
          CategoryNode('Paratha'),
        ]),
        CategoryNode('Desserts', [CategoryNode('Halwa')]),
      ]),
      Department('Gifts', LucideIcons.gift, null),
    ];

    expect(sellableGroups('Food'), {
      'Breakfast': ['Poori Bhaji', 'Paratha'],
      'Desserts': ['Halwa'],
    });
    // A department with no categories is its own section, holding itself.
    expect(sellableGroups('Gifts'), {
      'Gifts': ['Gifts'],
    });
    // Same names as the flat list, just grouped.
    expect(
      sellableGroups().values.expand((v) => v).toList(),
      sellableCategories(),
    );

    expect(departmentOf('Paratha'), 'Food');
    expect(departmentOf('Breakfast'), 'Food');
    expect(departmentOf('Gifts'), 'Gifts');
    expect(departmentOf('Nothing'), '');

    departments = fallbackDepartments;
  });

  test('option presets follow the department', () {
    expect(presetsFor('Food').map((p) => p.name), [
      'Portion',
      'Spice',
      'Serves',
    ]);
    expect(
      presetsFor('Electronics').map((p) => p.name).contains('Storage'),
      isTrue,
    );
    // Unknown department still gets something to tap.
    expect(presetsFor('').isNotEmpty, isTrue);
  });
}

/// The indexed departmentOf has to answer exactly what the walk it replaced
/// answered, including where a name sits under two departments — the walk
/// returned the first, so the index must too.
void _departmentIndexMatchesTheWalk() {
  String walk(String category) {
    for (final d in departments) {
      if (d.name == 'All') continue;
      if (d.name == category) return d.name;
      for (final c in d.categories) {
        if (c.name == category || c.leaves.contains(category)) return d.name;
      }
    }
    return '';
  }

  final names = <String>{
    for (final d in departments) ...[
      d.name,
      for (final c in d.categories) ...[c.name, ...c.leaves],
    ],
    'Nothing In Particular',
    '',
  };
  for (final name in names) {
    expect(departmentOf(name), walk(name), reason: 'departmentOf("$name")');
  }
}
