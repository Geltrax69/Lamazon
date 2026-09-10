import '../widgets/design_system.dart';
import '../widgets/screen_header.dart';
import 'addresses_screen.dart';
import 'order_confirmation_screen.dart';
import '../data/money.dart';
import '../widgets/app_nav.dart';
import 'package:flutter/material.dart';

import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/addresses.dart';
import '../data/cart.dart';
import '../data/orders.dart';
import '../data/session.dart';
import '../widgets/product_card.dart';
import 'location_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  @override
  void initState() {
    super.initState();
    // A basket left open in a background tab can outlive the stock it holds.
    // Correcting it here means the shopper sees the change with the items in
    // front of them, rather than being refused at "Place order".
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final trimmed = Cart.instance.reconcile();
      if (trimmed.isEmpty || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            trimmed.length == 1
                ? 'Only some of "${trimmed.first}" is left — '
                      'we reduced it to what the shop has.'
                : 'Some items ran low. We reduced them to what the shop has.',
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final cart = Cart.instance;
    return Scaffold(
      bottomNavigationBar: const AppBottomNav(current: AppTab.cart),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const ScreenHeader(title: 'My Cart'),
            Expanded(
              child: ListenableBuilder(
                listenable: cart,
                builder: (context, _) {
                  if (cart.isEmpty) return const _EmptyCart();
                  final summary = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _DeliveryAddress(),
                      const SizedBox(height: 16),
                      const ElevatedSurface(
                        child: ListTile(
                          contentPadding: EdgeInsets.all(16),
                          leading: Icon(LucideIcons.banknote),
                          title: Text('Cash on delivery'),
                          subtitle: Text(
                            'Pay the rider on arrival. Online payments are not available.',
                          ),
                          trailing: Icon(
                            LucideIcons.circleCheck,
                            color: LamazonTheme.strong,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _CheckoutPanel(cart: cart),
                    ],
                  );
                  return LayoutBuilder(
                    builder: (context, c) {
                      final lines = [
                        Text(
                          '${cart.count} ${cart.count == 1 ? 'item' : 'items'}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        for (final item in cart.items)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _CartRow(item: item),
                          ),
                      ];
                      if (c.maxWidth >= 900) {
                        return SingleChildScrollView(
                          padding: const EdgeInsets.all(32),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 6,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: lines,
                                ),
                              ),
                              const SizedBox(width: 32),
                              Expanded(flex: 4, child: summary),
                            ],
                          ),
                        );
                      }
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                        children: [
                          ...lines,
                          const SizedBox(height: 12),
                          summary,
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeliveryAddress extends StatelessWidget {
  const _DeliveryAddress();
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: AddressBook.instance,
    builder: (context, _) {
      final a =
          AddressBook.instance.selected ??
          AddressBook.instance.addresses.firstOrNull;
      return ElevatedSurface(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Icon(LucideIcons.mapPin, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Deliver to',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AddressesScreen(),
                      ),
                    ),
                    child: Text(a == null ? 'Add address' : 'Change'),
                  ),
                ],
              ),
              if (a != null) ...[
                Text(
                  a.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '${a.line}, ${a.city} ${a.pincode}',
                  style: const TextStyle(color: LamazonTheme.muted),
                ),
                if (a.phone.isNotEmpty)
                  Text(
                    a.phone,
                    style: const TextStyle(color: LamazonTheme.muted),
                  ),
              ] else
                const Text(
                  'Choose a delivery address before placing your order.',
                  style: TextStyle(color: LamazonTheme.muted),
                ),
            ],
          ),
        ),
      );
    },
  );
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: LucideIcons.shoppingBasket,
      title: 'Your cart is empty',
      message: 'Find something you love from stores near you.',
      action: 'Start shopping',
      // pushNamedAndRemoveUntil, not popUntil: popping left the browser
      // address bar reading /cart while home was on screen, and dropped the
      // shopper back at whatever mid-page scroll position they had left. From
      // an empty cart, "Start shopping" should mean the top of the shop.
      onAction: () =>
          Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false),
    );
  }
}

/// Swipe left to remove, like the reference design.
class _CartRow extends StatelessWidget {
  final CartItem item;
  const _CartRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final p = item.product;
    return Dismissible(
      key: ValueKey(p.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _removeWithUndo(context, p.id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          // Derived from the token, so the swipe-to-delete tint cannot drift
          // away from the colour of the icon sitting on it.
          color: LamazonTheme.danger.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(LamazonTheme.featuredRadius),
        ),
        child: const Icon(
          LucideIcons.trash2,
          color: LamazonTheme.danger,
          size: 22,
        ),
      ),
      child: ElevatedSurface(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 88,
                      height: 88,
                      child: NetImage(url: p.imageUrl, semanticLabel: p.name),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.store,
                          style: const TextStyle(
                            fontSize: 12,
                            color: LamazonTheme.muted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          p.name,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (p.discounted)
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'MRP ₹${(p.mrp * item.qty).moneyText}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: LamazonTheme.muted,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                              DiscountBadge(percent: p.discountPercent),
                            ],
                          ),
                        Text(
                          '₹${(p.price * item.qty).moneyText}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const TrackDivider(),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '₹${p.price.moneyText} each',
                      style: const TextStyle(
                        fontSize: 12,
                        color: LamazonTheme.muted,
                      ),
                    ),
                  ),
                  _QtyControls(item: item),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QtyControls extends StatelessWidget {
  final CartItem item;
  const _QtyControls({required this.item});

  @override
  Widget build(BuildContext context) {
    final last = item.qty <= 1;
    final atCap = Cart.instance.atCap(item.product);
    return Row(
      children: [
        // Going below one removes the line, so at one the button says so —
        // swiping the row away is not discoverable with a mouse.
        _qtyBtn(
          last ? LucideIcons.trash2 : LucideIcons.minus,
          () => last
              ? _removeWithUndo(context, item.product.id)
              : Cart.instance.setQty(item.product.id, item.qty - 1),
          filled: false,
          danger: last,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            // Not padLeft(2, '0'): "05" reads as a code, not a count.
            '${item.qty}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
        _qtyBtn(
          LucideIcons.plus,
          atCap
              ? null
              : () => Cart.instance.setQty(item.product.id, item.qty + 1),
          filled: true,
          // Says why, rather than leaving a dead grey button.
          label: atCap
              ? 'That is all the shop has'
              : 'Increase quantity',
        ),
      ],
    );
  }

  Widget _qtyBtn(
    IconData icon,
    VoidCallback? onTap, {
    required bool filled,
    bool danger = false,
    String? label,
  }) {
    return TactileIconButton(
      label:
          label ??
          (danger
              ? 'Remove item'
              : filled
              ? 'Increase quantity'
              : 'Decrease quantity'),
      onPressed: onTap,
      icon: icon,
      // LamazonTheme.touch, not 38: WCAG 2.5.8 and Material both put the
      // floor at 44, and these are the most-tapped controls in the app.
      size: LamazonTheme.touch,
      selected: filled,
      foreground: danger ? LamazonTheme.danger : LamazonTheme.strong,
    );
  }
}

/// Removing a line is one tap and used to be unrecoverable — the last item
/// took the whole basket with it. Undo costs nothing and is worth more here
/// than a confirmation dialog would be.
void _removeWithUndo(BuildContext context, String id) {
  final gone = Cart.instance.remove(id);
  if (gone == null) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Removed ${gone.product.name}'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => Cart.instance.putBack(gone),
        ),
      ),
    );
}

class _CheckoutPanel extends StatefulWidget {
  final Cart cart;
  const _CheckoutPanel({required this.cart});

  @override
  State<_CheckoutPanel> createState() => _CheckoutPanelState();
}

class _CheckoutPanelState extends State<_CheckoutPanel> {
  bool _placing = false;

  Cart get cart => widget.cart;

  /// Placing the order is the point at which the app stops being a browse
  /// and starts owing someone a delivery, so everything it needs is checked
  /// first: signed in, an address to deliver to, and lines a real shop
  /// actually stocks.
  Future<void> _placeOrder() async {
    if (!Session.instance.loggedIn) {
      // The button already says "Sign in to place order", so this is the
      // step the shopper asked for, not a refusal. Named, not constructed:
      // importing LoginScreen here would close a cycle back through home.
      await Navigator.pushNamed(context, AppRoutes.login);
      return;
    }
    // Whatever they picked, or the default — the server lists that one first.
    final address =
        AddressBook.instance.selected ??
        AddressBook.instance.addresses.firstOrNull;
    if (address == null) {
      _say('Add a delivery address first.');
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LocationScreen()),
      );
      return;
    }

    // Snapshot the submitted quantities: edits while the request is running
    // must neither place extra items nor remove newly added quantities.
    final lines = [
      for (final line in cart.items) (itemId: line.product.id, qty: line.qty),
    ];
    final expectedTotal = cart.total;
    final requestId = cart.checkoutRequestId;
    if (lines.isEmpty) return;
    setState(() => _placing = true);
    try {
      await cart.savedToStorage;
      final placed = await MyOrders.instance.place(
        lines,
        addressId: address.id,
        requestId: requestId,
        expectedTotal: expectedTotal,
      );
      for (final line in lines) {
        final remaining = cart.items
            .where((item) => item.product.id == line.itemId)
            .firstOrNull;
        if (remaining != null) {
          cart.setQty(line.itemId, remaining.qty - line.qty);
        }
      }
      await cart.savedToStorage;
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OrderConfirmationScreen(orders: placed),
        ),
      );
    } catch (e) {
      if (mounted) _say(e.toString().replaceFirst('ClientException: ', ''));
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  void _say(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedSurface(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SectionHeading(title: 'Order Summary'),
          const SizedBox(height: 12),
          _summaryRow(
            cart.count == 1
                ? 'Sub Total (1 item)'
                : 'Sub Total (${cart.count} items)',
            cart.subtotal,
          ),
          const SizedBox(height: 4),
          _summaryRow('Delivery', cart.shipping),
          const SizedBox(height: 2),
          // The number people actually want, which the API has been
          // returning all along while no screen showed it.
          Row(
            children: [
              const Icon(
                LucideIcons.clock,
                size: 13,
                color: LamazonTheme.muted,
              ),
              const SizedBox(width: 6),
              // Flexible: at 320px with text scaled to 1.3 an unconstrained
              // Text in a Row runs straight off the edge.
              Flexible(
                child: Text(
                  'Arrives in about $deliveryEta',
                  style: LamazonTheme.mutedBodyText,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: TrackDivider(),
          ),
          _summaryRow('Total', cart.total, bold: true),
          // Below the total, not inside it: the subtotal is already the
          // discounted price, so showing this as a deduction would look like
          // it comes off again.
          if (cart.saved > 0) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  LucideIcons.badgePercent,
                  size: 14,
                  color: LamazonTheme.strong,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'You saved ₹${cart.saved.moneyText} on this order',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: LamazonTheme.strong,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          // A guest reaches this button with a full cart and an address
          // filled in, and it used to promise an order it could not place —
          // one tap, one disappearing toast, no way forward. It names the
          // step that is actually next instead.
          ListenableBuilder(
            listenable: Session.instance,
            builder: (context, _) => SizedBox(
              width: double.infinity,
              child: ActionButton(
                onPressed: _placing ? null : _placeOrder,
                expand: true,
                loading: _placing,
                label: _placing
                    ? 'Placing your order…'
                    : Session.instance.loggedIn
                    ? 'Place order  ·  ₹${cart.total.moneyText}'
                    : 'Sign in to place order',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, double value, {bool bold = false}) {
    final style = TextStyle(
      fontSize: bold ? 15 : 13,
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      color: bold ? LamazonTheme.text : LamazonTheme.muted,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(label, style: style)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            '₹${value.moneyText}',
            style: style,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
