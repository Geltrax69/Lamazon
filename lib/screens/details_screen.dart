import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/product.dart';
import '../widgets/product_card.dart';

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

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ));
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
                onTap: () => _toast('Added $_qty to cart'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PillButton(
                label: 'Buy Now',
                background: _hero,
                onTap: () => _toast('Order placed (demo)'),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
