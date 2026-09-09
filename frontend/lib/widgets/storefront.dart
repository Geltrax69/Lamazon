import 'package:flutter/material.dart';

import '../data/campaigns.dart';
import '../data/categories.dart';
import '../models/product.dart';
import '../screens/details_screen.dart';
import '../screens/search_screen.dart';
import 'design_system.dart';
import 'product_card.dart';

/// Named campaign palettes keep admin-managed images in one visual world while
/// preserving the existing hexadecimal field for API compatibility.
class CampaignPalette {
  final String name;
  final String hex;
  final Color background;
  final Color foreground;
  final Color action;
  final Color actionForeground;
  const CampaignPalette._(
    this.name,
    this.hex,
    this.background,
    this.foreground,
    this.action,
    this.actionForeground,
  );

  static const forest = CampaignPalette._(
    'Forest / Lime',
    '#143E32',
    Color(0xFF143E32),
    Colors.white,
    LamazonTheme.lime,
    LamazonTheme.forest,
  );
  static const cacao = CampaignPalette._(
    'Cacao / Peach',
    '#4A3029',
    Color(0xFF4A3029),
    Colors.white,
    Color(0xFFF7A38E),
    Color(0xFF4A3029),
  );
  static const ink = CampaignPalette._(
    'Ink / Mist',
    '#263244',
    Color(0xFF263244),
    Colors.white,
    Color(0xFFC8DBEE),
    Color(0xFF263244),
  );
  static const presets = <CampaignPalette>[forest, cacao, ink];

  static CampaignPalette resolve(String hex) {
    final normalized = hex.trim().toUpperCase();
    for (final preset in presets) {
      if (preset.hex == normalized) return preset;
    }
    // Existing pastel campaigns are translated into the new, tighter three
    // theme family. Custom valid colours still work, but the template derives
    // readable text and action contrast rather than relying on the editor.
    if (const ['#F2E8CE', '#DCEACD', '#1D4A3C'].contains(normalized)) {
      return forest;
    }
    if (const ['#F7DCCB', '#E7DFF3'].contains(normalized)) return cacao;
    if (normalized == '#DCE9F5') return ink;
    final value = int.tryParse(normalized.replaceFirst('#', ''), radix: 16);
    if (value == null || normalized.length != 7) return forest;
    final background = Color(0xFF000000 | value);
    final dark = background.computeLuminance() < .42;
    return CampaignPalette._(
      'Custom',
      normalized,
      background,
      dark ? Colors.white : LamazonTheme.text,
      dark ? LamazonTheme.lime : LamazonTheme.forest,
      dark ? LamazonTheme.strong : Colors.white,
    );
  }
}

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
              'assets/categories/campaign-forest.png',
              fit: BoxFit.cover,
              alignment: Alignment.centerRight,
              excludeFromSemantics: true,
            )
          : NetImage(
              url: campaign.imageUrl,
              fit: BoxFit.cover,
              padTo: null,
              sourceWidth: 1600,
            );
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

  void _move(int direction) {
    setState(() {
      _index =
          (_index + direction + widget.campaigns.length) %
          widget.campaigns.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.campaigns.isEmpty) return const SizedBox.shrink();
    _index = _index.clamp(0, widget.campaigns.length - 1);
    final campaign = widget.campaigns[_index];
    final disabled = MediaQuery.disableAnimationsOf(context);
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
                  Text(widget.title, style: LamazonTheme.sectionText),
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
