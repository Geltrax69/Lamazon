import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lamazon/data/cart.dart';
import 'package:lamazon/data/wishlist.dart';
import 'package:lamazon/models/product.dart';

const product = Product(
  id: 'item-1',
  name: 'Burger',
  category: 'Burgers',
  price: 69,
  mrp: 99,
  imageUrl: 'https://example.com/burger.jpg',
  description: 'Lunch',
  options: [
    ItemOption(name: 'Sauce', values: ['Hot', 'Mild']),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'basket restores quantities and product details after a restart',
    () async {
      final cart = Cart();
      await cart.restore();
      cart.add(product);
      cart.setQty(product.id, 3);
      await cart.savedToStorage;
      final restarted = Cart();
      await restarted.restore();
      expect(restarted.count, 3);
      expect(restarted.total, 222);
      expect(restarted.items.single.product.toJson(), product.toJson());
      restarted.remove(product.id);
      await restarted.savedToStorage;
      final empty = Cart();
      await empty.restore();
      expect(empty.isEmpty, isTrue);
    },
  );

  test(
    'rapid edits persist the latest snapshot and ignore invalid additions',
    () async {
      final cart = Cart();
      await cart.restore();
      cart.add(product, 0);
      cart.add(product, -1);
      expect(cart.isEmpty, isTrue);
      cart.add(product);
      cart.setQty(product.id, 8);
      cart.remove(product.id);
      cart.add(product, 2);
      await cart.savedToStorage;
      final restarted = Cart();
      await restarted.restore();
      expect(restarted.count, 2);
    },
  );

  test('corrupt entries do not lose valid lines or prevent startup', () async {
    SharedPreferences.setMockInitialValues({
      'cart.v1': jsonEncode([
        {'product': product.toJson(), 'qty': 2},
        {
          'product': {'id': 'broken'},
          'qty': 1,
        },
        {'product': product.toJson(), 'qty': -5},
      ]),
    });
    final cart = Cart();
    await cart.restore();
    expect(cart.count, 2);
    SharedPreferences.setMockInitialValues({'cart.v1': 'broken json'});
    await cart.restore();
    expect(cart.isEmpty, isTrue);
  });

  test('wishlist additions and removals survive restart', () async {
    final wishlist = Wishlist();
    await wishlist.restore();
    wishlist.toggle('item-1');
    wishlist.toggle('item-2');
    wishlist.toggle('item-1');
    await wishlist.savedToStorage;
    final restarted = Wishlist();
    await restarted.restore();
    expect(restarted.ids, {'item-2'});
    expect(() => restarted.ids.add('unsaved'), throwsUnsupportedError);
  });
}
