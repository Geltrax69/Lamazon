import '../widgets/design_system.dart';
import '../data/money.dart';
import '../data/wishlist.dart';
import 'package:flutter/material.dart';

import '../widgets/app_shell.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/cart.dart';
import '../models/product.dart';
import '../widgets/product_card.dart';
import '../widgets/status_views.dart';
import 'cart_screen.dart';
import 'compare_screen.dart';

class DetailsScreen extends StatefulWidget {
  final Product product;
  const DetailsScreen({super.key, required this.product});

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  int _qty = 1;

  /// What the shopper has picked per option group, keyed by its name. Empty
  /// until they choose — nothing is preselected, because a default here is a
  /// choice the shop did not make on their behalf.
  final Map<String, String> _picked = {};

  /// The cart takes only what the shop actually has, so say when it took
  /// less than was asked for rather than letting the shortfall surface at
  /// checkout.
  bool _added(int wanted) {
    final got = Cart.instance.add(widget.product, wanted);
    if (got == wanted) return true;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            got == 0
                ? 'Your cart already holds every one the shop has.'
                : 'Only $got left — we added that many.',
          ),
        ),
      );
    return got > 0;
  }

  void _addToCart() {
    if (!_added(_qty)) return;
    showAddedToast(context, widget.product, messenger: _messenger.currentState);
  }

  void _buyNow() {
    if (!_added(_qty)) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CartScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final info = Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            p.store,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: LamazonTheme.green,
            ),
          ),
          const SizedBox(height: 8),
          // The product name is this page's h1. It is also the one place the
          // full stored title is shown — cards shorten it to stay scannable,
          // this does not, because here it is what you came to read.
          SectionTitle(
            p.name,
            level: 1,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '₹${(p.price * _qty).moneyText}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (p.discounted)
                Text(
                  'MRP ₹${(p.mrp * _qty).moneyText}',
                  style: const TextStyle(
                    fontSize: 16,
                    color: LamazonTheme.muted,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              if (p.discounted) DiscountBadge(percent: p.discountPercent),
            ],
          ),
          if (p.discounted)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'You save ₹${((p.mrp - p.price) * _qty).moneyText}',
                style: const TextStyle(
                  color: LamazonTheme.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            _qty == 1
                ? 'From: ₹${p.price.moneyText}'
                : '$_qty × ₹${p.price.moneyText}',
            style: const TextStyle(color: LamazonTheme.muted),
          ),
          const SizedBox(height: 12),
          Text(
            p.availableStock == null
                ? 'Availability confirmed at checkout'
                : p.availableStock == 0
                ? 'Currently out of stock'
                : '${p.availableStock} available',
            style: const TextStyle(
              color: LamazonTheme.green,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Row(
            children: [
              Icon(LucideIcons.star, size: 16, color: LamazonTheme.muted),
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  'No ratings yet',
                  style: TextStyle(color: LamazonTheme.muted, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          ElevatedSurface(
            radius: LamazonTheme.smallRadius,
            padding: EdgeInsets.zero,
            child: const Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  leading: Icon(LucideIcons.truck, color: LamazonTheme.strong),
                  title: Text('Local delivery'),
                  subtitle: Text(
                    '₹15 delivery per order. Timing confirmed by the store.',
                  ),
                ),
                TrackDivider(indent: 16, endIndent: 16),
                ListTile(
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  leading: Icon(
                    LucideIcons.banknote,
                    color: LamazonTheme.strong,
                  ),
                  title: Text('Cash on delivery'),
                  subtitle: Text('Pay the rider when your order arrives.'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Quantity',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              _QtyStepper(
                qty: _qty,
                // Never offers more than the shop can supply.
                max: p.availableStock,
                onChanged: (q) => setState(() => _qty = q),
              ),
            ],
          ),
          for (final option in p.choices)
            _OptionPicker(
              option: option,
              selected: _picked[option.name],
              onPick: (v) => setState(() => _picked[option.name] = v),
            ),
          const SizedBox(height: 28),
          const SectionTitle('About this product'),
          const SizedBox(height: 8),
          Text(
            p.description.isEmpty
                ? 'Product details have not been provided by the store.'
                : p.description,
            style: const TextStyle(
              fontSize: 15,
              height: 1.6,
              color: LamazonTheme.muted,
            ),
          ),
          ..._compareSection(context, p),
        ],
      ),
    );
    return ScaffoldMessenger(
      key: _messenger,
      child: Scaffold(
        backgroundColor: LamazonTheme.canvas,
        body: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, c) {
              if (c.maxWidth >= 900) {
                return SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 6, child: _Hero(product: p)),
                        const SizedBox(width: 24),
                        Expanded(flex: 5, child: info),
                      ],
                    ),
                  ),
                );
              }
              return ListView(
                children: [
                  _Hero(product: p),
                  info,
                ],
              );
            },
          ),
        ),
        bottomNavigationBar: DecoratedBox(
          decoration: const BoxDecoration(
            color: LamazonTheme.surface,
            boxShadow: LamazonTheme.raisedShadows,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const TrackDivider(),
              SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: ReadableBody(
                  maxWidth: 1100,
                  child: Row(
                    children: [
                      if (MediaQuery.sizeOf(context).width >= 900)
                        Expanded(
                          child: Text(
                            '₹${(p.price * _qty).moneyText}',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                      Expanded(
                        child: ActionButton(
                          label: 'Add to Cart',
                          primary: false,
                          onPressed: p.availableStock == 0 ? null : _addToCart,
                          expand: true,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ActionButton(
                          label: 'Buy Now',
                          onPressed: p.availableStock == 0 ? null : _buyNow,
                          expand: true,
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
  }
}

/// "Same product at other shops": this exact item's price elsewhere, with
/// the difference against the current shop's price.
List<Widget> _compareSection(BuildContext context, Product p) {
  if (p.offers.isEmpty) return const [];
  return [
    const SizedBox(height: 22),
    Row(
      children: [
        const Expanded(child: SectionTitle('Local vendors')),
        const SizedBox(width: 10),
        ActionButton(
          label: 'Compare all',
          primary: false,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CompareScreen(product: p)),
          ),
        ),
      ],
    ),
    const SizedBox(height: 2),
    Text(
      'Compared with ₹${p.price.moneyText} at ${p.store}',
      style: const TextStyle(fontSize: 12, color: LamazonTheme.muted),
    ),
    const SizedBox(height: 10),
    for (final o in p.offers)
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: ElevatedSurface(
          radius: LamazonTheme.smallRadius,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: LamazonTheme.track,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.store,
                  size: 18,
                  color: LamazonTheme.strong,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      o.store,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Text(
                      'Same product',
                      style: TextStyle(fontSize: 11, color: LamazonTheme.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${o.price.moneyText}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  _diffBadge(o.price - p.price),
                ],
              ),
            ],
          ),
        ),
      ),
  ];
}

Widget _diffBadge(double diff) {
  final String label;
  final Color color;
  if (diff > 0) {
    label = '₹${diff.moneyText} more';
    color = LamazonTheme.danger;
  } else if (diff < 0) {
    label = '₹${(-diff).moneyText} less';
    color = LamazonTheme.strong;
  } else {
    label = 'Same price';
    color = LamazonTheme.muted;
  }
  return Text(
    label,
    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
  );
}

/// Swipeable gallery: every photo gets the full width and you page through
/// them, instead of one big picture with a strip of thumbnails beside it.
class _Hero extends StatefulWidget {
  final Product product;
  const _Hero({required this.product});

  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> {
  final _pages = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photos = [widget.product.imageUrl, ...widget.product.extraImages];

    return SizedBox(
      height: MediaQuery.sizeOf(context).width >= 900
          ? 540
          : (MediaQuery.sizeOf(context).height * .45).clamp(240.0, 420.0),
      child: Stack(
        children: [
          // The photos sit on the page background — no coloured card behind.
          Positioned.fill(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(28),
              ),
              child: PageView.builder(
                controller: _pages,
                itemCount: photos.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => NetImage(
                  url: photos[i],
                  sourceWidth: 1024,
                  semanticLabel:
                      '${widget.product.name}, image ${i + 1} of ${photos.length}',
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _RoundIcon(
                    icon: LucideIcons.arrowLeft,
                    onTap: () => Navigator.pop(context),
                  ),
                  Row(
                    children: [
                      ListenableBuilder(
                        listenable: Wishlist.instance,
                        builder: (context, _) => _RoundIcon(
                          icon: Wishlist.instance.contains(widget.product.id)
                              ? LucideIcons.heartHandshake
                              : LucideIcons.heart,
                          onTap: () =>
                              Wishlist.instance.toggle(widget.product.id),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _RoundIcon(
                        icon: LucideIcons.shoppingCart,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CartScreen()),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (photos.length > 1)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ActionIcon(
                    icon: LucideIcons.chevronLeft,
                    label: 'Previous image',
                    onPressed: _page == 0
                        ? null
                        : () => _pages.previousPage(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOut,
                          ),
                  ),
                  ElevatedSurface(
                    radius: 14,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    child: Text(
                      '${_page + 1} / ${photos.length}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  ActionIcon(
                    icon: LucideIcons.chevronRight,
                    label: 'Next image',
                    onPressed: _page == photos.length - 1
                        ? null
                        : () => _pages.nextPage(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOut,
                          ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _RoundIcon({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionIcon(
      icon: icon,
      label: icon == LucideIcons.arrowLeft
          ? 'Back'
          : icon == LucideIcons.shoppingCart
          ? 'Open cart'
          : 'Save product',
      onPressed: onTap,
    );
  }
}

class _QtyStepper extends StatelessWidget {
  final int qty;
  final ValueChanged<int> onChanged;

  /// What the shop has. Null for the seed catalogue, which tracks no stock.
  final int? max;
  const _QtyStepper({required this.qty, required this.onChanged, this.max});

  bool get _atCap => max != null && qty >= max!;

  @override
  Widget build(BuildContext context) {
    return ElevatedSurface(
      radius: 24,
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _step(LucideIcons.minus, () {
            if (qty > 1) onChanged(qty - 1);
          }, filled: false),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              // A count, not a zero-padded code.
              '$qty',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
          _step(
            LucideIcons.plus,
            () => onChanged(qty + 1),
            filled: true,
            label: _atCap ? 'That is all the shop has' : 'Increase quantity',
          ),
        ],
      ),
    );
  }

  Widget _step(
    IconData icon,
    VoidCallback onTap, {
    required bool filled,
    String? label,
  }) {
    final off = filled ? _atCap : qty <= 1;
    return TactileIconButton(
      icon: icon,
      label: label ?? (filled ? 'Increase quantity' : 'Decrease quantity'),
      onPressed: off ? null : onTap,
      background: filled ? LamazonTheme.lime : LamazonTheme.surface,
      foreground: LamazonTheme.strong,
      // The WCAG 2.5.8 minimum, not 38.
      size: LamazonTheme.touch,
    );
  }
}

/// One option group as the shopper sees it. Colour values draw as swatches,
/// everything else as labels — the shop said which when it created the group.
class _OptionPicker extends StatelessWidget {
  final ItemOption option;
  final String? selected;
  final ValueChanged<String> onPick;
  const _OptionPicker({
    required this.option,
    required this.selected,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    if (option.values.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                option.name,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (selected != null) ...[
                const SizedBox(width: 8),
                Text(
                  option.isColour ? '' : selected!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: LamazonTheme.muted,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final value in option.values)
                ChoiceChip(
                  label: Text(value),
                  avatar: option.isColour
                      ? CircleAvatar(
                          backgroundColor: _swatchColour(value),
                          radius: 9,
                        )
                      : null,
                  selected: selected == value,
                  onSelected: (_) => onPick(value),
                  selectedColor: LamazonTheme.accent,
                  showCheckmark: false,
                  side: BorderSide.none,
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

Color _swatchColour(String hex) => Color(
  0xFF000000 | (int.tryParse(hex.replaceFirst('#', ''), radix: 16) ?? 0),
);
