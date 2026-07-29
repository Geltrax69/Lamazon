import 'package:flutter/material.dart';

import '../widgets/app_shell.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/catalog.dart';
import '../data/wishlist.dart';
import '../widgets/product_card.dart';
import 'details_screen.dart';

class WishlistScreen extends StatelessWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F1EF),
      body: ReadableBody(
        maxWidth: 820,
        child: SafeArea(
          child: ListenableBuilder(
            listenable: Wishlist.instance,
            builder: (context, _) {
              final items = products
                  .where((p) => Wishlist.instance.contains(p.id))
                  .toList();
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Row(
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
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ),
                        const Text(
                          'Wishlist',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 46),
                      ],
                    ),
                  ),
                  Expanded(
                    child: items.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  LucideIcons.heart,
                                  size: 44,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'Nothing saved yet',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF6B6B6B),
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Tap the heart on any product',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF9A9A9A),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                            gridDelegate:
                                SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: productTileMax,
                                  mainAxisSpacing: 16,
                                  crossAxisSpacing: 16,
                                  childAspectRatio: 0.68,
                                ),
                            itemCount: items.length,
                            itemBuilder: (_, i) => ProductCard(
                              product: items[i],
                              showAddToCart:
                                  items[i].tab == 'Food' ||
                                  items[i].tab == 'Grocery',
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      DetailsScreen(product: items[i]),
                                ),
                              ),
                            ),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
