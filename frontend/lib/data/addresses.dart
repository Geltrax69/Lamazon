import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api.dart';

enum AddressLabel { home, office, other }

extension AddressLabelInfo on AddressLabel {
  String get title => switch (this) {
    AddressLabel.home => 'Home',
    AddressLabel.office => 'Office',
    AddressLabel.other => 'Other',
  };
}

class Address {
  final String id;
  final AddressLabel label;
  final String line; // house / street
  final String city;
  final String pincode;
  final String name; // who the delivery is for
  final bool isDefault;
  final String phone; // and how the porter reaches them

  const Address({
    required this.id,
    required this.label,
    required this.line,
    required this.city,
    required this.pincode,
    this.name = '',
    this.phone = '',
    this.isDefault = false,
  });

  factory Address.fromJson(Map<String, dynamic> r) => Address(
    id: r['id'] as String,
    label: AddressLabel.values.firstWhere(
      (l) =>
          l.title.toLowerCase() == (r['label'] as String? ?? '').toLowerCase(),
      orElse: () => AddressLabel.home,
    ),
    line: r['line'] as String? ?? '',
    city: r['city'] as String? ?? '',
    pincode: r['pincode'] as String? ?? '',
    name: r['name'] as String? ?? '',
    phone: r['phone'] as String? ?? '',
    isDefault: r['isDefault'] == true,
  );

  String get full => '$line, $city $pincode';
}

/// Where the porters currently deliver. ponytail: one campus for now —
/// widen this list as coverage grows, nothing else changes.
const serviceableCities = ['Lovely Professional University'];


/// Accepted shorthands for the places above, so "LPU" or "lpu, phagwara"
/// still resolves.
const _aliases = {
  'lpu': 'Lovely Professional University',
  'lovely professional university': 'Lovely Professional University',
  'lpu phagwara': 'Lovely Professional University',
  'lpu, phagwara': 'Lovely Professional University',
};

bool isServiceable(String city) {
  final q = city.trim().toLowerCase();
  return _aliases[q] != null ||
      serviceableCities.any((c) => c.toLowerCase() == q);
}

/// ponytail: global address book, same ChangeNotifier pattern as Cart.
class AddressBook extends ChangeNotifier {
  AddressBook._();
  static final AddressBook instance = AddressBook._();

  // Starts empty: addresses belong to the person, and the server is where
  // they live. A sample one here would look real and vanish on sign-in.
  final List<Address> _addresses = [];

  String _selectedId = '';

  /// Completes once the book has been fetched, so callers can wait instead of
  /// acting on an empty list that simply has not arrived yet.
  final Completer<void> _ready = Completer<void>();
  Future<void> get ready => _ready.future;

  /// Marks the book settled without a fetch — a guest has no book to load,
  /// and callers waiting on [ready] would otherwise wait forever.
  void markLoaded() {
    if (!_ready.isCompleted) _ready.complete();
  }

  /// Pulls the book from the server. Called after sign-in and on restore, so
  /// a new browser shows the same addresses as the old one.
  Future<void> load() async {
    try {
      final list = await Api.instance.addresses();
      _addresses
        ..clear()
        ..addAll(list);
      _selectedId =
          list.where((a) => a.isDefault).firstOrNull?.id ??
          list.firstOrNull?.id ??
          '';
      notifyListeners();
    } catch (e) {
      logApiFailure('addresses', e);
    }
    if (!_ready.isCompleted) _ready.complete();
  }

  /// Forgets everything on sign-out — the next person on this browser must
  /// not see the last one's addresses.
  void clear() {
    _addresses.clear();
    _selectedId = '';
    notifyListeners();
  }

  // ponytail: no geolocator dependency yet — this flag stands in for the OS
  // permission. Wire enableLocation() to the real plugin when GPS is needed.
  bool _locationEnabled = false;
  bool get locationEnabled => _locationEnabled;

  void enableLocation() {
    _locationEnabled = true;
    notifyListeners();
  }

  List<Address> get addresses => List.unmodifiable(_addresses);
  Address? get selected =>
      _addresses.where((a) => a.id == _selectedId).firstOrNull;

  /// Do not create a local address when the server refuses it.
  Future<void> add(Address a) async {
    final saved = await Api.instance.addAddress(a);
    _addresses.add(saved);
    _selectedId = saved.id;
    notifyListeners();
    await load();
  }

  Future<void> edit(Address a) async {
    final saved = await Api.instance.editAddress(a);
    final index = _addresses.indexWhere((row) => row.id == a.id);
    if (index >= 0) _addresses[index] = saved;
    notifyListeners();
  }

  Future<void> select(String id) async {
    await Api.instance.selectAddress(id);
    _selectedId = id;
    notifyListeners();
  }

  Future<void> remove(String id) async {
    await Api.instance.deleteAddress(id);
    _addresses.removeWhere((a) => a.id == id);
    if (_selectedId == id) _selectedId = _addresses.firstOrNull?.id ?? '';
    notifyListeners();
    await load();
  }
}
