import 'design_system.dart';
import '../data/money.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/cart.dart';
import '../data/seller.dart';
import '../data/catalog.dart';
import '../data/wishlist.dart';
import '../models/product.dart';
import 'status_views.dart';

/// Whether naming the store on every card tells a shopper anything.
///
/// One shop's grid repeats the same word down the whole page; a mixed list
/// genuinely needs it to tell two burgers apart. Computed from the list
/// rather than set per screen, because which screens are single-store depends
/// on the catalogue, not on the code.
bool mixesStores(Iterable<Product> products) =>
    products.map((p) => p.store).toSet().length > 1;

/// One product, as a shopper scans it.
///
/// The order of this card is the whole design, and it used to be backwards.
/// It read: store name, product name in the largest type on the card, "In
/// stock", then the price last and smallest, next to a lime circle louder
/// than any of them. In a shop the price is the decision — it belongs first
/// and biggest, which is where every grocery app that works puts it.
///
/// Three things also came off it, because a line repeated on all 41 cards is
/// not information:
///
///  * the store, unless the list actually mixes shops ([showStore]);
///  * "In stock", which is the default state and so says nothing. Only the
///    exceptions are worth a line: running out, or out;
///  * the discount badge sitting over the photograph, which is now text
///    beside the price where it is read rather than decoration over food.
///
/// The card itself lost its shadow. Forty-one elevated surfaces on one page
/// is noise; the picture keeps a soft ground and the text sits on the page.
class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback? onTap;
  final bool showAddToCart; // quick-add only for food & grocery

  /// Whether the store's name earns its line. False inside a single shop or a
  /// department that only one shop stocks, where it is the same word 41 times.
  final bool showStore;
  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.showAddToCart = false,
    this.showStore = true,
  });

  /// The one line under the name, or nothing.
  ///
  /// Only exceptions get a line. "In stock" on every card is forty-one
  /// identical green sentences down a page, which is how a shopper learns to
  /// stop reading that row at all — so the scarcity warning that matters is
  /// the one they miss.
  (String, Color)? get _note {
    final left = product.availableStock;
    if (left == null) return null;
    if (left == 0) return ('Out of stock', LamazonTheme.danger);
    if (left <= scarceAt) return ('Only $left left', LamazonTheme.warning);
    return null;
  }

  /// Height reserved for everything under the picture.
  ///
  /// It used to be the picture that took the slack: the text block is a
  /// different height on every card — a discount line here, a store there, a
  /// scarcity warning on one in ten — so `Expanded` handed the difference to
  /// the image, and a single row measured image tops of 117/137/152px. Fixing
  /// the text block instead puts the variation in the empty space at the
  /// bottom of the card, where nobody can see it, and every picture, price and
  /// `+` in a row lines up.
  ///
  /// Sized for the worst case: price + saving + two lines of name + store +
  /// scarcity. Guarded by the overflow assertion in product_card_test.
  static const metaHeight = 114.0;

  @override
  Widget build(BuildContext context) {
    final note = _note;
    // The label is the whole card as one spoken sentence, but it may not
    // swallow the card: excludeSemantics here is what dropped the InkWell's
    // own focusable node (so no keyboard could reach a product) and deleted
    // the add-to-cart and save buttons from the accessibility tree outright.
    // Only the parts the sentence already describes are silenced.
    return Semantics(
      button: onTap != null,
      label: [
        // A legacy title can run to 194 characters, which is the entire
        // spoken name of the card before a price is reached. Cards are
        // scanned, not read: the tail belongs on the product page.
        product.name.spokenTitle,
        '₹${product.price.moneyText}',
        if (product.discounted) '${product.discountPercent} percent off',
        if (showStore) 'from ${product.store}',
        if (note != null) note.$1,
      ].join(', '),
      // Its own layer, inside the semantics rather than around it. Every
      // heart on screen listens to the wishlist, so toggling one rebuilds
      // all of them, and the CartButton runs a scale animation on tap —
      // without a boundary either one re-rasterises the whole grid it is
      // sitting in.
      child: RepaintBoundary(
        // No clipBehavior on the Material. An anti-aliased clip is a
        // saveLayer, charged on every frame for every card — forty-two of them
        // on a phone — and it was clipping content that cannot overflow: the
        // photograph rounds itself just below, and the text sits well inside
        // the box. The only thing it bought was a rounded ink splash, and
        // InkWell's own borderRadius does that for the length of a tap rather
        // than for the length of the session.
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(LamazonTheme.smallRadius),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(LamazonTheme.smallRadius),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ExcludeSemantics(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: ColoredBox(
                              // A ground of its own, so the picture reads as a
                              // tile rather than as text with an image floating
                              // above it. The picture is contained rather than
                              // cropped, so some ground always shows on one axis.
                              color: LamazonTheme.surface,
                              // catalogueImage already returns a centred square,
                              // so the box is filled rather than fitted — there
                              // is nothing left to letterbox.
                              child: NetImage(
                                url: catalogueImage(product.imageUrl),
                                padTo: null,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: WishlistHeart(productId: product.id),
                      ),
                      // Inside the picture, not under it. It is the thumb's
                      // target and it was costing the card a whole row of
                      // height beside the price, where it outweighed the number
                      // the shopper is actually reading.
                      if (showAddToCart)
                        Positioned(
                          right: 4,
                          bottom: 4,
                          child: CartButton(product: product),
                        ),
                    ],
                  ),
                ),
                SizedBox(
                  height: metaHeight,
                  child: ExcludeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        // Price first, and the largest thing on the card.
                        // scaleDown rather than ellipsis: a price is the one
                        // number on the card that may not be cut off, and
                        // grouped thousands made the pair wide enough to try.
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '₹${product.price.moneyText}',
                                style: const TextStyle(
                                  fontFamily: 'InterTight',
                                  fontSize: 17,
                                  height: 21 / 17,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -.2,
                                  color: LamazonTheme.text,
                                ),
                              ),
                              if (product.discounted) ...[
                                const SizedBox(width: 5),
                                Text(
                                  '₹${product.mrp.moneyText}',
                                  maxLines: 1,
                                  style: const TextStyle(
                                    fontFamily: 'InterTight',
                                    fontSize: 12.5,
                                    color: LamazonTheme.muted,
                                    decoration: TextDecoration.lineThrough,
                                    decorationColor: LamazonTheme.muted,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        // The saving as a readable line rather than a sticker
                        // over the food. Green, because it is good news, and it
                        // sits with the number it is about.
                        if (product.discounted)
                          Text(
                            '${product.discountPercent}% off',
                            maxLines: 1,
                            style: const TextStyle(
                              fontFamily: 'InterTight',
                              fontSize: 11.5,
                              height: 15 / 11.5,
                              fontWeight: FontWeight.w700,
                              color: LamazonTheme.strong,
                            ),
                          ),
                        const SizedBox(height: 2),
                        // The name is what you are buying, but you already know
                        // that from the picture. Medium weight, two lines, and
                        // it stops shouting over the price.
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'InterTight',
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                            height: 16.5 / 13,
                            letterSpacing: .05,
                            color: LamazonTheme.text,
                          ),
                        ),
                        if (showStore) ...[
                          const SizedBox(height: 2),
                          Text(
                            product.store,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'InterTight',
                              fontSize: 11,
                              height: 14 / 11,
                              letterSpacing: .2,
                              color: LamazonTheme.muted,
                            ),
                          ),
                        ],
                        if (note != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            note.$1,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'InterTight',
                              fontSize: 11.5,
                              height: 15 / 11.5,
                              fontWeight: FontWeight.w700,
                              color: note.$2,
                            ),
                          ),
                        ],
                      ],
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

/// The saving, as a shopper reads it. One shape everywhere it appears, so a
/// card, a details page and a cart line cannot drift apart.
class DiscountBadge extends StatelessWidget {
  final int percent;
  final double fontSize;
  const DiscountBadge({super.key, required this.percent, this.fontSize = 11});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: fontSize * 0.7, vertical: 4),
      decoration: BoxDecoration(
        color: LamazonTheme.peach,
        borderRadius: BorderRadius.circular(9),
        boxShadow: const [
          BoxShadow(
            color: Color(0x290D2119),
            offset: Offset(0, 2),
            blurRadius: 5,
          ),
        ],
      ),
      child: Text(
        '$percent% OFF',
        style: TextStyle(
          color: LamazonTheme.text,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// Price, with the old one struck through beside it when there is a discount.
/// Wraps rather than ellipsising: on a narrow card the saving is the point,
/// and half a struck-through number reads as a mistake.
class PriceLine extends StatelessWidget {
  final Product product;
  final double fontSize;
  const PriceLine({super.key, required this.product, this.fontSize = 15});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      children: [
        Text(
          '₹${product.price.moneyText}',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: fontSize),
        ),
        if (product.discounted)
          Text(
            '₹${product.mrp.moneyText}',
            style: TextStyle(
              fontSize: fontSize - 2,
              color: const Color(0xFF8A8A8A),
              decoration: TextDecoration.lineThrough,
              decorationColor: const Color(0xFF8A8A8A),
            ),
          ),
      ],
    );
  }
}

/// Tappable heart that toggles the product in the global wishlist.
/// Save for later, said quietly.
///
/// This was a 40px filled white circle with a drop shadow, sitting on every
/// card opposite an equally heavy add button — eighteen weighted circles on a
/// nine-card screen, all of them louder than the food they were sitting on.
/// Saving is a secondary action and now looks like one: no disc, a thin
/// outline, and a soft scrim only so the stroke survives a pale photograph.
///
/// The tap target stays at [LamazonTheme.touch]; only the drawing shrank.
class WishlistHeart extends StatelessWidget {
  final String productId;
  const WishlistHeart({super.key, required this.productId});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Wishlist.instance,
      builder: (context, _) {
        final liked = Wishlist.instance.contains(productId);
        return Semantics(
          button: true,
          selected: liked,
          label: liked ? 'Remove from saved' : 'Save product',
          // No excludeSemantics: it would take the InkResponse's own focusable
          // node with it and drop the heart out of the tab order. Nothing
          // inside speaks anyway — the tooltip opts out and the icon is mute.
          child: Tooltip(
            message: liked ? 'Remove from saved' : 'Save product',
            excludeFromSemantics: true,
            child: InkResponse(
              onTap: () => Wishlist.instance.toggle(productId),
              radius: 22,
              child: SizedBox(
                width: LamazonTheme.touch,
                height: LamazonTheme.touch,
                child: Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      // Just enough ground for the stroke to read on a white
                      // packshot and on a dark one, without becoming a button.
                      color: LamazonTheme.surface.withValues(alpha: .78),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(5),
                      child: Icon(
                        liked ? Icons.favorite : LucideIcons.heart,
                        size: 17,
                        color: liked
                            ? LamazonTheme.danger
                            : LamazonTheme.strong,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Animated quick-add button: cart icon pops into a green check when tapped.
class CartButton extends StatefulWidget {
  final Product product;
  const CartButton({super.key, required this.product});

  @override
  State<CartButton> createState() => _CartButtonState();
}

class _CartButtonState extends State<CartButton> {
  bool _added = false;

  void _add() {
    if (_added || _disabled) return;
    // add returns what it could actually fit, so a basket that is already
    // holding the shop's whole stock says so instead of silently doing
    // nothing and flashing a tick.
    if (Cart.instance.add(widget.product) == 0) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Your cart already holds every one the shop has.'),
          ),
        );
      return;
    }
    setState(() => _added = true);
    showAddedToast(context, widget.product);
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _added = false);
    });
  }

  bool get _disabled => widget.product.availableStock == 0;

  @override
  Widget build(BuildContext context) {
    final disabled = _disabled;
    return AnimatedScale(
      duration: Duration(
        milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 180,
      ),
      scale: _added ? 1.06 : 1,
      // A 44px lime disc with a layered drop shadow, nine of them on a
      // screen, was the loudest thing in the grid — louder than the
      // photography it sat on and louder than the price it was meant to
      // support. The tap target is unchanged; the disc inside it is smaller
      // and flatter, and the lime now reads as an accent rather than as
      // nine competing traffic lights.
      child: TactileIconButton(
        icon: _added ? LucideIcons.check : LucideIcons.plus,
        label: disabled
            ? 'Out of stock'
            : _added
            ? 'Added to cart'
            : Cart.instance.atCap(widget.product)
            ? 'Your cart holds all of them'
            : 'Add ${widget.product.name} to cart',
        onPressed: _added || disabled ? null : _add,
        background: disabled ? LamazonTheme.track : LamazonTheme.lime,
        foreground: disabled ? LamazonTheme.muted : LamazonTheme.strong,
        size: LamazonTheme.touch,
        inset: 5,
        flat: true,
      ),
    );
  }
}

/// Renders any pasted image link; broken links fall back to a grey placeholder
/// instead of crashing the grid.
///
/// Cloudinary pads the picture into [padTo] first (see [padded]) and it is
/// drawn with BoxFit.contain, so nothing is cropped or blown up — products
/// looking zoomed was BoxFit.cover filling a tile with the middle of whatever
/// shape the seller happened to upload.
///
/// [padTo] is the shape this image is drawn in: 1 for a product or category
/// tile, 16/9 for a store's cover banner. Pass null to leave the picture
/// alone, for the rare place that wants the original bytes.
class NetImage extends StatelessWidget {
  final String url;
  final BoxFit? fit;
  final double? padTo;
  final int? sourceWidth;
  final String? semanticLabel;
  const NetImage({
    super.key,
    required this.url,
    this.fit,
    this.padTo = 1,
    this.sourceWidth,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    // An empty URL is not a broken image, it is no image — and asking the
    // browser for "" fetches the page itself, so every one of the 200-odd
    // photoless rows came back as index.html and logged a decode failure.
    if (url.trim().isEmpty) return _fallback();
    return Image.network(
      padTo == null
          ? optimizedImage(url, sourceWidth ?? 1024)
          : padded(url, padTo!, sourceWidth),
      semanticLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
      fit: fit ?? (padTo == null ? BoxFit.cover : BoxFit.contain),
      loadingBuilder: (_, child, progress) =>
          progress == null ? child : const Skeleton(),
      errorBuilder: (_, error, _) {
        debugPrint('NetImage error [$url]: $error');
        return _fallback();
      },
    );
  }

  Widget _fallback() {
    return Container(
      color: const Color(0xFFF0F1EB),
      alignment: Alignment.center,
      child: const Icon(LucideIcons.imageOff, color: LamazonTheme.muted),
    );
  }
}
