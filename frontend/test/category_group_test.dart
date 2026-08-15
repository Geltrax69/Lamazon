import 'package:flutter_test/flutter_test.dart';
import 'package:lamazon/data/categories.dart';
import 'package:lamazon/screens/seller_product_screen.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

void main() {
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
