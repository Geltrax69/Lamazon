import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Saved on this device, including while browsing as a guest.
class Wishlist extends ChangeNotifier {
  Wishlist();
  static final Wishlist instance = Wishlist();
  SharedPreferences? _preferences;
  Future<void> _pendingWrite = Future.value();
  Future<void> get savedToStorage => _pendingWrite;
  final Set<String> _ids = {};

  Future<void> restore() async {
    _preferences = await SharedPreferences.getInstance();
    _ids.clear();
    try {
      _ids.addAll(
        (_preferences!.getStringList('wishlist.v1') ?? []).where(
          (id) => id.isNotEmpty,
        ),
      );
    } catch (_) {
      // Invalid local data must not prevent startup.
    }
    notifyListeners();
  }

  bool contains(String id) => _ids.contains(id);
  Set<String> get ids => Set.unmodifiable(_ids);

  void toggle(String id) {
    if (id.isEmpty) return;
    _ids.contains(id) ? _ids.remove(id) : _ids.add(id);
    final preferences = _preferences;
    if (preferences != null) {
      final snapshot = _ids.toList();
      _pendingWrite = _pendingWrite
          .then((_) async {
            await preferences.setStringList('wishlist.v1', snapshot);
          })
          .catchError((Object error) {
            debugPrint('Could not save wishlist: $error');
          });
    }
    notifyListeners();
  }
}
