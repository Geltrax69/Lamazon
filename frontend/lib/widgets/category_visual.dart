import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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
            // The category's own glyph, not its department's. Keying on the
            // department gave every shelf under one the same picture, so
            // "Toys & Games" and "Glue & Tape" both showed a book — forty
            // tiles carrying no information and actively misleading.
            glyphFor(name, fallback: department.icon),
            size: 28,
            color: LamazonTheme.lime.withValues(alpha: .82),
          ),
        ),
      ),
    );
  }
}


/// A glyph for one category, chosen from its name.
///
/// Keyword matching rather than a fixed table: categories are created by
/// admins at runtime, so any table would be stale the first time somebody
/// adds a shelf. [fallback] is the department's icon, used when nothing in
/// the name is recognisable — which is honest, where showing a book for
/// adhesive tape was not.
IconData glyphFor(String category, {required IconData fallback}) {
  final n = category.toLowerCase();
  for (final (pattern, icon) in _glyphs) {
    if (RegExp(pattern).hasMatch(n)) return icon;
  }
  return fallback;
}

/// Ordered: the first match wins, so put the specific before the general.
/// "Baby food" should be a baby, not a plate.
const _glyphs = <(String, IconData)>[
  (r'baby|infant|diaper', LucideIcons.baby),
  (r'toy|game|puzzle|play', LucideIcons.gamepad2),
  (r'glue|tape|adhesive|stapler|scissor', LucideIcons.paperclip),
  (r'pen|pencil|marker|ink', LucideIcons.penLine),
  (r'notebook|book|diary|paper|register', LucideIcons.bookOpen),
  (r'station|office|craft', LucideIcons.pencilRuler),
  (r'tea|coffee|chai', LucideIcons.coffee),
  (r'juice|drink|beverage|soda|water|cola', LucideIcons.cupSoda),
  (r'snack|chips|namkeen|biscuit|cookie|wafer', LucideIcons.cookie),
  (r'chocolate|candy|sweet|dessert|ice ?cream', LucideIcons.candy),
  (r'bread|bakery|cake|pastry|bun', LucideIcons.croissant),
  (r'milk|dairy|curd|cheese|butter|paneer|yog', LucideIcons.milk),
  (r'egg', LucideIcons.egg),
  (r'fruit|apple|banana|mango', LucideIcons.apple),
  (r'vegetable|veggie|sabzi|salad|green', LucideIcons.carrot),
  (r'rice|atta|flour|grain|pulse|dal|masala|spice|oil', LucideIcons.wheat),
  (r'meat|chicken|fish|egg|seafood', LucideIcons.drumstick),
  (r'pizza', LucideIcons.pizza),
  (r'burger|sandwich|roll|wrap', LucideIcons.sandwich),
  (r'biryani|meal|thali|lunch|dinner|food|restaurant', LucideIcons.utensils),
  (r'groc|kirana|essential|store cupboard', LucideIcons.shoppingBasket),
  (r'headphone|earphone|audio|speaker|sound', LucideIcons.headphones),
  (r'charger|cable|power ?bank|adapter|batter', LucideIcons.cable),
  (r'mobile|phone|smartphone', LucideIcons.smartphone),
  (r'laptop|computer|pc', LucideIcons.laptop),
  (r'watch|wearable|band|fitness', LucideIcons.watch),
  (r'camera|photo', LucideIcons.camera),
  (r'electro|gadget|tech|accessor', LucideIcons.plug),
  (r'skin|face|cream|lotion|moistur', LucideIcons.sparkles),
  (r'hair|shampoo|oil ?hair', LucideIcons.scissors),
  (r'makeup|lipstick|cosmetic|nail', LucideIcons.brush),
  (r'soap|bath|hygiene|dental|tooth|razor|shav', LucideIcons.droplets),
  (r'beauty|fragrance|perfume|deo', LucideIcons.flower2),
  (r'clean|detergent|wash|mop|broom|dish', LucideIcons.sprayCan),
  (r'kitchen|utensil|cookware|pan|bottle|container', LucideIcons.cookingPot),
  (r'house|home|furnish|decor ?home|storage', LucideIcons.house),
  (r'light|bulb|lamp|candle', LucideIcons.lightbulb),
  (r'gift|hamper|card|wrap ?gift', LucideIcons.gift),
  (r'flower|plant|bouquet|garden', LucideIcons.flower),
  (r'decor|party|balloon|festive', LucideIcons.partyPopper),
  (r'cloth|shirt|outfit|apparel|wear|dress|fashion', LucideIcons.shirt),
  (r'shoe|footwear|sandal|slipper|sneaker', LucideIcons.footprints),
  (r'bag|backpack|luggage|wallet', LucideIcons.backpack),
  (r'medicine|pharma|health|first ?aid|tablet', LucideIcons.pill),
  (r'pet|dog|cat', LucideIcons.pawPrint),
  (r'sport|gym|fitness|cricket|ball', LucideIcons.dumbbell),
  (r'stap|hardware|tool|repair', LucideIcons.wrench),
];
