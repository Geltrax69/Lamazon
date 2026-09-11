import 'dart:async';
import 'package:flutter/material.dart';

import '../data/campaigns.dart';
import '../data/catalog.dart';
import '../data/categories.dart';
import '../models/product.dart';
import '../screens/details_screen.dart';
import '../screens/search_screen.dart';
import 'banner_media.dart';
import 'campaign_palette.dart';
import 'design_system.dart';
import 'product_card.dart';

/// The shopper banner and admin preview share one safe crop, one contrast
/// treatment and one text layout, regardless of the uploaded image.
class CampaignBanner extends StatelessWidget {
  final Campaign campaign;
  final VoidCallback? onTap;
  const CampaignBanner({super.key, required this.campaign, this.onTap});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 760;
      final palette = CampaignPalette.resolve(campaign.colour);
      final image = campaign.imageUrl.trim().isEmpty
          ? Image.asset(
              'assets/categories/campaign-forest.webp',
              fit: BoxFit.cover,
              alignment: Alignment.centerRight,
              excludeFromSemantics: true,
            )
          : BannerMedia(url: campaign.imageUrl);
      return Semantics(
        button: onTap != null,
        label: '${campaign.title}. ${campaign.cta}',
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(LamazonTheme.featuredRadius),
            boxShadow: LamazonTheme.raisedShadows,
          ),
          child: Material(
            color: palette.background,
            borderRadius: BorderRadius.circular(LamazonTheme.featuredRadius),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              focusColor: LamazonTheme.lime.withValues(alpha: .35),
              child: SizedBox(
                height: wide ? 348 : 230,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned(
                      left: constraints.maxWidth * (wide ? .33 : .24),
                      right: 0,
                      top: 0,
                      bottom: 0,
                      child: image,
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          stops: const [.0, .48, .8, 1],
                          colors: [
                            palette.background,
                            palette.background.withValues(alpha: .98),
                            palette.background.withValues(alpha: .42),
                            palette.background.withValues(alpha: .04),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        wide ? 30 : 20,
                        wide ? 28 : 18,
                        constraints.maxWidth * (wide ? .43 : .36),
                        wide ? 28 : 18,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _CategoryTag(
                            label: campaign.category.isEmpty
                                ? 'THE LOCAL EDIT'
                                : campaign.category.toUpperCase(),
                            color: palette.foreground,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            campaign.title,
                            maxLines: wide ? 3 : 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'InterTight',
                              color: palette.foreground,
                              fontSize: wide ? 31 : 22,
                              height: wide ? 36 / 31 : 28 / 22,
                              fontWeight: FontWeight.w600,
                              letterSpacing: wide ? -1 : -.7,
                            ),
                          ),
                          if (campaign.subtitle.trim().isNotEmpty) ...[
                            const SizedBox(height: 7),
                            Text(
                              campaign.subtitle,
                              maxLines: wide ? 3 : 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'InterTight',
                                color: palette.foreground.withValues(
                                  alpha: .86,
                                ),
                                fontSize: 13,
                                height: 17 / 13,
                                letterSpacing: .15,
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          _CampaignAction(
                            label: campaign.cta,
                            color: palette.action,
                            foreground: palette.actionForeground,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _CategoryTag extends StatelessWidget {
  final String label;
  final Color color;
  const _CategoryTag({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .14),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: 'InterTight',
        color: color,
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
        letterSpacing: .9,
      ),
    ),
  );
}

class _CampaignAction extends StatelessWidget {
  final String label;
  final Color color;
  final Color foreground;
  const _CampaignAction({
    required this.label,
    required this.color,
    required this.foreground,
  });
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(23),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.alphaBlend(Colors.white.withValues(alpha: .36), color),
          color,
        ],
      ),
      boxShadow: LamazonTheme.tactileShadows,
    ),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 42),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'InterTight',
                  color: foreground,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 7),
            Icon(Icons.arrow_forward, size: 16, color: foreground),
          ],
        ),
      ),
    ),
  );
}

/// Manual paging honours the shopper's reading pace; visible dots show the
/// state without the distraction of an auto-rotating banner.
class CampaignDeck extends StatefulWidget {
  final List<Campaign> campaigns;
  const CampaignDeck({super.key, required this.campaigns});
  @override
  State<CampaignDeck> createState() => _CampaignDeckState();
}

class _CampaignDeckState extends State<CampaignDeck> {
  int _index = 0;
  Timer? _rotate;

  /// Long enough to read the copy and decide, short enough that a second
  /// campaign is seen at all. Blinkit's festival deck sits at about this.
  ///
  /// A clip gets twice as long: six seconds of a fifteen-second film is a
  /// banner whose ending nobody ever sees.
  static Duration _dwell(Campaign c) =>
      Duration(seconds: bannerKind(c.imageUrl) == BannerKind.video ? 12 : 6);

  @override
  void initState() {
    super.initState();
    _restart();
  }

  @override
  void didUpdateWidget(CampaignDeck old) {
    super.didUpdateWidget(old);
    if (widget.campaigns.length != old.campaigns.length) _restart();
  }

  void _restart() {
    _rotate?.cancel();
    // One campaign is not a carousel, and a timer that redraws the same card
    // forever is a wakelock with no upside.
    if (widget.campaigns.length < 2) return;
    // One shot rather than periodic, because _move re-arms it — which is how
    // the next slide gets a dwell of its own rather than the first one's.
    final showing =
        widget.campaigns[_index.clamp(0, widget.campaigns.length - 1)];
    _rotate = Timer(_dwell(showing), () {
      if (mounted) _move(1);
    });
  }

  @override
  void dispose() {
    _rotate?.cancel();
    super.dispose();
  }

  void _move(int direction) {
    setState(() {
      _index =
          (_index + direction + widget.campaigns.length) %
          widget.campaigns.length;
    });
    // A person who just pressed an arrow does not want the deck moving on
    // under them a moment later.
    _restart();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.campaigns.isEmpty) return const SizedBox.shrink();
    _index = _index.clamp(0, widget.campaigns.length - 1);
    final campaign = widget.campaigns[_index];
    final disabled = MediaQuery.disableAnimationsOf(context);
    // WCAG 2.2.2: something that moves on its own for more than five seconds
    // needs a way to stop it. Reduced motion is that person saying so in
    // advance, so the deck simply does not advance — the arrows still work.
    if (disabled && _rotate != null) {
      _rotate!.cancel();
      _rotate = null;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedSwitcher(
          duration: Duration(milliseconds: disabled ? 0 : 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeOut,
          child: CampaignBanner(
            key: ValueKey(campaign.id),
            campaign: campaign,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SearchScreen(
                  initialQuery: campaign.category,
                  tab: campaign.category.isEmpty
                      ? ''
                      : departmentOf(campaign.category),
                ),
              ),
            ),
          ),
        ),
        if (widget.campaigns.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TactileIconButton(
                  icon: Icons.arrow_back,
                  label: 'Previous banner',
                  onPressed: () => _move(-1),
                  size: 38,
                ),
                const SizedBox(width: 12),
                for (var i = 0; i < widget.campaigns.length; i++)
                  AnimatedContainer(
                    duration: Duration(milliseconds: disabled ? 0 : 180),
                    width: i == _index ? 22 : 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: i == _index
                          ? LamazonTheme.strong
                          : LamazonTheme.track,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                const SizedBox(width: 12),
                TactileIconButton(
                  icon: Icons.arrow_forward,
                  label: 'Next banner',
                  onPressed: () => _move(1),
                  size: 38,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A product rail stays visually open so factual products carry the emphasis,
/// rather than creating a nested card inside a second decorative card.
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
    this.colour = LamazonTheme.lime,
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
        (_scroll.offset + direction * _scroll.position.viewportDimension * .84)
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
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final scaled = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.4);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionTitle(widget.title),
                  if (widget.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(widget.subtitle, style: LamazonTheme.mutedBodyText),
                  ],
                ],
              ),
            ),
            if (wide) ...[
              const SizedBox(width: 12),
              TactileIconButton(
                icon: Icons.arrow_back,
                label: 'Previous products',
                onPressed: () => _move(-1),
                size: 40,
              ),
              const SizedBox(width: 8),
              TactileIconButton(
                icon: Icons.arrow_forward,
                label: 'Next products',
                onPressed: () => _move(1),
                size: 40,
              ),
            ] else if (widget.onSeeAll != null) ...[
              const SizedBox(width: 12),
              TactileIconButton(
                icon: Icons.arrow_forward,
                label: 'Browse ${widget.title}',
                onPressed: widget.onSeeAll,
                size: 40,
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 292 * scaled,
          child: ListView.separated(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: const EdgeInsets.only(bottom: 10),
            itemCount: widget.products.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) => SizedBox(
              width: 166 * scaled,
              child: ProductCard(
                product: widget.products[index],
                showStore: mixesStores(widget.products),
                showAddToCart:
                    widget.products[index].options.isEmpty &&
                    widget.products[index].sizes.isEmpty,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        DetailsScreen(product: widget.products[index]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
