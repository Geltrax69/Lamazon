import 'package:flutter/foundation.dart';

import '../models/product.dart';

class CartItem {
  final Product product;
  int qty;
  CartItem(this.product, this.qty);
}

/// ponytail: single global cart, ChangeNotifier + ListenableBuilder.
/// Swap for real state management if the app ever needs more than one store.
class Cart extends ChangeNotifier {
  Cart._();
  static final Cart instance = Cart._();

  final Map<String, CartItem> _items = {};

  List<CartItem> get items => _items.values.toList();
  bool get isEmpty => _items.isEmpty;
  int get count => _items.values.fold(0, (s, i) => s + i.qty);
  double get subtotal =>
      _items.values.fold(0, (s, i) => s + i.product.price * i.qty);
  double get shipping => isEmpty ? 0 : 15;
  double get total => subtotal + shipping;

  void add(Product p, [int qty = 1]) {
    _items.update(p.id, (i) => i..qty += qty, ifAbsent: () => CartItem(p, qty));
    notifyListeners();
  }

  void setQty(String id, int qty) {
    if (qty <= 0) {
      _items.remove(id);
    } else {
      _items[id]?.qty = qty;
    }
    notifyListeners();
  }

  void remove(String id) {
    _items.remove(id);
    notifyListeners();
  }
}
