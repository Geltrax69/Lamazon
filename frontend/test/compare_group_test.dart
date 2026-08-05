import 'package:flutter_test/flutter_test.dart';
import 'package:lamazon/models/product.dart';

void main() {
  group('attribute display', () {
    test('a unit is appended, so a seller types 20 and it reads 20W', () {
      expect(const GroupAttribute('Power', 'W').show('20'), '20W');
      expect(const GroupAttribute('Connector').show('USB-C'), 'USB-C');
    });

    test('an unanswered field is a dash, not a blank cell', () {
      // A blank column reads as a missing row; a dash reads as "not stated".
      expect(const GroupAttribute('Power', 'W').show(''), '—');
    });
  });

  group('parsing', () {
    test('a group carries its template in order', () {
      final g = CompareGroup.fromJson({
        'name': 'Chargers',
        'items': 3,
        'attributes': [
          {'name': 'Power', 'unit': 'W'},
          {'name': 'Connector'},
        ],
      });
      expect(g.name, 'Chargers');
      expect(g.items, 3);
      expect(g.attributes.map((a) => a.name).toList(), ['Power', 'Connector']);
      expect(g.attributes.first.unit, 'W');
    });

    test('a product with no group is simply not comparable', () {
      const p = Product(
        id: 'x',
        name: 'Samosa',
        category: 'Street Food',
        price: 20,
        imageUrl: '',
        description: '',
      );
      expect(p.compareGroup, '');
      expect(p.attributes, isEmpty);
    });
  });
}
