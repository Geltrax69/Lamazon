import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/addresses.dart';
import '../data/seller.dart';
import '../widgets/product_card.dart';
import '../widgets/screen_header.dart';
import 'seller_dashboard_screen.dart';

const _ink = Color(0xFF1A1A1A);
const _muted = Color(0xFF6B6B6B);
const _green = Color(0xFF2E7D32);

/// Opens a seller's store: business name, image, location, what they sell.
class SellerOnboardingScreen extends StatefulWidget {
  const SellerOnboardingScreen({super.key});

  @override
  State<SellerOnboardingScreen> createState() => _SellerOnboardingScreenState();
}

class _SellerOnboardingScreenState extends State<SellerOnboardingScreen> {
  final _name = TextEditingController();
  final _image = TextEditingController();
  final _location = TextEditingController();
  final _city = TextEditingController(text: serviceableCities.first);
  final _picked = <String>{};

  @override
  void dispose() {
    _name.dispose();
    _image.dispose();
    _location.dispose();
    _city.dispose();
    super.dispose();
  }

  bool get _complete =>
      _name.text.trim().isNotEmpty &&
      _location.text.trim().isNotEmpty &&
      isServiceable(_city.text) &&
      _picked.isNotEmpty;

  void _create() {
    Seller.instance.openStore(SellerStore(
      name: _name.text.trim(),
      imageUrl: _image.text.trim().isEmpty ? _defaultStoreImage : _image.text.trim(),
      location: _location.text.trim(),
      city: _city.text.trim(),
      categories: _picked.toList(),
    ));
    Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => const SellerDashboardScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final image = _image.text.trim();
    return Scaffold(
      backgroundColor: const Color(0xFFF1F1EF),
      body: SafeArea(
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
                  const SizedBox(height: 18),
                  _Label('Business name'),
                  _Field(
                    controller: _name,
                    icon: LucideIcons.store,
                    hint: 'e.g. Campus Snacks Corner',
                    onChanged: () => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  _Label('Store image'),
                  _Field(
                    controller: _image,
                    icon: LucideIcons.image,
                    hint: 'Paste an image link (optional)',
                    onChanged: () => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      height: 130,
                      width: double.infinity,
                      child: NetImage(
                          url: image.isEmpty ? _defaultStoreImage : image),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Label('Store location'),
                  _Field(
                    controller: _location,
                    icon: LucideIcons.mapPin,
                    hint: 'Block / shop number, area',
                    onChanged: () => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  _Field(
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
                          fontSize: 12, color: Color(0xFFD32F2F)),
                    ),
                  ],
                  const SizedBox(height: 18),
                  _Label('What will you sell?'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in sellCategories)
                        GestureDetector(
                          onTap: () => setState(() =>
                              _picked.contains(c) ? _picked.remove(c) : _picked.add(c)),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: _picked.contains(c) ? _ink : Colors.white,
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Text(c,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _picked.contains(c)
                                      ? Colors.white
                                      : _ink,
                                )),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _green,
                    disabledBackgroundColor: const Color(0xFFDDDDD9),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28)),
                  ),
                  onPressed: _complete ? _create : null,
                  child: const Text('Create store',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _defaultStoreImage =
    'https://images.unsplash.com/photo-1441986300917-64674bd600d8?w=600';

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 8),
      child: Text(text,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final VoidCallback onChanged;
  final TextInputType? keyboard;
  final int maxLines;
  const _Field({
    required this.controller,
    required this.icon,
    required this.hint,
    required this.onChanged,
    this.keyboard,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Icon(icon, size: 18, color: _muted),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboard,
              maxLines: maxLines,
              onChanged: (_) => onChanged(),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hint,
                hintStyle: const TextStyle(color: Color(0xFF9A9A9A)),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
              style:
                  const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared by the product form so both screens look the same.
class SellerField extends StatelessWidget {
  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final VoidCallback onChanged;
  final TextInputType? keyboard;
  final int maxLines;
  const SellerField({
    super.key,
    required this.controller,
    required this.icon,
    required this.hint,
    required this.onChanged,
    this.keyboard,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) => _Field(
        controller: controller,
        icon: icon,
        hint: hint,
        onChanged: onChanged,
        keyboard: keyboard,
        maxLines: maxLines,
      );
}

/// Shared section label.
class SellerLabel extends StatelessWidget {
  final String text;
  const SellerLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => _Label(text);
}
