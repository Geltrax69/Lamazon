import 'design_system.dart';
import '../data/money.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/cart.dart';
import '../data/catalog.dart';
import '../data/wishlist.dart';
import '../models/product.dart';
import 'status_views.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback? onTap;
  final bool showAddToCart; // quick-add only for food & grocery
  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.showAddToCart = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedSurface(
      radius: LamazonTheme.smallRadius,
      onTap: onTap,
      semanticLabel: product.name,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: ColoredBox(
                      color: const Color(0xFFF2F2EC),
                      child: NetImage(
                        url: product.imageUrl,
                        semanticLabel: product.name,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 5,
                  right: 5,
                  child: WishlistHeart(productId: product.id),
                ),
                if (product.discounted)
                  Positioned(
                    left: 5,
                    bottom: 5,
                    child: DiscountBadge(percent: product.discountPercent),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            product.store,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'InterTight',
              fontSize: 11.5,
              letterSpacing: .25,
              color: LamazonTheme.muted,
            ),
          ),
          const SizedBox(height: 3),
          // Always two lines tall. The picture takes the leftover height, so a
          // one-line name used to hand its card a taller photo than the card
          // beside it — the row of products then looked misaligned.
          SizedBox(
            height: 36,
            child: Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'InterTight',
                fontWeight: FontWeight.w600,
                fontSize: 14.5,
                height: 18 / 14.5,
                letterSpacing: .1,
              ),
            ),
          ),
          if (product.availableStock != null)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                product.availableStock == 0
                    ? 'Out of stock'
                    : product.availableStock! <= 5
                    ? 'Only ${product.availableStock} left'
                    : 'In stock',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'InterTight',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: product.availableStock == 0
                      ? LamazonTheme.danger
                      : LamazonTheme.strong,
                ),
              ),
            ),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(child: PriceLine(product: product, fontSize: 17)),
              if (showAddToCart) CartButton(product: product),
            ],
          ),
        ],
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
class WishlistHeart extends StatelessWidget {
  final String productId;
  const WishlistHeart({super.key, required this.productId});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Wishlist.instance,
      builder: (context, _) {
        final liked = Wishlist.instance.contains(productId);
        return TactileIconButton(
          icon: liked ? Icons.favorite : LucideIcons.heart,
          label: liked ? 'Remove from saved' : 'Save product',
          onPressed: () => Wishlist.instance.toggle(productId),
          selected: liked,
          size: 40,
          background: liked
              ? const Color(0xFFFCE3E5)
              : Colors.white.withValues(alpha: .96),
          foreground: liked ? LamazonTheme.danger : LamazonTheme.strong,
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
        size: 42,
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
