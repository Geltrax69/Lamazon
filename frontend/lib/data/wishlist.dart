import 'package:flutter/foundation.dart';

/// ponytail: global wishlist of product ids, same pattern as Cart.
class Wishlist extends ChangeNotifier {
  Wishlist._();
  static final Wishlist instance = Wishlist._();

  final Set<String> _ids = {};

  bool contains(String id) => _ids.contains(id);
  Set<String> get ids => _ids;

  void toggle(String id) {
    _ids.contains(id) ? _ids.remove(id) : _ids.add(id);
    notifyListeners();
  }
}
