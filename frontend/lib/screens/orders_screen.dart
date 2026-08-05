import '../widgets/app_nav.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/orders.dart';
import '../widgets/app_shell.dart';
import '../widgets/screen_header.dart';

const _ink = Color(0xFF1A1A1A);
const _muted = Color(0xFF6B6B6B);
const _green = Color(0xFF2E7D32);
const _red = Color(0xFFD32F2F);
const _amber = Color(0xFFE07B00);
const _blue = Color(0xFF2F6FED);

Color _statusColor(OrderStatus s) => switch (s) {
  OrderStatus.delivered => _green,
  OrderStatus.rejected => _red,
  OrderStatus.picked => _blue,
  _ => _amber,
};

String _ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} hr ago';
  return '${d.inDays} days ago';
}

/// The buyer's orders, read from the server every time this opens. There is
/// no local history: an order that is not on the server did not happen.
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  @override
  void initState() {
    super.initState();
    MyOrders.instance.load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The bar floats over the content rather than reserving a strip, which
      // is how it sits on home — bottomNavigationBar would push every screen
      // up by its height and leave a white band under it.
      extendBody: true,
      bottomNavigationBar: const SafeArea(
        child: AppBottomNav(current: AppTab.none),
      ),
      backgroundColor: const Color(0xFFF1F1EF),
      body: ReadableBody(
        maxWidth: 700,
        child: SafeArea(
          child: ListenableBuilder(
            listenable: MyOrders.instance,
            builder: (context, _) {
              final orders = MyOrders.instance.orders;
              return Column(
                children: [
                  const ScreenHeader(title: 'My Orders'),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: MyOrders.instance.load,
                      child: orders.isEmpty
                          ? ListView(
                              children: [
                                const SizedBox(height: 80),
                                Icon(
                                  MyOrders.instance.loading
                                      ? LucideIcons.loader
                                      : LucideIcons.package,
                                  size: 44,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  MyOrders.instance.error ??
                                      (MyOrders.instance.loading
                                          ? 'Loading your orders…'
                                          : 'No orders yet'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: _muted,
                                  ),
                                ),
                              ],
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                              itemCount: orders.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (_, i) =>
                                  _OrderCard(order: orders[i]),
                            ),
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

class _OrderCard extends StatelessWidget {
  final MyOrder order;
  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final colour = _statusColor(order.status);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Order No. #${order.id.toUpperCase()}',
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colour.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  order.status.title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: colour,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${order.units} × ${order.itemTitle}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          Text(
            '${order.storeName} · ${_ago(order.placedAt)}',
            style: const TextStyle(fontSize: 12.5, color: _muted),
          ),
          if (order.address.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              order.address,
              style: const TextStyle(fontSize: 12, color: _muted, height: 1.35),
            ),
          ],
          if (order.rejectReason.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'The shop said: ${order.rejectReason}',
              style: const TextStyle(fontSize: 12.5, color: _red),
            ),
          ],
          // The code is the whole verification: the rider cannot close the
          // order without it, so it is shown big enough to read out.
          if (order.deliveryCode.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F1EF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  const Text(
                    'Give this code to the rider',
                    style: TextStyle(fontSize: 11.5, color: _muted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    order.deliveryCode,
                    style: const TextStyle(
                      fontSize: 26,
                      letterSpacing: 8,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(fontSize: 13, color: _muted),
              ),
              Text(
                '₹${order.amount.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
