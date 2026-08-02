import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/api.dart';
import '../data/staff.dart';
import '../widgets/app_shell.dart';

const _ink = Color(0xFF1A1A1A);
const _muted = Color(0xFF6B6B6B);
const _green = Color(0xFF1B7F3B);
const _red = Color(0xFFD32F2F);

/// The rider's panel, at /delivery. Sign in with the number an admin approved
/// and the PIN they were given; then: what is ready to collect, what is on
/// this run, and the four digits that close it.
class DeliveryScreen extends StatelessWidget {
  const DeliveryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: StaffSession.rider,
      builder: (context, _) => StaffSession.rider.signedIn
          ? const _DeliveryHome()
          : const _RiderLogin(),
    );
  }
}

class _RiderLogin extends StatefulWidget {
  const _RiderLogin();

  @override
  State<_RiderLogin> createState() => _RiderLoginState();
}

class _RiderLoginState extends State<_RiderLogin> {
  final _phone = TextEditingController();
  final _pin = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Api.instance.riderLogin(_phone.text.trim(), _pin.text.trim());
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('ClientException: ', ''));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F1EF),
      body: ReadableBody(
        maxWidth: 460,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(LucideIcons.bike, size: 40, color: _green),
                  const SizedBox(height: 16),
                  const Text(
                    'Lamazon delivery',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Only numbers an admin has approved can sign in here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: _muted),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: _boxed('Mobile number'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pin,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    onSubmitted: (_) => _signIn(),
                    decoration: _boxed('4-digit PIN'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!,
                        style: const TextStyle(fontSize: 12.5, color: _red)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _green,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                    ),
                    onPressed: _busy ? null : _signIn,
                    child: Text(_busy ? 'Signing in…' : 'Sign in'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _boxed(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      );
}

class _DeliveryHome extends StatefulWidget {
  const _DeliveryHome();

  @override
  State<_DeliveryHome> createState() => _DeliveryHomeState();
}

class _DeliveryHomeState extends State<_DeliveryHome> {
  Map<String, dynamic>? _panel;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final panel = await Api.instance.riderOrders();
      if (mounted) {
        setState(() {
          _panel = panel;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() =>
            _error = e.toString().replaceFirst('ClientException: ', ''));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pick(String id) async {
    try {
      await Api.instance.riderPick(id);
    } catch (e) {
      _say(e.toString().replaceFirst('ClientException: ', ''));
    }
    await _load();
  }

  /// The code is the hand-over. A wrong one changes nothing, which is why the
  /// error is worth showing plainly rather than as a failed request.
  Future<void> _deliver(String id) async {
    final code = TextEditingController();
    final typed = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Delivery code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Ask the customer for their 4 digits. The order only closes if '
              'they match.',
              style: TextStyle(fontSize: 13, color: _muted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: code,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: const InputDecoration(hintText: '0000'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _green),
            onPressed: () => Navigator.pop(dialog, code.text.trim()),
            child: const Text('Delivered'),
          ),
        ],
      ),
    );
    if (typed == null || typed.isEmpty) return;
    try {
      await Api.instance.riderDeliver(id, typed);
      _say('Delivered. The shop and the customer have been told.');
    } catch (e) {
      _say(e.toString().replaceFirst('ClientException: ', ''));
    }
    await _load();
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ));
  }

  @override
  Widget build(BuildContext context) {
    final rider = _panel?['rider'] as Map<String, dynamic>?;
    final orders = (_panel?['orders'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    final carrying = orders.where((o) => o['stage'] == 'picked').toList();
    final waiting = orders.where((o) => o['stage'] == 'accepted').toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F1EF),
      body: ReadableBody(
        maxWidth: 720,
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hello ${rider?['name']?.toString().isEmpty ?? true ? 'rider' : rider!['name']}',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            StaffSession.rider.subject,
                            style:
                                const TextStyle(fontSize: 12.5, color: _muted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh',
                      onPressed: _load,
                      icon: const Icon(LucideIcons.refreshCw, size: 18),
                    ),
                    TextButton(
                      onPressed: StaffSession.rider.signOut,
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _Tile(
                      label: 'On this run',
                      value: '${carrying.length}',
                      color: _green,
                    ),
                    const SizedBox(width: 10),
                    _Tile(label: 'Ready to collect', value: '${waiting.length}'),
                    const SizedBox(width: 10),
                    _Tile(
                      label: 'Delivered',
                      value: '${rider?['delivered'] ?? 0}',
                    ),
                  ],
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(_error!,
                        style: const TextStyle(color: _red, fontSize: 13)),
                  ),
                if (_loading && _panel == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                const SizedBox(height: 24),
                const _Heading('On this run'),
                if (carrying.isEmpty)
                  const _Empty('Nothing picked up yet.')
                else
                  for (final o in carrying)
                    _OrderCard(
                      order: o,
                      action: 'Delivered — enter code',
                      onAction: () => _deliver(o['id'] as String),
                    ),
                const SizedBox(height: 24),
                const _Heading('Ready to collect'),
                if (waiting.isEmpty)
                  const _Empty(
                    'Nothing right now. Orders land here on their own when a '
                    'shop accepts one — pull down to check again.',
                  )
                else
                  for (final o in waiting)
                    _OrderCard(
                      order: o,
                      action: 'Picked up',
                      onAction: () => _pick(o['id'] as String),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One order, with everything a rider needs and nothing they should not have:
/// the number, the shop, and who to hand it to. Never the delivery code.
class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final String action;
  final VoidCallback onAction;
  const _OrderCard({
    required this.order,
    required this.action,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Order No. #${(order['id'] as String).toUpperCase()}',
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              // An assigned order is yours whether or not you get there
              // first, and it is worth saying so.
              if ((order['assignedTo'] as String? ?? '').isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Yours',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: _green,
                    ),
                  ),
                ),
              Text(
                '₹${(order['amount'] as num).toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: _green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'From ${order['storeName']}',
            style: const TextStyle(fontSize: 12.5, color: _muted),
          ),
          const SizedBox(height: 8),
          Text(
            '${order['units']} × ${order['itemTitle']}',
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1),
          ),
          const Text(
            'Deliver to',
            style: TextStyle(fontSize: 11.5, color: _muted),
          ),
          const SizedBox(height: 2),
          Text(
            '${order['receiverName']}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          Text(
            '${order['receiverPhone']}',
            style: const TextStyle(fontSize: 13, color: _ink),
          ),
          Text(
            '${order['receiverAddress']}',
            style: const TextStyle(fontSize: 13, height: 1.35, color: _muted),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _green,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              onPressed: onAction,
              child: Text(action,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _Tile({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color ?? _ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: _muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  final String text;
  const _Heading(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      );
}

class _Empty extends StatelessWidget {
  final String text;
  const _Empty(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(text, style: const TextStyle(fontSize: 13, color: _muted)),
      );
}
