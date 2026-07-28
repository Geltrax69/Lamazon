import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/orders.dart';
import '../widgets/product_card.dart';

const _ink = Color(0xFF1A1A1A);
const _green = Color(0xFF2E7D32);
const _red = Color(0xFFD32F2F);

Color _statusColor(OrderStatus s) => switch (s) {
      OrderStatus.delivered => _green,
      OrderStatus.cancelled => _red,
      _ => const Color(0xFFE07B00),
    };

String _ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} hr ago';
  return '${d.inDays} days ago';
}

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F1EF),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: const BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle),
                      child: const Icon(LucideIcons.arrowLeft,
                          size: 18, color: _ink),
                    ),
                  ),
                  const Text('My Orders',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 46),
                ],
              ),
            ),
            Expanded(
              child: sampleOrders.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.package,
                              size: 44, color: Colors.grey),
                          SizedBox(height: 12),
                          Text('No orders yet',
                              style: TextStyle(
                                  fontSize: 14, color: Color(0xFF6B6B6B))),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                      itemCount: sampleOrders.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, i) =>
                          _OrderCard(order: sampleOrders[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;
  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(order.status);
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => OrderDetailScreen(order: order))),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(order.status.title,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: color)),
                ),
                const Spacer(),
                Text(_ago(order.placedAt),
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF9A9A9A))),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // Thumbnails of the first few items.
                for (final l in order.lines.take(3))
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 46,
                        height: 46,
                        child: NetImage(url: l.product.imageUrl),
                      ),
                    ),
                  ),
                if (order.lines.length > 3)
                  Text('+${order.lines.length - 3}',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF9A9A9A))),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('₹${order.total.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w800)),
                    Text('${order.itemCount} items',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF9A9A9A))),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(order.id,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF9A9A9A))),
                const Spacer(),
                const Text('View details',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _ink)),
                const Icon(LucideIcons.chevronRight, size: 14, color: _ink),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Order detail with a delivery progress tracker.
class OrderDetailScreen extends StatelessWidget {
  final Order order;
  const OrderDetailScreen({super.key, required this.order});

  static const _steps = [
    OrderStatus.placed,
    OrderStatus.packed,
    OrderStatus.onTheWay,
    OrderStatus.delivered,
  ];

  @override
  Widget build(BuildContext context) {
    final cancelled = order.status == OrderStatus.cancelled;
    final currentStep = cancelled ? -1 : _steps.indexOf(order.status);
    return Scaffold(
      backgroundColor: const Color(0xFFF1F1EF),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(LucideIcons.arrowLeft,
                        size: 18, color: _ink),
                  ),
                ),
                Text(order.id,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(width: 46),
              ],
            ),
            const SizedBox(height: 20),
            if (cancelled)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDECEA),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(LucideIcons.circleX, size: 20, color: _red),
                    SizedBox(width: 10),
                    Text('This order was cancelled',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _red)),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < _steps.length; i++)
                      _TrackStep(
                        title: _steps[i].title,
                        done: i <= currentStep,
                        active: i == currentStep,
                        isLast: i == _steps.length - 1,
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            const Text('Items',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            for (final l in order.lines)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                          width: 52,
                          height: 52,
                          child: NetImage(url: l.product.imageUrl)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.product.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                          Text('${l.product.store}  •  Qty ${l.qty}',
                              style: const TextStyle(
                                  fontSize: 11, color: Color(0xFF9A9A9A))),
                        ],
                      ),
                    ),
                    Text('₹${(l.product.price * l.qty).toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Delivery address',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(order.address,
                      style: const TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: Color(0xFF6B6B6B))),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total paid',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                      Text('₹${order.total.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackStep extends StatelessWidget {
  final String title;
  final bool done;
  final bool active;
  final bool isLast;

  const _TrackStep({
    required this.title,
    required this.done,
    required this.active,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final color = done ? _green : const Color(0xFFD8D8D4);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(done ? LucideIcons.check : LucideIcons.circle,
                  size: 12, color: Colors.white),
            ),
            if (!isLast)
              Container(width: 2, height: 30, color: color),
          ],
        ),
        const SizedBox(width: 12),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(title,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                  color: done ? _ink : const Color(0xFF9A9A9A))),
        ),
      ],
    );
  }
}
