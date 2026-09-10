import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../data/addresses.dart';
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
            DecoratedBox(
              decoration: const BoxDecoration(
                color: LamazonTheme.lime,
                shape: BoxShape.circle,
                boxShadow: LamazonTheme.tactileShadows,
              ),
              child: const SizedBox(
                width: 80,
                height: 80,
                child: Icon(
                  LucideIcons.check,
                  size: 36,
                  color: LamazonTheme.strong,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Your order is placed',
              textAlign: TextAlign.center,
              style: LamazonTheme.titleText,
            ),
            const SizedBox(height: 12),
            const Text(
              'We have sent your order to the store. You can follow its progress below.',
              textAlign: TextAlign.center,
              style: TextStyle(color: LamazonTheme.muted, height: 1.5),
            ),
            const SizedBox(height: 28),
            ElevatedSurface(
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
                  const SizedBox(height: 8),
                  // "When will it get here" is the first thing anyone thinks
                  // after ordering, and this screen never answered it.
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        LucideIcons.clock,
                        size: 15,
                        color: LamazonTheme.strong,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Arriving in about $deliveryEta',
                          style: const TextStyle(
                            color: LamazonTheme.strong,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            for (final order in orders)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ElevatedSurface(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(
                        'Order ${orderRef(order.id)}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text('${order.units} × ${order.itemTitle}'),
                      Text(
                        order.storeName,
                        style: const TextStyle(color: LamazonTheme.muted),
                      ),
                      const SizedBox(height: 12),
                      const TrackDivider(),
                      const SizedBox(height: 12),
                      ActionButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => OrderDetailScreen(order: order),
                          ),
                        ),
                        icon: LucideIcons.package,
                        label: 'Track order',
                        primary: false,
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),
            ActionButton(
              onPressed: () => Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/', (r) => false),
              label: 'Continue shopping',
              expand: true,
            ),
          ],
        ),
      ),
    ),
  );
}
