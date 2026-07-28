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
  const ProductCard(
      {super.key, required this.product, this.onTap, this.showAddToCart = false});

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Hero(
                    tag: 'product-${product.id}',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: NetImage(url: product.imageUrl),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: WishlistHeart(productId: product.id),
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
                          fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '₹${product.price.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15),
                    ),
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
            child: Icon(
              LucideIcons.heart,
              size: 16,
              color: liked ? const Color(0xFFE53935) : const Color(0xFF1A1A1A),
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
    return Image.network(
      url,
      fit: fit,
      loadingBuilder: (_, child, progress) => progress == null
          ? child
          : Container(color: const Color(0xFFE8E8E4)),
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
