import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/api.dart';
import '../data/seller.dart';
import '../widgets/app_shell.dart';
import '../widgets/photo_manager.dart';
import '../widgets/product_card.dart';
import '../widgets/screen_header.dart';

const _ink = Color(0xFF1A1A1A);
const _muted = Color(0xFF6B6B6B);

/// One store's listings, so an admin can fix the pictures on any of them.
///
/// Scoped to a store rather than the whole catalogue: the reason to open this
/// is always "that shop's photos are wrong", and a list of every product on
/// the platform is not something anyone scrolls to find one.
class AdminPhotosScreen extends StatefulWidget {
  final String owner;
  final String storeName;
  const AdminPhotosScreen({
    super.key,
    required this.owner,
    required this.storeName,
  });

  @override
  State<AdminPhotosScreen> createState() => _AdminPhotosScreenState();
}

class _AdminPhotosScreenState extends State<AdminPhotosScreen> {
  List<InventoryItem> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await Api.instance.adminItems(widget.owner);
      if (mounted) {
        setState(() {
          _items = items;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e.toString().replaceFirst('ClientException: ', ''),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F1EF),
      body: ReadableBody(
        maxWidth: 760,
        child: SafeArea(
          child: Column(
            children: [
              ScreenHeader(title: widget.storeName),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                        children: [
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFFD32F2F),
                                ),
                              ),
                            ),
                          if (_items.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: Center(
                                child: Text(
                                  'This store has no products yet.',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    color: _muted,
                                  ),
                                ),
                              ),
                            )
                          else
                            for (final item in _items)
                              _ItemPhotos(item: item, onSaved: _load),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One product, folded shut. Opened, its photos are the same grid the seller
/// gets — drag to reorder, × to remove, add more — writing through the admin
/// routes instead of the seller ones.
class _ItemPhotos extends StatefulWidget {
  final InventoryItem item;
  final VoidCallback onSaved;
  const _ItemPhotos({required this.item, required this.onSaved});

  @override
  State<_ItemPhotos> createState() => _ItemPhotosState();
}

class _ItemPhotosState extends State<_ItemPhotos> {
  late List<Shot> _shots = [
    for (final u in widget.item.imageUrls) Shot.remote(u),
  ];
  bool _open = false;
  bool _busy = false;

  Future<void> _save(List<Shot> next) async {
    setState(() {
      _shots = next;
      _busy = true;
    });
    try {
      var urls = [
        for (final s in next)
          if (!s.isNew) s.url!,
      ];
      final fresh = [
        for (final s in next)
          if (s.isNew) s.bytes!,
      ];
      if (fresh.isNotEmpty) {
        final after = await Api.instance.addItemPhotos(
          widget.item.id,
          fresh,
          asAdmin: true,
        );
        urls = [...urls, ...after.where((u) => !urls.contains(u))];
      }
      final saved = await Api.instance.setItemPhotos(
        widget.item.id,
        urls,
        asAdmin: true,
      );
      widget.item.imageUrls = saved;
      if (mounted) {
        setState(() => _shots = [for (final u in saved) Shot.remote(u)]);
      }
      widget.onSaved();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceFirst('ClientException: ', '')),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: SizedBox(
                      width: 46,
                      height: 46,
                      child: NetImage(
                        url: _shots.isEmpty ? '' : (_shots.first.url ?? ''),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          // A listing with no picture is the one an admin
                          // opened this screen to fix, so it says so.
                          _shots.isEmpty
                              ? 'No photos'
                              : '${_shots.length} photo'
                                    '${_shots.length == 1 ? '' : 's'} · '
                                    '${widget.item.category}',
                          style: TextStyle(
                            fontSize: 12,
                            color: _shots.isEmpty
                                ? const Color(0xFFEF6C00)
                                : _muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _open ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                    size: 16,
                    color: _muted,
                  ),
                ],
              ),
            ),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
              child: PhotoManager(shots: _shots, busy: _busy, onChanged: _save),
            ),
        ],
      ),
    );
  }
}

/// The row an admin taps on a store card to get here.
class StorePhotosButton extends StatelessWidget {
  final String owner;
  final String storeName;
  const StorePhotosButton({
    super.key,
    required this.owner,
    required this.storeName,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AdminPhotosScreen(owner: owner, storeName: storeName),
        ),
      ),
      icon: const Icon(LucideIcons.images, size: 15),
      label: const Text('Photos'),
      style: TextButton.styleFrom(foregroundColor: _ink),
    );
  }
}
