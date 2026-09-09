import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../data/orders.dart';
import '../data/money.dart';
import '../widgets/design_system.dart';
import '../widgets/app_shell.dart';
import 'order_detail_screen.dart';

class OrderConfirmationScreen extends StatelessWidget {
  final List<MyOrder> orders;
  const OrderConfirmationScreen({super.key, required this.orders});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ReadableBody(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 36),
            const CircleAvatar(
              radius: 40,
              backgroundColor: LamazonTheme.accent,
              child: Icon(LucideIcons.check, size: 36, color: LamazonTheme.ink),
            ),
            const SizedBox(height: 24),
            Text(
              'Your order is placed',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            const Text(
              'We have sent your order to the store. You can follow its progress below.',
              textAlign: TextAlign.center,
              style: TextStyle(color: LamazonTheme.muted, height: 1.5),
            ),
            const SizedBox(height: 28),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pay on delivery',
                      style: TextStyle(color: LamazonTheme.muted),
                    ),
                    Text(
                      '₹${orders.fold<double>(0, (sum, o) => sum + o.amount).moneyText}',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    if (orders.isNotEmpty) Text(orders.first.address),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            for (final order in orders)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(
                        'Order ${order.id}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text('${order.units} × ${order.itemTitle}'),
                      Text(
                        order.storeName,
                        style: const TextStyle(color: LamazonTheme.muted),
                      ),
                      TextButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => OrderDetailScreen(order: order),
                          ),
                        ),
                        icon: const Icon(LucideIcons.package),
                        label: const Text('Track order'),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
              child: const Text('Continue shopping'),
            ),
          ],
        ),
      ),
    ),
  );
}
