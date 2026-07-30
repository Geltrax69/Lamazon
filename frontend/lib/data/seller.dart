import 'package:flutter/foundation.dart';

import 'api.dart';

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
  final Uint8List? photo; // the bytes the seller picked, shown immediately
  final String location; // campus block / street
  final String city;
  final List<String> categories;

  /// Cloudinary URL, filled in once the upload lands. The local bytes stay as
  /// the thing actually rendered, so the tile never flickers.
  String photoUrl = '';

  SellerStore({
    required this.name,
    required this.photo,
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
  List<Uint8List> photos; // first one is the cover

  /// Set once the backend has a row for this item, and the Cloudinary URLs
  /// that came back with the upload.
  String? serverId;
  List<String> imageUrls = [];

  InventoryItem({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.price,
    required this.stock,
    this.photos = const [],
  });

  Uint8List? get cover => photos.isEmpty ? null : photos.first;

  StockStatus get status => stock <= 0
      ? StockStatus.out
      : stock <= lowStockAt
          ? StockStatus.low
          : StockStatus.inStock;

  /// What this line is worth at listed price.
  double get value => price * stock;
}

/// Where an incoming order has got to. Accepting reserves it; delivering
/// is what actually takes the units out of stock.
enum OrderStage { received, accepted, delivered }

extension OrderStageInfo on OrderStage {
  String get label => switch (this) {
        OrderStage.received => 'New',
        OrderStage.accepted => 'Accepted',
        OrderStage.delivered => 'Delivered',
      };
}

class SellerOrder {
  final String id;
  final String itemId;
  final String itemTitle;
  final int units;
  final double amount;
  OrderStage stage;

  SellerOrder({
    required this.id,
    required this.itemId,
    required this.itemTitle,
    required this.units,
    required this.amount,
    this.stage = OrderStage.received,
  });
}

/// ponytail: in-memory seller account, same ChangeNotifier pattern as Cart.
/// One store per user, which is all a single-account app can have.
class Seller extends ChangeNotifier {
  Seller._();
  static final Seller instance = Seller._();

  SellerStore? _store;
  final List<InventoryItem> _items = [];
  final List<SellerOrder> _orders = [];

  SellerStore? get store => _store;
  bool get hasStore => _store != null;
  List<InventoryItem> get items => List.unmodifiable(_items);
  List<SellerOrder> get orders => List.unmodifiable(_orders);

  int countAt(OrderStage stage) =>
      _orders.where((o) => o.stage == stage).length;

  /// Orders still waiting on the seller — the number worth acting on.
  int get openOrders => _orders.where((o) => o.stage != OrderStage.delivered).length;

  int get skuCount => _items.length;
  int get unitsInStock => _items.fold(0, (n, i) => n + (i.stock.clamp(0, 1 << 30)));
  int get lowOrOutCount =>
      _items.where((i) => i.status != StockStatus.inStock).length;
  double get inventoryValue => _items.fold(0.0, (n, i) => n + i.value);

  void openStore(SellerStore store) {
    _store = store;
    notifyListeners();
    _pushStore(store); // photos and row land in the background
  }

  /// The screens stay synchronous and local-first: the store shows up at once
  /// and the network catches up, or logs why it did not.
  Future<void> _pushStore(SellerStore store) async {
    try {
      store.photoUrl = await Api.instance.createStore(
        name: store.name,
        location: store.location,
        city: store.city,
        categories: store.categories,
        photo: store.photo,
      );
      notifyListeners();
    } catch (e) {
      logApiFailure('store sync', e);
    }
  }

  void addItem(InventoryItem item) {
    _items.insert(0, item);
    _pushItem(item);
    // ponytail: no order backend yet, so the first product brings two
    // demo orders along to make the store page real. Delete this call the
    // day orders arrive from the shopper side.
    if (_orders.isEmpty) _seedDemoOrders(item);
    notifyListeners();
  }

  /// Row and photos in a single request: either the whole listing lands or
  /// none of it does, so there is no half-saved item to reconcile.
  Future<void> _pushItem(InventoryItem item) async {
    try {
      final saved = await Api.instance.addItem(
        title: item.title,
        description: item.description,
        category: item.category,
        price: item.price,
        stock: item.stock,
        photos: item.photos,
      );
      item.serverId = saved.id;
      item.imageUrls = saved.imageUrls;
      notifyListeners();
    } catch (e) {
      logApiFailure('item sync', e);
    }
  }

  void _seedDemoOrders(InventoryItem item) {
    _orders.addAll([
      SellerOrder(
        id: 'o1',
        itemId: item.id,
        itemTitle: item.title,
        units: 2,
        amount: item.price * 2,
      ),
      SellerOrder(
        id: 'o2',
        itemId: item.id,
        itemTitle: item.title,
        units: 1,
        amount: item.price,
        stage: OrderStage.accepted,
      ),
    ]);
  }

  void acceptOrder(String id) {
    _orders.firstWhere((o) => o.id == id).stage = OrderStage.accepted;
    notifyListeners();
  }

  /// Handing the order over is what removes the units from inventory.
  void deliverOrder(String id) {
    final order = _orders.firstWhere((o) => o.id == id);
    order.stage = OrderStage.delivered;
    final item = _items.where((i) => i.id == order.itemId).firstOrNull;
    if (item != null) {
      item.stock = (item.stock - order.units).clamp(0, 1 << 30);
    }
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
