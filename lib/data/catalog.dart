import '../models/product.dart';

// ponytail: local data behind a Future so every screen gets real
// loading/error/success states now, and swapping in an API later
// changes only this function.
Future<List<Product>> loadCatalog() async {
  await Future.delayed(const Duration(milliseconds: 600));
  return products;
}

// Promoted shops, shown in "Shop By Shop". Tag with a tab name to only
// show them for that category; 'All' shows everywhere.
const shops = [
  Shop(
    name: 'Velora Store',
    tagline: 'Trendy fashion, up to 40% off',
    imageUrl:
        'https://images.unsplash.com/photo-1441986300917-64674bd600d8?w=400',
  ),
  Shop(
    name: 'GadgetHub',
    tagline: 'Latest electronics & audio',
    imageUrl:
        'https://images.unsplash.com/photo-1498049794561-7780e7231661?w=400',
    tab: 'Electronics',
  ),
  Shop(
    name: 'FreshMart',
    tagline: 'Farm-fresh groceries daily',
    imageUrl:
        'https://images.unsplash.com/photo-1542838132-92c53300491e?w=400',
    tab: 'Grocery',
  ),
  Shop(
    name: 'Spice Kitchen',
    tagline: 'Hot meals in 30 min',
    imageUrl:
        'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=400',
    tab: 'Food',
  ),
  Shop(
    name: 'Wrap & Give',
    tagline: 'Gifts for every occasion',
    imageUrl:
        'https://images.unsplash.com/photo-1513201099705-a9746e1e201f?w=400',
    tab: 'Gifts',
  ),
  Shop(
    name: 'GlowUp',
    tagline: 'Skincare & makeup essentials',
    imageUrl:
        'https://images.unsplash.com/photo-1596462502278-27bfdc403348?w=400',
    tab: 'Beauty',
  ),
  Shop(
    name: 'Urban Threads',
    tagline: 'Streetwear new drops weekly',
    imageUrl:
        'https://images.unsplash.com/photo-1567401893414-76b7b1e5a7a5?w=400',
  ),
  Shop(
    name: 'TechnoWorld',
    tagline: 'Phones, laptops & accessories',
    imageUrl:
        'https://images.unsplash.com/photo-1531297484001-80022131f5a1?w=400',
    tab: 'Electronics',
  ),
  Shop(
    name: 'Daily Basket',
    tagline: 'Groceries delivered in minutes',
    imageUrl:
        'https://images.unsplash.com/photo-1578916171728-46686eac8d58?w=400',
    tab: 'Grocery',
  ),
  Shop(
    name: 'Sweet Tooth',
    tagline: 'Cakes, desserts & bakes',
    imageUrl:
        'https://images.unsplash.com/photo-1551024506-0bccd828d307?w=400',
    tab: 'Food',
  ),
  Shop(
    name: 'Petal & Co',
    tagline: 'Flowers & handmade gifts',
    imageUrl:
        'https://images.unsplash.com/photo-1490750967868-88aa4486c946?w=400',
    tab: 'Gifts',
  ),
  Shop(
    name: 'Velvet Touch',
    tagline: 'Luxury fragrances & care',
    imageUrl:
        'https://images.unsplash.com/photo-1541643600914-78b084683601?w=400',
    tab: 'Beauty',
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
  Product(
    id: 'p5',
    name: 'Wireless Headphones',
    category: 'Audio',
    tab: 'Electronics',
    price: 2999,
    imageUrl:
        'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=600',
    store: 'GadgetHub',
  ),
  Product(
    id: 'p6',
    name: 'Smart Watch',
    category: 'Wearables',
    tab: 'Electronics',
    price: 4499,
    imageUrl:
        'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=600',
    store: 'GadgetHub',
  ),
  Product(
    id: 'p7',
    name: 'Fresh Fruit Basket',
    category: 'Fruits',
    tab: 'Grocery',
    price: 549,
    imageUrl:
        'https://images.unsplash.com/photo-1610832958506-aa56368176cf?w=600',
    store: 'FreshMart',
  ),
  Product(
    id: 'p8',
    name: 'Organic Vegetables Box',
    category: 'Vegetables',
    tab: 'Grocery',
    price: 399,
    imageUrl:
        'https://images.unsplash.com/photo-1518977676601-b53f82aba655?w=600',
    store: 'FreshMart',
  ),
  Product(
    id: 'p9',
    name: 'Farmhouse Pizza',
    category: 'Fast Food',
    tab: 'Food',
    price: 349,
    imageUrl:
        'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=600',
    store: 'Spice Kitchen',
  ),
  Product(
    id: 'p10',
    name: 'Classic Burger Meal',
    category: 'Fast Food',
    tab: 'Food',
    price: 249,
    imageUrl:
        'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=600',
    store: 'Spice Kitchen',
  ),
  Product(
    id: 'p11',
    name: 'Premium Gift Hamper',
    category: 'Hampers',
    tab: 'Gifts',
    price: 1299,
    imageUrl:
        'https://images.unsplash.com/photo-1549465220-1a8b9238cd48?w=600',
    store: 'Wrap & Give',
  ),
  Product(
    id: 'p12',
    name: 'Lipstick Gift Set',
    category: 'Makeup',
    tab: 'Beauty',
    price: 899,
    imageUrl:
        'https://images.unsplash.com/photo-1586495777744-4413f21062fa?w=600',
    store: 'GlowUp',
  ),
];
