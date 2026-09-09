import '../widgets/design_system.dart';
import '../widgets/category_visual.dart';
import '../widgets/storefront.dart';
import '../data/api.dart';
import '../data/campaigns.dart';
import '../data/wishlist.dart';
import 'wishlist_screen.dart';
import '../data/app_info.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

import '../data/addresses.dart';
import '../data/catalog.dart';
import '../data/categories.dart';
import '../data/session.dart';
import '../widgets/notify_banner.dart';
import '../models/product.dart';
import '../widgets/app_nav.dart';
import '../widgets/app_shell.dart';
import '../widgets/product_card.dart';
import '../widgets/status_views.dart';
import 'addresses_screen.dart';
import 'details_screen.dart';
import 'search_screen.dart';
import 'seller_dashboard_screen.dart';
import 'shop_screen.dart';
import 'shops_screen.dart';

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
  late Future<(List<Product>, List<Shop>)> _future = _loadWithFallback();
  int _tab = 0;
  List<Campaign> _campaigns = const [];
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<List<Campaign>> _loadCampaigns() async {
    try {
      return await Api.instance.campaigns().timeout(
        const Duration(milliseconds: 1200),
      );
    } catch (e) {
      logApiFailure('campaigns', e);
      return [starterCampaign];
    }
  }

  void _selectDepartment(int index) => setState(() {
    _tab = index;
    _shownCount = _productPage;
  });

  /// Kept aside so the drawer can list every category without waiting on a
  /// second load. Assigned before the FutureBuilder rebuilds, so no setState.
  List<Product> _all = const [];

  /// How much of the grid is built. Reset whenever the tab changes, so
  /// switching department does not carry ten pages of the last one.
  int _shownCount = _productPage;

  Future<(List<Product>, List<Shop>)> _load() async {
    // The navigation comes down with the catalogue: the tabs are the admin's
    // now, and drawing last boot's set would show departments that are gone.
    await loadDepartments().timeout(
      const Duration(milliseconds: 800),
      onTimeout: () => departments,
    );
    final (loadedItems, loadedShops, campaigns) = await (
      loadCatalog().timeout(
        const Duration(milliseconds: 900),
        onTimeout: () => products,
      ),
      loadShops().timeout(
        const Duration(milliseconds: 900),
        onTimeout: () => shops,
      ),
      _loadCampaigns(),
    ).wait;
    _campaigns = campaigns;
    _all = loadedItems;
    // An admin can delete the department the shopper was standing in.
    if (_tab >= departments.length) _tab = 0;
    return (loadedItems, loadedShops);
  }

  Future<(List<Product>, List<Shop>)> _loadWithFallback() {
    return _load().timeout(
      const Duration(seconds: 2),
      onTimeout: () {
        _campaigns = [starterCampaign];
        _all = products;
        return (products, shops);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = departments[_tab].colour;
    return Scaffold(
      backgroundColor: kBg,
      drawer: _MenuDrawer(
        products: _all,
        activeTab: _tab,
        onTab: _selectDepartment,
      ),
      body: AnimatedContainer(
        duration: Duration(
          milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 220,
        ),
        color: Color.alphaBlend(
          (theme ?? kAccent).withValues(alpha: .035),
          const Color(0xFFF8F8F4),
        ),
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              FutureBuilder<(List<Product>, List<Shop>)>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const CatalogSkeleton();
                  }
                  if (snap.hasError) {
                    return ErrorView(
                      onRetry: () =>
                          setState(() => _future = _loadWithFallback()),
                    );
                  }
                  final (items, liveShops) = snap.data!;
                  return _content(items, liveShops);
                },
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: AppBottomNav(theme: theme),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(List<Product> items, List<Shop> liveShops) {
    final dept = departments[_tab];
    final tabName = dept.name;
    final shownShops = liveShops
        .where((s) => _tab == 0 || s.tab == tabName)
        .toList();
    final shownProducts = items
        .where((p) => _tab == 0 || p.tab == tabName)
        .toList();
    final shown = shownProducts.take(_shownCount).toList();
    final offers = shownProducts
        .where((p) => p.discounted && p.availableStock != 0)
        .take(10)
        .toList();
    final campaigns = _campaigns
        .where(
          (c) =>
              c.enabled &&
              (_tab == 0 || c.department == tabName || c.category == tabName),
        )
        .toList();
    final wide = isWide(context);
    final tint = Color.alphaBlend(
      (dept.colour ?? kAccent).withValues(alpha: .15),
      Colors.white,
    );
    final stockedDepartments = departments
        .where((d) => d.name != 'All' && items.any((p) => p.tab == d.name))
        .take(3)
        .toList();
    return RefreshIndicator(
      onRefresh: () async {
        final next = _load();
        setState(() => _future = next);
        await next;
      },
      child: ListView(
        controller: _scroll,
        padding: EdgeInsets.fromLTRB(wide ? 32 : 16, 8, wide ? 32 : 16, 110),
        children: [
          const _TopBar(),
          const SizedBox(height: 16),
          if (Session.instance.loggedIn) const NotifyBanner(),
          _SearchBar(tab: tabName),
          const SizedBox(height: 8),
          _TabBar(active: _tab, onTap: _selectDepartment),
          const SizedBox(height: 16),
          if (campaigns.isNotEmpty)
            CampaignDeck(key: ValueKey(tabName), campaigns: campaigns)
          else if (_tab != 0)
            CampaignBanner(
              campaign: Campaign(
                id: 'department-$tabName',
                title: _departmentHeadline(tabName),
                subtitle: 'Discover $tabName from your local stores.',
                category: tabName,
                colour: '#${tint.toARGB32().toRadixString(16).substring(2)}',
                cta: 'Explore $tabName',
              ),
              onTap: () => _openSearch(context, tabName),
            ),
          const SizedBox(height: 28),
          if (_tab == 0) ...[
            const Text(
              'A little of everything',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -.5,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Find your next favourite, by category.',
              style: TextStyle(color: LamazonTheme.muted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, c) => GridView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: c.maxWidth < 600
                      ? 4
                      : c.maxWidth < 1000
                      ? 6
                      : 8,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 10,
                  childAspectRatio:
                      .72 /
                      MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.5),
                ),
                itemCount: departments.length - 1,
                itemBuilder: (context, i) {
                  final d = departments[i + 1];
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _selectDepartment(i + 1),
                      child: Column(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: SizedBox.expand(
                                child: CategoryVisual(
                                  name: d.name,
                                  imageUrl: d.imageUrl,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            d.name,
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
            ),
            const SizedBox(height: 28),
          ] else
            ..._categoryBoard(context, tabName),
          if (offers.isNotEmpty) ...[
            CollectionShelf(
              title: 'Good finds. Better prices.',
              subtitle: 'Savings on the shelf right now',
              products: offers,
              colour: tint,
            ),
            const SizedBox(height: 28),
          ],
          ListenableBuilder(
            listenable: Wishlist.instance,
            builder: (context, _) {
              final saved = shownProducts
                  .where((p) => Wishlist.instance.contains(p.id))
                  .take(10)
                  .toList();
              if (saved.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 28),
                child: CollectionShelf(
                  title: 'Still on your mind?',
                  subtitle: 'Your saved finds, ready when you are',
                  products: saved,
                  colour: const Color(0xFFF1E8EF),
                  onSeeAll: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const WishlistScreen()),
                  ),
                ),
              );
            },
          ),
          if (shownShops.isNotEmpty) ...[
            _SectionHeader(
              title: 'Stores near you',
              onSeeAll: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ShopsScreen(tab: tabName)),
              ),
            ),
            const SizedBox(height: 12),
            _ShopAds(shops: shownShops),
            const SizedBox(height: 28),
          ],
          if (_tab == 0)
            for (final d in stockedDepartments) ...[
              _SectionHeader(
                title: d.name,
                onSeeAll: () => _selectDepartment(departments.indexOf(d)),
              ),
              const SizedBox(height: 12),
              if (d.categories.isNotEmpty) ...[
                _CategoryGrid(
                  department: d,
                  nodes: d.categories.take(8).toList(),
                ),
                const SizedBox(height: 16),
              ],
              CollectionShelf(
                title: _departmentHeadline(d.name),
                products: items.where((p) => p.tab == d.name).take(8).toList(),
                colour: Color.alphaBlend(
                  (d.colour ?? kAccent).withValues(alpha: .12),
                  Colors.white,
                ),
                onSeeAll: () => _selectDepartment(departments.indexOf(d)),
              ),
              const SizedBox(height: 28),
            ],
          if (shownShops.isEmpty && shownProducts.isEmpty)
            _NothingHere(tab: tabName),
          if (shownProducts.isNotEmpty) ...[
            _SectionHeader(
              title: _tab == 0
                  ? 'Discover local favourites'
                  : 'Explore $tabName',
              onSeeAll: () => _openSearch(context, tabName),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: productTileMax,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: .60,
              ),
              itemCount: shown.length,
              itemBuilder: (_, i) => ProductCard(
                product: shown[i],
                showAddToCart:
                    shown[i].options.isEmpty && shown[i].sizes.isEmpty,
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
          ],
          const SizedBox(height: 40),
          const Text(
            'Local stores.\nLots to love.',
            style: TextStyle(
              fontSize: 36,
              height: 1.05,
              letterSpacing: -1,
              fontWeight: FontWeight.w800,
              color: Color(0xFF637458),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                _selectDepartment(0);
                if (MediaQuery.disableAnimationsOf(context)) {
                  _scroll.jumpTo(0);
                } else {
                  _scroll.animateTo(
                    0,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                  );
                }
              },
              icon: const Icon(Icons.arrow_upward),
              label: const Text('Back to exploring'),
            ),
          ),
          const SizedBox(height: 12),
          const Center(child: _VersionBadge()),
        ],
      ),
    );
  }
}

String _departmentHeadline(String name) {
  return switch (CategoryVisual.indexFor(name)) {
    0 => 'A craving worth following.',
    1 => 'Fresh picks. Full cupboards.',
    2 => 'Small upgrades. Big difference.',
    3 => 'A little something lovely.',
    4 => 'Your everyday feel-good.',
    5 => 'Make yourself at home.',
    6 => 'Make room for a little play.',
    _ => 'Snack. Sip. Repeat.',
  };
}

/// An empty shop, said once instead of implied by three empty sections.
class _NothingHere extends StatelessWidget {
  final String tab;
  const _NothingHere({required this.tab});

  @override
  Widget build(BuildContext context) {
    final scoped = tab.isNotEmpty && tab != 'All';
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 24),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Icon(LucideIcons.store, size: 42, color: Color(0xFFBDBDB8)),
          const SizedBox(height: 14),
          Text(
            scoped ? 'No shops in $tab yet' : 'No shops open yet',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            scoped
                ? 'Try another department, or open a store here yourself.'
                : 'The first store to open here will show up on this page.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              color: Color(0xFF6B6B6B),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: kInk,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SellerDashboardScreen()),
            ),
            child: const Text(
              'Open your store',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
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
      return const SizedBox.shrink();
    }
    return FutureBuilder<Patch?>(
      future: updater.readCurrentPatch(),
      builder: (context, snap) {
        final n = snap.data?.number;
        return Text(
          n == null
              ? 'v${AppInfo.version} • base release'
              : 'v${AppInfo.version} • patch #$n',
          style: const TextStyle(fontSize: 11, color: Color(0xFFB0B0AC)),
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();
  @override
  Widget build(BuildContext context) => Row(
    children: [
      ActionIcon(
        icon: LucideIcons.menu,
        label: 'Browse departments',
        onPressed: Scaffold.of(context).openDrawer,
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Lamazon',
              style: TextStyle(
                fontSize: 25,
                letterSpacing: -.7,
                fontWeight: FontWeight.w800,
              ),
            ),
            ListenableBuilder(
              listenable: AddressBook.instance,
              builder: (context, _) {
                final a = AddressBook.instance.selected;
                return InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddressesScreen()),
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Row(
                      children: [
                        const Icon(
                          LucideIcons.mapPin,
                          size: 16,
                          color: LamazonTheme.green,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            a == null
                                ? 'Choose delivery location'
                                : '${a.label.title} · ${a.line}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: LamazonTheme.muted,
                            ),
                          ),
                        ),
                        const Icon(LucideIcons.chevronDown, size: 16),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    ],
  );
}

class _SearchBar extends StatelessWidget {
  final String tab;
  const _SearchBar({this.tab = ''});
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SearchScreen(tab: tab)),
      ),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          border: Border.all(color: LamazonTheme.line),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          children: [
            Icon(LucideIcons.search, size: 22),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Search products, shops & more',
                style: TextStyle(color: LamazonTheme.muted, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _TabBar extends StatelessWidget {
  final int active;
  final ValueChanged<int> onTap;
  const _TabBar({required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 78,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: departments.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (_, i) {
        final d = departments[i];
        final selected = i == active;
        return Semantics(
          selected: selected,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onTap(i),
              child: AnimatedContainer(
                duration: Duration(
                  milliseconds: MediaQuery.disableAnimationsOf(context)
                      ? 0
                      : 180,
                ),
                constraints: const BoxConstraints(minWidth: 66),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? Color.alphaBlend(
                          (d.colour ?? kAccent).withValues(alpha: .20),
                          Colors.white,
                        )
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(d.icon, size: 23, color: kInk),
                    const SizedBox(height: 6),
                    Text(
                      d.name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 3,
                      width: 22,
                      color: selected ? kInk : Colors.transparent,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
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
    // The menu is the admin's tree, not whatever strings the catalogue
    // happens to contain — that is what makes Street Food sit above Chaat
    // rather than beside it. Filtered to what is actually on sale, so no
    // branch leads to an empty shelf.
    final stocked = <String>{
      for (final p in products)
        if (p.category.isNotEmpty) p.category,
    };

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
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
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
                for (final node in tab.categories)
                  ..._branch(context, node, tab, stocked, 0),
              const SizedBox(height: 6),
            ],
            if (departments.where((d) => d.name != 'All').isEmpty)
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

/// One branch of the menu, and everything under it that has something to
/// buy. A section whose whole subtree is out of stock is left out rather than
/// opened onto an empty result.
List<Widget> _branch(
  BuildContext context,
  CategoryNode node,
  Department tab,
  Set<String> stocked,
  int depth,
) {
  final children = [
    for (final c in node.children)
      ..._branch(context, c, tab, stocked, depth + 1),
  ];
  if (children.isEmpty && !stocked.contains(node.name)) return const [];
  return [
    _DrawerCategory(
      name: node.name,
      color: tab.colour,
      depth: depth,
      section: node.children.isNotEmpty,
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                SearchScreen(initialQuery: node.name, tab: tab.name),
          ),
        );
      },
    ),
    ...children,
  ];
}

class _DrawerCategory extends StatelessWidget {
  final String name;
  final Color? color;
  final int depth;
  final bool section;
  final VoidCallback onTap;
  const _DrawerCategory({
    required this.name,
    required this.color,
    required this.onTap,
    this.depth = 0,
    this.section = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        // Indented under its tab, and again per level: the nesting is the
        // only thing saying which section a category belongs to.
        padding: EdgeInsets.fromLTRB(42 + depth * 16, 7, 12, 7),
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
                style: TextStyle(
                  fontSize: section ? 13.5 : 13,
                  fontWeight: section ? FontWeight.w700 : FontWeight.w400,
                  color: const Color(0xFF3A3A3A),
                ),
              ),
            ),
            const Icon(
              LucideIcons.chevronRight,
              size: 14,
              color: Color(0xFF62645E),
            ),
          ],
        ),
      ),
    );
  }
}

/// The shop's menu as a board of pictures: a heading per department, then a
/// grid of what sits inside it. On a department tab it is that one department;
/// on All it is every one of them, which is the whole shop on one page.
List<Widget> _categoryBoard(BuildContext context, String tab) {
  final shown = departments.where(
    (d) => d.name != 'All' && (tab == 'All' || d.name == tab),
  );
  return [
    for (final d in shown) ...[
      _SectionHeader(
        title: tab == 'All' ? d.name : 'Shop by category',
        onSeeAll: () => _openSearch(context, d.name),
      ),
      const SizedBox(height: 12),
      if (tab != 'All' && d.categories.isEmpty)
        TextButton(
          onPressed: () => _openSearch(context, d.name),
          child: Text('Browse ${d.name} products'),
        )
      else
        _CategoryGrid(
          department: d,
          // A department with nothing inside it is still somewhere to go — one
          // tile of itself, rather than a heading over a gap.
          nodes: d.categories.isEmpty
              ? [CategoryNode(d.name, const [], d.imageUrl)]
              : d.categories,
        ),
      const SizedBox(height: 22),
    ],
  ];
}

/// One department's categories, four or so across, each opening a search
/// filtered to it.
class _CategoryGrid extends StatelessWidget {
  final Department department;
  final List<CategoryNode> nodes;
  const _CategoryGrid({required this.department, required this.nodes});

  @override
  Widget build(BuildContext context) {
    final tint = (department.colour ?? kAccent).withValues(alpha: 0.14);
    return GridView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 128,
        mainAxisSpacing: 14,
        crossAxisSpacing: 12,
        // Room for the square plus two lines of name under it.
        childAspectRatio: 0.74,
      ),
      itemCount: nodes.length,
      itemBuilder: (context, i) {
        final node = nodes[i];
        return InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  SearchScreen(initialQuery: node.name, tab: department.name),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  padding: EdgeInsets.zero,
                  decoration: BoxDecoration(
                    color: tint,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  // No picture yet is the ordinary state of a fresh category,
                  // so it falls back to the department's icon rather than to
                  // a broken-image box.
                  child: CategoryVisual(
                    name: node.name,
                    imageUrl: node.imageUrl,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                node.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Promoted shops drifting past like running ads; tap one to open it.
class _ShopAds extends StatefulWidget {
  final List<Shop> shops;
  const _ShopAds({required this.shops});

  @override
  State<_ShopAds> createState() => _ShopAdsState();
}

/// Store cards that advance on their own but yield to a finger. The marquee
/// this replaced could not be steered at all — a shop slid away mid-read and
/// tapping one meant chasing it.
class _ShopAdsState extends State<_ShopAds> {
  static const _dwell = Duration(seconds: 4);

  /// How long the carousel stays still after a swipe. Long enough to read the
  /// card you went looking for; without it the next tick drags you onwards
  /// the moment you stop moving.
  static const _pauseAfterTouch = Duration(seconds: 8);

  PageController? _controller;
  Timer? _timer;
  DateTime _touched = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_dwell, (_) => _advance());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  void _advance() {
    final controller = _controller;
    if (controller == null ||
        !controller.hasClients ||
        widget.shops.length < 2) {
      return;
    }
    if (MediaQuery.disableAnimationsOf(context)) return;
    if (DateTime.now().difference(_touched) < _pauseAfterTouch) return;
    final next = ((controller.page ?? 0).round() + 1) % widget.shops.length;
    controller.animateToPage(
      next,
      // Wrapping back to the first card animates the whole way rather than
      // jumping, so the loop reads as a loop and not as a glitch.
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.shops.isEmpty) return const SizedBox.shrink();
    final wide = isWide(context);
    final fraction = wide ? 0.42 : 0.86;
    if (_controller == null || _controller!.viewportFraction != fraction) {
      final old = _controller;
      final page = old != null && old.hasClients ? (old.page ?? 0).round() : 0;
      _controller = PageController(
        viewportFraction: fraction,
        initialPage: page,
      );
      if (old != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
      }
    }
    return SizedBox(
      height: 96,
      child: NotificationListener<ScrollNotification>(
        // Only a drag counts as the shopper taking over; the notifications
        // from our own animateToPage carry no drag details.
        onNotification: (n) {
          if (n is ScrollStartNotification && n.dragDetails != null) {
            _touched = DateTime.now();
          }
          if (n is ScrollEndNotification && n.dragDetails != null) {
            _touched = DateTime.now();
          }
          return false;
        },
        child: PageView.builder(
          controller: _controller,
          padEnds: false,
          itemCount: widget.shops.length,
          itemBuilder: (_, i) => Padding(
            padding: const EdgeInsets.only(right: 14),
            child: _ShopAd(shop: widget.shops[i]),
          ),
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
      // No fixed width: the card fills whatever slot the carousel gives it.
      // It used to be 246 regardless, so on a narrow phone the PageView handed
      // it less than that and the row overflowed by the difference.
      child: Container(
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
                child: NetImage(url: thumb(shop.imageUrl, 160), padTo: 16 / 9),
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
                      Flexible(
                        child: Text(
                          'Local delivery',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B6B6B),
                          ),
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
  final VoidCallback? onSeeAll;
  const _SectionHeader({required this.title, this.onSeeAll});

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
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 10),
        if (onSeeAll != null)
          TextButton(onPressed: onSeeAll, child: const Text('See all')),
      ],
    );
  }
}
