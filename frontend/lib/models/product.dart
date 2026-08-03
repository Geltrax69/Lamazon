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
  });

  /// True only when there is a real saving to show. An MRP equal to the price
  /// is a sale the seller has ended, not a 0% one worth a badge.
  bool get discounted => mrp > price;

  /// Whole percent off, rounded the way a shopper reads it. 199 from 249 is
  /// "20% off", not "20.08%".
  int get discountPercent =>
      discounted ? (((mrp - price) / mrp) * 100).round() : 0;
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
