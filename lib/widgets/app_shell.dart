import 'package:flutter/material.dart';

/// Widest the app content is allowed to get. Past this the phone layout
/// stops looking like a design and starts looking like a stretched form.
const _maxContentWidth = 460.0;

/// On a phone this is a no-op. On a wide window it centres the app at phone
/// width against a plain backdrop, so desktop gets a deliberate layout
/// instead of full-bleed rows of stretched cards.
class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width <= _maxContentWidth + 40) return child;
    return ColoredBox(
      color: const Color(0xFFE4E4DF),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxContentWidth),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F1EF),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 30,
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
