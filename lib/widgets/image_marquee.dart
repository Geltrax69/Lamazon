import 'package:flutter/material.dart';

import 'product_card.dart';

/// Rows of product tiles drifting sideways, alternating direction per row —
/// the moving backdrop behind the login screen.
class ImageMarquee extends StatefulWidget {
  final List<String> urls;
  final int rows;
  final double tile;
  const ImageMarquee(
      {super.key, required this.urls, this.rows = 3, this.tile = 104});

  @override
  State<ImageMarquee> createState() => _ImageMarqueeState();
}

class _ImageMarqueeState extends State<ImageMarquee>
    with SingleTickerProviderStateMixin {
  // One controller drives every row; each row reads it at its own speed.
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 40),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.tile + 12;
    return Column(
      children: [
        for (var r = 0; r < widget.rows; r++) ...[
          if (r > 0) const SizedBox(height: 12),
          SizedBox(
            height: widget.tile,
            child: ClipRect(
              // The strip is far wider than the screen; let it overflow the
              // viewport instead of being squeezed to fit.
              child: OverflowBox(
                maxWidth: double.infinity,
                alignment: Alignment.centerLeft,
                child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
                  // Offset within one tile width, so the strip loops seamlessly.
                  // Each row drifts the other way, at its own speed.
                  final t =
                      (_c.value * (1 + r * 0.4) * (r.isEven ? 1 : -1)) % 1;
                  return Transform.translate(
                    offset: Offset(-t * step * widget.urls.length, 0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Two copies: as the first scrolls off, the second fills in.
                        for (var pass = 0; pass < 2; pass++)
                          for (var i = 0; i < widget.urls.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: _Tile(
                                url: widget.urls[
                                    (i + r * 5) % widget.urls.length],
                                size: widget.tile,
                              ),
                            ),
                      ],
                    ),
                  );
                },
                ),
              ),
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
