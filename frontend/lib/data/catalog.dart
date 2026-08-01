import '../models/product.dart';
import 'api.dart';

/// The catalog the app is currently showing — live rows once they load, the
/// bundled samples before that.
///
/// Screens that look a product up by id have to read this rather than the
/// bundled list: the two do not hold the same products, so filtering the
/// bundled one silently drops anything that exists only on the server. That
/// is what made the wishlist look broken.
List<Product> shownCatalog = products;

/// Catalog from the Go API, falling back to the bundled sample data when the
/// backend is unreachable — the app stays usable offline and in tests.
Future<List<Product>> loadCatalog() async {
  try {
    final live = await Api.instance.products();
    if (live.isNotEmpty) {
      shownCatalog = live;
      return live;
    }
  } catch (e) {
    logApiFailure('products', e);
  }
  shownCatalog = products;
  return products;
}

/// Shops from the API, same fallback.
Future<List<Shop>> loadShops() async {
  try {
    final live = await Api.instance.shops();
    if (live.isNotEmpty) return live;
  } catch (e) {
    logApiFailure('shops', e);
  }
  return shops;
}

/// Everything a shop sells: its own listings, plus items it stocks that are
/// listed elsewhere — each priced at this shop's price.
List<Product> productsAtShop(String shopName) {
  final out = <Product>[];
  for (final p in products) {
    if (p.store == shopName) {
      out.add(p);
      continue;
    }
    for (final o in p.offers) {
      if (o.store != shopName) continue;
      out.add(Product(
        id: '${p.id}@$shopName',
        name: p.name,
        category: p.category,
        tab: p.tab,
        price: o.price,
        imageUrl: p.imageUrl,
        store: shopName,
        description: p.description,
        sizes: p.sizes,
        extraImages: p.extraImages,
        // Compare against the original listing and the other vendors.
        offers: [
          ShopOffer(p.store, p.price),
          ...p.offers.where((x) => x.store != shopName),
        ],
      ));
      break;
    }
  }
  return out;
}

/// Unsplash sizes images from the query string, so asking for a thumbnail
/// costs a fraction of the full photo. ponytail: string swap, no image
/// pipeline — works because every catalog URL carries ?w=.
String thumb(String url, int width) =>
    url.replaceFirst(RegExp(r'w=\d+'), 'w=$width');

// ponytail: static location/ETA. Wire to geolocation + a delivery API when
// one exists; only these three strings change.
const deliveryEta = '12 mins';
const userLocation = 'Lovely Professional University, Punjab';
const storeDistance = '900 m';

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
  Shop(
    name: 'Biryani House',
    tagline: 'Authentic dum biryani',
    imageUrl:
        'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=400',
    tab: 'Food',
  ),
  Shop(
    name: 'Cafe Brew',
    tagline: 'Coffee, shakes & snacks',
    imageUrl:
        'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=400',
    tab: 'Food',
  ),
  Shop(
    name: 'Nature Fresh',
    tagline: 'Organic staples & dairy',
    imageUrl:
        'https://images.unsplash.com/photo-1488459716781-31db52582fe9?w=400',
    tab: 'Grocery',
  ),
  Shop(
    name: 'ToyVerse',
    tagline: 'Figures, toys & collectibles',
    imageUrl:
        'https://images.unsplash.com/photo-1558679908-541bcf1249ff?w=400',
    tab: 'Gifts',
  ),
];

// Prices in INR. Each product carries its own description and, where other
// shops stock the same item, their prices for comparison.
const products = [
  Product(
    id: 'p1',
    name: 'Brown Denim Jacket',
    category: "Men's outfit",
    price: 1799,
    imageUrl:
        'https://images.unsplash.com/photo-1551028719-00167b16eac5?w=600',
    description:
        'Classic brown denim jacket with a button front, twin chest pockets '
        'and soft cotton lining. Fits true to size for everyday layering.',
    sizes: ['S', 'M', 'L', 'XL'],
    offers: [
      ShopOffer('Urban Threads', 1649),
      ShopOffer('Velora Store', 1899),
    ],
  ),
  Product(
    id: 'p2',
    name: 'Grey Casual Shoe',
    category: 'Men Footwear',
    price: 999,
    imageUrl:
        'https://images.unsplash.com/photo-1525966222134-fcfa99b8ae77?w=600',
    store: 'Velora Store',
    description:
        'Lightweight slip-on casual shoe in grey canvas with a cushioned '
        'insole and flexible rubber sole. Easy to pair with any outfit.',
    sizes: ['S', 'M', 'L', 'XL'],
    offers: [
      ShopOffer('Urban Threads', 1099),
      ShopOffer('Lamazon Store', 949),
    ],
  ),
  Product(
    id: 'p3',
    name: "Men's Pullover Hoodie",
    category: "Men's outfit",
    price: 1499,
    imageUrl:
        'https://images.unsplash.com/photo-1556821840-3a63f95609a7?w=600',
    description:
        'Cozy fleece pullover hoodie with a kangaroo pocket and adjustable '
        'drawstrings. Brushed inner for warmth without the bulk.',
    sizes: ['XS', 'S', 'M', 'L', 'XL', 'XXL'],
    extraImages: [
      'https://images.unsplash.com/photo-1620799140408-edc6dcb6d633?w=300',
      'https://images.unsplash.com/photo-1618354691373-d851c5c3a990?w=300',
      'https://images.unsplash.com/photo-1556821840-3a63f95609a7?w=300',
    ],
    offers: [
      ShopOffer('Urban Threads', 1399),
      ShopOffer('Velora Store', 1599),
    ],
  ),
  Product(
    id: 'p4',
    name: 'Classic White Sneakers',
    category: 'Men Footwear',
    price: 799,
    imageUrl:
        'https://images.unsplash.com/photo-1600185365926-3a2ce3cdb9eb?w=600',
    description:
        'Minimal white low-top sneakers with a durable outsole and padded '
        'collar. A wardrobe staple that goes with everything.',
    sizes: ['M', 'L', 'XL'],
    offers: [
      ShopOffer('Velora Store', 899),
    ],
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
    description:
        'Over-ear wireless headphones with 40mm drivers, 30-hour battery '
        'life and a built-in mic for calls. Bluetooth 5.3, USB-C charging.',
    offers: [
      ShopOffer('TechnoWorld', 2799),
    ],
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
    description:
        'Fitness smartwatch with heart-rate and sleep tracking, 1.4" AMOLED '
        'display and 7-day battery. Water resistant to 5 ATM.',
    offers: [
      ShopOffer('TechnoWorld', 4299),
    ],
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
    description:
        'Seasonal mix of 6-8 fresh fruits — apples, oranges, kiwi, grapes '
        'and more. Hand-picked the same morning it ships.',
    offers: [
      ShopOffer('Daily Basket', 599),
      ShopOffer('Nature Fresh', 529),
    ],
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
    description:
        'Weekly box of certified-organic vegetables: potatoes, onions, '
        'tomatoes, leafy greens and seasonal picks. Pesticide-free.',
    offers: [
      ShopOffer('Daily Basket', 379),
      ShopOffer('Nature Fresh', 419),
    ],
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
    description:
        'Wood-fired pizza loaded with capsicum, onion, corn, mushroom and '
        'mozzarella on a hand-stretched base. Serves 2.',
    offers: [
      ShopOffer('Cafe Brew', 379),
    ],
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
    description:
        'Double-patty burger with cheese, lettuce and house sauce, served '
        'with fries and a cold drink.',
    offers: [
      ShopOffer('Cafe Brew', 269),
    ],
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
    description:
        'Curated hamper with chocolates, scented candle, dry fruits and a '
        'greeting card, wrapped in a reusable keepsake box.',
    offers: [
      ShopOffer('Petal & Co', 1399),
    ],
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
    description:
        'Set of 4 matte lipsticks in everyday shades. Long-stay, transfer-'
        'proof formula enriched with vitamin E.',
    offers: [
      ShopOffer('Velvet Touch', 949),
    ],
  ),
  Product(
    id: 'p13',
    name: 'Paneer Dum Biryani',
    category: 'Biryani',
    tab: 'Food',
    price: 299,
    imageUrl:
        'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=600',
    store: 'Biryani House',
    description:
        'Slow-cooked basmati rice layered with spiced paneer, saffron and '
        'fried onions. Comes with raita and salan.',
    offers: [
      ShopOffer('Spice Kitchen', 329),
    ],
  ),
  Product(
    id: 'p14',
    name: 'Cold Coffee & Brownie',
    category: 'Beverages',
    tab: 'Food',
    price: 189,
    imageUrl:
        'https://images.unsplash.com/photo-1461023058943-07fcbe16d735?w=600',
    store: 'Cafe Brew',
    description:
        'Thick cold coffee blended with ice cream, paired with a warm '
        'chocolate brownie.',
  ),
  Product(
    id: 'p15',
    name: 'Chocolate Truffle Cake',
    category: 'Desserts',
    tab: 'Food',
    price: 549,
    imageUrl:
        'https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=600',
    store: 'Sweet Tooth',
    description:
        'Half-kg dark chocolate truffle cake with layered ganache. Eggless '
        'option available; delivered chilled.',
    offers: [
      ShopOffer('Cafe Brew', 599),
    ],
  ),
  Product(
    id: 'p16',
    name: 'Anime Action Figure',
    category: 'Collectibles',
    tab: 'Gifts',
    price: 799,
    imageUrl:
        'https://images.unsplash.com/photo-1608889175123-8ee362201f81?w=600',
    store: 'ToyVerse',
    description:
        '16cm collectible action figure with articulated joints and display '
        'stand. Official licensed merchandise.',
    offers: [
      ShopOffer('Wrap & Give', 849),
    ],
  ),
  Product(
    id: 'p17',
    name: 'Classic Analog Watch',
    category: 'Watches',
    tab: 'Gifts',
    price: 1999,
    imageUrl:
        'https://images.unsplash.com/photo-1524592094714-0f0654e20314?w=600',
    store: 'Wrap & Give',
    description:
        'Minimal analog watch with a stainless-steel case, leather strap '
        'and Japanese quartz movement. Gift box included.',
    offers: [
      ShopOffer('ToyVerse', 2199),
    ],
  ),
  Product(
    id: 'p18',
    name: 'Scented Candle Set',
    category: 'Home',
    tab: 'Gifts',
    price: 499,
    imageUrl:
        'https://images.unsplash.com/photo-1602874801007-bd458bb1b8b6?w=600',
    store: 'Petal & Co',
    description:
        'Set of 3 soy-wax candles — vanilla, lavender and sandalwood. '
        '25-hour burn time each, in reusable glass jars.',
    offers: [
      ShopOffer('Wrap & Give', 549),
    ],
  ),
  Product(
    id: 'p19',
    name: 'Teddy Bear (Large)',
    category: 'Soft Toys',
    tab: 'Gifts',
    price: 599,
    imageUrl:
        'https://images.unsplash.com/photo-1562040506-a9b32cb51b94?w=600',
    store: 'ToyVerse',
    description:
        '90cm plush teddy bear in ultra-soft fur with embroidered eyes. '
        'Machine washable and safe for all ages.',
  ),
  Product(
    id: 'p20',
    name: 'Fresh Milk 1L',
    category: 'Dairy',
    tab: 'Grocery',
    price: 68,
    imageUrl:
        'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=600',
    store: 'Nature Fresh',
    description:
        'Farm-fresh full-cream milk, pasteurised and packed the same day. '
        'No preservatives.',
    offers: [
      ShopOffer('FreshMart', 66),
      ShopOffer('Daily Basket', 70),
    ],
  ),
  Product(
    id: 'p21',
    name: 'Multigrain Bread',
    category: 'Bakery',
    tab: 'Grocery',
    price: 45,
    imageUrl:
        'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=600',
    store: 'Daily Basket',
    description:
        'Freshly baked multigrain loaf with oats, flax and sunflower seeds. '
        'Baked daily, zero maida.',
    offers: [
      ShopOffer('Nature Fresh', 48),
    ],
  ),
  Product(
    id: 'p22',
    name: 'Basmati Rice 5kg',
    category: 'Staples',
    tab: 'Grocery',
    price: 499,
    imageUrl:
        'https://images.unsplash.com/photo-1586201375761-83865001e31c?w=600',
    store: 'Nature Fresh',
    description:
        'Aged long-grain basmati rice with rich aroma. Ideal for biryani '
        'and pulao; 5kg vacuum pack.',
    offers: [
      ShopOffer('FreshMart', 529),
      ShopOffer('Daily Basket', 479),
    ],
  ),
  Product(
    id: 'p23',
    name: 'Farm Eggs (12)',
    category: 'Dairy',
    tab: 'Grocery',
    price: 96,
    imageUrl:
        'https://images.unsplash.com/photo-1506976785307-8732e854ad03?w=600',
    store: 'Daily Basket',
    description:
        'Dozen free-range brown eggs from certified farms, graded and '
        'packed within 24 hours.',
    offers: [
      ShopOffer('Nature Fresh', 102),
    ],
  ),
];
