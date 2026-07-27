import '../models/product.dart';

// ponytail: static catalog. Paste any image links / shop links below and the
// UI renders them. Swap for an API/scraper later if it ever exists.

const categories = [
  Category(
    name: "Men's outfit",
    imageUrl:
        'https://images.unsplash.com/photo-1617137968427-85924c800a22?w=200',
  ),
  Category(
    name: "Woman's outfit",
    imageUrl:
        'https://images.unsplash.com/photo-1618244972963-dbee1a7edc95?w=200',
  ),
  Category(
    name: "Men's footwear",
    imageUrl:
        'https://images.unsplash.com/photo-1549298916-b41d501d3772?w=200',
  ),
  Category(
    name: 'Grocery',
    imageUrl:
        'https://images.unsplash.com/photo-1542838132-92c53300491e?w=200',
  ),
];

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
