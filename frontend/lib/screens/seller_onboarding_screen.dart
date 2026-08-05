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

/// Opens a seller's store: business name, photo, location, what they sell.
class SellerOnboardingScreen extends StatefulWidget {
  const SellerOnboardingScreen({super.key});

  @override
  State<SellerOnboardingScreen> createState() => _SellerOnboardingScreenState();
}

class _SellerOnboardingScreenState extends State<SellerOnboardingScreen> {
  final _name = TextEditingController();
  final _location = TextEditingController();
  final _city = TextEditingController(text: serviceableCities.first);
  final _picked = <String>{};
  Uint8List? _photo;

  /// A store signs up to departments, not to the categories inside them —
  /// this is what decides which tab the shop appears under.
  List<String> get _departmentNames =>
      [for (final d in departments) if (d.name != 'All') d.name];

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

  void _create() {
    Seller.instance.openStore(
      SellerStore(
        name: _name.text.trim(),
        photo: _photo,
        location: _location.text.trim(),
        city: _city.text.trim(),
        categories: _picked.toList(),
      ),
    );
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const SellerDashboardScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final blocker = _blocker;
    return Scaffold(
      backgroundColor: const Color(0xFFF1F1EF),
      body: ReadableBody(
        maxWidth: 620,
        child: SafeArea(
          child: Column(
            children: [
              const ScreenHeader(title: 'Open your store'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  children: [
                    const Text(
                      'Sell to everyone ordering on campus. Takes a minute.',
                      style: TextStyle(fontSize: 13.5, color: _muted),
                    ),
                    const SizedBox(height: 20),
                    const SellerSection(
                      title: 'Store photo',
                      hint: 'Your shopfront, counter or logo',
                    ),
                    PhotoTile(
                      photo: _photo,
                      emptyLabel: 'Upload store photo',
                      emptyHint: 'Tap to choose from your device',
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
                label: 'Create store',
                blocker: blocker,
                onSubmit: _create,
              ),
            ],
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
