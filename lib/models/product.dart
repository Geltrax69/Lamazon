class Product {
  final String id;
  final String name;
  final String category;
  final String tab; // which top tab this belongs to; 'All' tab shows everything
  final double price;
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
    required this.imageUrl,
    this.store = 'Lamazon Store',
    required this.description,
    this.sizes = const [],
    this.extraImages = const [],
    this.offers = const [],
  });
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
