import 'dart:async';
import 'package:flutter/material.dart';
import '../data/api.dart';
import '../data/orders.dart';
import '../widgets/app_shell.dart';
import '../widgets/screen_header.dart';

class OrderDetailScreen extends StatefulWidget {
  final MyOrder order;
  const OrderDetailScreen({super.key, required this.order});
  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  Timer? _refresh;
  bool _cancelling = false;
  @override
  void initState() {
    super.initState();
    MyOrders.instance.load();
    _refresh = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted &&
          ModalRoute.of(context)?.isCurrent == true &&
          !MyOrders.instance.loading) {
        MyOrders.instance.load();
      }
    });
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  Future<void> _cancel(MyOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: Text('${order.units} × ${order.itemTitle}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Keep order'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Cancel order'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _cancelling = true);
    try {
      await Api.instance.cancelOrder(order.id);
      await MyOrders.instance.load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('ClientException: ', '')),
          ),
        );
      }
      await MyOrders.instance.load();
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF1F1EF),
    body: ReadableBody(
      maxWidth: 700,
      child: SafeArea(
        child: ListenableBuilder(
          listenable: MyOrders.instance,
          builder: (context, _) {
            final order =
                MyOrders.instance.orders
                    .where((o) => o.id == widget.order.id)
                    .firstOrNull ??
                widget.order;
            return Column(
              children: [
                ScreenHeader(title: 'Order ${orderRef(order.id)}'),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: MyOrders.instance.load,
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        Text(
                          order.itemTitle,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        Text(order.storeName),
                        Text(
                          '${order.units} item(s) · Total ₹${order.amount.toStringAsFixed(2)}',
                        ),
                        const SizedBox(height: 20),
                        Text(
                          order.rejectReason == 'Cancelled by customer'
                              ? 'Cancelled'
                              : order.status.title,
                        ),
                        if (order.rejectReason.isNotEmpty)
                          Text(order.rejectReason),
                        if (order.deliveryCode.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text('Delivery code: ${order.deliveryCode}'),
                          const Text(
                            'Share this code only when your order is handed to you.',
                          ),
                        ],
                        const SizedBox(height: 20),
                        const Text('Delivery address'),
                        Text(order.address),
                        const SizedBox(height: 20),
                        if (MyOrders.instance.error != null)
                          Text(MyOrders.instance.error!),
                        TextButton(
                          onPressed: MyOrders.instance.loading
                              ? null
                              : MyOrders.instance.load,
                          child: const Text('Refresh status'),
                        ),
                        if (order.status == OrderStatus.placed)
                          TextButton(
                            onPressed: _cancelling
                                ? null
                                : () => _cancel(order),
                            child: Text(
                              _cancelling ? 'Cancelling…' : 'Cancel order',
                            ),
                          ),
                      ],
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
