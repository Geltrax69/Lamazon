import 'package:flutter/material.dart';
import 'product_card.dart';
import '../data/categories.dart';

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
                'assets/categories/category-atlas.png',
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
