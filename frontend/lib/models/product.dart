class Product {
  final String id;
  final String name;
  final String category;
  final String tab; // which top tab this belongs to; 'All' tab shows everything
  final double price;
  /// Price before the discount. Zero means the seller is not running one.
  final double mrp;
  final String imageUrl; // any web image link works here
  final String store;
  final String description;
  final List<String> sizes;
  final List<String> extraImages;
  final List<ShopOffer> offers; // same product priced at other shops
  /// What the shop asks the buyer to choose. Empty for most things.
  final List<ItemOption> options;

  const Product({
    required this.id,
    required this.name,
    required this.category,
    this.tab = 'All',
    required this.price,
    this.mrp = 0,
    required this.imageUrl,
    this.store = 'Lamazon Store',
    required this.description,
    this.sizes = const [],
    this.extraImages = const [],
    this.offers = const [],
    this.options = const [],
  });

  /// True only when there is a real saving to show. An MRP equal to the price
  /// is a sale the seller has ended, not a 0% one worth a badge.
  bool get discounted => mrp > price;

  /// Whole percent off, rounded the way a shopper reads it. 199 from 249 is
  /// "20% off", not "20.08%".
  int get discountPercent =>
      discounted ? (((mrp - price) / mrp) * 100).round() : 0;

  /// What the shopper picks. The bundled catalogue predates option groups and
  /// carries a plain [sizes] list; rather than leave that data stranded, it
  /// becomes a Size group so both kinds of product render through one path.
  List<ItemOption> get choices => options.isNotEmpty
      ? options
      : sizes.isEmpty
      ? const []
      : [ItemOption(name: 'Size', values: sizes)];
}

/// One thing a buyer picks before ordering, and the choices the shop offers.
/// [kind] is 'colour' when the values are hex and should draw as swatches.
class ItemOption {
  final String name;
  final String kind;
  final List<String> values;
  const ItemOption({
    required this.name,
    this.kind = 'text',
    this.values = const [],
  });

  bool get isColour => kind == 'colour';

  factory ItemOption.fromJson(Map<String, dynamic> r) => ItemOption(
    name: r['name'] as String? ?? '',
    kind: r['kind'] as String? ?? 'text',
    values: (r['values'] as List<dynamic>? ?? const []).cast<String>(),
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'kind': kind,
    'values': values,
  };
}

class ShopOffer {
  final String store;
  final double price;
  const ShopOffer(this.store, this.price);
}

class Shop {
  final String name;
  final String tagline;
  final String imageUrl;
  final String tab;

  const Shop({
    required this.name,
    required this.tagline,
    required this.imageUrl,
    this.tab = 'All',
  });
}
