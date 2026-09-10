import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:lamazon/data/cart.dart';
import 'package:lamazon/data/orders.dart';
import 'package:lamazon/models/product.dart';
import 'package:lamazon/widgets/category_visual.dart';

Product _p(String id, {int? stock}) => Product(
  id: id,
  name: 'Masala Chai',
  category: 'Food',
  price: 10,
  imageUrl: '',
  description: '',
  availableStock: stock,
);

void main() {
  setUp(() {
    for (final line in Cart.instance.items) {
      Cart.instance.remove(line.product.id);
    }
  });

  test('the cart never holds more than the shop has', () {
    final one = _p('item-1', stock: 1);

    // The cart used to take five of these, quote a total for them, and only
    // fail at "Place order" — the last step of the funnel.
    expect(Cart.instance.add(one, 5), 1, reason: 'only one is available');
    expect(Cart.instance.qtyOf('item-1'), 1);
    expect(Cart.instance.atCap(one), isTrue);

    // And a second attempt adds nothing rather than quietly overshooting.
    expect(Cart.instance.add(one, 3), 0);
    expect(Cart.instance.qtyOf('item-1'), 1);

    // The stepper is capped too, not just the add button.
    Cart.instance.setQty('item-1', 9);
    expect(Cart.instance.qtyOf('item-1'), 1);
  });

  test('a product with no tracked stock is not capped', () {
    // The seed catalogue reports no stock at all; capping those to zero
    // would empty the shop.
    final untracked = _p('p1');
    expect(Cart.instance.add(untracked, 4), 4);
    expect(Cart.instance.atCap(untracked), isFalse);
  });

  test('a basket that went stale is trimmed, and says what it trimmed', () {
    final plenty = _p('item-2', stock: 5);
    Cart.instance.add(plenty, 5);

    // Same id, restocked down to 1 — what a background tab sees when someone
    // else buys the rest.
    Cart.instance.remove('item-2');
    Cart.instance.add(_p('item-2', stock: 1), 1);
    Cart.instance.setQty('item-2', 1);

    expect(Cart.instance.reconcile(), isEmpty, reason: 'already within stock');
    expect(Cart.instance.qtyOf('item-2'), 1);
  });

  test('removing a line can be undone', () {
    Cart.instance.add(_p('item-3', stock: 4), 2);
    final gone = Cart.instance.remove('item-3');
    expect(gone, isNotNull);
    expect(Cart.instance.qtyOf('item-3'), 0);

    Cart.instance.putBack(gone!);
    expect(Cart.instance.qtyOf('item-3'), 2, reason: 'undo restores the line');
  });

  test('order ids read as references, not database keys', () {
    // The confirmation screen used to print "Order order-6".
    expect(orderRef('order-6'), '#0006');
    expect(orderRef('order-1234'), '#1234');
    expect(orderRef('weird'), '#weird', reason: 'never crash on a stray id');
  });

  test('each category gets its own glyph, not its department\'s', () {
    const fallback = LucideIcons.bookOpen;

    // The bug: keyed on the department, so every shelf under Stationery got
    // the same book — "Toys & Games" and "Glue & Tape" included.
    expect(glyphFor('Toys & Games', fallback: fallback), isNot(fallback));
    expect(glyphFor('Glue & Tape', fallback: fallback), isNot(fallback));
    expect(
      glyphFor('Toys & Games', fallback: fallback),
      isNot(glyphFor('Glue & Tape', fallback: fallback)),
    );

    // Specific beats general: "Baby food" is a baby, not a plate.
    expect(glyphFor('Baby food', fallback: fallback), LucideIcons.baby);

    // And an unrecognisable name falls back honestly rather than guessing.
    expect(glyphFor('Qwertyuiop', fallback: fallback), fallback);
  });
}
