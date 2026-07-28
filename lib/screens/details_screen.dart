import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/cart.dart';
import '../models/product.dart';
import '../widgets/product_card.dart';
import '../widgets/status_views.dart';
import 'cart_screen.dart';
import 'compare_screen.dart';

const _hero = Color(0xFFF3A952); // warm orange hero, from the design
const _ink = Color(0xFF1A1A1A);

class DetailsScreen extends StatefulWidget {
  final Product product;
  const DetailsScreen({super.key, required this.product});

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  int _qty = 1;
  int _size = 0;
  int _color = 0;

  static const _colors = [
    _hero,
    Color(0xFF1A1A1A),
    Color(0xFF8FB8D8),
    Color(0xFFC9D4DC),
  ];

  void _addToCart() {
    Cart.instance.add(widget.product, _qty);
    showAddedToast(context, widget.product);
  }

  void _buyNow() {
    Cart.instance.add(widget.product, _qty);
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const CartScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F5F2),
      body: Column(
        children: [
          _Hero(product: p),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(p.name,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w700)),
                    ),
                    _QtyStepper(
                      qty: _qty,
                      onChanged: (q) => setState(() => _qty = q),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text.rich(TextSpan(children: [
                      const TextSpan(
                          text: 'From: ',
                          style: TextStyle(
                              fontSize: 14, color: Color(0xFF6B6B6B))),
                      TextSpan(
                          text: '₹${p.price.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w800)),
                    ])),
                    const Spacer(),
                    for (var i = 0; i < _colors.length; i++)
                      GestureDetector(
                        onTap: () => setState(() => _color = i),
                        child: Container(
                          margin: const EdgeInsets.only(left: 8),
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: _colors[i],
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _color == i
                                  ? _ink
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                if (p.sizes.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  const Text('Select Size',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: p.sizes.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (_, i) => GestureDetector(
                        onTap: () => setState(() => _size = i),
                        child: Container(
                          width: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _size == i ? _hero : Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Text(p.sizes[i],
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: _size == i
                                      ? FontWeight.w700
                                      : FontWeight.w500)),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                const Text('Description',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(p.description,
                    style: const TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: Color(0xFF6B6B6B))),
                const SizedBox(height: 4),
                Text('Sold by ${p.store}',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF9A9A9A))),
                ..._compareSection(context, p),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Row(
          children: [
            Expanded(
              child: _PillButton(
                label: 'Add to Cart',
                background: Colors.white,
                onTap: _addToCart,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PillButton(
                label: 'Buy Now',
                background: _hero,
                onTap: _buyNow,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Same product at other shops": this exact item's price elsewhere, with
/// the difference against the current shop's price.
List<Widget> _compareSection(BuildContext context, Product p) {
  if (p.offers.isEmpty) return const [];
  return [
    const SizedBox(height: 22),
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Flexible(
          child: Text('Local vendors',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        ),
        GestureDetector(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => CompareScreen(product: p))),
          child: const Row(
            children: [
              Text('Compare all',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2E7D32))),
              SizedBox(width: 2),
              Icon(LucideIcons.chevronRight,
                  size: 15, color: Color(0xFF2E7D32)),
            ],
          ),
        ),
      ],
    ),
    const SizedBox(height: 2),
    Text('Compared with ₹${p.price.toStringAsFixed(0)} at ${p.store}',
        style: const TextStyle(fontSize: 12, color: Color(0xFF9A9A9A))),
    const SizedBox(height: 10),
    for (final o in p.offers)
      Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0xFFF1F1EF),
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(LucideIcons.store, size: 18, color: _ink),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(o.store,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                  const Text('Same product',
                      style: TextStyle(
                          fontSize: 11, color: Color(0xFF9A9A9A))),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('₹${o.price.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
                _diffBadge(o.price - p.price),
              ],
            ),
          ],
        ),
      ),
  ];
}

Widget _diffBadge(double diff) {
  final String label;
  final Color color;
  if (diff > 0) {
    label = '₹${diff.toStringAsFixed(0)} more';
    color = const Color(0xFFD32F2F);
  } else if (diff < 0) {
    label = '₹${(-diff).toStringAsFixed(0)} less';
    color = const Color(0xFF2E7D32);
  } else {
    label = 'Same price';
    color = const Color(0xFF9A9A9A);
  }
  return Text(label,
      style:
          TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color));
}

class _Hero extends StatelessWidget {
  final Product product;
  const _Hero({required this.product});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.all(14),
      height: MediaQuery.sizeOf(context).height * 0.44,
      decoration: BoxDecoration(
        color: _hero,
        borderRadius: BorderRadius.circular(32),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _RoundIcon(
                  icon: LucideIcons.arrowLeft,
                  onTap: () => Navigator.pop(context),
                ),
                const Text('Details',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                const _RoundIcon(icon: LucideIcons.heart),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: NetImage(url: product.imageUrl),
                    ),
                  ),
                  if (product.extraImages.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 64,
                      child: Column(
                        children: [
                          for (final url in product.extraImages.take(3)) ...[
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: SizedBox(
                                  width: 64,
                                  child: NetImage(url: url),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
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
        decoration:
            const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        child: Icon(icon, size: 18, color: _ink),
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  final int qty;
  final ValueChanged<int> onChanged;
  const _QtyStepper({required this.qty, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          _step(LucideIcons.minus, () {
            if (qty > 1) onChanged(qty - 1);
          }, filled: false),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(qty.toString().padLeft(2, '0'),
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700)),
          ),
          _step(LucideIcons.plus, () => onChanged(qty + 1), filled: true),
        ],
      ),
    );
  }

  Widget _step(IconData icon, VoidCallback onTap, {required bool filled}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: filled ? _hero : Colors.white,
          shape: BoxShape.circle,
          border: filled ? null : Border.all(color: const Color(0xFFE3E3E0)),
        ),
        child: Icon(icon, size: 14, color: _ink),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final String label;
  final Color background;
  final VoidCallback onTap;
  const _PillButton(
      {required this.label, required this.background, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, color: _ink)),
      ),
    );
  }
}
