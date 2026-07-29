import 'package:flutter/material.dart';

import 'product_card.dart';

/// One row of widgets drifting sideways forever, looping seamlessly.
/// Used for the login backdrop and the running store ads on home.
class MarqueeStrip extends StatefulWidget {
  final List<Widget> children;
  final double itemWidth; // including the gap after each item
  final Duration period; // time for one full pass
  final bool reverse;
  const MarqueeStrip({
    super.key,
    required this.children,
    required this.itemWidth,
    this.period = const Duration(seconds: 40),
    this.reverse = false,
  });

  @override
  State<MarqueeStrip> createState() => _MarqueeStripState();
}

class _MarqueeStripState extends State<MarqueeStrip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.period,
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final span = widget.itemWidth * widget.children.length;
    return ClipRect(
      // The strip is far wider than the screen; let it overflow the viewport
      // instead of being squeezed to fit.
      child: OverflowBox(
        maxWidth: double.infinity,
        alignment: Alignment.centerLeft,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = (widget.reverse ? -_c.value : _c.value) % 1;
            return Transform.translate(
              offset: Offset(-t * span, 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                // Two copies: as the first scrolls off, the second fills in.
                children: [
                  for (var pass = 0; pass < 2; pass++) ...widget.children,
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Rows of product tiles drifting sideways, alternating direction per row —
/// the moving backdrop behind the login screen.
class ImageMarquee extends StatelessWidget {
  final List<String> urls;
  final int rows;
  final double tile;
  const ImageMarquee({
    super.key,
    required this.urls,
    this.rows = 3,
    this.tile = 104,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var r = 0; r < rows; r++) ...[
          if (r > 0) const SizedBox(height: 12),
          SizedBox(
            height: tile,
            child: MarqueeStrip(
              itemWidth: tile + 12,
              reverse: r.isOdd,
              period: Duration(seconds: 40 - r * 8),
              children: [
                for (var i = 0; i < urls.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _Tile(
                      url: urls[(i + r * 5) % urls.length],
                      size: tile,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  final String url;
  final double size;
  const _Tile({required this.url, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFEAF4FB),
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: NetImage(url: url),
    );
  }
}
