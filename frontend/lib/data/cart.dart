import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/product.dart';

class CartItem {
  final Product product;
  int qty;
  CartItem(this.product, this.qty);
}

/// ponytail: single global cart, ChangeNotifier + ListenableBuilder.
/// Swap for real state management if the app ever needs more than one store.
class Cart extends ChangeNotifier {
  Cart();
  static final Cart instance = Cart();
  SharedPreferences? _preferences;
  Future<void> _pendingWrite = Future.value();
  Future<void> get savedToStorage => _pendingWrite;

  Future<void> restore() async {
    _preferences = await SharedPreferences.getInstance();
    _items.clear();
    try {
      final rows =
          jsonDecode(_preferences!.getString('cart.v1') ?? '[]') as List;
      for (final row in rows) {
        try {
          final product = Product.fromJson(
            Map<String, dynamic>.from(row['product'] as Map),
          );
          final qty = row['qty'] as int;
          if (product.id.isNotEmpty &&
              product.price.isFinite &&
              product.price >= 0 &&
              qty > 0) {
            _items[product.id] = CartItem(product, qty);
          }
        } catch (_) {
          // A damaged line must not discard the rest of the basket.
        }
      }
    } catch (_) {
      // Invalid local data must not prevent the app from starting.
    }
    notifyListeners();
  }

  void _save() {
    final preferences = _preferences;
    if (preferences == null) return;
    final snapshot = jsonEncode([
      for (final item in _items.values)
        {'product': item.product.toJson(), 'qty': item.qty},
    ]);
    _pendingWrite = _pendingWrite
        .then((_) async {
          await preferences.setString('cart.v1', snapshot);
        })
        .catchError((Object error) {
          debugPrint('Could not save basket: $error');
        });
  }

  final Map<String, CartItem> _items = {};

  List<CartItem> get items => _items.values.toList();
  bool get isEmpty => _items.isEmpty;
  int get count => _items.values.fold(0, (s, i) => s + i.qty);
  double get subtotal =>
      _items.values.fold(0, (s, i) => s + i.product.price * i.qty);
  double get shipping => isEmpty ? 0 : 15;
  double get total => subtotal + shipping;

  /// What the discounts took off, across the whole basket. Items without an
  /// MRP contribute nothing rather than counting their full price as a
  /// saving, which is what `discounted` is guarding.
  double get saved => _items.values.fold(
    0,
    (s, i) =>
        s +
        (i.product.discounted ? (i.product.mrp - i.product.price) * i.qty : 0),
  );

  void add(Product p, [int qty = 1]) {
    if (qty <= 0) return;
    _items.update(p.id, (i) => i..qty += qty, ifAbsent: () => CartItem(p, qty));
    _save();
    notifyListeners();
  }

  void setQty(String id, int qty) {
    if (qty <= 0) {
      _items.remove(id);
    } else {
      _items[id]?.qty = qty;
    }
    _save();
    notifyListeners();
  }

  void remove(String id) {
    _items.remove(id);
    _save();
    notifyListeners();
  }
}
