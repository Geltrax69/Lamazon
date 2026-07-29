import 'package:flutter/material.dart';

/// Breakpoints. Phone is the base design; the rest widen it.
const _tablet = 700.0;

bool isWide(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= _tablet;

/// Widest a product card is allowed to get. Cards keep their size and the
/// grid simply fits more of them in — a card that grows with the monitor
/// reads as a billboard, which is what made the desktop view look wrong.
const productTileMax = 230.0;

/// Caps how wide the app content runs on a big monitor, and pads the sides
/// once there is room. Content still fills the width — this is a page, not
/// a phone in a frame.
class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF1F1EF),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: child,
        ),
      ),
    );
  }
}

/// Forms and lists read badly when a text field is 1200px wide, so the
/// screens that are mostly reading and typing stay column-width.
class ReadableBody extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const ReadableBody({super.key, required this.child, this.maxWidth = 620});

  @override
  Widget build(BuildContext context) {
    // Align with heightFactor 1 rather than Center: inside a bottom bar a
    // Center would claim the whole height and squash the body to nothing.
    return Align(
      alignment: Alignment.topCenter,
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
