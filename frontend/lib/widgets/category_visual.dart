import 'package:flutter/material.dart';
import 'design_system.dart';
import 'product_card.dart';
import '../data/catalog.dart';
import '../data/categories.dart';
import '../models/product.dart';

/// Bundled category artwork fills missing navigation images, never merchandise.
class CategoryVisual extends StatelessWidget {
  final String name, imageUrl;
  const CategoryVisual({super.key, required this.name, this.imageUrl = ''});
  static int indexFor(String name) {
    final n = name.toLowerCase();
    if (RegExp('groc|vegetable|fruit|rice|dairy|milk|oil').hasMatch(n)) {
      return 1;
    }
    if (RegExp('snack|drink|cookie|juice|beverage').hasMatch(n)) return 7;
    if (RegExp('station|game|book|paper|pen').hasMatch(n)) return 6;
    if (RegExp('house|clean|kitchen|detergent').hasMatch(n)) return 5;
    if (RegExp('beauty|skin|hair|care|cosmetic').hasMatch(n)) return 4;
    if (RegExp('gift|flower|decor').hasMatch(n)) return 3;
    if (RegExp('electro|headphone|cable|charger|phone|audio').hasMatch(n)) {
      return 2;
    }
    if (RegExp('groc|vegetable|fruit|rice|dairy|milk|oil').hasMatch(n)) {
      return 1;
    }
    final parent = departmentOf(name);
    if (parent.isNotEmpty && parent != name) return indexFor(parent);
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isNotEmpty) {
      return NetImage(url: imageUrl, semanticLabel: name);
    }
    // The atlas holds one picture per department, so every category under one
    // resolves to the same cell. On a department tile that is right; on a grid
    // of six shelves it drew the same photograph six times, which says nothing
    // and reads as broken. A plate says "no artwork yet" honestly, and shows
    // the admin exactly which shelves still need one.
    final parent = departmentOf(name);
    if (parent.isNotEmpty && parent != name) {
      // Before falling back, look for something the shop actually sells on
      // this shelf. A real product photograph is both truer and better looking
      // than any stand-in, and these fill themselves in as stock arrives.
      final stocked = shownCatalog.firstWhere(
        (p) =>
            p.category == name &&
            p.imageUrl.trim().isNotEmpty &&
            p.availableStock != 0,
        orElse: () => const Product(
          id: '',
          name: '',
          category: '',
          price: 0,
          imageUrl: '',
          description: '',
        ),
      );
      if (stocked.imageUrl.trim().isNotEmpty) {
        return NetImage(url: stocked.imageUrl, semanticLabel: name);
      }
      return _Plate(name: name, parent: parent);
    }
    final i = indexFor(name);
    return Semantics(
      image: true,
      label: '$name category',
      child: ClipRect(
        child: LayoutBuilder(
          builder: (_, c) => OverflowBox(
            alignment: Alignment.topLeft,
            maxWidth: c.maxWidth * 4,
            maxHeight: c.maxHeight * 2,
            child: Transform.translate(
              offset: Offset(-(i % 4) * c.maxWidth, -(i ~/ 4) * c.maxHeight),
              child: Image.asset(
                'assets/categories/category-atlas-v2.png',
                width: c.maxWidth * 4,
                height: c.maxHeight * 2,
                fit: BoxFit.fill,
                excludeFromSemantics: true,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Stands in for a shelf the shop has not photographed yet.
class _Plate extends StatelessWidget {
  final String name, parent;
  const _Plate({required this.name, required this.parent});

  @override
  Widget build(BuildContext context) {
    final department = departments.firstWhere(
      (d) => d.name == parent,
      orElse: () => allDepartment,
    );
    return Semantics(
      image: true,
      label: '$name category',
      // Forest and lime, like the still-life artwork it sits beside, so a
      // shelf without a photograph reads as part of the set rather than as a
      // hole in it. A repeated texture is fine where a repeated photograph is
      // not: it depicts nothing, so it claims nothing.
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [LamazonTheme.forest, LamazonTheme.strong],
          ),
        ),
        child: Center(
          child: Icon(
            department.icon,
            size: 28,
            color: LamazonTheme.lime.withValues(alpha: .82),
          ),
        ),
      ),
    );
  }
}
