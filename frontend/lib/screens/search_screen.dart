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
  late final _controller = TextEditingController(text: widget.initialQuery);

  /// What the server found. The screen used to filter whatever list happened
  /// to be in memory, which is one shop's view at best and the bundled
  /// samples at worst — so searching for something a real seller had listed
  /// could come back empty.
  List<Product> _hits = const [];
  bool _busy = false;
  Timer? _debounce;

  bool get _scoped => widget.tab.isNotEmpty && widget.tab != 'All';

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
        tab: _scoped ? widget.tab : null,
        query: q,
      );
      // The field may have moved on while this was in flight; a slow reply
      // for an old query must not overwrite a newer one.
      if (!mounted || _query.trim() != q) return;
      setState(() {
        _hits = found;
        _busy = false;
      });
    } catch (e) {
      logApiFailure('search', e);
      if (!mounted) return;
      // Offline, the catalogue in memory is still better than nothing.
      final lower = q.toLowerCase();
      setState(() {
        _hits = shownCatalog
            .where(
              (p) =>
                  (!_scoped || p.tab == widget.tab) &&
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
    final results = _hits;
    return Scaffold(
      backgroundColor: const Color(0xFFF1F1EF),
      body: ReadableBody(
        maxWidth: 980,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          LucideIcons.arrowLeft,
                          size: 18,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              LucideIcons.search,
                              size: 18,
                              color: Colors.grey,
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
                                  // The scope is in the hint rather than
                                  // silent: a search that quietly ignores
                                  // half the catalogue reads as broken.
                                  hintText: _scoped
                                      ? 'Search in ${widget.tab}...'
                                      : 'Search products, shops...',
                                  hintStyle: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 14,
                                  ),
                                  border: InputBorder.none,
                                ),
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
                        tab: widget.tab,
                        onPick: (name) {
                          _controller.text = name;
                          _onTyped(name);
                        },
                      )
                    : _busy && results.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : results.isEmpty
                    ? const _NoResults()
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: productTileMax,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 0.68,
                        ),
                        itemCount: results.length,
                        itemBuilder: (_, i) => ProductCard(
                          product: results[i],
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
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      children: [
        if (!scoped) ...[
          const _HintHeading('Shop by department'),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.6,
            children: [
              for (final d in departments)
                if (d.name != 'All')
                  _DepartmentTile(
                    department: d,
                    onTap: () => onPick(d.name),
                  ),
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
                return GestureDetector(
                  onTap: () => onPick(entry.key),
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
                              url: thumb(entry.value.imageUrl, 160),
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
              childAspectRatio: 0.68,
            ),
            itemCount: picks.length,
            itemBuilder: (_, i) => ProductCard(
              product: picks[i],
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
                Icon(LucideIcons.search, size: 40, color: Colors.grey),
                SizedBox(height: 12),
                Text(
                  'Search across all shops and products',
                  style: TextStyle(fontSize: 14, color: Color(0xFF6B6B6B)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A department as something you can see rather than read: its own colour
/// behind its own icon.
class _DepartmentTile extends StatelessWidget {
  final Department department;
  final VoidCallback onTap;
  const _DepartmentTile({required this.department, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = department.colour ?? const Color(0xFF1A1A1A);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(department.icon, size: 17, color: accent),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                department.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
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
    child: Text(
      text,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
    ),
  );
}

class _NoResults extends StatelessWidget {
  const _NoResults();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.packageSearch, size: 44, color: Colors.grey),
          SizedBox(height: 12),
          Text(
            'No products found',
            style: TextStyle(fontSize: 14, color: Color(0xFF6B6B6B)),
          ),
        ],
      ),
    );
  }
}
