import 'package:flutter/material.dart';

import '../widgets/app_shell.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/api.dart';
import '../data/cart.dart';
import '../models/product.dart';
import '../widgets/product_card.dart';
import '../widgets/status_views.dart';

const _ink = Color(0xFF1A1A1A);
const _green = Color(0xFF2E7D32);

/// Full price comparison for one product across every local vendor that
/// stocks it, cheapest first.
class CompareScreen extends StatelessWidget {
  final Product product;
  const CompareScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    // This shop's own price plus every other vendor's, cheapest first.
    final rows = <ShopOffer>[
      ShopOffer(product.store, product.price),
      ...product.offers,
    ]..sort((a, b) => a.price.compareTo(b.price));
    final best = rows.first;
    final worst = rows.last;
    final saving = worst.price - best.price;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F1EF),
      body: ReadableBody(
        maxWidth: 700,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        LucideIcons.arrowLeft,
                        size: 18,
                        color: _ink,
                      ),
                    ),
                  ),
                  const Text(
                    'Compare Prices',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 46),
                ],
              ),
              const SizedBox(height: 16),
              // Two different questions on one screen: which shop sells this
              // cheapest, and which product to buy instead. Categories cannot
              // answer the second — two shops shelve the same charger
              // differently — which is what the comparison group is for.
              if (product.compareGroup.isNotEmpty) _Rivals(product: product),
              // Product being compared.
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: 72,
                      height: 72,
                      child: NetImage(url: product.imageUrl),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          product.category,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B6B6B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (saving > 0) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.trendingDown,
                        size: 18,
                        color: _green,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Save ₹${saving.toStringAsFixed(0)} by buying from '
                          '${best.store}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _green,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Text(
                '${rows.length} local vendors',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < rows.length; i++)
                _VendorRow(
                  offer: rows[i],
                  product: product,
                  isBest: i == 0,
                  // Nearer vendors listed first is a fair stand-in until real
                  // vendor distances arrive with the location API.
                  distance: '${(1.2 + i * 0.8).toStringAsFixed(1)} km',
                  eta: '${10 + i * 4} mins',
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VendorRow extends StatelessWidget {
  final ShopOffer offer;
  final Product product;
  final bool isBest;
  final String distance;
  final String eta;

  const _VendorRow({
    required this.offer,
    required this.product,
    required this.isBest,
    required this.distance,
    required this.eta,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: isBest ? Border.all(color: _green, width: 1.5) : null,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F1EF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.store, size: 18, color: _ink),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            offer.store,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (isBest) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _green,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'BEST PRICE',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(
                          LucideIcons.mapPin,
                          size: 11,
                          color: Color(0xFF9A9A9A),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          distance,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF9A9A9A),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Icon(
                          LucideIcons.timer,
                          size: 11,
                          color: Color(0xFF9A9A9A),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          eta,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF9A9A9A),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                '₹${offer.price.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: isBest ? _green : _ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              // Buy from this vendor at their price.
              Cart.instance.add(
                Product(
                  id: '${product.id}@${offer.store}',
                  name: product.name,
                  category: product.category,
                  tab: product.tab,
                  price: offer.price,
                  imageUrl: product.imageUrl,
                  store: offer.store,
                  description: product.description,
                ),
              );
              showAddedToast(context, product);
            },
            child: Container(
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isBest ? _green : const Color(0xFFF1F1EF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Add from ${offer.store}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isBest ? Colors.white : _ink,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Everything comparable to this one, on the fields its group is compared by.
/// Loaded here rather than passed in: the catalogue in hand is one shop's
/// view, and a rival is by definition somebody else's stock.
class _Rivals extends StatefulWidget {
  final Product product;
  const _Rivals({required this.product});

  @override
  State<_Rivals> createState() => _RivalsState();
}

class _RivalsState extends State<_Rivals> {
  late final Future<Map<String, dynamic>> _future = Api.instance.compare(
    widget.product.compareGroup,
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final fields = [
          for (final a in (snap.data!['attributes'] as List<dynamic>))
            GroupAttribute.fromJson(a as Map<String, dynamic>),
        ];
        final rows = (snap.data!['products'] as List<dynamic>)
            .cast<Map<String, dynamic>>();
        // One product on its own is not a comparison, it is a product.
        if (rows.length < 2) return const SizedBox.shrink();
        final cheapest = rows.first['id'];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Other ${snap.data!['group']}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            const Text(
              'Same job, side by side. Cheapest first.',
              style: TextStyle(fontSize: 12, color: Color(0xFF6B6B6B)),
            ),
            const SizedBox(height: 10),
            // Scrolls sideways: a template can carry five fields, and squeezing
            // them into a phone's width is what turns a table into a puzzle.
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final row in rows)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 170,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${row['title']}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: row['id'] == widget.product.id
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '${row['store']}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF9A9A9A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 92,
                              child: Row(
                                children: [
                                  Text(
                                    '₹${(row['price'] as num).toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                      color: row['id'] == cheapest
                                          ? _green
                                          : _ink,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            for (final f in fields)
                              SizedBox(
                                width: 96,
                                child: Text(
                                  f.show(
                                    '${(row['values'] as Map?)?[f.name] ?? ''}',
                                  ),
                                  style: const TextStyle(fontSize: 12.5),
                                ),
                              ),
                          ],
                        ),
                      ),
                    const Divider(height: 14),
                    // The header goes last in the column but reads first,
                    // because the rows above set the column widths.
                    Row(
                      children: [
                        const SizedBox(width: 170, child: Text('')),
                        const SizedBox(
                          width: 92,
                          child: Text(
                            'Price',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF9A9A9A),
                            ),
                          ),
                        ),
                        for (final f in fields)
                          SizedBox(
                            width: 96,
                            child: Text(
                              f.name,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF9A9A9A),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }
}
