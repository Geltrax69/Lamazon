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

class _SellerDashboardScreenState extends State<SellerDashboardScreen> {
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
                        const Text(
                          'Orders',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
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
                                style: TextStyle(fontSize: 13.5, color: _muted),
                              ),
                            ),
                          )
                        else
                          for (final order in Seller.instance.orders) ...[
                            _OrderRow(order: order),
                            const SizedBox(height: 10),
                          ],
                        const SizedBox(height: 22),
                        Text(
                          'Inventory (${items.length})',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
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
                                  style: TextStyle(fontSize: 15, color: _muted),
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
                        else
                          for (final item in items) ...[
                            _ItemRow(item: item),
                            const SizedBox(height: 10),
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
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SellerProductScreen()),
        ),
        icon: const Icon(LucideIcons.plus, size: 18),
        label: const Text(
          'Add product',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// One incoming order, with the single action it is waiting on.
class _OrderRow extends StatelessWidget {
  final SellerOrder order;
  const _OrderRow({required this.order});

  Color get _stageColor => switch (order.stage) {
    OrderStage.received => _amber,
    OrderStage.accepted => const Color(0xFF2F6FED),
    OrderStage.delivered => _green,
  };

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
              ],
            ),
          ),
          if (order.stage != OrderStage.delivered)
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: order.stage == OrderStage.received
                    ? _ink
                    : _green,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: () => order.stage == OrderStage.received
                  ? Seller.instance.acceptOrder(order.id)
                  : Seller.instance.deliverOrder(order.id),
              child: Text(
                order.stage == OrderStage.received ? 'Accept' : 'Delivered',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
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
