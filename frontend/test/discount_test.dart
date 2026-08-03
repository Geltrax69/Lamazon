import 'package:flutter_test/flutter_test.dart';
import 'package:lamazon/models/product.dart';

Product at({required double price, required double mrp}) => Product(
  id: 'x',
  name: 'x',
  category: 'x',
  price: price,
  mrp: mrp,
  imageUrl: '',
  description: '',
);

void main() {
  group('discount', () {
    test('no MRP is not a discount', () {
      final p = at(price: 200, mrp: 0);
      expect(p.discounted, isFalse);
      expect(p.discountPercent, 0);
    });

    test('MRP equal to price ends the sale rather than showing 0% off', () {
      expect(at(price: 200, mrp: 200).discounted, isFalse);
    });

    // The server and the schema both reject this, so it should only ever
    // arrive from an older row — and a markup must not render as a saving.
    test('MRP below price is never shown as a discount', () {
      final p = at(price: 300, mrp: 200);
      expect(p.discounted, isFalse);
      expect(p.discountPercent, 0);
    });

    test('percentage is off the MRP, rounded the way a shopper reads it', () {
      expect(at(price: 199, mrp: 249).discountPercent, 20);
      expect(at(price: 750, mrp: 1000).discountPercent, 25);
      expect(at(price: 1, mrp: 3).discountPercent, 67);
    });
  });
}
