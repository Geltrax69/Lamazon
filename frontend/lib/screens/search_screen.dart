import '../widgets/design_system.dart';
import '../widgets/app_nav.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../widgets/app_shell.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/api.dart';
import '../data/catalog.dart';
import '../data/categories.dart';
import '../models/product.dart';
import '../widgets/product_card.dart';
import 'details_screen.dart';

class SearchScreen extends StatefulWidget {
  /// Pre-filled query, used when arriving from a category tile.
  final String initialQuery;

  /// The department the shopper was in. Empty, or 'All', means everything —
  /// arriving from Electronics and being shown pizza is the shopper losing
  /// the filter they set two taps ago.
  final String tab;
  const SearchScreen({super.key, this.initialQuery = '', this.tab = ''});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late String _query = widget.initialQuery;
  late String _tab = widget.tab;
  late final _controller = TextEditingController(text: widget.initialQuery);

  /// What the server found. The screen used to filter whatever list happened
  /// to be in memory, which is one shop's view at best and the bundled
  /// samples at worst — so searching for something a real seller had listed
  /// could come back empty.
  List<Product> _hits = const [];
  bool _busy = false;
  Timer? _debounce;
  _Sort _sort = _Sort.relevance;

  /// What the grid actually shows. Relevance is the server's own order, so
  /// that branch returns the list untouched rather than re-ranking it here.
  List<Product> get _sorted {
    if (_sort == _Sort.relevance) return _hits;
    final out = [..._hits];
    switch (_sort) {
      case _Sort.priceLow:
        out.sort((a, b) => a.price.compareTo(b.price));
      case _Sort.priceHigh:
        out.sort((a, b) => b.price.compareTo(a.price));
      case _Sort.discount:
        out.sort((a, b) => b.discountPercent.compareTo(a.discountPercent));
      case _Sort.relevance:
        break;
    }
    return out;
  }

  bool get _scoped => _tab.isNotEmpty && _tab != 'All';

  @override
  void initState() {
    super.initState();
    if (_query.trim().isNotEmpty) _run(_query);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onTyped(String value) {
    setState(() => _query = value);
    // One request per pause, not per keystroke.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => _run(value));
  }

  Future<void> _run(String value) async {
    final q = value.trim();
    final scope = _tab;
    if (q.isEmpty) {
      setState(() {
        _hits = const [];
        _busy = false;
      });
      return;
    }
    setState(() => _busy = true);
    try {
      final found = await Api.instance.products(
        tab: _scoped ? _tab : null,
        query: q,
      );
      // The field may have moved on while this was in flight; a slow reply
      // for an old query must not overwrite a newer one.
      if (!mounted || _query.trim() != q || _tab != scope) return;
      setState(() {
        _hits = found;
        _busy = false;
      });
    } catch (e) {
      logApiFailure('search', e);
      if (!mounted || _query.trim() != q || _tab != scope) return;
      // Offline, the catalogue in memory is still better than nothing.
      final lower = q.toLowerCase();
      setState(() {
        _hits = shownCatalog
            .where(
              (p) =>
                  (!_scoped || p.tab == _tab) &&
                  (p.name.toLowerCase().contains(lower) ||
                      p.category.toLowerCase().contains(lower) ||
                      p.store.toLowerCase().contains(lower)),
            )
            .toList();
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim();
    final results = _sorted;
    return Scaffold(
      // The bar floats over the content rather than reserving a strip, which
      // is how it sits on home — bottomNavigationBar would push every screen
      // up by its height and leave a white band under it.
      extendBody: true,
      bottomNavigationBar: const SafeArea(
        child: AppBottomNav(current: AppTab.none),
      ),
      backgroundColor: LamazonTheme.canvas,
      body: ReadableBody(
        maxWidth: 1400,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(
                  children: [
                    TactileIconButton(
                      icon: LucideIcons.arrowLeft,
                      label: 'Back',
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 56,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: LamazonTheme.surface,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          children: [
                            const ExcludeSemantics(
                              child: Icon(
                                LucideIcons.search,
                                size: 18,
                                color: LamazonTheme.muted,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                autofocus: widget.initialQuery.isEmpty,
                                onChanged: _onTyped,
                                textInputAction: TextInputAction.search,
                                onSubmitted: _run,
                                decoration: InputDecoration(
                                  // labelText only. Setting hintText to the
                                  // same thing printed the label twice,
                                  // stacked, the moment the field focused.
                                  // The scope belongs in the label, because a
                                  // search that quietly ignores half the
                                  // catalogue reads as broken.
                                  labelText: _scoped
                                      ? 'Search in $_tab'
                                      : 'Search products, shops',
                                  filled: false,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: const UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: LamazonTheme.strong,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Clearing a query took selecting the text and
                            // deleting it; every search field on the web has
                            // had this control for twenty years.
                            if (q.isNotEmpty)
                              TactileIconButton(
                                icon: LucideIcons.x,
                                label: 'Clear search',
                                size: 36,
                                onPressed: () {
                                  _debounce?.cancel();
                                  _controller.clear();
                                  setState(() {
                                    _query = '';
                                    _hits = const [];
                                    _busy = false;
                                  });
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_scoped)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: InputChip(
                      label: Text('In $_tab'),
                      onDeleted: () {
                        _debounce?.cancel();
                        setState(() => _tab = '');
                        _run(_query);
                      },
                    ),
                  ),
                ),
              // How many, and in what order. Without a count there is no way
              // to tell "nothing matched" from "still loading", and no way to
              // trust that the six cards on screen are all there is.
              if (q.isNotEmpty && !_busy && results.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            results.length == 1
                                ? '1 result for "$q"'
                                : '${results.length} results for "$q"',
                            style: LamazonTheme.mutedBodyText,
                          ),
                        ),
                      ),
                      // Sized to the longest option, and the menu sized to
                      // match. Left to itself the button shrank to fit "Best
                      // match" and the menu grew rightwards past it to fit
                      // "Price: low to high", which put the popup flush
                      // against the right edge of the window with no gutter at
                      // all — the one element on the page that had none.
                      SizedBox(
                        width: _sortMenuWidth,
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<_Sort>(
                            value: _sort,
                            isDense: true,
                            isExpanded: true,
                            menuWidth: _sortMenuWidth,
                            alignment: AlignmentDirectional.centerEnd,
                            borderRadius: BorderRadius.circular(
                              LamazonTheme.smallRadius,
                            ),
                            style: LamazonTheme.mutedBodyText,
                            onChanged: (next) =>
                                setState(() => _sort = next ?? _sort),
                            items: [
                              for (final option in _Sort.values)
                                DropdownMenuItem(
                                  value: option,
                                  child: Text(
                                    option.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: q.isEmpty
                    ? _SearchHint(
                        tab: _tab,
                        onPick: (name) {
                          _controller.text = name;
                          _onTyped(name);
                        },
                      )
                    : _busy && results.isEmpty
                    ? const CatalogSkeleton()
                    : results.isEmpty
                    ? _NoResults(
                        onReset: () {
                          _controller.clear();
                          setState(() {
                            _query = '';
                            _tab = '';
                            _hits = [];
                          });
                        },
                      )
                    : GridView.builder(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          8,
                          20,
                          bottomNavInset(context) + 16,
                        ),
                        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: productTileMax,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: productTileAspect,
                        ),
                        itemCount: results.length,
                        itemBuilder: (_, i) => ProductCard(
                          product: results[i],
                          showStore: mixesStores(results),
                          showAddToCart:
                              results[i].tab == 'Food' ||
                              results[i].tab == 'Grocery',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  DetailsScreen(product: results[i]),
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The empty state. It used to be a grey magnifier, then a wall of words —
/// neither of which is a reason to stay on the page. It is the shop now:
/// departments you can see, categories with a photo of what is in them, and
/// real products to tap straight into.
class _SearchHint extends StatelessWidget {
  final String tab;
  final ValueChanged<String> onPick;
  const _SearchHint({required this.tab, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final scoped = tab.isNotEmpty && tab != 'All';
    final pool = scoped
        ? shownCatalog.where((p) => p.tab == tab).toList()
        : shownCatalog;

    // One product per category, to put a face on the name. Categories with
    // nothing in them are left out — a tile with no photo is the pale thing
    // this screen was.
    final faces = <String, Product>{};
    for (final p in pool) {
      if (p.category.isEmpty || p.imageUrl.isEmpty) continue;
      faces.putIfAbsent(p.category, () => p);
    }
    final withPhotos = faces.entries.take(12).toList();

    // Discounts first, then whatever else is in stock: the point is that
    // something on this page is worth tapping.
    final picks = [
      ...pool.where((p) => p.discounted),
      ...pool.where((p) => !p.discounted),
    ].take(6).toList();

    return ListView(
      padding: EdgeInsets.fromLTRB(20, 4, 20, bottomNavInset(context) + 24),
      children: [
        if (!scoped) ...[
          const _HintHeading('Shop by department'),
          // A tile sized to what it holds. crossAxisCount: 2 with an aspect
          // ratio of 2.6 gave each department 613x236px to carry one 24px
          // icon and one word, so two fit per viewport and reaching the ninth
          // took four screens of scrolling. maxCrossAxisExtent lets the row
          // fill the width it has — five across on a desktop, two on a phone
          // — and mainAxisExtent fixes the height at what the content needs.
          GridView.extent(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            maxCrossAxisExtent: 240,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 3.6,
            children: [
              for (final d in departments)
                if (d.name != 'All')
                  _DepartmentTile(department: d, onTap: () => onPick(d.name)),
            ],
          ),
          const SizedBox(height: 24),
        ],
        if (withPhotos.isNotEmpty) ...[
          _HintHeading(scoped ? 'Browse $tab' : 'Shop by category'),
          SizedBox(
            height: 118,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: withPhotos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (_, i) {
                final entry = withPhotos[i];
                return Semantics(
                  button: true,
                  label: 'Browse ${entry.key}',
                  child: InkWell(
                    onTap: () => onPick(entry.key),
                    borderRadius: BorderRadius.circular(14),
                    child: ExcludeSemantics(
                      child: SizedBox(
                        width: 78,
                        child: Column(
                          children: [
                            Container(
                              width: 74,
                              height: 74,
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: ClipOval(
                                child: NetImage(
                                  url: catalogueImage(
                                    entry.value.imageUrl,
                                    160,
                                  ),
                                  fit: BoxFit.cover,
                                  padTo: null,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              entry.key,
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                height: 1.25,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
        ],
        if (picks.isNotEmpty) ...[
          _HintHeading(
            picks.first.discounted ? 'On offer right now' : 'Popular right now',
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: productTileMax,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: productTileAspect,
            ),
            itemCount: picks.length,
            itemBuilder: (_, i) => ProductCard(
              product: picks[i],
              showStore: mixesStores(picks),
              showAddToCart:
                  picks[i].tab == 'Food' || picks[i].tab == 'Grocery',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DetailsScreen(product: picks[i]),
                ),
              ),
            ),
          ),
        ],
        // Only when there is nothing at all to show — an empty catalogue is
        // the one case where words are all there is.
        if (withPhotos.isEmpty && picks.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Column(
              children: [
                Icon(LucideIcons.search, size: 40, color: LamazonTheme.muted),
                SizedBox(height: 12),
                Text(
                  'Search across all shops and products',
                  style: LamazonTheme.mutedBodyText,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A department, on the same ivory as everything else.
///
/// These were pastel blue, peach, lilac and pink blocks — precisely the
/// "rainbow-department dashboard" DESIGN.md opens by refusing, and the reason
/// this screen read as a different product from home. The department's own
/// colour survives as the icon, where it identifies without shouting; the
/// surface stays in the system.
class _DepartmentTile extends StatelessWidget {
  final Department department;
  final VoidCallback onTap;
  const _DepartmentTile({required this.department, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = department.colour ?? LamazonTheme.strong;
    return Semantics(
      button: true,
      label: department.name,
      child: Material(
        color: LamazonTheme.surface,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: LamazonTheme.track),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(department.icon, size: 17, color: accent),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ExcludeSemantics(
                    child: Text(
                      department.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                        color: LamazonTheme.text,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HintHeading extends StatelessWidget {
  final String text;
  const _HintHeading(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: SectionTitle(
      text,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
    ),
  );
}

class _NoResults extends StatelessWidget {
  final VoidCallback onReset;
  const _NoResults({required this.onReset});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: LucideIcons.packageSearch,
      title: 'No products found',
      message: 'Try a different name or browse all departments.',
      action: 'Browse all products',
      onAction: onReset,
    );
  }
}

/// Wide enough for "Price: low to high" plus the chevron, so neither the
/// button nor its menu has to grow into the window's margin.
const _sortMenuWidth = 170.0;

/// How the results are ordered. Relevance is whatever the server ranked;
/// the rest are client-side because the result set is already in hand.
enum _Sort {
  relevance('Best match'),
  priceLow('Price: low to high'),
  priceHigh('Price: high to low'),
  discount('Biggest discount');

  final String label;
  const _Sort(this.label);
}
