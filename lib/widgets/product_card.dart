import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/product.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback? onTap;
  const ProductCard({super.key, required this.product, this.onTap});

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
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.heart, size: 16),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            product.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 2),
          Text(
            '₹${product.price.toStringAsFixed(0)}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ],
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
