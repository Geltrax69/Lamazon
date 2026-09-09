/// Preserve paise everywhere without adding decimal zeros to whole-rupee prices.
extension MoneyText on num {
  String get moneyText {
    final rounded = (this * 100).round();
    return rounded % 100 == 0
        ? (rounded ~/ 100).toString()
        : (rounded / 100).toStringAsFixed(2);
  }
}
