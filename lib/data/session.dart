import 'package:flutter/foundation.dart';

/// ponytail: in-memory sign-in state, same ChangeNotifier pattern as Cart.
/// No OTP, no backend — swap login() for the real auth call when there is one.
class Session extends ChangeNotifier {
  Session._();
  static final Session instance = Session._();

  String? _phone;
  bool _skipped = false;

  String? get phone => _phone;
  bool get loggedIn => _phone != null;

  /// True once the user has either logged in or chosen to browse as a guest,
  /// so the login screen is not shown again.
  bool get onboarded => loggedIn || _skipped;

  String get maskedPhone {
    final p = _phone;
    if (p == null || p.length < 4) return '';
    return '${p.substring(0, p.length - 4)}XXXX';
  }

  void login(String phone) {
    _phone = phone;
    _skipped = false;
    notifyListeners();
  }

  void skip() {
    _skipped = true;
    notifyListeners();
  }

  void logout() {
    _phone = null;
    _skipped = true;
    notifyListeners();
  }
}
