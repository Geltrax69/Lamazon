import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/catalog.dart';
import '../data/api.dart';
import '../data/money.dart';
import '../data/orders.dart';
import '../widgets/app_shell.dart';
import '../widgets/design_system.dart';
import '../widgets/screen_header.dart';

/// Where one order has got to, and the two things the buyer needs from it:
/// the code they read out at the door, and a way out while there is still one.
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
        // Names what is being cancelled and what it costs, so the dialog is
        // a decision rather than a speed bump.
        content: Text(
          '${order.units} × ${order.itemTitle} from ${order.storeName}, '
          '₹${order.amount.moneyText}.\n\n'
          'The shop has not accepted it yet, so nothing has been prepared. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Keep order'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            style: TextButton.styleFrom(foregroundColor: LamazonTheme.danger),
            child: const Text('Cancel order'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _cancelling = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Api.instance.cancelOrder(order.id);
      await MyOrders.instance.load();
      messenger.showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Order cancelled.'),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(e.toString().replaceFirst('ClientException: ', '')),
        ),
      );
      await MyOrders.instance.load();
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: LamazonTheme.canvas,
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
            final cancelled = order.rejectReason == 'Cancelled by customer';
            return Column(
              children: [
                ScreenHeader(title: 'Order ${orderRef(order.id)}'),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: MyOrders.instance.load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        _StatusPanel(order: order, cancelled: cancelled),
                        const SizedBox(height: 16),

                        // The code goes only to the buyer, which is what makes
                        // reading it out proof the two of them met. It is the
                        // most important thing on this screen while an order
                        // is live, so it looks like it.
                        if (order.deliveryCode.isNotEmpty) ...[
                          _DeliveryCode(code: order.deliveryCode),
                          const SizedBox(height: 16),
                        ],

                        ElevatedSurface(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SectionHeading(title: 'What you ordered'),
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          order.itemTitle,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          order.storeName,
                                          style: LamazonTheme.mutedBodyText,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    // "1 item(s)" was the old copy.
                                    order.units == 1
                                        ? '1 item'
                                        : '${order.units} items',
                                    style: LamazonTheme.mutedBodyText,
                                  ),
                                ],
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: TrackDivider(),
                              ),
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Total paid on delivery',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '₹${order.amount.moneyText}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        ElevatedSurface(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SectionHeading(title: 'Delivering to'),
                              const SizedBox(height: 8),
                              Text(
                                order.address.isEmpty
                                    ? 'No address recorded for this order.'
                                    : order.address,
                                style: const TextStyle(height: 1.5),
                              ),
                            ],
                          ),
                        ),

                        if (MyOrders.instance.error != null) ...[
                          const SizedBox(height: 16),
                          _Notice(
                            icon: LucideIcons.circleAlert,
                            colour: LamazonTheme.danger,
                            text: MyOrders.instance.error!,
                          ),
                        ],

                        const SizedBox(height: 20),
                        // Refreshing happens on a timer anyway; the button is
                        // for the person who does not want to wait 20 seconds,
                        // and it now says when it is working.
                        ActionButton(
                          label: MyOrders.instance.loading
                              ? 'Refreshing…'
                              : 'Refresh status',
                          icon: LucideIcons.refreshCw,
                          primary: false,
                          expand: true,
                          loading: MyOrders.instance.loading,
                          onPressed: MyOrders.instance.loading
                              ? null
                              : MyOrders.instance.load,
                        ),
                        // Only while the shop has not accepted it. After that
                        // there is food being made, and the API refuses.
                        if (order.status == OrderStatus.placed) ...[
                          const SizedBox(height: 10),
                          ActionButton(
                            label: _cancelling
                                ? 'Cancelling…'
                                : 'Cancel order',
                            primary: false,
                            expand: true,
                            loading: _cancelling,
                            onPressed: _cancelling
                                ? null
                                : () => _cancel(order),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'You can cancel until the shop accepts it.',
                            textAlign: TextAlign.center,
                            style: LamazonTheme.mutedBodyText,
                          ),
                        ],
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

/// Where the order is, as a line the eye can follow rather than a sentence.
class _StatusPanel extends StatelessWidget {
  final MyOrder order;
  final bool cancelled;
  const _StatusPanel({required this.order, required this.cancelled});

  /// The happy path, in order. A rejected or cancelled order left it, so it
  /// draws a plain notice instead of a track with a hole in it.
  static const _steps = [
    (OrderStatus.placed, 'Placed', LucideIcons.receipt),
    (OrderStatus.accepted, 'Accepted', LucideIcons.chefHat),
    (OrderStatus.picked, 'On the way', LucideIcons.bike),
    (OrderStatus.delivered, 'Delivered', LucideIcons.circleCheck),
  ];

  @override
  Widget build(BuildContext context) {
    if (cancelled || order.status == OrderStatus.rejected) {
      return _Notice(
        icon: LucideIcons.circleX,
        colour: LamazonTheme.danger,
        text: cancelled
            ? 'You cancelled this order. Nothing was charged.'
            : order.rejectReason.isEmpty
            ? 'The shop could not take this order.'
            : 'The shop could not take this order: ${order.rejectReason}',
      );
    }
    final reached = _steps.indexWhere((s) => s.$1 == order.status);
    return ElevatedSurface(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            headingLevel: 2,
            liveRegion: true,
            child: Text(order.status.title, style: LamazonTheme.sectionText),
          ),
          if (!order.status.isOver) ...[
            const SizedBox(height: 2),
            Text(
              'Arriving in about $deliveryEta',
              style: LamazonTheme.mutedBodyText,
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              for (var i = 0; i < _steps.length; i++) ...[
                if (i > 0)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      color: i <= reached
                          ? LamazonTheme.strong
                          : LamazonTheme.track,
                    ),
                  ),
                _Step(
                  icon: _steps[i].$3,
                  label: _steps[i].$2,
                  done: i <= reached,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool done;
  const _Step({required this.icon, required this.label, required this.done});

  @override
  Widget build(BuildContext context) => Semantics(
    label: done ? '$label, done' : '$label, not yet',
    excludeSemantics: true,
    child: SizedBox(
      width: 62,
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? LamazonTheme.strong : LamazonTheme.track,
            ),
            child: Icon(
              icon,
              size: 16,
              color: done ? Colors.white : LamazonTheme.muted,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              height: 1.2,
              fontWeight: done ? FontWeight.w600 : FontWeight.w400,
              color: done ? LamazonTheme.text : LamazonTheme.muted,
            ),
          ),
        ],
      ),
    ),
  );
}

/// The four digits, big enough to read off a phone at a door.
class _DeliveryCode extends StatelessWidget {
  final String code;
  const _DeliveryCode({required this.code});

  @override
  Widget build(BuildContext context) => ElevatedSurface(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              LucideIcons.shieldCheck,
              size: 18,
              color: LamazonTheme.strong,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Your delivery code',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Spaced so it can be read aloud a digit at a time, and selectable
        // rather than a picture of a number.
        Semantics(
          label: 'Delivery code ${code.split('').join(' ')}',
          excludeSemantics: true,
          child: SelectableText(
            code.split('').join('  '),
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
              color: LamazonTheme.strong,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Read it out only when your order is actually handed to you. '
          'It is how the rider proves the delivery happened.',
          style: LamazonTheme.mutedBodyText,
        ),
      ],
    ),
  );
}

class _Notice extends StatelessWidget {
  final IconData icon;
  final Color colour;
  final String text;
  const _Notice({
    required this.icon,
    required this.colour,
    required this.text,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: colour.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(LamazonTheme.featuredRadius),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: colour),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 13, height: 1.45, color: colour),
          ),
        ),
      ],
    ),
  );
}
