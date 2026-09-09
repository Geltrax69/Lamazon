import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../data/cart.dart';
import '../data/seller.dart';
import '../data/session.dart';
import '../screens/cart_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/seller_dashboard_screen.dart';
import '../screens/wishlist_screen.dart';
import 'design_system.dart';

enum AppTab { home, cart, saved, account, none }

class AppBottomNav extends StatelessWidget {
  final Color? theme;
  final AppTab current;
  const AppBottomNav({super.key, this.theme, this.current = AppTab.home});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      Cart.instance,
      Seller.instance,
      Session.instance,
    ]),
    builder: (context, _) {
      final selling = Session.instance.isSeller || Seller.instance.hasStore;
      final selected = current == AppTab.none ? 0 : current.index;
      return Align(
        heightFactor: 1,
        alignment: Alignment.bottomCenter,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1400),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: LamazonTheme.line)),
          ),
          child: NavigationBar(
            selectedIndex: selected,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            onDestinationSelected: (index) {
              if (index == selected && current != AppTab.none) return;
              if (index == 0) {
                Navigator.of(context).popUntil((r) => r.isFirst);
                return;
              }
              final screen = switch (index) {
                1 => const CartScreen(),
                2 =>
                  selling
                      ? const SellerDashboardScreen()
                      : const WishlistScreen(),
                _ => const ProfileScreen(),
              };
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => screen),
              );
            },
            destinations: [
              const NavigationDestination(
                icon: Icon(LucideIcons.house),
                selectedIcon: Icon(LucideIcons.house, fill: 1),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: Cart.instance.count > 0,
                  label: Text('${Cart.instance.count}'),
                  child: const Icon(LucideIcons.shoppingCart),
                ),
                label: 'Cart',
              ),
              NavigationDestination(
                icon: Icon(selling ? LucideIcons.store : LucideIcons.heart),
                label: selling ? 'My store' : 'Saved',
              ),
              const NavigationDestination(
                icon: Icon(LucideIcons.user),
                label: 'Account',
              ),
            ],
          ),
        ),
      );
    },
  );
}
