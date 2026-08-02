import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whoever is signed in to a staff panel: the admin, or a delivery rider.
///
/// Deliberately separate from [Session], the shopper's sign-in. They are
/// different people with different tokens, and mixing them would mean a
/// shopper's session could be mistaken for an admin's — the backend refuses
/// that, and so does this.
class StaffSession extends ChangeNotifier {
  StaffSession._(this.role);

  /// One per panel, so signing in as a rider on the same browser does not
  /// sign the admin out.
  static final StaffSession admin = StaffSession._('admin');
  static final StaffSession rider = StaffSession._('rider');

  final String role;

  String? _token;
  String _subject = ''; // username, or phone
  String _name = '';

  String? get token => _token;
  String get subject => _subject;
  String get name => _name;
  bool get signedIn => _token != null;

  String get _tokenKey => 'staff.$role.token';
  String get _subjectKey => 'staff.$role.subject';
  String get _nameKey => 'staff.$role.name';

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    _subject = prefs.getString(_subjectKey) ?? '';
    _name = prefs.getString(_nameKey) ?? '';
    notifyListeners();
  }

  Future<void> signIn(String token, String subject, [String name = '']) async {
    _token = token;
    _subject = subject;
    _name = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_subjectKey, subject);
    await prefs.setString(_nameKey, name);
    notifyListeners();
  }

  Future<void> signOut() async {
    _token = null;
    _subject = '';
    _name = '';
    final prefs = await SharedPreferences.getInstance();
    for (final key in [_tokenKey, _subjectKey, _nameKey]) {
      await prefs.remove(key);
    }
    notifyListeners();
  }
}
