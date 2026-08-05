import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/cart.dart';
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
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: NetImage(url: product.imageUrl),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: WishlistHeart(productId: product.id),
                ),
                // Bottom-left, where it sits over the image rather than over
                // the product: the top corners are the heart's and the part
                // of a photo people frame their subject in.
                if (product.discounted)
                  Positioned(
                    left: 10,
                    bottom: 10,
                    child: DiscountBadge(percent: product.discountPercent),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    PriceLine(product: product),
                  ],
                ),
              ),
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
          '₹${product.price.toStringAsFixed(0)}',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: fontSize),
        ),
        if (product.discounted)
          Text(
            '₹${product.mrp.toStringAsFixed(0)}',
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
        return GestureDetector(
          onTap: () => Wishlist.instance.toggle(productId),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            // Small pop each time the heart toggles, in both directions.
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, anim) => ScaleTransition(
                scale: Tween(begin: 0.6, end: 1.0).animate(
                  CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
                ),
                child: child,
              ),
              // Lucide is outline-only, so the filled state uses Material's
              // heart — solid red once the product is wishlisted.
              child: Icon(
                liked ? Icons.favorite : LucideIcons.heart,
                key: ValueKey(liked),
                size: liked ? 18 : 16,
                color: liked
                    ? const Color(0xFFE53935)
                    : const Color(0xFF1A1A1A),
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
    if (_added) return;
    setState(() => _added = true);
    Cart.instance.add(widget.product);
    showAddedToast(context, widget.product);
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _added = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _add,
      child: AnimatedScale(
        scale: _added ? 1.18 : 1,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _added ? const Color(0xFF43A047) : const Color(0xFF1A1A1A),
            shape: BoxShape.circle,
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: Icon(
              _added ? LucideIcons.check : LucideIcons.shoppingCart,
              key: ValueKey(_added),
              size: 15,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// Renders any pasted image link; broken links fall back to a grey placeholder
/// instead of crashing the grid.
class NetImage extends StatelessWidget {
  final String url;
  final BoxFit fit;
  const NetImage({super.key, required this.url, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    // An empty URL is not a broken image, it is no image — and asking the
    // browser for "" fetches the page itself, so every one of the 200-odd
    // photoless rows came back as index.html and logged a decode failure.
    if (url.trim().isEmpty) return _fallback();
    return Image.network(
      url,
      fit: fit,
      loadingBuilder: (_, child, progress) =>
          progress == null ? child : Container(color: const Color(0xFFE8E8E4)),
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
