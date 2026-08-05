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

/// The empty state, which used to be one grey magnifier on a blank page. It
/// is the whole menu now: the shopper is here to find something, and the
/// fastest way to help is to show what there is.
class _SearchHint extends StatelessWidget {
  final String tab;
  final ValueChanged<String> onPick;
  const _SearchHint({required this.tab, required this.onPick});

  @override
  Widget build(BuildContext context) {
    // Inside a department, its own sections. Across the shop, the
    // departments themselves — a hundred category chips is not a shortcut.
    final scoped = tab.isNotEmpty && tab != 'All';
    final sections = scoped ? sectionsOf(tab) : const <CategoryNode>[];
    final departmentNames = [
      for (final d in departments)
        if (d.name != 'All') d.name,
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        if (scoped && sections.isNotEmpty) ...[
          _HintHeading('Browse $tab'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in sections)
                _HintChip(label: s.name, onTap: () => onPick(s.name)),
            ],
          ),
          const SizedBox(height: 22),
          // The things inside those sections, which is what people actually
          // type: nobody searches "Street Food", they search "samosa".
          _HintHeading('Popular in $tab'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final name in sections
                  .expand((s) => s.children)
                  .map((c) => c.name)
                  .take(18))
                _HintChip(label: name, onTap: () => onPick(name), small: true),
            ],
          ),
        ] else ...[
          _HintHeading('Departments'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final d in departments)
                if (d.name != 'All')
                  _HintChip(
                    label: d.name,
                    icon: d.icon,
                    colour: d.colour,
                    onTap: () => onPick(d.name),
                  ),
            ],
          ),
          const SizedBox(height: 22),
          if (departmentNames.isNotEmpty) ...[
            _HintHeading('Try one of these'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final name in departments
                    .expand((d) => d.categories)
                    .expand((c) => c.children.isEmpty ? [c] : c.children)
                    .map((c) => c.name)
                    .take(20))
                  _HintChip(label: name, onTap: () => onPick(name), small: true),
              ],
            ),
          ],
        ],
      ],
    );
  }
}

class _HintHeading extends StatelessWidget {
  final String text;
  const _HintHeading(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
    ),
  );
}

class _HintChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? colour;
  final bool small;
  final VoidCallback onTap;
  const _HintChip({
    required this.label,
    required this.onTap,
    this.icon,
    this.colour,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = colour ?? const Color(0xFF1A1A1A);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: small ? 12 : 14,
          vertical: small ? 8 : 10,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: accent),
              const SizedBox(width: 7),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: small ? 12.5 : 13.5,
                fontWeight: small ? FontWeight.w500 : FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
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
