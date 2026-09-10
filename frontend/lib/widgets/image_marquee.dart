import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'design_system.dart';
import 'product_card.dart';

/// One row of widgets drifting sideways forever, looping seamlessly.
/// Used for the login backdrop and the running store ads on home.
class MarqueeStrip extends StatefulWidget {
  final List<Widget> children;
  final double itemWidth; // including the gap after each item
  final Duration period; // time for one full pass
  final bool reverse;

  /// Stops the drift. WCAG 2.2.2 asks for a way to pause anything that moves
  /// for more than five seconds; this one runs forever.
  final bool paused;
  const MarqueeStrip({
    super.key,
    required this.children,
    required this.itemWidth,
    this.period = const Duration(seconds: 40),
    this.reverse = false,
    this.paused = false,
  });

  @override
  State<MarqueeStrip> createState() => _MarqueeStripState();
}

class _MarqueeStripState extends State<MarqueeStrip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.period,
  );

  @override
  void initState() {
    super.initState();
    if (!widget.paused) _c.repeat();
  }

  @override
  void didUpdateWidget(MarqueeStrip old) {
    super.didUpdateWidget(old);
    if (widget.paused == old.paused) return;
    // stop() rather than reset(): resuming should carry on from where the
    // strip was, not jump back to the start.
    widget.paused ? _c.stop() : _c.repeat();
  }

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
            final t = MediaQuery.disableAnimationsOf(context)
                ? 0.0
                : (widget.reverse ? -_c.value : _c.value) % 1;
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
class ImageMarquee extends StatefulWidget {
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
  State<ImageMarquee> createState() => _ImageMarqueeState();
}

class _ImageMarqueeState extends State<ImageMarquee> {
  bool _paused = false;

  @override
  Widget build(BuildContext context) {
    final tile = widget.tile;
    // Reduced motion already stopped the drift; when it is on, the control
    // would claim to do something that is already done.
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        _strip(tile),
        if (!reduced && widget.urls.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(8),
            child: TactileIconButton(
              icon: _paused ? LucideIcons.play : LucideIcons.pause,
              label: _paused
                  ? 'Resume the moving backdrop'
                  : 'Pause the moving backdrop',
              size: 36,
              onPressed: () => setState(() => _paused = !_paused),
            ),
          ),
      ],
    );
  }

  Widget _strip(double tile) {
    final urls = widget.urls;
    return Column(
      children: [
        for (var r = 0; r < widget.rows; r++) ...[
          if (r > 0) const SizedBox(height: 12),
          SizedBox(
            height: tile,
            child: MarqueeStrip(
              itemWidth: tile + 12,
              reverse: r.isOdd,
              period: Duration(seconds: 40 - r * 8),
              paused: _paused,
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
        // What shows through until the photo arrives. A cool blue read as a
        // hole in the warm canvas behind it.
        color: LamazonTheme.track,
        borderRadius: BorderRadius.circular(LamazonTheme.featuredRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: NetImage(url: url),
    );
  }
}
