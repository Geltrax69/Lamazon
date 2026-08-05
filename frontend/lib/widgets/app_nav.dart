import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/cart.dart';
import '../data/seller.dart';
import '../data/session.dart';
import '../screens/cart_screen.dart';
import '../screens/home_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/seller_dashboard_screen.dart';
import '../screens/wishlist_screen.dart';

/// Which of the four the current screen is, or none of them.
enum AppTab { home, cart, saved, account, none }

/// The bar that follows you around the app. It used to live only on home, so
/// every other screen was a dead end you had to back out of.
class AppBottomNav extends StatelessWidget {
  final Color? theme; // selected tab color; null = default green
  /// True on the screen the bar itself is sitting on, so it does not offer
  /// to push another copy of where you already are.
  final AppTab current;
  const AppBottomNav({super.key, this.theme, this.current = AppTab.home});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 520),
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(36),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            // Home was decoration before — a pill that looked selected on
            // every screen and did nothing. From anywhere else it is the way
            // back to the shop, and popping beats pushing another home on
            // top of the one already underneath.
            onTap: () => current == AppTab.home
                ? null
                : Navigator.of(context).popUntil((r) => r.isFirst),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              padding: EdgeInsets.symmetric(
                horizontal: current == AppTab.home ? 18 : 16,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: current == AppTab.home
                    ? (theme ?? kAccent).withValues(alpha: 0.35)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.house, size: 20, color: kInk),
                  if (current == AppTab.home) ...[
                    const SizedBox(width: 8),
                    const Text(
                      'Home',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CartScreen()),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListenableBuilder(
                listenable: Cart.instance,
                builder: (context, _) {
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(
                        LucideIcons.shoppingCart,
                        size: 22,
                        color: kInk,
                      ),
                      if (Cart.instance.count > 0)
                        Positioned(
                          top: -6,
                          right: -8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD32F2F),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${Cart.instance.count}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
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
          // Sellers get their store here instead of the wishlist — stock is
          // what they open the app for. Saved items move to the account
          // screen for them.
          ListenableBuilder(
            listenable: Seller.instance,
            builder: (context, _) {
              final selling =
                  Session.instance.isSeller || Seller.instance.hasStore;
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => selling
                        ? const SellerDashboardScreen()
                        : const WishlistScreen(),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        selling ? Icons.storefront_outlined : LucideIcons.heart,
                        size: 22,
                        color: kInk,
                      ),
                      if (selling && Seller.instance.openOrders > 0)
                        Positioned(
                          top: -6,
                          right: -8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF6C00),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${Seller.instance.openOrders}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Icon(LucideIcons.user, size: 22, color: kInk),
            ),
          ),
        ],
      ),
    );
  }
}
