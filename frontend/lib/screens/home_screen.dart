import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

import '../data/addresses.dart';
import '../data/cart.dart';
import '../data/catalog.dart';
import '../data/categories.dart';
import '../data/session.dart';
import '../widgets/notify_banner.dart';
import '../data/seller.dart';
import '../models/product.dart';
import '../widgets/app_shell.dart';
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

/// Tiles built per page of the product grid.
const _productPage = 12;


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

  /// Kept aside so the drawer can list every category without waiting on a
  /// second load. Assigned before the FutureBuilder rebuilds, so no setState.
  List<Product> _all = const [];

  /// How much of the grid is built. Reset whenever the tab changes, so
  /// switching department does not carry ten pages of the last one.
  int _shownCount = _productPage;

  Future<(List<Product>, List<Shop>)> _load() async {
    // The navigation comes down with the catalogue: the tabs are the admin's
    // now, and drawing last boot's set would show departments that are gone.
    await loadDepartments();
    final items = await loadCatalog();
    final shops = await loadShops();
    _all = items;
    // An admin can delete the department the shopper was standing in.
    if (_tab >= departments.length) _tab = 0;
    return (items, shops);
  }

  @override
  void initState() {
    super.initState();
    _askForLocationIfNeeded();
  }

  /// Asks for a delivery location, but only once the saved addresses have
  /// arrived. Firing on the first frame asked people who already had an
  /// address saved, because the book was still empty when we looked.
  Future<void> _askForLocationIfNeeded() async {
    await AddressBook.instance.ready;
    if (!mounted) return;
    if (AddressBook.instance.addresses.isNotEmpty ||
        AddressBook.instance.locationEnabled) {
      return;
    }
    showLocationPrompt(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = departments[_tab].colour;
    return Scaffold(
      backgroundColor: kBg,
      drawer: _MenuDrawer(
        products: _all,
        activeTab: _tab,
        onTab: (i) => setState(() => _tab = i),
      ),
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
    final tabName = departments[_tab].name;
    final shownShops = liveShops
        .where((s) => _tab == 0 || s.tab == tabName)
        .toList();
    final shownProducts = items
        .where((p) => _tab == 0 || p.tab == tabName)
        .toList();
    final shown = shownProducts.take(_shownCount).toList();
    final wide = isWide(context);
    return ListView(
      padding: EdgeInsets.fromLTRB(wide ? 32 : 20, 8, wide ? 32 : 20, 110),
      children: [
        const _TopBar(),
        const SizedBox(height: 20),
        // Asked here, not only on the seller screen: order updates matter to
        // whoever is buying too, and this is the first screen after signing in.
        if (Session.instance.loggedIn) const NotifyBanner(),
        _SearchBar(tab: tabName),
        const SizedBox(height: 12),
        _TabBar(
          active: _tab,
          onTap: (i) => setState(() {
            _tab = i;
            _shownCount = _productPage;
          }),
        ),
        const SizedBox(height: 12),
        // Shops first: who is open near you is the thing a shopper is
        // deciding on this screen, and the categories are how they narrow it
        // down afterwards.
        _SectionHeader(
          title: 'Stores near you',
          serif: true,
          onSeeAll: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ShopsScreen(tab: tabName)),
          ),
        ),
        const SizedBox(height: 12),
        _ShopAds(shops: shownShops),
        const SizedBox(height: 22),
        _SectionHeader(
          title: 'Shop By Category',
          onSeeAll: () => _openSearch(context, tabName),
        ),
        const SizedBox(height: 12),
        _CategoryRow(products: shownProducts, tab: tabName),
        const SizedBox(height: 24),
        _SectionHeader(
          title: 'New Arrival',
          onSeeAll: () => _openSearch(context, tabName),
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
          // A page at a time. The Food tab alone is 200-odd products, and
          // building every tile up front is what made the first scroll stutter
          // on a phone.
          itemCount: shown.length,
          itemBuilder: (_, i) => ProductCard(
            product: shown[i],
            showAddToCart:
                shown[i].tab == 'Food' || shown[i].tab == 'Grocery',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DetailsScreen(product: shown[i]),
              ),
            ),
          ),
        ),
        if (shownProducts.length > shown.length) ...[
          const SizedBox(height: 16),
          _ShowMore(
            left: shownProducts.length - shown.length,
            onTap: () => setState(() => _shownCount += _productPage),
          ),
        ],
        const SizedBox(height: 16),
        const Center(child: _VersionBadge()),
      ],
    );
  }
}

/// The next page of the grid. Says how many are left, so the shopper knows
/// whether they are near the end of the aisle or the start of it.
class _ShowMore extends StatelessWidget {
  final int left;
  final VoidCallback onTap;
  const _ShowMore({required this.left, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Text(
          'Show more  ·  $left left',
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: kInk,
          ),
        ),
      ),
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
        // Every category is one tap from here, instead of scrolling the row
        // and hoping the one you want is in the current tab.
        Builder(
          builder: (context) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: Scaffold.of(context).openDrawer,
            child: Container(
              width: 42,
              height: 42,
              margin: const EdgeInsets.only(right: 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.menu, size: 19),
            ),
          ),
        ),
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
  final String tab;
  const _SearchBar({this.tab = ''});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SearchScreen(tab: tab)),
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
        itemCount: departments.length,
        separatorBuilder: (_, _) => const SizedBox(width: 30),
        itemBuilder: (_, i) {
          final tab = departments[i];
          final isActive = i == active;
          final activeColor = tab.colour ?? kInk;
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

/// The whole catalogue, one tap deep: the six tabs, then every category in
/// them. The row on the home screen only shows the current tab's categories
/// and only as many as fit; this is the version you can actually browse.
class _MenuDrawer extends StatelessWidget {
  final List<Product> products;
  final int activeTab;
  final ValueChanged<int> onTab;
  const _MenuDrawer({
    required this.products,
    required this.activeTab,
    required this.onTab,
  });

  @override
  Widget build(BuildContext context) {
    // Grouped by tab so a category sits under the department it belongs to,
    // and sorted so the list does not reshuffle when the catalogue changes.
    final byTab = <String, Set<String>>{};
    for (final p in products) {
      if (p.category.isEmpty) continue;
      byTab.putIfAbsent(p.tab, () => <String>{}).add(p.category);
    }

    return Drawer(
      backgroundColor: kBg,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Browse',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(LucideIcons.x, size: 19),
                ),
              ],
            ),
            const SizedBox(height: 6),
            for (final (i, tab) in departments.indexed) ...[
              _DrawerTab(
                tab: tab,
                selected: i == activeTab,
                onTap: () {
                  onTab(i);
                  Navigator.pop(context);
                },
              ),
              // The 'All' tab is every department at once, so listing its
              // categories here would repeat the whole drawer under it.
              if (i != 0)
                for (final name in (byTab[tab.name]?.toList()?..sort()) ??
                    const <String>[])
                  _DrawerCategory(
                    name: name,
                    color: tab.colour,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              SearchScreen(initialQuery: name, tab: tab.name),
                        ),
                      );
                    },
                  ),
              const SizedBox(height: 6),
            ],
            if (products.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'Categories appear here once the catalogue loads.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF6B6B6B)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DrawerTab extends StatelessWidget {
  final Department tab;
  final bool selected;
  final VoidCallback onTap;
  const _DrawerTab({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = tab.colour ?? const Color(0xFF1A1A1A);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.14) : null,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(tab.icon, size: 18, color: accent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                tab.name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: selected ? accent : const Color(0xFF1A1A1A),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerCategory extends StatelessWidget {
  final String name;
  final Color? color;
  final VoidCallback onTap;
  const _DrawerCategory({
    required this.name,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        // Indented under its tab: the nesting is the only thing saying which
        // department a category belongs to.
        padding: const EdgeInsets.fromLTRB(42, 8, 12, 8),
        child: Row(
          children: [
            Container(
              width: 5,
              height: 5,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: color ?? const Color(0xFF6B6B6B),
                shape: BoxShape.circle,
              ),
            ),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(fontSize: 13.5, color: Color(0xFF3A3A3A)),
              ),
            ),
            const Icon(
              LucideIcons.chevronRight,
              size: 14,
              color: Color(0xFF9A9A9A),
            ),
          ],
        ),
      ),
    );
  }
}

/// Product categories in the current tab, each opening a filtered search.
class _CategoryRow extends StatelessWidget {
  final List<Product> products;
  final String tab;
  const _CategoryRow({required this.products, this.tab = ''});

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
                builder: (_) => SearchScreen(initialQuery: name, tab: tab),
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
    // A PageView, not the drifting marquee it used to be: a shop that slides
    // away on its own is one you cannot read, and cannot tap without chasing.
    // Swiping is the shopper's now, and each card snaps into place.
    final wide = isWide(context);
    return SizedBox(
      height: 96,
      child: PageView.builder(
        controller: PageController(
          // Less than one, so the next card peeks in and the row reads as
          // something that continues rather than as one lonely tile.
          viewportFraction: wide ? 0.42 : 0.86,
        ),
        padEnds: false,
        itemCount: shops.length,
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.only(right: 14),
          child: _ShopAd(shop: shops[i]),
        ),
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
/// Search stays inside the department the shopper is browsing.
void _openSearch(BuildContext context, [String tab = '']) => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SearchScreen(tab: tab)),
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
