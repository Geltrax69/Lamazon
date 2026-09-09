import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/addresses.dart';
import '../data/api.dart';
import '../data/campaigns.dart';
import '../data/catalog.dart';
import '../data/categories.dart';
import '../data/session.dart';
import '../data/wishlist.dart';
import '../models/product.dart';
import '../widgets/app_nav.dart';
import '../widgets/category_visual.dart';
import '../widgets/design_system.dart';
import '../widgets/notify_banner.dart';
import '../widgets/product_card.dart';
import '../widgets/status_views.dart';
import '../widgets/storefront.dart';
import 'addresses_screen.dart';
import 'details_screen.dart';
import 'search_screen.dart';
import 'seller_dashboard_screen.dart';
import 'shop_screen.dart';
import 'shops_screen.dart';
import 'wishlist_screen.dart';

const _productPage = 12;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<(List<Product>, List<Shop>)> _future = _loadWithFallback();
  final _scroll = ScrollController();
  List<Campaign> _campaigns = const [];
  List<Product> _all = const [];
  int _tab = 0;
  int _shownCount = _productPage;

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
    } catch (error) {
      logApiFailure('campaigns', error);
      return [starterCampaign];
    }
  }

  Future<(List<Product>, List<Shop>)> _load() async {
    await loadDepartments().timeout(
      const Duration(milliseconds: 800),
      onTimeout: () => departments,
    );
    final (items, liveShops, campaigns) = await (
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
    _all = items;
    if (_tab >= departments.length) _tab = 0;
    return (items, liveShops);
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

  void _selectDepartment(int index) {
    setState(() {
      _tab = index;
      _shownCount = _productPage;
    });
  }

  void _openSearch([String initialQuery = '']) {
    final department = departments[_tab].name;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SearchScreen(
          initialQuery: initialQuery,
          tab: initialQuery.isEmpty ? department : departmentOf(initialQuery),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LamazonTheme.canvas,
      drawer: _BrowseDrawer(
        products: _all,
        activeTab: _tab,
        onSelectDepartment: _selectDepartment,
      ),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            FutureBuilder<(List<Product>, List<Shop>)>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const CatalogSkeleton();
                }
                if (snapshot.hasError) {
                  return ErrorView(
                    onRetry: () =>
                        setState(() => _future = _loadWithFallback()),
                  );
                }
                final (items, liveShops) = snapshot.data!;
                return _content(items, liveShops);
              },
            ),
            const Align(
              alignment: Alignment.bottomCenter,
              child: AppBottomNav(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(List<Product> items, List<Shop> liveShops) {
    final activeDepartment = departments[_tab];
    final tabName = activeDepartment.name;
    final scopedProducts = items
        .where((product) => _tab == 0 || product.tab == tabName)
        .toList();
    final scopedShops = liveShops
        .where((shop) => _tab == 0 || shop.tab == tabName)
        .toList();
    final offers = scopedProducts
        .where((product) => product.discounted && product.availableStock != 0)
        .take(10)
        .toList();
    final campaigns = _campaigns
        .where(
          (campaign) =>
              campaign.enabled &&
              (_tab == 0 ||
                  campaign.department == tabName ||
                  campaign.category == tabName),
        )
        .toList();
    final visible = scopedProducts.take(_shownCount).toList();

    return RefreshIndicator(
      onRefresh: () async {
        final next = _load();
        setState(() => _future = next);
        await next;
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth >= 1500
              ? 1400.0
              : constraints.maxWidth;
          final side =
              (constraints.maxWidth - maxWidth) / 2 +
              LamazonTheme.gutter(context);
          return ListView(
            controller: _scroll,
            padding: EdgeInsets.fromLTRB(side, 8, side, 112),
            children: [
              const _ServiceHeader(),
              const SizedBox(height: 12),
              _SearchLaunch(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        SearchScreen(tab: tabName == 'All' ? '' : tabName),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _DepartmentStrip(active: _tab, onSelect: _selectDepartment),
              if (Session.instance.loggedIn) ...[
                const SizedBox(height: 12),
                const NotifyBanner(),
              ],
              const SizedBox(height: 22),
              if (campaigns.isNotEmpty)
                CampaignDeck(key: ValueKey(tabName), campaigns: campaigns)
              else
                CampaignBanner(
                  campaign: Campaign(
                    id: 'department-$tabName',
                    title: _departmentHeadline(tabName),
                    subtitle: 'A considered edit from stores in your area.',
                    category: tabName == 'All' ? '' : tabName,
                    colour: '#143E32',
                    cta: 'Explore the edit',
                  ),
                  onTap: () => _openSearch(tabName == 'All' ? '' : tabName),
                ),
              const SizedBox(height: 34),
              _CategoryBoard(
                activeTab: _tab,
                onSelectDepartment: _selectDepartment,
                onOpenCategory: (name, department) => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        SearchScreen(initialQuery: name, tab: department),
                  ),
                ),
              ),
              if (offers.isNotEmpty) ...[
                const SizedBox(height: 34),
                CollectionShelf(
                  title: 'Around you',
                  subtitle: 'Fresh picks with a real saving',
                  products: offers,
                  onSeeAll: () => _openSearch(),
                ),
              ],
              if (scopedShops.isNotEmpty) ...[
                const SizedBox(height: 36),
                SectionHeading(
                  title: 'Stores near you',
                  subtitle: 'Local storefronts, one tap away',
                  onAction: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ShopsScreen(tab: tabName),
                    ),
                  ),
                  actionLabel: 'See all',
                ),
                const SizedBox(height: 14),
                _StoreRail(shops: scopedShops),
              ],
              ListenableBuilder(
                listenable: Wishlist.instance,
                builder: (context, _) {
                  final saved = scopedProducts
                      .where(
                        (product) => Wishlist.instance.contains(product.id),
                      )
                      .take(10)
                      .toList();
                  if (saved.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 36),
                    child: CollectionShelf(
                      title: 'Saved for later',
                      subtitle: 'Your shortlist is waiting',
                      products: saved,
                      onSeeAll: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const WishlistScreen(),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 36),
              if (scopedProducts.isEmpty)
                _NothingHere(tab: tabName)
              else ...[
                SectionHeading(
                  title: _tab == 0
                      ? 'Discover local favourites'
                      : 'Explore $tabName',
                  subtitle: _tab == 0
                      ? 'Real products from nearby shops'
                      : 'Everything in this department',
                  onAction: () => _openSearch(),
                  actionLabel: 'See all',
                ),
                const SizedBox(height: 14),
                GridView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 240,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: .60,
                  ),
                  itemCount: visible.length,
                  itemBuilder: (_, index) => ProductCard(
                    product: visible[index],
                    showAddToCart:
                        visible[index].options.isEmpty &&
                        visible[index].sizes.isEmpty,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DetailsScreen(product: visible[index]),
                      ),
                    ),
                  ),
                ),
                if (scopedProducts.length > visible.length) ...[
                  const SizedBox(height: 20),
                  Center(
                    child: ActionButton(
                      label:
                          'Show ${scopedProducts.length - visible.length} more',
                      onPressed: () =>
                          setState(() => _shownCount += _productPage),
                      icon: Icons.arrow_downward,
                      primary: false,
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 42),
              const _HomeClose(),
            ],
          );
        },
      ),
    );
  }
}

String _departmentHeadline(String name) {
  return switch (CategoryVisual.indexFor(name)) {
    0 => 'A little delight, close by.',
    1 => 'A fresher kind of everyday.',
    2 => 'Small upgrades, beautifully useful.',
    3 => 'Something thoughtful, waiting nearby.',
    4 => 'Your everyday feel-good edit.',
    5 => 'Make home feel more like home.',
    6 => 'A little play goes a long way.',
    _ => 'Snack, sip, repeat.',
  };
}

class _ServiceHeader extends StatelessWidget {
  const _ServiceHeader();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(LamazonTheme.featuredRadius),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [LamazonTheme.forest, LamazonTheme.strong],
      ),
      boxShadow: LamazonTheme.raisedShadows,
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 15),
      child: Row(
        children: [
          ActionIcon(
            icon: LucideIcons.menu,
            label: 'Browse departments',
            onPressed: Scaffold.of(context).openDrawer,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: ListenableBuilder(
              listenable: AddressBook.instance,
              builder: (context, _) {
                final address = AddressBook.instance.selected;
                return InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddressesScreen()),
                  ),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Lamazon',
                          style: TextStyle(
                            fontFamily: 'InterTight',
                            fontSize: 22,
                            height: 28 / 22,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -.7,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(
                              LucideIcons.mapPin,
                              size: 15,
                              color: LamazonTheme.lime,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                address == null
                                    ? 'Choose delivery location'
                                    : '${address.label.title} · ${address.line}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'InterTight',
                                  fontSize: 13.5,
                                  height: 18 / 13.5,
                                  letterSpacing: .2,
                                  color: Color(0xFFE4EBE6),
                                ),
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Icon(
                              LucideIcons.chevronDown,
                              size: 16,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          const _AccountShortcut(),
        ],
      ),
    ),
  );
}

class _AccountShortcut extends StatelessWidget {
  const _AccountShortcut();
  @override
  // Named, not constructed: importing ProfileScreen here closes a
  // home -> profile -> login -> home cycle that DDC cannot link.
  Widget build(BuildContext context) => TactileIconButton(
    icon: LucideIcons.userRound,
    label: 'Open account',
    background: Colors.white.withValues(alpha: .96),
    onPressed: () => Navigator.pushNamed(context, AppRoutes.account),
  );
}

class _SearchLaunch extends StatelessWidget {
  final VoidCallback onTap;
  const _SearchLaunch({required this.onTap});

  @override
  Widget build(BuildContext context) => ElevatedSurface(
    radius: LamazonTheme.featuredRadius,
    onTap: onTap,
    semanticLabel: 'Search products and stores',
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    prominent: true,
    child: const Row(
      children: [
        Icon(LucideIcons.search, size: 21, color: LamazonTheme.strong),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            'Search products, shops and more',
            style: TextStyle(
              fontFamily: 'InterTight',
              fontSize: 15,
              letterSpacing: .2,
              color: LamazonTheme.muted,
            ),
          ),
        ),
        Icon(LucideIcons.arrowUpRight, size: 18, color: LamazonTheme.strong),
      ],
    ),
  );
}

class _DepartmentStrip extends StatelessWidget {
  final int active;
  final ValueChanged<int> onSelect;
  const _DepartmentStrip({required this.active, required this.onSelect});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 92,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      itemCount: departments.length,
      padding: const EdgeInsets.only(bottom: 8),
      separatorBuilder: (_, _) => const SizedBox(width: 11),
      itemBuilder: (context, index) {
        final department = departments[index];
        final selected = index == active;
        return Semantics(
          selected: selected,
          button: true,
          label: department.name,
          child: SizedBox(
            width: 66,
            child: InkWell(
              onTap: () => onSelect(index),
              borderRadius: BorderRadius.circular(14),
              // The tap target is the whole column; the hover wash over that
              // much area reads as a grey slab, so only the press shows.
              hoverColor: Colors.transparent,
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: Duration(
                      milliseconds: MediaQuery.disableAnimationsOf(context)
                          ? 0
                          : 180,
                    ),
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: selected
                          ? LamazonTheme.lime
                          : LamazonTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: selected
                          ? LamazonTheme.tactileShadows
                          : LamazonTheme.surfaceShadows,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: index == 0
                        ? Icon(department.icon, color: LamazonTheme.strong)
                        : CategoryVisual(
                            name: department.name,
                            imageUrl: department.imageUrl,
                          ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    department.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'InterTight',
                      fontSize: 11.5,
                      letterSpacing: .15,
                      color: selected ? LamazonTheme.strong : LamazonTheme.text,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _CategoryBoard extends StatelessWidget {
  final int activeTab;
  final ValueChanged<int> onSelectDepartment;
  final void Function(String category, String department) onOpenCategory;
  const _CategoryBoard({
    required this.activeTab,
    required this.onSelectDepartment,
    required this.onOpenCategory,
  });

  @override
  Widget build(BuildContext context) {
    final active = departments[activeTab];
    // "All" is a filter, not a need, and its artwork is another department's —
    // so the board shows the eight real departments, or, once one is chosen,
    // that department's own categories.
    final entries = <_CategoryEntry>[
      if (activeTab == 0)
        for (final (index, department) in departments.indexed)
          if (index != 0)
            _CategoryEntry(
              department.name,
              department.name,
              department.imageUrl,
              departmentIndex: index,
            )
          else
            for (final category in active.categories)
              _CategoryEntry(category.name, active.name, category.imageUrl),
    ];
    if (entries.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          activeTab == 0 ? 'Shop by need' : 'Find your next thing',
          style: LamazonTheme.sectionText,
        ),
        const SizedBox(height: 4),
        Text(
          activeTab == 0
              ? 'Every department, one calm visual system'
              : 'Browse the edit, then choose a real local product',
          style: LamazonTheme.mutedBodyText,
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final count = constraints.maxWidth >= 1060
                ? 8
                : constraints.maxWidth >= 690
                ? 6
                : 4;
            return GridView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: count,
                mainAxisSpacing: 14,
                crossAxisSpacing: 12,
                childAspectRatio: .73,
              ),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                return _CategoryTile(
                  entry: entry,
                  onTap: () {
                    if (entry.departmentIndex != null) {
                      onSelectDepartment(entry.departmentIndex!);
                    } else {
                      onOpenCategory(entry.name, entry.department);
                    }
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _CategoryEntry {
  final String name;
  final String department;
  final String imageUrl;
  final int? departmentIndex;
  const _CategoryEntry(
    this.name,
    this.department,
    this.imageUrl, {
    this.departmentIndex,
  });
}

class _CategoryTile extends StatelessWidget {
  final _CategoryEntry entry;
  final VoidCallback onTap;
  const _CategoryTile({required this.entry, required this.onTap});
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Browse ${entry.name}',
    child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(LamazonTheme.smallRadius),
        boxShadow: LamazonTheme.surfaceShadows,
      ),
      child: Material(
        color: LamazonTheme.surface,
        borderRadius: BorderRadius.circular(LamazonTheme.smallRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Column(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: CategoryVisual(
                      name: entry.name,
                      imageUrl: entry.imageUrl,
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  entry.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'InterTight',
                    fontSize: 12,
                    height: 15 / 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: .1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _StoreRail extends StatelessWidget {
  final List<Shop> shops;
  const _StoreRail({required this.shops});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 116,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      padding: const EdgeInsets.only(bottom: 10),
      itemCount: shops.length,
      separatorBuilder: (_, _) => const SizedBox(width: 12),
      itemBuilder: (context, index) => _StoreTile(shop: shops[index]),
    ),
  );
}

class _StoreTile extends StatelessWidget {
  final Shop shop;
  const _StoreTile({required this.shop});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 260,
    child: ElevatedSurface(
      radius: LamazonTheme.smallRadius,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ShopScreen(shop: shop)),
      ),
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: SizedBox(
              width: 84,
              height: 84,
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
                    fontFamily: 'InterTight',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -.15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  shop.tagline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'InterTight',
                    fontSize: 12.5,
                    height: 15 / 12.5,
                    letterSpacing: .15,
                    color: LamazonTheme.muted,
                  ),
                ),
                const SizedBox(height: 6),
                const Row(
                  children: [
                    Icon(
                      LucideIcons.mapPin,
                      size: 13,
                      color: LamazonTheme.strong,
                    ),
                    SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Local delivery',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'InterTight',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: LamazonTheme.strong,
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

class _NothingHere extends StatelessWidget {
  final String tab;
  const _NothingHere({required this.tab});

  @override
  Widget build(BuildContext context) {
    final scoped = tab.isNotEmpty && tab != 'All';
    return ElevatedSurface(
      radius: LamazonTheme.featuredRadius,
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          const Icon(LucideIcons.store, size: 38, color: LamazonTheme.strong),
          const SizedBox(height: 14),
          Text(
            scoped ? 'Nothing in $tab yet' : 'No shops open yet',
            textAlign: TextAlign.center,
            style: LamazonTheme.titleText,
          ),
          const SizedBox(height: 7),
          Text(
            scoped
                ? 'Try another department, or open a store here yourself.'
                : 'The first local store to open will appear here.',
            textAlign: TextAlign.center,
            style: LamazonTheme.mutedBodyText,
          ),
          const SizedBox(height: 20),
          ActionButton(
            label: 'Open your store',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SellerDashboardScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeClose extends StatelessWidget {
  const _HomeClose();
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: LamazonTheme.forest,
      borderRadius: BorderRadius.circular(LamazonTheme.featuredRadius),
      boxShadow: LamazonTheme.raisedShadows,
    ),
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Local stores.\nGood things, close by.',
              style: TextStyle(
                fontFamily: 'InterTight',
                fontSize: 22,
                height: 28 / 22,
                fontWeight: FontWeight.w600,
                letterSpacing: -.7,
                color: Colors.white,
              ),
            ),
          ),
          TactileIconButton(
            icon: Icons.arrow_upward,
            label: 'Back to top',
            background: LamazonTheme.lime,
            foreground: LamazonTheme.strong,
            onPressed: () {
              final state = context.findAncestorStateOfType<_HomeScreenState>();
              if (state == null) return;
              if (MediaQuery.disableAnimationsOf(context)) {
                state._scroll.jumpTo(0);
              } else {
                state._scroll.animateTo(
                  0,
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                );
              }
            },
          ),
        ],
      ),
    ),
  );
}

class _BrowseDrawer extends StatelessWidget {
  final List<Product> products;
  final int activeTab;
  final ValueChanged<int> onSelectDepartment;
  const _BrowseDrawer({
    required this.products,
    required this.activeTab,
    required this.onSelectDepartment,
  });

  @override
  Widget build(BuildContext context) {
    final stocked = <String>{
      for (final product in products)
        if (product.category.isNotEmpty) product.category,
    };
    return Drawer(
      backgroundColor: LamazonTheme.canvas,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Browse', style: LamazonTheme.titleText),
                ),
                TactileIconButton(
                  icon: LucideIcons.x,
                  label: 'Close browse menu',
                  size: 40,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 18),
            for (final (index, department) in departments.indexed) ...[
              _DrawerDepartment(
                department: department,
                selected: index == activeTab,
                onTap: () {
                  onSelectDepartment(index);
                  Navigator.pop(context);
                },
              ),
              if (index != 0)
                for (final category in department.categories)
                  if (stocked.isEmpty || stocked.contains(category.name))
                    _DrawerCategory(
                      category: category,
                      department: department.name,
                    ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _DrawerDepartment extends StatelessWidget {
  final Department department;
  final bool selected;
  final VoidCallback onTap;
  const _DrawerDepartment({
    required this.department,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => ElevatedSurface(
    radius: LamazonTheme.smallRadius,
    color: selected ? LamazonTheme.lime : LamazonTheme.surface,
    onTap: onTap,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    child: Row(
      children: [
        Icon(department.icon, size: 19, color: LamazonTheme.strong),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            department.name,
            style: const TextStyle(
              fontFamily: 'InterTight',
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Icon(
          LucideIcons.chevronRight,
          size: 17,
          color: LamazonTheme.strong,
        ),
      ],
    ),
  );
}

class _DrawerCategory extends StatelessWidget {
  final CategoryNode category;
  final String department;
  const _DrawerCategory({required this.category, required this.department});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () {
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              SearchScreen(initialQuery: category.name, tab: department),
        ),
      );
    },
    borderRadius: BorderRadius.circular(10),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(42, 9, 8, 9),
      child: Row(
        children: [
          const Icon(LucideIcons.dot, size: 16, color: LamazonTheme.muted),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              category.name,
              style: const TextStyle(
                fontFamily: 'InterTight',
                fontSize: 13.5,
                letterSpacing: .2,
                color: LamazonTheme.text,
              ),
            ),
          ),
          const Icon(
            LucideIcons.arrowUpRight,
            size: 14,
            color: LamazonTheme.muted,
          ),
        ],
      ),
    ),
  );
}
