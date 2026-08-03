import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/api.dart';
import '../data/staff.dart';
import '../widgets/app_shell.dart';

const _ink = Color(0xFF1A1A1A);
const _muted = Color(0xFF6B6B6B);
const _green = Color(0xFF2E7D32);
const _amber = Color(0xFFEF6C00);
const _red = Color(0xFFD32F2F);

/// The admin panel, at /admin/log_IN. Password in, and then the three things
/// an admin actually does: see who is here, decide which stores go live, and
/// hand out delivery numbers.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: StaffSession.admin,
      builder: (context, _) => StaffSession.admin.signedIn
          ? const _AdminHome()
          : const _AdminLogin(),
    );
  }
}

class _AdminLogin extends StatefulWidget {
  const _AdminLogin();

  @override
  State<_AdminLogin> createState() => _AdminLoginState();
}

class _AdminLoginState extends State<_AdminLogin> {
  final _user = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _user.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Api.instance.adminLogin(_user.text.trim(), _password.text);
    } catch (e) {
      // The server says "wrong username or password" and nothing more, on
      // purpose — repeat it rather than guessing which half was wrong.
      setState(
        () => _error = e.toString().replaceFirst('ClientException: ', ''),
      );
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
                  const Icon(LucideIcons.shieldCheck, size: 40, color: _ink),
                  const SizedBox(height: 16),
                  const Text(
                    'Lamazon admin',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Staff only. Sellers and riders sign in elsewhere.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: _muted),
                  ),
                  const SizedBox(height: 24),
                  _Field(controller: _user, label: 'Username'),
                  const SizedBox(height: 12),
                  _Field(
                    controller: _password,
                    label: 'Password',
                    obscure: true,
                    onSubmit: _signIn,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(fontSize: 12.5, color: _red),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _ink,
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
}

class _AdminHome extends StatefulWidget {
  const _AdminHome();

  @override
  State<_AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<_AdminHome> {
  Map<String, dynamic>? _overview;
  List<dynamic> _stores = const [];
  List<dynamic> _riders = const [];
  List<dynamic> _orders = const [];
  _Tab _tab = _Tab.review;
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
      final overview = await Api.instance.adminOverview();
      final stores = await Api.instance.adminStores();
      final riders = await Api.instance.riders();
      final orders = await Api.instance.adminOrders();
      if (!mounted) return;
      setState(() {
        _overview = overview;
        _stores = stores;
        _riders = riders;
        _orders = orders;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e.toString().replaceFirst('ClientException: ', ''),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _approve(String owner) async {
    await Api.instance.approveStore(owner);
    await _load();
  }

  Future<void> _reject(String owner) async {
    final reason = TextEditingController();
    final given = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Why is this store not approved?'),
        content: TextField(
          controller: reason,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'The seller sees this, so make it actionable',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _red),
            onPressed: () => Navigator.pop(dialog, reason.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (given == null || given.isEmpty) return;
    await Api.instance.rejectStore(owner, given);
    await _load();
  }

  /// The PIN exists for exactly one moment — this dialog. It is not stored in
  /// readable form anywhere, so an admin who closes this hands out a new one.
  Future<void> _addRider() async {
    final phone = TextEditingController();
    final name = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Add a delivery number'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: phone,
              autofocus: true,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Mobile number'),
            ),
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final pin = await Api.instance.addRider(phone.text, name.text);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Give them this PIN'),
          content: Text(
            '$pin\n\nThey sign in at /delivery with their number and this PIN. '
            'It is shown once — adding the number again issues a new one.',
            style: const TextStyle(fontSize: 15, height: 1.5),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('ClientException: ', '')),
          ),
        );
    }
  }

  /// Orders hand themselves to a rider when the shop accepts them, so this is
  /// the exception: the rider who did not turn up. Only orders nobody has
  /// picked up can be moved — after that the bag is physically with someone
  /// and the database says so.
  Future<void> _assign(Map<String, dynamic> order) async {
    final active = _riders.where((r) => r['active'] == true).toList();
    if (active.isEmpty) {
      _say('Add a delivery number first.');
      return;
    }
    final chosen = await showDialog<String>(
      context: context,
      builder: (dialog) => SimpleDialog(
        title: Text('Who takes #${(order['id'] as String).toUpperCase()}?'),
        children: [
          for (final r in active)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialog, r['phone'] as String),
              child: Text(
                '${(r['name'] as String?)?.isEmpty ?? true ? 'Rider' : r['name']} · '
                '${r['phone']}  (${r['carrying']} carrying)',
              ),
            ),
          const Divider(),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialog, ''),
            child: const Text('Leave it open to any rider'),
          ),
        ],
      ),
    );
    if (chosen == null) return;
    try {
      await Api.instance.assignOrder(order['id'] as String, chosen);
    } catch (e) {
      _say(e.toString().replaceFirst('ClientException: ', ''));
    }
    await _load();
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  @override
  Widget build(BuildContext context) {
    final o = _overview;
    final counts = _counts();
    return Scaffold(
      backgroundColor: const Color(0xFFF1F1EF),
      body: ReadableBody(
        maxWidth: 820,
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Admin',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh',
                      onPressed: _load,
                      icon: const Icon(LucideIcons.refreshCw, size: 18),
                    ),
                    TextButton(
                      onPressed: StaffSession.admin.signOut,
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: _red, fontSize: 13),
                    ),
                  ),
                if (_loading && o == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (o != null) ...[
                  // The numbers are also the way in: tapping one opens the
                  // list behind it, so a count is never a dead end.
                  Row(
                    children: [
                      _Tile(
                        label: 'People',
                        value: '${o['users']}',
                        onTap: () => _show(_Tab.people),
                      ),
                      const SizedBox(width: 10),
                      _Tile(
                        label: 'Sellers',
                        value: '${o['sellers']}',
                        onTap: () => _show(_Tab.approved),
                      ),
                      const SizedBox(width: 10),
                      _Tile(
                        label: 'To review',
                        value: '${counts[_Tab.review]}',
                        color: counts[_Tab.review]! > 0 ? _amber : null,
                        onTap: () => _show(_Tab.review),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _Tile(
                        label: 'Riders',
                        value: '${o['riders']}',
                        onTap: () => _show(_Tab.delivery),
                      ),
                      const SizedBox(width: 10),
                      _Tile(
                        label: 'Orders',
                        value: '${o['orders']}',
                        onTap: () => _show(_Tab.orders),
                      ),
                      const SizedBox(width: 10),
                      _Tile(
                        label: 'Rejected',
                        value: '${counts[_Tab.rejected]}',
                        onTap: () => _show(_Tab.rejected),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 22),
                // One list at a time. Six sections stacked down one page meant
                // scrolling past everything to reach anything.
                SizedBox(
                  height: 38,
                  child: ListView(
                    key: const PageStorageKey('admin-tabs'),
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final tab in _Tab.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _Pill(
                            label: '${tab.label} (${counts[tab]})',
                            selected: _tab == tab,
                            onTap: () => _show(tab),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ..._section(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _show(_Tab tab) => setState(() => _tab = tab);

  List<Map<String, dynamic>> _storesWith(String status) => _stores
      .cast<Map<String, dynamic>>()
      .where((s) => s['status'] == status)
      .toList();

  Map<_Tab, int> _counts() => {
    _Tab.review: _storesWith('pending').length,
    _Tab.approved: _storesWith('approved').length,
    _Tab.rejected: _storesWith('rejected').length,
    _Tab.orders: _orders.length,
    _Tab.delivery: _riders.length,
    _Tab.people: (_overview?['people'] as List?)?.length ?? 0,
  };

  /// What the chosen button shows. Each branch is one list plus the line of
  /// context it needs — the rules that are not visible in the rows themselves.
  List<Widget> _section() {
    switch (_tab) {
      case _Tab.review:
        final pending = _storesWith('pending');
        return [
          const _Note(
            'A store stays invisible to shoppers, and its owner '
            'cannot add stock, until it is approved here.',
          ),
          if (pending.isEmpty)
            const _Empty('Nothing waiting. Every store has been looked at.')
          else
            for (final s in pending)
              _StoreCard(
                store: s,
                onApprove: () => _approve(s['owner'] as String),
                onReject: () => _reject(s['owner'] as String),
              ),
        ];

      case _Tab.approved:
        final live = _storesWith('approved');
        return [
          const _Note('Live on the shop page and taking orders.'),
          if (live.isEmpty)
            const _Empty('No approved stores yet.')
          else
            for (final s in live)
              _StoreCard(
                store: s,
                onReject: () => _reject(s['owner'] as String),
              ),
        ];

      case _Tab.rejected:
        final out = _storesWith('rejected');
        return [
          const _Note(
            'The seller sees the reason and can edit their store to '
            'send it back for another look.',
          ),
          if (out.isEmpty)
            const _Empty('Nothing rejected.')
          else
            for (final s in out)
              _StoreCard(
                store: s,
                onApprove: () => _approve(s['owner'] as String),
              ),
        ];

      case _Tab.orders:
        return [
          const _Note(
            'Accepted orders go to a rider automatically — whoever '
            'is carrying the least, picked at random between equals. '
            'Reassign only when someone does not turn up.',
          ),
          if (_orders.isEmpty)
            const _Empty('No orders yet.')
          else
            for (final ord in _orders.cast<Map<String, dynamic>>())
              _AdminOrderRow(
                order: ord,
                riders: _riders,
                onAssign: () => _assign(ord),
              ),
        ];

      case _Tab.delivery:
        return [
          Row(
            children: [
              const Expanded(
                child: _Note(
                  'Riders sign in at /delivery with their number '
                  'and the PIN issued when you add them.',
                ),
              ),
              TextButton.icon(
                onPressed: _addRider,
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Text('Add number'),
              ),
            ],
          ),
          if (_riders.isEmpty)
            const _Empty('No delivery numbers yet.')
          else
            for (final r in _riders.cast<Map<String, dynamic>>())
              _RiderRow(
                rider: r,
                onRemove: () async {
                  await Api.instance.removeRider(r['phone'] as String);
                  await _load();
                },
              ),
        ];

      case _Tab.people:
        final people = (_overview?['people'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>();
        return [
          const _Note(
            'Everyone who has signed in. Selling is not a setting — '
            'it follows from owning a store.',
          ),
          if (people.isEmpty)
            const _Empty('Nobody has signed in yet.')
          else
            for (final p in people) _PersonRow(person: p),
        ];
    }
  }
}

/// The sections of the panel, in the order they matter: what needs a decision
/// first, then what has been decided, then the day-to-day.
enum _Tab {
  review('To review'),
  approved('Approved'),
  rejected('Rejected'),
  orders('Orders'),
  delivery('Delivery'),
  people('People');

  final String label;
  const _Tab(this.label);
}

class _Pill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _ink : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : _muted,
          ),
        ),
      ),
    );
  }
}

class _StoreCard extends StatelessWidget {
  final Map<String, dynamic> store;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  const _StoreCard({required this.store, this.onApprove, this.onReject});

  Color get _colour => switch (store['status']) {
    'approved' => _green,
    'rejected' => _red,
    _ => _amber,
  };

  @override
  Widget build(BuildContext context) {
    final categories = (store['categories'] as List<dynamic>? ?? const []).join(
      ', ',
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
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
                  store['name'] as String? ?? '',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _colour.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${store['status']}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _colour,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${store['owner']} · ${store['phone'] ?? ''}',
            style: const TextStyle(fontSize: 12, color: _muted),
          ),
          Text(
            '${store['location']}, ${store['city']} · $categories · '
            '${store['items']} products',
            style: const TextStyle(fontSize: 12, color: _muted),
          ),
          if ((store['rejectReason'] as String? ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Reason: ${store['rejectReason']}',
                style: const TextStyle(fontSize: 12, color: _red),
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (onApprove != null)
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: _green),
                  onPressed: onApprove,
                  child: const Text('Approve'),
                ),
              const SizedBox(width: 10),
              if (onReject != null)
                OutlinedButton(
                  onPressed: onReject,
                  child: const Text('Reject', style: TextStyle(color: _red)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One order with its stage and whoever is carrying it. Assigning is only
/// offered while it can still change hands.
class _AdminOrderRow extends StatelessWidget {
  final Map<String, dynamic> order;
  final List<dynamic> riders;
  final VoidCallback onAssign;
  const _AdminOrderRow({
    required this.order,
    required this.riders,
    required this.onAssign,
  });

  Color get _colour => switch (order['stage']) {
    'delivered' => _green,
    'rejected' => _red,
    'picked' => const Color(0xFF6A1B9A),
    'accepted' => const Color(0xFF2F6FED),
    _ => _amber,
  };

  String _nameOf(String phone) {
    if (phone.isEmpty) return '';
    final match = riders
        .cast<Map<String, dynamic>>()
        .where((r) => r['phone'] == phone)
        .firstOrNull;
    final name = match?['name'] as String? ?? '';
    return name.isEmpty ? phone : '$name · $phone';
  }

  @override
  Widget build(BuildContext context) {
    final stage = order['stage'] as String;
    final carrier = order['riderPhone'] as String? ?? '';
    final assigned = order['assignedTo'] as String? ?? '';
    final canAssign = stage == 'received' || stage == 'accepted';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '#${(order['id'] as String).toUpperCase()} · '
                  '${order['units']} × ${order['itemTitle']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _colour.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  stage,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _colour,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            '${order['storeName']} → ${order['receiverName']} · '
            '${order['receiverPhone']}',
            style: const TextStyle(fontSize: 12, color: _muted),
          ),
          Text(
            '${order['receiverAddress']}',
            style: const TextStyle(fontSize: 11.5, color: _muted),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  carrier.isNotEmpty
                      ? 'Carried by ${_nameOf(carrier)}'
                      : assigned.isNotEmpty
                      ? 'Assigned to ${_nameOf(assigned)}'
                      : 'Open to any rider',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: assigned.isEmpty && carrier.isEmpty ? _muted : _ink,
                  ),
                ),
              ),
              if (canAssign)
                TextButton(
                  onPressed: onAssign,
                  child: Text(assigned.isEmpty ? 'Assign rider' : 'Reassign'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RiderRow extends StatelessWidget {
  final Map<String, dynamic> rider;
  final VoidCallback onRemove;
  const _RiderRow({required this.rider, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final active = rider['active'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${rider['name']?.toString().isEmpty ?? true ? 'Rider' : rider['name']} · ${rider['phone']}',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${rider['delivered']} delivered · ${rider['carrying']} carrying'
                  '${active ? '' : ' · switched off'}',
                  style: const TextStyle(fontSize: 12, color: _muted),
                ),
              ],
            ),
          ),
          if (active)
            IconButton(
              tooltip: 'Switch off',
              onPressed: onRemove,
              icon: const Icon(LucideIcons.userX, size: 18, color: _red),
            ),
        ],
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  final Map<String, dynamic> person;
  const _PersonRow({required this.person});

  @override
  Widget build(BuildContext context) {
    final store = person['storeName'] as String? ?? '';
    final seller = store.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The badge sits on the same line as the address but cannot be
          // pushed into it: a long address wraps inside its own half.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  person['email'] as String? ?? '',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (seller ? _green : _muted).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  seller ? 'Buyer + Seller' : 'Buyer',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: seller ? _green : _muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            [
              person['id'],
              if ((person['name'] as String? ?? '').isNotEmpty) person['name'],
              if ((person['phone'] as String? ?? '').isNotEmpty)
                person['phone'],
              if (seller) '$store (${person['storeStatus']})',
            ].join(' · '),
            style: const TextStyle(fontSize: 11.5, color: _muted),
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
  final VoidCallback? onTap;
  const _Tile({
    required this.label,
    required this.value,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
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
      ),
    );
  }
}

class _Note extends StatelessWidget {
  final String text;
  const _Note(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: const TextStyle(fontSize: 12, height: 1.4, color: _muted),
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

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final VoidCallback? onSubmit;
  const _Field({
    required this.controller,
    required this.label,
    this.obscure = false,
    this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      onSubmitted: onSubmit == null ? null : (_) => onSubmit!(),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
