import 'package:flutter/material.dart';

import '../widgets/app_shell.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/catalog.dart';
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

  bool get _scoped => widget.tab.isNotEmpty && widget.tab != 'All';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    // shownCatalog, not the bundled list: the two do not hold the same
    // products, and searching the bundle could not find a single thing a real
    // seller had listed.
    final inTab = _scoped
        ? shownCatalog.where((p) => p.tab == widget.tab).toList()
        : shownCatalog;
    final results = q.isEmpty
        ? const <Product>[]
        : inTab
              .where(
                (p) =>
                    p.name.toLowerCase().contains(q) ||
                    p.category.toLowerCase().contains(q) ||
                    p.store.toLowerCase().contains(q),
              )
              .toList();
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
                                onChanged: (v) => setState(() => _query = v),
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
                    ? const _SearchHint()
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

class _SearchHint extends StatelessWidget {
  const _SearchHint();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.search, size: 44, color: Colors.grey),
          SizedBox(height: 12),
          Text(
            'Search across all shops and products',
            style: TextStyle(fontSize: 14, color: Color(0xFF6B6B6B)),
          ),
        ],
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
