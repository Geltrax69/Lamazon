import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/catalog.dart';
import '../models/product.dart';
import '../widgets/app_shell.dart';
import '../widgets/product_card.dart';
import '../widgets/screen_header.dart';
import 'shop_screen.dart';

/// Every store, for when "Stores near you" is not enough. The home row shows
/// a handful sideways; this is the same data as a list you can scroll.
class ShopsScreen extends StatelessWidget {
  const ShopsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F1EF),
      body: ReadableBody(
        maxWidth: 760,
        child: SafeArea(
          child: FutureBuilder<List<Shop>>(
            future: loadShops(),
            builder: (context, snap) {
              final list = snap.data ?? const <Shop>[];
              return Column(
                children: [
                  const ScreenHeader(title: 'Stores near you'),
                  if (!snap.hasData)
                    const Expanded(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 90),
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _ShopRow(shop: list[i]),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ShopRow extends StatelessWidget {
  final Shop shop;
  const _ShopRow({required this.shop});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ShopScreen(shop: shop)),
      ),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 76,
                height: 76,
                child: NetImage(url: thumb(shop.imageUrl, 160)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    shop.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    shop.tagline,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.3,
                      color: Color(0xFF6B6B6B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Row(
                    children: [
                      Icon(LucideIcons.timer, size: 12, color: Color(0xFF6B6B6B)),
                      SizedBox(width: 4),
                      Text(
                        '12 mins',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF6B6B6B)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight, size: 18, color: Color(0xFF9A9A9A)),
          ],
        ),
      ),
    );
  }
}
