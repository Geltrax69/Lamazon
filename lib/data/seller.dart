import 'package:flutter/foundation.dart';

/// What a seller can list under, mirroring the shopper-side tabs.
const sellCategories = [
  'Electronics',
  'Clothes',
  'Stationary',
  'Gifts',
  'Food',
  'Grocery',
];

/// Below this many units an item is flagged for restocking.
const lowStockAt = 5;

enum StockStatus { inStock, low, out }

extension StockStatusInfo on StockStatus {
  String get label => switch (this) {
        StockStatus.inStock => 'In stock',
        StockStatus.low => 'Low stock',
        StockStatus.out => 'Sold out',
      };
}

class SellerStore {
  final String name;
  final String imageUrl;
  final String location; // campus block / street
  final String city;
  final List<String> categories;

  const SellerStore({
    required this.name,
    required this.imageUrl,
    required this.location,
    required this.city,
    required this.categories,
  });
}

/// One line of stock. ponytail: no variants, cost price or supplier — add
/// those the day a seller actually needs them.
class InventoryItem {
  final String id;
  String title;
  String description;
  String category;
  double price;
  int stock;
  String imageUrl;

  InventoryItem({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.price,
    required this.stock,
    required this.imageUrl,
  });

  StockStatus get status => stock <= 0
      ? StockStatus.out
      : stock <= lowStockAt
          ? StockStatus.low
          : StockStatus.inStock;

  /// What this line is worth at listed price.
  double get value => price * stock;
}

/// ponytail: in-memory seller account, same ChangeNotifier pattern as Cart.
/// One store per user, which is all a single-account app can have.
class Seller extends ChangeNotifier {
  Seller._();
  static final Seller instance = Seller._();

  SellerStore? _store;
  final List<InventoryItem> _items = [];

  SellerStore? get store => _store;
  bool get hasStore => _store != null;
  List<InventoryItem> get items => List.unmodifiable(_items);

  int get skuCount => _items.length;
  int get unitsInStock => _items.fold(0, (n, i) => n + (i.stock.clamp(0, 1 << 30)));
  int get lowOrOutCount =>
      _items.where((i) => i.status != StockStatus.inStock).length;
  double get inventoryValue => _items.fold(0.0, (n, i) => n + i.value);

  void openStore(SellerStore store) {
    _store = store;
    notifyListeners();
  }

  void addItem(InventoryItem item) {
    _items.insert(0, item);
    notifyListeners();
  }

  /// Edits happen on the live object, so callers mutate then call this.
  void itemChanged() => notifyListeners();

  void removeItem(String id) {
    _items.removeWhere((i) => i.id == id);
    notifyListeners();
  }

  /// Stock never goes negative — a sale below zero is a data bug, not a state.
  void adjustStock(String id, int delta) {
    final item = _items.firstWhere((i) => i.id == id);
    item.stock = (item.stock + delta).clamp(0, 1 << 30);
    notifyListeners();
  }
}
