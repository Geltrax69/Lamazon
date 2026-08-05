import 'package:flutter/material.dart';

import '../widgets/app_shell.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/seller.dart';
import '../widgets/notify_banner.dart';
import '../widgets/photo_picker.dart';
import '../widgets/screen_header.dart';
import 'seller_product_screen.dart';

const _ink = Color(0xFF1A1A1A);
const _muted = Color(0xFF6B6B6B);
const _green = Color(0xFF2E7D32);
const _amber = Color(0xFFEF6C00);
const _red = Color(0xFFD32F2F);

/// The seller's store page: what it's worth, what's running out, and every
/// line of stock they can edit.
class SellerDashboardScreen extends StatefulWidget {
  const SellerDashboardScreen({super.key});

  @override
  State<SellerDashboardScreen> createState() => _SellerDashboardScreenState();
}

/// How many rows a page shows before "show more". Enough to fill a screen
/// without making the shop wait on a hundred widgets it will not look at.
const _pageSize = 8;

enum _Pane { orders, inventory }

class _SellerDashboardScreenState extends State<SellerDashboardScreen> {
  /// Null until the seller picks a side, so the first view can follow the
  /// shop's own state: a store with no orders yet opens on its stock rather
  /// than on an empty list.
  _Pane? _chosen;
  _Pane get _pane =>
      _chosen ??
      (Seller.instance.orders.isEmpty ? _Pane.inventory : _Pane.orders);
  int _shownOrders = _pageSize;
  int _shownItems = _pageSize;

  @override
  void initState() {
    super.initState();
    // What the server holds is the store. Reading it on open means a listing
    // that failed to save is visibly absent rather than sitting here looking
    // fine while no shopper can see it.
    Seller.instance.load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F1EF),
      body: ReadableBody(
        maxWidth: 760,
        child: SafeArea(
          child: ListenableBuilder(
            listenable: Seller.instance,
            builder: (context, _) {
              final store = Seller.instance.store;
              if (store == null) return const SizedBox.shrink();
              final items = Seller.instance.items;
              return Column(
                children: [
                  const ScreenHeader(title: 'Your store'),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 90),
                      children: [
                        const _SyncBanner(),
                        _ReviewBanner(store: store),
                        const NotifyBanner(),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: SizedBox(
                            height: 140,
                            width: double.infinity,
                            child: store.photo == null
                                ? Container(
                                    color: const Color(0xFFE8E8E4),
                                    alignment: Alignment.center,
                                    child: const Icon(
                                      LucideIcons.store,
                                      size: 36,
                                      color: Colors.grey,
                                    ),
                                  )
                                : Image.memory(store.photo!, fit: BoxFit.cover),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          store.name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontFamily: 'Georgia',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              LucideIcons.mapPin,
                              size: 13,
                              color: _muted,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${store.location}, ${store.city}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: _muted,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final c in store.categories)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  c,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            _Stat(
                              label: 'Products',
                              value: '${Seller.instance.skuCount}',
                            ),
                            const SizedBox(width: 10),
                            _Stat(
                              label: 'Units',
                              value: '${Seller.instance.unitsInStock}',
                            ),
                            const SizedBox(width: 10),
                            _Stat(
                              label: 'Needs restock',
                              value: '${Seller.instance.lowOrOutCount}',
                              color: Seller.instance.lowOrOutCount > 0
                                  ? _amber
                                  : null,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Inventory value',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '₹${Seller.instance.inventoryValue.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        // Orders and inventory used to run one after the
                        // other, so a shop with a day's orders had to scroll
                        // past all of them to change a price. Two panes, one
                        // tap apart, and neither can bury the other.
                        _PaneToggle(
                          pane: _pane,
                          orders: Seller.instance.orders.length,
                          items: items.length,
                          onTap: (p) => setState(() => _chosen = p),
                        ),
                        const SizedBox(height: 14),
                        if (_pane == _Pane.orders) ...[
                          Row(
                            children: [
                              _Stat(
                                label: 'Received',
                                value:
                                    '${Seller.instance.countAt(OrderStage.received)}',
                                color:
                                    Seller.instance.countAt(OrderStage.received) >
                                        0
                                    ? _amber
                                    : null,
                              ),
                              const SizedBox(width: 10),
                              _Stat(
                                label: 'Accepted',
                                value:
                                    '${Seller.instance.countAt(OrderStage.accepted)}',
                              ),
                              const SizedBox(width: 10),
                              _Stat(
                                label: 'Delivered',
                                value:
                                    '${Seller.instance.countAt(OrderStage.delivered)}',
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (Seller.instance.orders.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 18),
                              child: Center(
                                child: Text(
                                  'No orders yet',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    color: _muted,
                                  ),
                                ),
                              ),
                            )
                          else ...[
                            // A page at a time, newest first. The ones that
                            // need answering are at the top; the rest is a
                            // record, and a record does not need to be
                            // rendered all at once.
                            for (final order
                                in Seller.instance.orders.take(_shownOrders)) ...[
                              _OrderRow(order: order),
                              const SizedBox(height: 10),
                            ],
                            if (Seller.instance.orders.length > _shownOrders)
                              _MoreButton(
                                left:
                                    Seller.instance.orders.length - _shownOrders,
                                noun: 'orders',
                                onTap: () =>
                                    setState(() => _shownOrders += _pageSize),
                              ),
                          ],
                        ] else ...[
                          if (items.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 30),
                              child: Column(
                                children: [
                                  Icon(
                                    LucideIcons.packageOpen,
                                    size: 44,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'No products yet',
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: _muted,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Add your first one to start selling',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: Color(0xFF9A9A9A),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else ...[
                            for (final item in items.take(_shownItems)) ...[
                              _ItemRow(item: item),
                              const SizedBox(height: 10),
                            ],
                            if (items.length > _shownItems)
                              _MoreButton(
                                left: items.length - _shownItems,
                                noun: 'products',
                                onTap: () =>
                                    setState(() => _shownItems += _pageSize),
                              ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      // Adding stock is exactly what approval gates, so the button goes with
      // it. Showing it and failing the save afterwards would be worse.
      floatingActionButton: ListenableBuilder(
        listenable: Seller.instance,
        builder: (context, _) {
          if (Seller.instance.store?.approved != true) {
            return const SizedBox.shrink();
          }
          return FloatingActionButton.extended(
            backgroundColor: _green,
            foregroundColor: Colors.white,
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SellerProductScreen()),
              );
              // Land on what you just added. Coming back to the orders pane
              // after adding a product looks like the add did nothing.
              if (mounted) setState(() => _chosen = _Pane.inventory);
            },
            icon: const Icon(LucideIcons.plus, size: 18),
            label: const Text(
              'Add product',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          );
        },
      ),
    );
  }
}

/// One incoming order, with the single action it is waiting on.
/// Orders or inventory, with the counts on the buttons so the shop can see
/// there is something waiting without opening the other side.
class _PaneToggle extends StatelessWidget {
  final _Pane pane;
  final int orders;
  final int items;
  final ValueChanged<_Pane> onTap;
  const _PaneToggle({
    required this.pane,
    required this.orders,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        children: [
          _half('Orders ($orders)', _Pane.orders),
          _half('Inventory ($items)', _Pane.inventory),
        ],
      ),
    );
  }

  Widget _half(String label, _Pane which) => Expanded(
    child: GestureDetector(
      onTap: () => onTap(which),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: pane == which ? _ink : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: pane == which ? Colors.white : _muted,
          ),
        ),
      ),
    ),
  );
}

/// The rest of a long list, on request. Says how many are left rather than
/// "Show more", so the shop knows whether it is one tap or ten.
class _MoreButton extends StatelessWidget {
  final int left;
  final String noun;
  final VoidCallback onTap;
  const _MoreButton({
    required this.left,
    required this.noun,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          'Show $left more $noun',
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: _ink,
          ),
        ),
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  final SellerOrder order;
  const _OrderRow({required this.order});

  Color get _stageColor => switch (order.stage) {
    OrderStage.received => _amber,
    OrderStage.accepted => const Color(0xFF2F6FED),
    OrderStage.picked => const Color(0xFF6A1B9A),
    OrderStage.rejected => _red,
    OrderStage.delivered => _green,
  };

  /// Asks for the reason, because a rejection without one leaves the customer
  /// with nothing to do about it.
  Future<void> _reject(BuildContext context) async {
    final reason = TextEditingController();
    final given = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Why can you not take this order?'),
        content: TextField(
          controller: reason,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. Kitchen is closed, item just ran out',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Keep it'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _red),
            onPressed: () => Navigator.pop(dialog, reason.text.trim()),
            child: const Text('Reject order'),
          ),
        ],
      ),
    );
    if (given == null || given.isEmpty) return;
    final failure = await Seller.instance.rejectOrder(order.id, given);
    if (failure != null && context.mounted) _say(context, failure);
  }

  Future<void> _accept(BuildContext context) async {
    final failure = await Seller.instance.acceptOrder(order.id);
    if (!context.mounted) return;
    _say(
      context,
      failure ??
          'Accepted. The customer has their delivery code — a rider takes it '
              'from here.',
    );
  }

  void _say(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _stageColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        order.stage.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _stageColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '#${order.id.toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF9A9A9A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${order.units} × ${order.itemTitle}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '₹${order.amount.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 12.5, color: _muted),
                ),
                if (order.receiverName.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'For ${order.receiverName} · ${order.receiverPhone}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, color: _muted),
                  ),
                ],
                if (order.rejectReason.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Rejected: ${order.rejectReason}',
                    style: const TextStyle(fontSize: 11.5, color: _red),
                  ),
                ],
              ],
            ),
          ),
          // Only a brand new order is waiting on the shop. Once it is
          // accepted the rider owns it, and the shop cannot close it — that
          // takes the customer's code.
          if (order.stage.needsSeller)
            Column(
              children: [
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _ink,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: () => _accept(context),
                  child: const Text(
                    'Accept',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _reject(context),
                  child: const Text(
                    'Reject',
                    style: TextStyle(fontSize: 12, color: _red),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Where the store stands with review. A pending store looks finished to its
/// owner otherwise, and they would sit waiting for orders that cannot come.
class _ReviewBanner extends StatelessWidget {
  final SellerStore store;
  const _ReviewBanner({required this.store});

  @override
  Widget build(BuildContext context) {
    if (store.approved) return const SizedBox.shrink();
    final rejected = store.rejected;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: (rejected ? _red : _amber).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            rejected ? LucideIcons.circleAlert : LucideIcons.clock,
            size: 18,
            color: rejected ? _red : _amber,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rejected
                      ? 'Your store was not approved'
                      : 'Your store has been sent for review',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: rejected ? _red : _amber,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  rejected
                      ? '${store.rejectReason}\n\nFix that and save the store '
                          'again to send it back for review.'
                      : 'An admin is looking at it. You can add products as '
                          'soon as it is approved — shoppers see it then too.',
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: _ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _Stat({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color ?? _ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11.5, color: _muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final InventoryItem item;
  const _ItemRow({required this.item});

  Color get _statusColor => switch (item.status) {
    StockStatus.inStock => _green,
    StockStatus.low => _amber,
    StockStatus.out => _red,
  };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SellerProductScreen(existing: item),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              PhotoOrPlaceholder(photo: item.cover, size: 64),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '₹${item.price.toStringAsFixed(0)} · ${item.category}'
                      '${item.photos.length > 1 ? " · ${item.photos.length} photos" : ""}',
                      style: const TextStyle(fontSize: 12.5, color: _muted),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            item.status.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _statusColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${item.stock} left',
                          style: const TextStyle(fontSize: 11.5, color: _muted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Quick restock without opening the form.
              Column(
                children: [
                  _StockButton(
                    icon: LucideIcons.plus,
                    onTap: () => Seller.instance.adjustStock(item.id, 1),
                  ),
                  const SizedBox(height: 6),
                  _StockButton(
                    icon: LucideIcons.minus,
                    onTap: () => Seller.instance.adjustStock(item.id, -1),
                  ),
                ],
              ),
              IconButton(
                tooltip: 'Remove',
                icon: const Icon(LucideIcons.trash2, size: 17, color: _red),
                onPressed: () => Seller.instance.removeItem(item.id),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StockButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _StockButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F1EF),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, size: 15, color: _ink),
      ),
    );
  }
}


/// Shown when something never reached the server. Silence here is what let a
/// store exist in one browser tab and nowhere else.
class _SyncBanner extends StatelessWidget {
  const _SyncBanner();

  @override
  Widget build(BuildContext context) {
    final error = Seller.instance.syncError;
    if (error == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEC),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.triangleAlert, size: 18, color: Color(0xFFD03A3A)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(fontSize: 12.5, height: 1.35),
            ),
          ),
          TextButton(
            onPressed: () => Seller.instance.retrySync(),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
