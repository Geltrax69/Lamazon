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
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: NetImage(
                          url: product.imageUrl,
                          semanticLabel: product.name,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: WishlistHeart(productId: product.id),
                    ),
                    if (product.discounted)
                      Positioned(
                        left: 4,
                        bottom: 4,
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
                style: const TextStyle(fontSize: 11, color: LamazonTheme.muted),
              ),
              const SizedBox(height: 3),
              Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  height: 1.25,
                ),
              ),
              if (product.availableStock != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    product.availableStock == 0
                        ? 'Out of stock'
                        : product.availableStock! <= 5
                        ? 'Only ${product.availableStock} left'
                        : 'In stock',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: product.availableStock == 0
                          ? Colors.red.shade800
                          : LamazonTheme.green,
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(child: PriceLine(product: product, fontSize: 17)),
                  if (showAddToCart) CartButton(product: product),
                ],
              ),
            ],
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
        color: const Color(0xFFD32F2F),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$percent% OFF',
        style: TextStyle(
          color: Colors.white,
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
        return IconButton.filledTonal(
          tooltip: liked ? 'Remove from saved' : 'Save product',
          onPressed: () => Wishlist.instance.toggle(productId),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: .95),
            minimumSize: const Size(48, 48),
          ),
          icon: Icon(
            liked ? Icons.favorite : LucideIcons.heart,
            size: 20,
            color: liked ? const Color(0xFFC62828) : LamazonTheme.ink,
          ),
          isSelected: liked,
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
    if (_added || widget.product.availableStock == 0) return;
    setState(() => _added = true);
    Cart.instance.add(widget.product);
    showAddedToast(context, widget.product);
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _added = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      tooltip: widget.product.availableStock == 0
          ? 'Out of stock'
          : _added
          ? 'Added to cart'
          : 'Add ${widget.product.name} to cart',
      onPressed: _added || widget.product.availableStock == 0 ? null : _add,
      style: IconButton.styleFrom(
        backgroundColor: LamazonTheme.accent,
        foregroundColor: LamazonTheme.ink,
        disabledBackgroundColor: LamazonTheme.green,
        disabledForegroundColor: Colors.white,
        minimumSize: const Size(48, 48),
      ),
      icon: Icon(_added ? LucideIcons.check : LucideIcons.plus, size: 20),
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
      color: const Color(0xFFE8E8E4),
      alignment: Alignment.center,
      child: const Icon(LucideIcons.imageOff, color: Colors.grey),
    );
  }
}
