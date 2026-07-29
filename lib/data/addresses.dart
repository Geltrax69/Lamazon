import 'package:flutter/foundation.dart';

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

  const Address({
    required this.id,
    required this.label,
    required this.line,
    required this.city,
    required this.pincode,
  });

  String get full => '$line, $city $pincode';
}

/// Cities the porters currently cover. Everything else is out of service.
const serviceableCities = [
  'Jalandhar',
  'Ludhiana',
  'Amritsar',
  'Chandigarh',
  'Patiala',
  'Delhi',
];

bool isServiceable(String city) => serviceableCities
    .any((c) => c.toLowerCase() == city.trim().toLowerCase());

/// ponytail: global address book, same ChangeNotifier pattern as Cart.
class AddressBook extends ChangeNotifier {
  AddressBook._();
  static final AddressBook instance = AddressBook._();

  final List<Address> _addresses = [
    const Address(
      id: 'a1',
      label: AddressLabel.home,
      line: '12 Green Avenue, Model Town',
      city: 'Jalandhar',
      pincode: '144003',
    ),
  ];

  String _selectedId = 'a1';

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

  void add(Address a) {
    _addresses.add(a);
    _selectedId = a.id;
    notifyListeners();
  }

  void select(String id) {
    _selectedId = id;
    notifyListeners();
  }

  void remove(String id) {
    _addresses.removeWhere((a) => a.id == id);
    if (_selectedId == id && _addresses.isNotEmpty) {
      _selectedId = _addresses.first.id;
    }
    notifyListeners();
  }
}
