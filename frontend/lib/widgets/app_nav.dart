import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../data/cart.dart';
import '../data/seller.dart';
import '../data/session.dart';
import 'design_system.dart';

enum AppTab { home, cart, saved, account, none }

/// Where the bottom bar can go. Names rather than widgets, so the bar depends
/// on no screen and the route table — which nothing imports — owns the
/// construction.
abstract final class AppRoutes {
  static const cart = '/cart';
  static const login = '/login';
  static const saved = '/saved';
  static const store = '/store';
  static const account = '/account';
}

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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: LamazonTheme.surface,
              borderRadius: BorderRadius.all(
                Radius.circular(LamazonTheme.featuredRadius),
              ),
              boxShadow: LamazonTheme.raisedShadows,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: NavigationBar(
                selectedIndex: selected,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                onDestinationSelected: (index) {
                  if (index == selected && current != AppTab.none) return;
                  if (index == 0) {
                    Navigator.of(context).popUntil((r) => r.isFirst);
                    return;
                  }
                  // Named, not constructed. The nav used to import the four
                  // screens it opens while all eight screens imported the nav
                  // back, and that cycle is what DDC blew its stack linking:
                  // every screen ended up in one module that could not be
                  // initialised without already being initialised.
                  Navigator.pushNamed(context, switch (index) {
                    1 => AppRoutes.cart,
                    2 => selling ? AppRoutes.store : AppRoutes.saved,
                    _ => AppRoutes.account,
                  });
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
                      backgroundColor: LamazonTheme.peach,
                      textColor: LamazonTheme.text,
                      label: Text('${Cart.instance.count}'),
                      child: const Icon(LucideIcons.shoppingCart),
                    ),
                    selectedIcon: const Icon(LucideIcons.shoppingCart, fill: 1),
                    label: 'Cart',
                  ),
                  NavigationDestination(
                    icon: Icon(selling ? LucideIcons.store : LucideIcons.heart),
                    selectedIcon: Icon(
                      selling ? LucideIcons.store : LucideIcons.heart,
                      fill: 1,
                    ),
                    label: selling ? 'My store' : 'Saved',
                  ),
                  const NavigationDestination(
                    icon: Icon(LucideIcons.user),
                    selectedIcon: Icon(LucideIcons.user, fill: 1),
                    label: 'Account',
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
