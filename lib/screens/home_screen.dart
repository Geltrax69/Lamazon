import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/catalog.dart';
import '../models/product.dart';
import '../widgets/product_card.dart';
import '../widgets/status_views.dart';

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
  _Tab('Electronics', LucideIcons.headphones, Color(0xFFD5418E)),
  _Tab('Grocery', LucideIcons.carrot, Color(0xFF43A047)),
  _Tab('Food', LucideIcons.utensils, Color(0xFFFF8A3D)),
  _Tab('Gifts', LucideIcons.gift, Color(0xFF9C6ADE)),
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
              const Align(
                  alignment: Alignment.bottomCenter, child: _BottomNav()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(List<Product> items) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
      children: [
        const _TopBar(),
        const SizedBox(height: 20),
        const _SearchBar(),
        const SizedBox(height: 12),
        _TabBar(active: _tab, onTap: (i) => setState(() => _tab = i)),
        const SizedBox(height: 12),
        const _PromoBanner(),
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
          itemCount: items.length,
          itemBuilder: (_, i) => ProductCard(product: items[i]),
        ),
      ],
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
          Container(width: 1, height: 24, color: Colors.grey.shade300),
          const SizedBox(width: 12),
          const Icon(LucideIcons.slidersHorizontal, size: 20, color: kInk),
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

class _PromoBanner extends StatelessWidget {
  const _PromoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 170,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: kAccent,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: kInk,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Limited Offer',
                    style: TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'First Purchase Enjoy\na Special Offer',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: kInk,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Shop Now',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(
                        LucideIcons.arrowUpRight,
                        color: Colors.white,
                        size: 15,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: const SizedBox(
              width: 110,
              height: 130,
              child: NetImage(
                url:
                    'https://images.unsplash.com/photo-1483985988355-763728e1935b?w=400',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        const Text('See all',
            style: TextStyle(fontSize: 13, color: Color(0xFF7BA32E))),
      ],
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav();

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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: kAccent.withValues(alpha: 0.35),
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
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Icon(LucideIcons.shoppingCart, size: 22, color: kInk),
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
