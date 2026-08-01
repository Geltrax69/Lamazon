import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

import '../data/addresses.dart';
import '../data/cart.dart';
import '../data/catalog.dart';
import '../data/session.dart';
import '../widgets/notify_banner.dart';
import '../data/seller.dart';
import '../models/product.dart';
import '../widgets/app_shell.dart';
import '../widgets/image_marquee.dart';
import '../widgets/location_prompt.dart';
import '../widgets/product_card.dart';
import '../widgets/status_views.dart';
import 'addresses_screen.dart';
import 'cart_screen.dart';
import 'details_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';
import 'seller_dashboard_screen.dart';
import 'shop_screen.dart';
import 'shops_screen.dart';
import 'wishlist_screen.dart';

const kAccent = Color(0xFFA6D544); // lime green from the design
const kInk = Color(0xFF1A1A1A);
const kBg = Color(0xFFF1F1EF);

class _Tab {
  final String name;
  final IconData icon;
  final Color? color; // null = default white theme
  const _Tab(this.name, this.icon, this.color);
}

const _tabs = [
  _Tab('All', LucideIcons.layoutGrid, null),
  _Tab('Electronics', LucideIcons.headphones, Color(0xFF2F6FED)),
  _Tab('Grocery', LucideIcons.carrot, Color(0xFF43A047)),
  _Tab('Food', LucideIcons.utensils, Color(0xFFFF8A3D)),
  _Tab('Gifts', LucideIcons.gift, Color(0xFF9C6ADE)),
  _Tab('Beauty', LucideIcons.brush, Color(0xFFF06292)),
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Catalog and shops both come from the API; one future so the screen has
  // a single loading and error state.
  late Future<(List<Product>, List<Shop>)> _future = _load();
  int _tab = 0;

  Future<(List<Product>, List<Shop>)> _load() async =>
      (await loadCatalog(), await loadShops());

  @override
  void initState() {
    super.initState();
    // Ask for a delivery location once, on the first frame after launch.
    if (!AddressBook.instance.locationEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showLocationPrompt(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = _tabs[_tab].color;
    return Scaffold(
      backgroundColor: kBg,
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0, 0.45],
            colors: [theme?.withValues(alpha: 0.28) ?? kBg, kBg],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              FutureBuilder<(List<Product>, List<Shop>)>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const LoadingView();
                  }
                  if (snap.hasError) {
                    return ErrorView(
                      onRetry: () => setState(() => _future = _load()),
                    );
                  }
                  final (items, liveShops) = snap.data!;
                  return _content(items, liveShops);
                },
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: _BottomNav(theme: theme),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(List<Product> items, List<Shop> liveShops) {
    final tabName = _tabs[_tab].name;
    final shownShops = liveShops
        .where((s) => _tab == 0 || s.tab == tabName)
        .toList();
    final shownProducts = items
        .where((p) => _tab == 0 || p.tab == tabName)
        .toList();
    final wide = isWide(context);
    return ListView(
      padding: EdgeInsets.fromLTRB(wide ? 32 : 20, 8, wide ? 32 : 20, 110),
      children: [
        const _TopBar(),
        const SizedBox(height: 20),
        // Asked here, not only on the seller screen: order updates matter to
        // whoever is buying too, and this is the first screen after signing in.
        if (Session.instance.loggedIn) const NotifyBanner(),
        const _SearchBar(),
        const SizedBox(height: 12),
        _TabBar(active: _tab, onTap: (i) => setState(() => _tab = i)),
        const SizedBox(height: 12),
        _SectionHeader(
          title: 'Shop By Category',
          serif: true,
          onSeeAll: () => _openSearch(context),
        ),
        const SizedBox(height: 12),
        _CategoryRow(products: shownProducts),
        const SizedBox(height: 22),
        _SectionHeader(
          title: 'Stores near you',
          onSeeAll: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ShopsScreen()),
          ),
        ),
        const SizedBox(height: 12),
        _ShopAds(shops: shownShops),
        const SizedBox(height: 24),
        _SectionHeader(
          title: 'New Arrival',
          onSeeAll: () => _openSearch(context),
        ),
        const SizedBox(height: 12),
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
          itemCount: shownProducts.length,
          itemBuilder: (_, i) => ProductCard(
            product: shownProducts[i],
            showAddToCart:
                shownProducts[i].tab == 'Food' ||
                shownProducts[i].tab == 'Grocery',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DetailsScreen(product: shownProducts[i]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Center(child: _VersionBadge()),
      ],
    );
  }
}

/// Shows which OTA patch is running, so update delivery is visible on-device.
class _VersionBadge extends StatelessWidget {
  const _VersionBadge();

  @override
  Widget build(BuildContext context) {
    final updater = ShorebirdUpdater();
    if (!updater.isAvailable) {
      // Debug builds and platforms without the Shorebird engine.
      return const Text(
        'dev build — no OTA',
        style: TextStyle(fontSize: 11, color: Color(0xFFB0B0AC)),
      );
    }
    return FutureBuilder<Patch?>(
      future: updater.readCurrentPatch(),
      builder: (context, snap) {
        final n = snap.data?.number;
        return Text(
          n == null ? 'v1.0.1 • base release' : 'v1.0.1 • patch #$n',
          style: const TextStyle(fontSize: 11, color: Color(0xFFB0B0AC)),
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Location + how fast the porter reaches this address. Tapping opens
        // the saved addresses so the delivery point can be switched.
        Expanded(
          child: ListenableBuilder(
            listenable: AddressBook.instance,
            builder: (context, _) {
              final a = AddressBook.instance.selected;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddressesScreen()),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Delivery in $deliveryEta',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          a == null
                              ? LucideIcons.mapPin
                              : AddressesScreen.iconFor(a.label),
                          size: 13,
                          color: const Color(0xFF6B6B6B),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            a == null
                                ? 'Set delivery location'
                                : '${a.label.title} • ${a.city} • $storeDistance',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF6B6B6B),
                            ),
                          ),
                        ),
                        const Icon(
                          LucideIcons.chevronDown,
                          size: 15,
                          color: Color(0xFF6B6B6B),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SearchScreen()),
      ),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
        ),
        child: const Row(
          children: [
            Icon(LucideIcons.search, size: 20, color: Colors.grey),
            SizedBox(width: 10),
            Text(
              'what are you looking for?',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  final int active;
  final ValueChanged<int> onTap;
  const _TabBar({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _tabs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 30),
        itemBuilder: (_, i) {
          final tab = _tabs[i];
          final isActive = i == active;
          final activeColor = tab.color ?? kInk;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onTap(i),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(tab.icon, size: 22, color: isActive ? activeColor : kInk),
                const SizedBox(height: 4),
                Text(
                  tab.name,
                  style: TextStyle(
                    fontSize: 12,
                    color: isActive ? activeColor : kInk,
                    fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  height: 3,
                  width: 34,
                  decoration: BoxDecoration(
                    color: isActive ? activeColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Product categories in the current tab, each opening a filtered search.
class _CategoryRow extends StatelessWidget {
  final List<Product> products;
  const _CategoryRow({required this.products});

  @override
  Widget build(BuildContext context) {
    // One tile per category present, illustrated by the first product in it.
    final seen = <String, Product>{};
    for (final p in products) {
      seen.putIfAbsent(p.category, () => p);
    }
    final entries = seen.entries.toList();
    return SizedBox(
      height: 124,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: entries.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, i) {
          final name = entries[i].key;
          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SearchScreen(initialQuery: name),
              ),
            ),
            child: SizedBox(
              width: 82,
              child: Column(
                children: [
                  Container(
                    width: 78,
                    height: 78,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(5),
                    child: ClipOval(
                      child: NetImage(
                        url: thumb(entries[i].value.imageUrl, 160),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Promoted shops drifting past like running ads; tap one to open it.
class _ShopAds extends StatelessWidget {
  final List<Shop> shops;
  const _ShopAds({required this.shops});

  @override
  Widget build(BuildContext context) {
    if (shops.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 96,
      child: MarqueeStrip(
        itemWidth: 246 + 14,
        period: Duration(seconds: 6 * shops.length),
        children: [
          for (final shop in shops)
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: _ShopAd(shop: shop),
            ),
        ],
      ),
    );
  }
}

class _ShopAd extends StatelessWidget {
  final Shop shop;
  const _ShopAd({required this.shop});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ShopScreen(shop: shop)),
      ),
      child: Container(
        width: 246,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 76,
                height: 76,
                child: NetImage(url: thumb(shop.imageUrl, 160)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    shop.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    shop.tagline,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      height: 1.3,
                      color: Color(0xFF6B6B6B),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: const [
                      Icon(
                        LucideIcons.timer,
                        size: 12,
                        color: Color(0xFF6B6B6B),
                      ),
                      SizedBox(width: 4),
                      Text(
                        deliveryEta,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B6B6B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Browsing everything is what the search screen already does, so "See all"
/// opens it rather than inventing a second list of the same products.
void _openSearch(BuildContext context) => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SearchScreen()),
    );

class _SectionHeader extends StatelessWidget {
  final String title;
  final bool serif; // editorial serif look, as in the Shop By Shop design
  final VoidCallback? onSeeAll;
  const _SectionHeader({required this.title, this.serif = false, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: serif
                ? const TextStyle(
                    fontSize: 24,
                    fontFamily: 'Georgia',
                    fontWeight: FontWeight.w600,
                  )
                : const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 10),
        // "See all" was a bare Text — it looked like a link and did nothing.
        GestureDetector(
          onTap: onSeeAll,
          behavior: HitTestBehavior.opaque,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Text(
              'See all',
              style: TextStyle(fontSize: 13, color: Color(0xFF7BA32E)),
            ),
          ),
        ),
      ],
    );
  }
}

class _BottomNav extends StatelessWidget {
  final Color? theme; // selected tab color; null = default green
  const _BottomNav({this.theme});

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
          AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: (theme ?? kAccent).withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Row(
              children: [
                Icon(LucideIcons.house, size: 20, color: kInk),
                SizedBox(width: 8),
                Text(
                  'Home',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ],
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
              final selling = Seller.instance.hasStore;
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
	                        selling
	                            ? Icons.storefront_outlined
	                            : LucideIcons.heart,
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
