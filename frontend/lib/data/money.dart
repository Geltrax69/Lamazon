/// Preserve paise everywhere without adding decimal zeros to whole-rupee
/// prices, and group the thousands the way a rupee is written.
extension MoneyText on num {
  String get moneyText {
    final rounded = (this * 100).round();
    final whole = _grouped((rounded ~/ 100).abs());
    final sign = rounded < 0 ? '-' : '';
    if (rounded % 100 == 0) return '$sign$whole';
    final paise = (rounded.abs() % 100).toString().padLeft(2, '0');
    return '$sign$whole.$paise';
  }
}

/// Indian digit grouping: the last three, then twos. ₹88,690 and ₹1,00,000,
/// which is how the number is read aloud here — lakhs, not hundred-thousands.
String _grouped(int value) {
  final digits = value.toString();
  if (digits.length <= 3) return digits;
  final tail = digits.substring(digits.length - 3);
  var head = digits.substring(0, digits.length - 3);
  final parts = <String>[];
  while (head.length > 2) {
    parts.insert(0, head.substring(head.length - 2));
    head = head.substring(0, head.length - 2);
  }
  if (head.isNotEmpty) parts.insert(0, head);
  return '${parts.join(',')},$tail';
}

/// A title a screen reader can get through.
///
/// One legacy product carries a 194-character name — it predates the 160-char
/// cap on create and update. On a card that is the entire accessible name
/// before a price is ever reached, and a card is scanned rather than read. The
/// stored value is untouched; only the spoken and the scanned forms are cut,
/// and the product page still shows it in full.
extension SpokenTitle on String {
  static const _limit = 72;
  String get spokenTitle {
    final title = trim();
    if (title.length <= _limit) return title;
    final cut = title.lastIndexOf(' ', _limit);
    return '${title.substring(0, cut > 40 ? cut : _limit).trimRight()}…';
  }
}
