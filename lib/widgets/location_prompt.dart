import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/addresses.dart';
import '../screens/location_screen.dart';

const _ink = Color(0xFF1A1A1A);
const _green = Color(0xFF2E7D32);

/// Asks for a delivery location when the app has none: enable the device's
/// location, or type an address instead.
Future<void> showLocationPrompt(BuildContext context) =>
    showDialog(context: context, builder: (_) => const _LocationPromptDialog());

class _LocationPromptDialog extends StatelessWidget {
  const _LocationPromptDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 28),
          const _SlashedPin(),
          const SizedBox(height: 22),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Location permission not enabled',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 28),
            child: Text(
              'Please enable location permission for a better delivery '
              'experience',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: Color(0xFF6B6B6B),
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Divider(height: 1, color: Color(0xFFEDEDEA)),
          _Action(
            label: 'Enable device location',
            color: _green,
            onTap: () {
              AddressBook.instance.enableLocation();
              Navigator.pop(context);
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text(
                      AddressBook.instance.selected == null
                          ? 'Location on — add an address to start ordering'
                          : 'Location on • delivering to '
                                '${AddressBook.instance.selected!.city}',
                    ),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ),
                );
            },
          ),
          const Divider(height: 1, color: Color(0xFFEDEDEA)),
          _Action(
            label: 'Select location manually',
            color: _ink,
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LocationScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Map pin struck through with a red bar — the "no location" mark.
class _SlashedPin extends StatelessWidget {
  const _SlashedPin();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(LucideIcons.mapPin, size: 84, color: _ink),
          Transform.rotate(
            angle: -0.72, // ~41°, corner to corner across the pin
            child: Container(
              width: 108,
              height: 9,
              decoration: BoxDecoration(
                color: const Color(0xFFE02B2B),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _Action({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 56,
        width: double.infinity,
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}
