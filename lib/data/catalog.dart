import '../models/product.dart';

// ponytail: static catalog. Paste any image links / shop links below and the
// UI renders them. Swap for an API/scraper later if it ever exists.

// ponytail: local data behind a Future so every screen gets real
// loading/error/success states now, and swapping in an API later
// changes only this function.
Future<List<Product>> loadCatalog() async {
  await Future.delayed(const Duration(milliseconds: 600));
  return products;
}

// Prices in INR.
const products = [
  Product(
    id: 'p1',
    name: 'Brown Denim Jacket',
    category: "Men's outfit",
    price: 1799,
    imageUrl:
        'https://images.unsplash.com/photo-1551028719-00167b16eac5?w=600',
    sizes: ['S', 'M', 'L', 'XL'],
  ),
  Product(
    id: 'p2',
    name: 'Grey Casual Shoe',
    category: 'Men Footwear',
    price: 999,
    imageUrl:
        'https://images.unsplash.com/photo-1525966222134-fcfa99b8ae77?w=600',
    store: 'Velora Store',
    sizes: ['S', 'M', 'L', 'XL'],
  ),
  Product(
    id: 'p3',
    name: "Men's Pullover Hoodie",
    category: "Men's outfit",
    price: 1499,
    imageUrl:
        'https://images.unsplash.com/photo-1556821840-3a63f95609a7?w=600',
    sizes: ['XS', 'S', 'M', 'L', 'XL', 'XXL'],
  ),
  Product(
    id: 'p4',
    name: 'Classic White Sneakers',
    category: 'Men Footwear',
    price: 799,
    imageUrl:
        'https://images.unsplash.com/photo-1600185365926-3a2ce3cdb9eb?w=600',
    sizes: ['M', 'L', 'XL'],
  ),
];
