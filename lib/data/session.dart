import 'package:flutter/foundation.dart';

/// ponytail: in-memory sign-in state, same ChangeNotifier pattern as Cart.
/// No password, no backend — swap login() for the real auth call when there
/// is one.
class Session extends ChangeNotifier {
  Session._();
  static final Session instance = Session._();

  String? _email;
  bool _skipped = false;

  String? get email => _email;
  bool get loggedIn => _email != null;

  /// True once the user has either logged in or chosen to browse as a guest,
  /// so the login screen is not shown again.
  bool get onboarded => loggedIn || _skipped;

  /// Anything with a name, an @ and a dotted domain after it.
  static bool isValidEmail(String value) =>
      RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(value.trim());

  void login(String email) {
    _email = email.trim();
    _skipped = false;
    notifyListeners();
  }

  void skip() {
    _skipped = true;
    notifyListeners();
  }

  void logout() {
    _email = null;
    _skipped = true;
    notifyListeners();
  }
}
