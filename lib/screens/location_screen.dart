import 'package:flutter/material.dart';

import '../widgets/app_shell.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/addresses.dart';

const _ink = Color(0xFF1A1A1A);
const _green = Color(0xFF2E7D32);
const _red = Color(0xFFD32F2F);

/// Enter a delivery location manually, check whether porters cover it, and
/// save it under Home / Office / Other.
class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  final _line = TextEditingController();
  final _city = TextEditingController();
  final _pin = TextEditingController();
  AddressLabel _label = AddressLabel.home;
  bool _checked = false;

  @override
  void dispose() {
    _line.dispose();
    _city.dispose();
    _pin.dispose();
    super.dispose();
  }

  bool get _serviceable => isServiceable(_city.text);
  bool get _complete =>
      _line.text.trim().isNotEmpty &&
      _city.text.trim().isNotEmpty &&
      _pin.text.trim().length >= 5;

  void _save() {
    final a = Address(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      label: _label,
      line: _line.text.trim(),
      city: _city.text.trim(),
      pincode: _pin.text.trim(),
    );
    AddressBook.instance.add(a);
    Navigator.pop(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Delivering to ${a.label.title} • ${a.city}'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F1EF),
      body: ReadableBody(
        maxWidth: 620,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          LucideIcons.arrowLeft,
                          size: 18,
                          color: _ink,
                        ),
                      ),
                    ),
                    const Text(
                      'Enter Location',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 46),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  children: [
                    _Field(
                      controller: _line,
                      hint: 'House / Flat, street, area',
                      icon: LucideIcons.house,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    _Field(
                      controller: _city,
                      hint: 'City',
                      icon: LucideIcons.building2,
                      onChanged: (_) => setState(() => _checked = false),
                    ),
                    const SizedBox(height: 12),
                    _Field(
                      controller: _pin,
                      hint: 'Pincode',
                      icon: LucideIcons.mapPin,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Save as',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        for (final l in AddressLabel.values) ...[
                          _LabelChip(
                            label: l,
                            selected: _label == l,
                            onTap: () => setState(() => _label = l),
                          ),
                          const SizedBox(width: 10),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Serviceability result.
                    if (_checked)
                      _serviceable
                          ? const _Banner(
                              icon: LucideIcons.circleCheck,
                              color: _green,
                              background: Color(0xFFE8F5E9),
                              title: 'We deliver here',
                              body: 'Porters reach this area in about 12 mins.',
                            )
                          : _Banner(
                              icon: LucideIcons.circleAlert,
                              color: _red,
                              background: const Color(0xFFFDECEA),
                              title: 'Not available in your location',
                              body:
                                  'We do not deliver to ${_city.text.trim()} yet. '
                                  'We currently serve '
                                  '${serviceableCities.join(", ")}.',
                            ),
                    if (_checked) const SizedBox(height: 16),
                    const Text(
                      'Where we deliver',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final c in serviceableCities)
                          GestureDetector(
                            onTap: () => setState(() {
                              _city.text = c;
                              _checked = false;
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Text(
                                c,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              // Check first, then save only if serviceable.
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: GestureDetector(
                  onTap: !_complete
                      ? null
                      : _checked && _serviceable
                      ? _save
                      : () => setState(() => _checked = true),
                  child: Container(
                    height: 54,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: !_complete
                          ? const Color(0xFFD8D8D4)
                          : _checked && !_serviceable
                          ? const Color(0xFFD8D8D4)
                          : _ink,
                      borderRadius: BorderRadius.circular(27),
                    ),
                    child: Text(
                      !_checked ? 'Check availability' : 'Save address',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: !_complete || (_checked && !_serviceable)
                            ? const Color(0xFF8A8A86)
                            : Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF9A9A9A)),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF9A9A9A),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LabelChip extends StatelessWidget {
  final AddressLabel label;
  final bool selected;
  final VoidCallback onTap;
  const _LabelChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  IconData get _icon => switch (label) {
    AddressLabel.home => LucideIcons.house,
    AddressLabel.office => LucideIcons.briefcase,
    AddressLabel.other => LucideIcons.mapPin,
  };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _ink : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(_icon, size: 15, color: selected ? Colors.white : _ink),
            const SizedBox(width: 6),
            Text(
              label.title,
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

class _Banner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color background;
  final String title;
  final String body;

  const _Banner({
    required this.icon,
    required this.color,
    required this.background,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: TextStyle(fontSize: 12, height: 1.4, color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
