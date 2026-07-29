import 'package:flutter/material.dart';

/// Breakpoints. Phone is the base design; the rest widen it.
const _tablet = 700.0;
const _desktop = 1100.0;

bool isWide(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= _tablet;

/// How many product columns fit without the cards turning into postage
/// stamps or billboards.
int gridColumns(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  if (w >= 1500) return 5;
  if (w >= _desktop) return 4;
  if (w >= _tablet) return 3;
  return 2;
}

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
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
