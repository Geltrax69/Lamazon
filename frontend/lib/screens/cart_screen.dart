import 'package:flutter/material.dart';

import '../widgets/app_shell.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/cart.dart';
import '../widgets/product_card.dart';

const _ink = Color(0xFF1A1A1A);
const _green = Color(0xFF1D4A3C); // deep green from the design

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = Cart.instance;
    return Scaffold(
      backgroundColor: const Color(0xFFF1F1EF),
      body: ReadableBody(
        maxWidth: 700,
        child: SafeArea(
          child: ListenableBuilder(
            listenable: cart,
            builder: (context, _) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _RoundIcon(
                          icon: LucideIcons.arrowLeft,
                          onTap: () => Navigator.pop(context),
                        ),
                        // The count belongs in the title: it is the one
                        // number people check before paying.
                        Column(
                          children: [
                            const Text(
                              'My Cart',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (!cart.isEmpty)
                              Text(
                                cart.count == 1 ? '1 item' : '${cart.count} items',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6B6B6B),
                                ),
                              ),
                          ],
                        ),
                        const _RoundIcon(icon: LucideIcons.shoppingCart),
                      ],
                    ),
                  ),
                  Expanded(
                    child: cart.isEmpty
                        ? const _EmptyCart()
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                            itemCount: cart.items.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (_, i) =>
                                _CartRow(item: cart.items[i]),
                          ),
                  ),
                  if (!cart.isEmpty) _CheckoutPanel(cart: cart),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.shoppingBasket, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          const Text(
            'Your cart is empty',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            'Items you add will show up here',
            style: TextStyle(fontSize: 12.5, color: Color(0xFF9A9A9A)),
          ),
          const SizedBox(height: 16),
          // An empty screen with no way out is a dead end.
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              decoration: BoxDecoration(
                color: _green,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Text(
                'Start shopping',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Swipe left to remove, like the reference design.
class _CartRow extends StatelessWidget {
  final CartItem item;
  const _CartRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final p = item.product;
    return Dismissible(
      key: ValueKey(p.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => Cart.instance.remove(p.id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFF8D7DA),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(
          LucideIcons.trash2,
          color: Color(0xFFD32F2F),
          size: 22,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 74,
                height: 74,
                child: NetImage(url: p.imageUrl),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    p.store,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF9A9A9A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '₹${(p.price * item.qty).toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  // At one unit the line total and the unit price are the
                  // same number, so only say it when they differ.
                  if (item.qty > 1)
                    Text(
                      '₹${p.price.toStringAsFixed(0)} each',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9A9A9A),
                      ),
                    ),
                ],
              ),
            ),
            _QtyControls(item: item),
          ],
        ),
      ),
    );
  }
}

class _QtyControls extends StatelessWidget {
  final CartItem item;
  const _QtyControls({required this.item});

  @override
  Widget build(BuildContext context) {
    final last = item.qty <= 1;
    return Row(
      children: [
        // Going below one removes the line, so at one the button says so —
        // swiping the row away is not discoverable with a mouse.
        _qtyBtn(
          last ? LucideIcons.trash2 : LucideIcons.minus,
          () => Cart.instance.setQty(item.product.id, item.qty - 1),
          filled: false,
          danger: last,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            item.qty.toString().padLeft(2, '0'),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
        _qtyBtn(
          LucideIcons.plus,
          () => Cart.instance.setQty(item.product.id, item.qty + 1),
          filled: true,
        ),
      ],
    );
  }

  Widget _qtyBtn(
    IconData icon,
    VoidCallback onTap, {
    required bool filled,
    bool danger = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: filled ? _green : Colors.white,
          shape: BoxShape.circle,
          border: filled
              ? null
              : Border.all(
                  color: danger
                      ? const Color(0xFFF0C8CB)
                      : const Color(0xFFE3E3E0),
                ),
        ),
        child: Icon(
          icon,
          size: 13,
          color: filled
              ? Colors.white
              : danger
                  ? const Color(0xFFD32F2F)
                  : _ink,
        ),
      ),
    );
  }
}

class _CheckoutPanel extends StatelessWidget {
  final Cart cart;
  const _CheckoutPanel({required this.cart});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.only(left: 16, right: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F1EF),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Promo code',
                      hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 9,
                  ),
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  decoration: BoxDecoration(
                    color: _green,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Apply',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Order Summary',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 8),
          _summaryRow(
            cart.count == 1 ? 'Sub Total (1 item)' : 'Sub Total (${cart.count} items)',
            cart.subtotal,
          ),
          const SizedBox(height: 4),
          _summaryRow('Delivery', cart.shipping),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1),
          ),
          _summaryRow('Total', cart.total, bold: true),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(
                    content: Text('Payment flow coming soon (demo)'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
            },
            child: Container(
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _green,
                borderRadius: BorderRadius.circular(26),
              ),
              // The amount rides on the button, so nobody pays without
              // seeing what they are paying.
              child: Text(
                'Make a Payment  ·  ₹${cart.total.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, double value, {bool bold = false}) {
    final style = TextStyle(
      fontSize: bold ? 15 : 13,
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      color: bold ? _ink : const Color(0xFF6B6B6B),
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text('₹${value.toStringAsFixed(0)}', style: style),
      ],
    );
  }
}

class _RoundIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _RoundIcon({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: _ink),
      ),
    );
  }
}
