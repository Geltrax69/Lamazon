class Product {
  final String id;
  final String name;
  final String category;
  final double price;
  final String imageUrl; // any web image link works here
  final String store;
  final List<String> sizes;
  final List<String> extraImages;

  const Product({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.imageUrl,
    this.store = 'Lamazon Store',
    this.sizes = const [],
    this.extraImages = const [],
  });
}

class Category {
  final String name;
  final String imageUrl;
  const Category({required this.name, required this.imageUrl});
}
