import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'api.dart';

/// One department across the top of the shop, with the categories filed under
/// it. The admin decides what these are; the app only draws them.
class Department {
  final String name;
  final IconData icon;

  /// null is the plain white theme the All tab uses.
  final Color? colour;
  final List<CategoryNode> categories;

  const Department(this.name, this.icon, this.colour,
      [this.categories = const []]);
}

/// A category inside a department, with whatever sits inside it. A food menu
/// goes three deep — Food, Street Food, Chaat — so this nests rather than
/// being a flat list of names.
class CategoryNode {
  final String name;
  final List<CategoryNode> children;
  const CategoryNode(this.name, [this.children = const []]);

  factory CategoryNode.fromJson(Map<String, dynamic> r) => CategoryNode(
    r['name'] as String? ?? '',
    [
      for (final c in (r['children'] as List<dynamic>? ?? const []))
        CategoryNode.fromJson(c as Map<String, dynamic>),
    ],
  );

  /// The names a product can actually be filed under: the deepest level, or
  /// this one when it has nothing inside it. A seller picking "Street Food"
  /// when Chaat and Samosa exist is picking the shelf, not the item.
  List<String> get leaves =>
      children.isEmpty ? [name] : [for (final c in children) ...c.leaves];
}

/// The All tab is not a row in the database. It is the absence of a filter,
/// so an admin can neither rename it nor delete it by accident.
const allDepartment = Department('All', LucideIcons.layoutGrid, null);

/// What the app shipped with. Used until the server answers, and if it never
/// does — a shop with no navigation is worse than a shop with last year's.
const fallbackDepartments = [
  allDepartment,
  Department('Electronics', LucideIcons.headphones, Color(0xFF2F6FED)),
  Department('Grocery', LucideIcons.carrot, Color(0xFF43A047)),
  Department('Food', LucideIcons.utensils, Color(0xFFFF8A3D)),
  Department('Gifts', LucideIcons.gift, Color(0xFF9C6ADE)),
  Department('Beauty', LucideIcons.brush, Color(0xFFF06292)),
];

/// The departments the app is currently showing, All first.
List<Department> departments = fallbackDepartments;

/// Icons cannot be stored as data — Flutter tree-shakes anything it cannot see
/// referenced, so a name assembled at runtime would render a blank box. The
/// admin picks from this set, and the keys are what the database holds.
const departmentIcons = <String, IconData>{
  'headphones': LucideIcons.headphones,
  'carrot': LucideIcons.carrot,
  'utensils': LucideIcons.utensils,
  'gift': LucideIcons.gift,
  'brush': LucideIcons.brush,
  'shirt': LucideIcons.shirt,
  'house': LucideIcons.house,
  'book': LucideIcons.bookOpen,
  'dumbbell': LucideIcons.dumbbell,
  'baby': LucideIcons.baby,
  'pill': LucideIcons.pill,
  'wrench': LucideIcons.wrench,
  'cookie': LucideIcons.cookie,
  'sprayCan': LucideIcons.sprayCan,
  'cable': LucideIcons.cable,
  'tag': LucideIcons.tag,
};

IconData iconNamed(String key) => departmentIcons[key] ?? LucideIcons.tag;

Color? _colourOf(String hex) {
  final clean = hex.replaceFirst('#', '').trim();
  if (clean.length != 6) return null;
  final value = int.tryParse(clean, radix: 16);
  return value == null ? null : Color(0xFF000000 | value);
}

/// Reads the navigation from the server. Falls back to the bundled list, the
/// same way the catalog does, so the shop still opens when the API is down.
Future<List<Department>> loadDepartments() async {
  try {
    final rows = await Api.instance.categories();
    if (rows.isNotEmpty) {
      departments = [
        allDepartment,
        for (final r in rows)
          Department(
            r['name'] as String,
            iconNamed(r['icon'] as String? ?? ''),
            _colourOf(r['colour'] as String? ?? ''),
            [
              for (final c in (r['children'] as List<dynamic>? ?? const []))
                CategoryNode.fromJson(c as Map<String, dynamic>),
            ],
          ),
      ];
      return departments;
    }
  } catch (e) {
    logApiFailure('categories', e);
  }
  return departments;
}

/// Everything a seller can file an item under: the categories an admin has
/// created, or the department itself when it has none yet. Without that
/// fallback a brand-new department would be unsellable in.
List<String> sellableCategories([String? department]) {
  final out = <String>[];
  for (final d in departments) {
    if (d.name == 'All') continue;
    if (department != null && d.name != department) continue;
    out.addAll(
      d.categories.isEmpty
          ? [d.name]
          : [for (final c in d.categories) ...c.leaves],
    );
  }
  return out;
}

/// The sections of a department, in order, for anything that shows the menu
/// rather than the things on it.
List<CategoryNode> sectionsOf(String department) =>
    departments
        .firstWhere(
          (d) => d.name == department,
          orElse: () => const Department('', LucideIcons.tag, null),
        )
        .categories;
