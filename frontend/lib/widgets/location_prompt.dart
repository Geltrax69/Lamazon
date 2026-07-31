import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/addresses.dart';
import '../data/geo.dart';
import '../screens/location_screen.dart';

const _ink = Color(0xFF1A1A1A);
const _green = Color(0xFF2E7D32);

/// Asks for a delivery location when the app has none: enable the device's
/// location, or type an address instead.
Future<void> showLocationPrompt(BuildContext context) =>
    showDialog(context: context, builder: (_) => const _LocationPromptDialog());

class _LocationPromptDialog extends StatefulWidget {
  const _LocationPromptDialog();

  @override
  State<_LocationPromptDialog> createState() => _LocationPromptDialogState();
}

class _LocationPromptDialogState extends State<_LocationPromptDialog> {
  bool _locating = false;
  GeoFix? _fix;
  String? _error;

  /// Asks the browser where we are, then shows what it said. Nothing is saved
  /// until the person confirms it — a wrong fix silently setting the delivery
  /// address is worse than no fix at all.
  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _error = null;
    });
    final fix = await Geo.instance.locate();
    if (!mounted) return;
    setState(() {
      _locating = false;
      _fix = fix;
      _error = fix == null
          ? 'Could not get your location. Allow it in your browser, or enter '
              'your address instead.'
          : null;
    });
  }

  void _useIt() {
    AddressBook.instance.enableLocation();
    Navigator.pop(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Delivering to ${serviceableCities.first}'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  /// What the browser found, in words rather than coordinates, with the
  /// accuracy shown so a vague fix looks vague.
  Widget _confirmCard(GeoFix fix) {
    final here = fix.onCampus;
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 24),
            Icon(
              here ? LucideIcons.mapPin : LucideIcons.mapPinOff,
              size: 34,
              color: here ? _green : const Color(0xFFD03A3A),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                here ? 'You look like you are here' : 'You are outside our area',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 26),
              child: Text(
                here
                    ? '${serviceableCities.first}\n'
                        '${fix.distanceLabel} from the centre of campus'
                    : 'We only deliver around ${serviceableCities.first}, '
                        'and you are ${fix.distanceLabel}.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  color: Color(0xFF6B6B6B),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Accurate to about ${fix.accuracyMetres.round()} m',
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF9A9A9A)),
            ),
            const SizedBox(height: 20),
            const Divider(height: 1, color: Color(0xFFEDEDEA)),
            if (here)
              _Action(label: 'Yes, deliver here', color: _green, onTap: _useIt),
            _Action(
              label: here ? 'No, pick another address' : 'Enter an address',
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_fix != null) return _confirmCard(_fix!);
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      // A dialog only pads its insets, so on a wide window it would run the
      // full width of the screen. Cap it at a card.
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
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
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 14, 28, 0),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: Color(0xFFD03A3A),
                  ),
                ),
              ),
            _Action(
              label: _locating
                  ? 'Finding you…'
                  : Geo.instance.supported
                      ? 'Use my current location'
                      : 'Enable device location',
              color: _green,
              onTap: () {
                if (_locating) return;
                if (Geo.instance.supported) {
                  _locate();
                  return;
                }
                AddressBook.instance.enableLocation();
                Navigator.pop(context);
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(
                      content: Text('Location on — add an address to start ordering'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 2),
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
