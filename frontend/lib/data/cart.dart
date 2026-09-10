import 'dart:convert';
import 'dart:math';

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
  String _requestId = _newRequestId();
  String get checkoutRequestId => _requestId;
  static String _newRequestId() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  Future<void> restore() async {
    _preferences = await SharedPreferences.getInstance();
    _items.clear();
    try {
      final saved = _preferences!.getString('cart.v2');
      final envelope = saved == null ? null : jsonDecode(saved) as Map;
      final rows = envelope == null
          ? jsonDecode(_preferences!.getString('cart.v1') ?? '[]') as List
          : envelope['items'] as List;
      _requestId = envelope?['requestId'] as String? ?? _newRequestId();
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
    _save(rotate: false);
    await savedToStorage;
    notifyListeners();
  }

  void _save({bool rotate = true}) {
    if (rotate) _requestId = _newRequestId();
    final preferences = _preferences;
    if (preferences == null) return;
    // Save the basket and retry ID together so a restart cannot mix revisions.
    final snapshot = jsonEncode({
      'requestId': _requestId,
      'items': [
        for (final item in _items.values)
          {'product': item.product.toJson(), 'qty': item.qty},
      ],
    });
    _pendingWrite = _pendingWrite
        .then((_) async {
          await preferences.setString('cart.v2', snapshot);
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

  /// The most of this product the basket may hold. Null availableStock means
  /// the seed catalogue, which does not track stock — those stay uncapped.
  static int? capFor(Product p) => p.availableStock;

  /// True when the basket already holds everything the shop has.
  bool atCap(Product p) {
    final cap = capFor(p);
    return cap != null && qtyOf(p.id) >= cap;
  }

  int qtyOf(String id) => _items[id]?.qty ?? 0;

  /// Adds up to what is actually in stock and returns how many went in, so a
  /// caller can say "only 1 left" rather than promising five.
  ///
  /// The cap lives here rather than in each of the five call sites: the cart
  /// used to accept five units of an item with one in stock, quote a total for
  /// them, and fail at "Place order" — the last step of the funnel and the
  /// worst place to find out.
  int add(Product p, [int qty = 1]) {
    if (qty <= 0) return 0;
    final cap = capFor(p);
    final room = cap == null ? qty : (cap - qtyOf(p.id)).clamp(0, qty);
    if (room <= 0) return 0;
    _items.update(
      p.id,
      (i) => i..qty += room,
      ifAbsent: () => CartItem(p, room),
    );
    _save();
    notifyListeners();
    return room;
  }

  void setQty(String id, int qty) {
    final line = _items[id];
    if (qty <= 0) {
      _items.remove(id);
    } else if (line != null) {
      final cap = capFor(line.product);
      line.qty = cap == null ? qty : qty.clamp(1, cap < 1 ? 1 : cap);
    }
    _save();
    notifyListeners();
  }

  /// Trims every line back to what the shop can actually supply, and reports
  /// what it had to change. Called when the cart screen opens, so a basket
  /// that went stale in a background tab corrects itself before checkout
  /// rather than during it.
  List<String> reconcile() {
    final trimmed = <String>[];
    for (final line in _items.values) {
      final cap = capFor(line.product);
      if (cap == null || line.qty <= cap) continue;
      trimmed.add(line.product.name);
      line.qty = cap;
    }
    _items.removeWhere((_, line) => line.qty <= 0);
    if (trimmed.isEmpty) return const [];
    _save();
    notifyListeners();
    return trimmed;
  }

  /// Returns the line it took out, so the caller can offer an undo instead of
  /// making a mis-tap cost the whole basket.
  CartItem? remove(String id) {
    final gone = _items.remove(id);
    _save();
    notifyListeners();
    return gone;
  }

  /// Puts a removed line back exactly as it was, undo's other half.
  /// (`restore` above is the one that reads the basket back off disk.)
  void putBack(CartItem line) {
    _items[line.product.id] = line;
    _save();
    notifyListeners();
  }
}
