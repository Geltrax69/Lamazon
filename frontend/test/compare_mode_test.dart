import 'package:flutter_test/flutter_test.dart';
import 'package:lamazon/models/product.dart';

void main() {
  test('only higher and lower actually rank', () {
    expect(const GroupAttribute('Power', 'W', CompareMode.higher).ranked, isTrue);
    expect(const GroupAttribute('Price', '', CompareMode.lower).ranked, isTrue);
    // These three are shown, never ranked — so a seller who leaves one blank
    // is not nagged, because there is no row to lose.
    expect(const GroupAttribute('Fast charge', '', CompareMode.feature).ranked, isFalse);
    expect(const GroupAttribute('Brand', '', CompareMode.info).ranked, isFalse);
    expect(const GroupAttribute('Flavour').ranked, isFalse);
  });

  test('a template written before modes existed still parses', () {
    final f = GroupAttribute.fromJson({'name': 'Power', 'unit': 'W'});
    expect(f.mode, CompareMode.none);
    expect(f.perUnit, isFalse);
    expect(f.ranked, isFalse);
  });

  test('the winner comes in but never goes back out', () {
    final f = GroupAttribute.fromJson({
      'name': 'Weight',
      'unit': 'g',
      'mode': 'higher_better',
      'perUnit': true,
      'winner': 'item-b',
    });
    expect(f.winner, 'item-b');
    // The winner is decided per request against the other listings, so sending
    // it back on a save would store a fact about a comparison, not a product.
    expect(f.toJson(), {'name': 'Weight', 'unit': 'g', 'mode': 'higher_better', 'perUnit': true});
  });

  test('a derived row reads its values as numbers', () {
    final d = DerivedRow.fromJson({
      'name': '₹ / 100 g',
      'values': {'a': 30, 'b': 24.5},
      'winner': 'b',
    });
    expect(d.values['a'], 30.0);
    expect(d.values['b'], 24.5);
    expect(d.winner, 'b');
  });
}
