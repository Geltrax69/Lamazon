import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

import '../data/cart.dart';
import '../data/catalog.dart';
import '../models/product.dart';
import '../widgets/product_card.dart';
import '../widgets/status_views.dart';
import 'cart_screen.dart';
import 'details_screen.dart';

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
  late Future<List<Product>> _future = loadCatalog();
  int _tab = 0;

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
              FutureBuilder<List<Product>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const LoadingView();
                  }
                  if (snap.hasError) {
                    return ErrorView(
                      onRetry: () =>
                          setState(() => _future = loadCatalog()),
                    );
                  }
                  return _content(snap.data!);
                },
              ),
              Align(
                  alignment: Alignment.bottomCenter,
                  child: _BottomNav(theme: theme)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(List<Product> items) {
    final tabName = _tabs[_tab].name;
    final shownShops =
        shops.where((s) => _tab == 0 || s.tab == tabName).toList();
    final shownProducts =
        items.where((p) => _tab == 0 || p.tab == tabName).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
      children: [
        const _TopBar(),
        const SizedBox(height: 20),
        const _SearchBar(),
        const SizedBox(height: 12),
        _TabBar(active: _tab, onTap: (i) => setState(() => _tab = i)),
        const SizedBox(height: 12),
        const _SectionHeader(title: 'Shop By Shop', serif: true),
        const SizedBox(height: 12),
        _ShopRow(shops: shownShops),
        const SizedBox(height: 24),
        const _SectionHeader(title: 'New Arrival'),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.68,
          ),
          itemCount: shownProducts.length,
          itemBuilder: (_, i) => ProductCard(
            product: shownProducts[i],
            showAddToCart: shownProducts[i].tab == 'Food' ||
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
      return const Text('dev build — no OTA',
          style: TextStyle(fontSize: 11, color: Color(0xFFB0B0AC)));
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
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: const [
        _CircleButton(icon: LucideIcons.menu),
        _CircleButton(icon: LucideIcons.shoppingBag),
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  const _CircleButton({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 20, color: kInk),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.search, size: 20, color: Colors.grey),
          const SizedBox(width: 10),
          const Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'what are you looking for?',
                hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
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
                Icon(tab.icon,
                    size: 22, color: isActive ? activeColor : kInk),
                const SizedBox(height: 4),
                Text(tab.name,
                    style: TextStyle(
                        fontSize: 12,
                        color: isActive ? activeColor : kInk,
                        fontWeight:
                            isActive ? FontWeight.w800 : FontWeight.w500)),
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

/// Horizontal carousel of promoted shops for the selected category.
class _ShopRow extends StatelessWidget {
  final List<Shop> shops;
  const _ShopRow({required this.shops});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 208,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: shops.length,
        separatorBuilder: (_, _) => const SizedBox(width: 16),
        itemBuilder: (_, i) {
          final shop = shops[i];
          return SizedBox(
            width: 150,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: NetImage(url: shop.imageUrl),
                  ),
                ),
                const SizedBox(height: 10),
                Text(shop.name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(shop.tagline,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF6B6B6B))),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final bool serif; // editorial serif look, as in the Shop By Shop design
  const _SectionHeader({required this.title, this.serif = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(title,
            style: serif
                ? const TextStyle(
                    fontSize: 24,
                    fontFamily: 'Georgia',
                    fontWeight: FontWeight.w600)
                : const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700)),
        const Text('See all',
            style: TextStyle(fontSize: 13, color: Color(0xFF7BA32E))),
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
                Text('Home',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const CartScreen())),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListenableBuilder(
                listenable: Cart.instance,
                builder: (context, _) {
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(LucideIcons.shoppingCart,
                          size: 22, color: kInk),
                      if (Cart.instance.count > 0)
                        Positioned(
                          top: -6,
                          right: -8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD32F2F),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${Cart.instance.count}',
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Icon(LucideIcons.heart, size: 22, color: kInk),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Icon(LucideIcons.user, size: 22, color: kInk),
          ),
        ],
      ),
    );
  }
}
