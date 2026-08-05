import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../widgets/app_shell.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/addresses.dart';
import '../data/categories.dart';
import '../data/seller.dart';
import '../widgets/photo_picker.dart';
import '../widgets/screen_header.dart';
import '../widgets/seller_form.dart';
import 'seller_dashboard_screen.dart';

const _ink = Color(0xFF1A1A1A);
const _muted = Color(0xFF6B6B6B);
const _green = Color(0xFF2E7D32);

/// Opens a seller's store, or edits the one they have: business name, photo,
/// location, what they sell.
///
/// One screen for both, because they ask for exactly the same things and the
/// server upserts on the owner — a separate edit form would be the same
/// fields with a different set of bugs.
class SellerOnboardingScreen extends StatefulWidget {
  /// The store being changed, or null when opening the first one.
  final SellerStore? existing;
  const SellerOnboardingScreen({super.key, this.existing});

  @override
  State<SellerOnboardingScreen> createState() => _SellerOnboardingScreenState();
}

class _SellerOnboardingScreenState extends State<SellerOnboardingScreen> {
  // Editing starts from the store. Opening starts from whatever was left
  // behind last time, so coming back lands where you left.
  bool get _editing => widget.existing != null;

  late final _name = TextEditingController(
    text: widget.existing?.name ?? StoreDraft.name,
  );
  late final _location = TextEditingController(
    text: widget.existing?.location ?? StoreDraft.location,
  );
  late final _city = TextEditingController(
    text:
        widget.existing?.city ??
        (StoreDraft.city.isEmpty ? serviceableCities.first : StoreDraft.city),
  );
  late final _picked = <String>{
    ...?widget.existing?.categories,
    if (!_editing) ...StoreDraft.categories,
  };
  late Uint8List? _photo = widget.existing?.photo ?? StoreDraft.photo;

  /// A store signs up to departments, not to the categories inside them —
  /// this is what decides which tab the shop appears under.
  List<String> get _departmentNames => [
    for (final d in departments)
      if (d.name != 'All') d.name,
  ];

  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    _city.dispose();
    super.dispose();
  }

  /// What is still missing, so the button can say so instead of just sitting
  /// there greyed out.
  String? get _blocker {
    if (_name.text.trim().isEmpty) return 'Add your business name';
    if (_location.text.trim().isEmpty) return 'Add your store location';
    if (!isServiceable(_city.text)) {
      return 'We only deliver around ${serviceableCities.first}';
    }
    if (_picked.isEmpty) return 'Pick at least one category';
    return null;
  }

  void _saveDraft() {
    // A draft is for a store that does not exist yet. Editing one that does
    // has somewhere to put changes already, and stashing them here would
    // reappear as a phantom draft next time somebody opens a new store.
    if (_editing) return;
    StoreDraft.photo = _photo;
    StoreDraft.name = _name.text;
    StoreDraft.location = _location.text;
    StoreDraft.city = _city.text;
    StoreDraft.categories = {..._picked};
  }

  /// Leaving with something typed asks first. The photo is the expensive part
  /// — picking it again means going back to the camera roll — so "keep" is
  /// the default and discarding is the one you have to mean.
  Future<bool> _confirmLeave() async {
    _saveDraft();
    if (StoreDraft.isEmpty) return true;
    final keep = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Keep this for later?'),
        content: const Text(
          'Your photo and what you have filled in are still here. Keep them '
          'and they will be waiting when you come back.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text(
              'Discard',
              style: TextStyle(color: Color(0xFFD32F2F)),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Keep draft'),
          ),
        ],
      ),
    );
    // Dismissed without choosing: stay on the form rather than guessing.
    if (keep == null) return false;
    if (!keep) StoreDraft.clear();
    return true;
  }

  void _create() {
    // The form has become a store; there is nothing left to come back to.
    StoreDraft.clear();
    Seller.instance.openStore(
      SellerStore(
        name: _name.text.trim(),
        photo: _photo,
        location: _location.text.trim(),
        city: _city.text.trim(),
        categories: _picked.toList(),
        // Editing keeps the standing it already has. The server decides
        // anyway — it only sends a store back for review when it had been
        // rejected — but saying so here stops the screen flashing "pending"
        // at an approved shop in the meantime.
        status: widget.existing?.status ?? 'pending',
        rejectReason: widget.existing?.rejectReason ?? '',
      ),
    );
    if (_editing) {
      Navigator.pop(context);
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const SellerDashboardScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final blocker = _blocker;
    return PopScope(
      // The system back gesture has to ask the same question the arrow does,
      // or half the ways out of this screen still lose the photo.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmLeave() && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F1EF),
        body: ReadableBody(
          maxWidth: 620,
          child: SafeArea(
            child: Column(
              children: [
                ScreenHeader(
                  title: _editing ? 'Edit store' : 'Open your store',
                  onBack: _confirmLeave,
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    children: [
                      Text(
                        _editing
                            ? 'Changes show on your store page and to shoppers.'
                            : 'Sell to everyone ordering on campus. Takes a '
                                  'minute.',
                        style: const TextStyle(fontSize: 13.5, color: _muted),
                      ),
                      const SizedBox(height: 20),
                      const SellerSection(
                        title: 'Store photo',
                        hint: 'Your shopfront, counter or logo',
                      ),
                      PhotoTile(
                        photo: _photo,
                        emptyLabel: 'Upload store photo',
                        emptyHint: 'Tap to choose, then frame it',
                        // The shape the dashboard and the store card show it
                        // in, so the crop is the picture shoppers get.
                        aspect: 16 / 9,
                        onChanged: (p) => setState(() => _photo = p),
                      ),
                      const SizedBox(height: 22),
                      const SellerSection(title: 'Business name'),
                      SellerField(
                        controller: _name,
                        icon: LucideIcons.store,
                        hint: 'e.g. Campus Snacks Corner',
                        onChanged: () => setState(() {}),
                      ),
                      const SizedBox(height: 22),
                      const SellerSection(
                        title: 'Store location',
                        hint: 'Where buyers collect or you hand over',
                      ),
                      SellerField(
                        controller: _location,
                        icon: LucideIcons.mapPin,
                        hint: 'Block / shop number, area',
                        onChanged: () => setState(() {}),
                      ),
                      const SizedBox(height: 10),
                      SellerField(
                        controller: _city,
                        icon: LucideIcons.building2,
                        hint: 'Campus / city',
                        onChanged: () => setState(() {}),
                      ),
                      if (_city.text.trim().isNotEmpty &&
                          !isServiceable(_city.text)) ...[
                        const SizedBox(height: 8),
                        Text(
                          'We only deliver around ${serviceableCities.first} today.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFD32F2F),
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      const SellerSection(
                        title: 'What will you sell?',
                        hint: 'Pick every category that applies',
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final c in _departmentNames)
                            _CategoryChip(
                              label: c,
                              selected: _picked.contains(c),
                              onTap: () => setState(
                                () => _picked.contains(c)
                                    ? _picked.remove(c)
                                    : _picked.add(c),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                SellerSubmitBar(
                  label: _editing ? 'Save changes' : 'Create store',
                  blocker: blocker,
                  onSubmit: _create,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Selectable pill with a tick once it is on.
class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _green : Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(LucideIcons.check, size: 14, color: Colors.white),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : _ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
