import '../widgets/design_system.dart';
import '../widgets/app_nav.dart';
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
      // The bar floats over the content rather than reserving a strip, which
      // is how it sits on home — bottomNavigationBar would push every screen
      // up by its height and leave a white band under it.
      extendBody: true,
      bottomNavigationBar: const SafeArea(
        child: AppBottomNav(current: AppTab.saved),
      ),
      backgroundColor: LamazonTheme.canvas,
      body: ReadableBody(
        maxWidth: 820,
        child: SafeArea(
          child: ListenableBuilder(
            listenable: Wishlist.instance,
            builder: (context, _) {
              final items = shownCatalog
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
                              color: LamazonTheme.text,
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
                        ? EmptyState(
                            icon: LucideIcons.heart,
                            title: 'Nothing saved yet',
                            message:
                                'Tap the heart on a product to keep it here.',
                            action: 'Explore products',
                            onAction: () => Navigator.of(
                              context,
                            ).pushNamedAndRemoveUntil('/', (r) => false),
                          )
                        : GridView.builder(
                            padding: EdgeInsets.fromLTRB(20, 8, 20, bottomNavInset(context) + 16),
                            gridDelegate:
                                SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: productTileMax,
                                  mainAxisSpacing: 16,
                                  crossAxisSpacing: 16,
                                  childAspectRatio: productTileAspect,
                                ),
                            itemCount: items.length,
                            itemBuilder: (_, i) => ProductCard(
                              showStore: mixesStores(items),
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
