import 'package:flutter/material.dart';
import 'design_system.dart';

/// Breakpoints. Phone is the base design; the rest widen it.
const _tablet = 700.0;

bool isWide(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= _tablet;

/// Widest a product card is allowed to get. Cards keep their size and the
/// grid simply fits more of them in — a card that grows with the monitor
/// reads as a billboard, which is what made the desktop view look wrong.
///
/// 168, not 230. At 230 a 375px phone fits two, and the pair carried enough
/// empty space inside them to look like placeholders. Three across is the
/// density every grocery app that works runs at, and it is what makes a
/// catalogue feel stocked rather than sparse.
/// Flutter's grid takes ceil(width / (max + spacing)) columns, so this is the
/// number that decides the count: at 335px of usable phone width with 14px
/// gutters, 150 gives three and 168 gives two.
const productTileMax = 150.0;

/// Height as a multiple of width. The card is a square picture plus about
/// four short lines, so it is meaningfully taller than it is wide — the old
/// 0.60 was tuned for a card carrying a 36px name block and a button row that
/// no longer exist.
const productTileAspect = 0.50;

/// Caps how wide the app content runs on a big monitor, and pads the sides
/// once there is room. Content still fills the width — this is a page, not
/// a phone in a frame.
class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: LamazonTheme.canvas,
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
