import 'package:flutter/material.dart';
import '../data/campaigns.dart';
import '../data/categories.dart';
import '../models/product.dart';
import '../screens/details_screen.dart';
import '../screens/search_screen.dart';
import 'category_visual.dart';
import 'design_system.dart';
import 'product_card.dart';

/// A reusable campaign surface, shared by the live storefront and admin preview.
class CampaignBanner extends StatelessWidget {
  final Campaign campaign;
  final VoidCallback? onTap;
  const CampaignBanner({super.key, required this.campaign, this.onTap});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final wide = c.maxWidth > 650;
      final fg = campaign.background.computeLuminance() > .4
          ? const Color(0xFF253B29)
          : Colors.white;
      return Material(
        color: campaign.background,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: wide ? 300 : 248,
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  bottom: 0,
                  right: 0,
                  width: c.maxWidth * .49,
                  child: ExcludeSemantics(
                    child: campaign.imageUrl.isNotEmpty
                        ? NetImage(url: campaign.imageUrl, fit: BoxFit.cover)
                        : campaign.category.isNotEmpty
                        ? CategoryVisual(name: campaign.category)
                        : Image.asset(
                            'assets/categories/everyday-campaign.png',
                            fit: BoxFit.cover,
                            alignment: Alignment.centerRight,
                          ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(wide ? 32 : 20),
                  child: SizedBox(
                    width: c.maxWidth * .50,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          campaign.category.isEmpty
                              ? 'The neighbourhood edit'
                              : campaign.category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: fg,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          campaign.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: wide ? 40 : 28,
                            height: 1.03,
                            letterSpacing: -.8,
                            fontWeight: FontWeight.w800,
                            color: fg,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          campaign.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.35,
                            color: fg,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Container(
                          constraints: const BoxConstraints(minHeight: 44),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: fg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  campaign.cta,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: fg == Colors.white
                                        ? Colors.black
                                        : Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.arrow_forward,
                                size: 17,
                                color: fg == Colors.white
                                    ? Colors.black
                                    : Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Manual paging keeps a campaign still while it is being read. The quick
/// transition respects reduced motion and retains a visible selected position.
class CampaignDeck extends StatefulWidget {
  final List<Campaign> campaigns;
  const CampaignDeck({super.key, required this.campaigns});
  @override
  State<CampaignDeck> createState() => _CampaignDeckState();
}

class _CampaignDeckState extends State<CampaignDeck> {
  int _index = 0;
  @override
  Widget build(BuildContext context) {
    if (widget.campaigns.isEmpty) return const SizedBox.shrink();
    _index = _index.clamp(0, widget.campaigns.length - 1);
    final c = widget.campaigns[_index];
    return Column(
      children: [
        AnimatedSwitcher(
          duration: Duration(
            milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 220,
          ),
          child: CampaignBanner(
            key: ValueKey(c.id),
            campaign: c,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SearchScreen(
                  initialQuery: c.category,
                  tab: c.category.isEmpty ? '' : departmentOf(c.category),
                ),
              ),
            ),
          ),
        ),
        if (widget.campaigns.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Previous banner',
                onPressed: () => setState(
                  () => _index =
                      (_index - 1 + widget.campaigns.length) %
                      widget.campaigns.length,
                ),
                icon: const Icon(Icons.chevron_left),
              ),
              Text(
                '${_index + 1} / ${widget.campaigns.length}',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              IconButton(
                tooltip: 'Next banner',
                onPressed: () => setState(
                  () => _index = (_index + 1) % widget.campaigns.length,
                ),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
      ],
    );
  }
}

class CollectionShelf extends StatefulWidget {
  final String title, subtitle;
  final List<Product> products;
  final Color colour;
  final VoidCallback? onSeeAll;
  const CollectionShelf({
    super.key,
    required this.title,
    required this.products,
    this.subtitle = '',
    this.colour = const Color(0xFFF5EBD5),
    this.onSeeAll,
  });
  @override
  State<CollectionShelf> createState() => _CollectionShelfState();
}

class _CollectionShelfState extends State<CollectionShelf> {
  final _scroll = ScrollController();
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _move(double direction) {
    if (!_scroll.hasClients) return;
    final target =
        (_scroll.offset + direction * _scroll.position.viewportDimension * .8)
            .clamp(0.0, _scroll.position.maxScrollExtent);
    if (MediaQuery.disableAnimationsOf(context)) {
      _scroll.jumpTo(target);
    } else {
      _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.products.isEmpty) return const SizedBox.shrink();
    final scaled = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.5);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: widget.colour,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 21,
                          height: 1.1,
                          letterSpacing: -.4,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (widget.subtitle.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            widget.subtitle,
                            style: const TextStyle(
                              fontSize: 12,
                              color: LamazonTheme.muted,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (MediaQuery.sizeOf(context).width >= 700) ...[
                  IconButton(
                    tooltip: 'Previous products',
                    onPressed: () => _move(-1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  IconButton(
                    tooltip: 'Next products',
                    onPressed: () => _move(1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
                if (widget.onSeeAll != null)
                  IconButton(
                    tooltip: 'Browse ${widget.title}',
                    onPressed: widget.onSeeAll,
                    icon: const Icon(Icons.arrow_forward),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 292 * scaled,
            child: ListView.separated(
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: widget.products.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) => SizedBox(
                width: 166 * scaled,
                child: ProductCard(
                  product: widget.products[i],
                  showAddToCart:
                      widget.products[i].options.isEmpty &&
                      widget.products[i].sizes.isEmpty,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          DetailsScreen(product: widget.products[i]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
