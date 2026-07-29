import 'package:flutter/material.dart';

import '../widgets/app_shell.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/catalog.dart';
import '../models/product.dart';
import '../widgets/product_card.dart';
import 'details_screen.dart';

/// A single vendor's storefront: hero, delivery info, and their products.
class ShopScreen extends StatelessWidget {
  final Shop shop;
  const ShopScreen({super.key, required this.shop});

  @override
  Widget build(BuildContext context) {
    final items = productsAtShop(shop.name);
    return Scaffold(
      backgroundColor: const Color(0xFFF1F1EF),
      body: ReadableBody(
        maxWidth: 980,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Row(
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
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: SizedBox(
                  height: 160,
                  child: NetImage(url: shop.imageUrl),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                shop.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontFamily: 'Georgia',
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                shop.tagline,
                style: const TextStyle(fontSize: 13, color: Color(0xFF6B6B6B)),
              ),
              const SizedBox(height: 10),
              Row(
                children: const [
                  _InfoChip(icon: LucideIcons.timer, label: deliveryEta),
                  SizedBox(width: 8),
                  _InfoChip(icon: LucideIcons.mapPin, label: storeDistance),
                  SizedBox(width: 8),
                  _InfoChip(icon: LucideIcons.star, label: '4.5'),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                'Products (${items.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      'No products listed yet',
                      style: TextStyle(fontSize: 14, color: Color(0xFF6B6B6B)),
                    ),
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: productTileMax,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.68,
                  ),
                  itemCount: items.length,
                  itemBuilder: (_, i) => ProductCard(
                    product: items[i],
                    showAddToCart:
                        items[i].tab == 'Food' || items[i].tab == 'Grocery',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DetailsScreen(product: items[i]),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, size: 13, color: const Color(0xFF1A1A1A)),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
