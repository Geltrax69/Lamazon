import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

const _ink = Color(0xFF1A1A1A);

/// Opens the cropper on [bytes] and returns the cropped photo, or null if the
/// person backed out. The picture they framed is the picture that is saved:
/// preview and export run the same painter, so there is no second piece of
/// maths to drift out of step with the one on screen.
///
/// ponytail: dart:ui rather than an image-cropping package. Every one of those
/// needs its own Android activity, iOS pod and a separate web implementation,
/// which is three platform configs for what a canvas and a matrix already do.
Future<Uint8List?> cropPhoto(
  BuildContext context,
  Uint8List bytes, {
  double aspect = 16 / 9,
  String title = 'Adjust photo',
}) async {
  final image = await decodeImageFromList(bytes);
  if (!context.mounted) return null;
  return Navigator.push<Uint8List>(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _CropScreen(image: image, aspect: aspect, title: title),
    ),
  );
}

class _CropScreen extends StatefulWidget {
  final ui.Image image;
  final double aspect;
  final String title;
  const _CropScreen({
    required this.image,
    required this.aspect,
    required this.title,
  });

  @override
  State<_CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<_CropScreen> {
  /// How much the person has zoomed in beyond "just fills the frame". Never
  /// below 1, so the frame cannot end up with a transparent corner.
  double _zoom = 1;
  Offset _offset = Offset.zero;

  double _startZoom = 1;
  Offset _startOffset = Offset.zero;
  Offset _startFocal = Offset.zero;

  void _onStart(ScaleStartDetails d) {
    _startZoom = _zoom;
    _startOffset = _offset;
    _startFocal = d.focalPoint;
  }

  void _onUpdate(ScaleUpdateDetails d, Size frame) {
    setState(() {
      _zoom = (_startZoom * d.scale).clamp(1, 6);
      _offset = _startOffset + (d.focalPoint - _startFocal);
      _offset = _clamp(_offset, frame);
    });
  }

  /// Keeps the image covering the frame. Panning past the edge would show
  /// whatever is behind it, and export that as part of the photo.
  Offset _clamp(Offset offset, Size frame) {
    final scale = _coverScale(widget.image, frame) * _zoom;
    final w = widget.image.width * scale;
    final h = widget.image.height * scale;
    final slackX = ((w - frame.width) / 2).clamp(0.0, double.infinity);
    final slackY = ((h - frame.height) / 2).clamp(0.0, double.infinity);
    return Offset(
      offset.dx.clamp(-slackX, slackX),
      offset.dy.clamp(-slackY, slackY),
    );
  }

  bool _busy = false;

  Future<void> _use(Size frame) async {
    setState(() => _busy = true);
    final bytes = await renderCrop(
      image: widget.image,
      frame: frame,
      zoom: _zoom,
      offset: _offset,
    );
    if (!mounted) return;
    if (bytes == null) {
      setState(() => _busy = false);
      return;
    }
    Navigator.pop(context, bytes);
  }

  /// The crop frame, sized to the space available. Worked out once per build
  /// so the preview and the export are told the same rectangle — the button
  /// used to guess at it separately, which is one number too many.
  Size _frameFor(BoxConstraints box) {
    final width = box.maxWidth - 32;
    final height = width / widget.aspect;
    final capped = box.maxHeight - 32;
    return height <= capped
        ? Size(width, height)
        : Size(capped * widget.aspect, capped);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, outer) {
            // Room for the header, the hint and the controls; whatever is
            // left is the picture.
            final frame = _frameFor(
              BoxConstraints(
                maxWidth: outer.maxWidth,
                maxHeight: outer.maxHeight - 190,
              ),
            );
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(LucideIcons.x, color: Colors.white),
                      ),
                      Expanded(
                        child: Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() {
                          _zoom = 1;
                          _offset = Offset.zero;
                        }),
                        child: const Text(
                          'Reset',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: GestureDetector(
                      onScaleStart: _onStart,
                      onScaleUpdate: (d) => _onUpdate(d, frame),
                      child: ClipRect(
                        child: SizedBox(
                          width: frame.width,
                          height: frame.height,
                          child: CustomPaint(
                            painter: _CropPainter(
                              image: widget.image,
                              zoom: _zoom,
                              offset: _offset,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Drag to move, pinch or use the slider to zoom.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 12.5),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: _zoom,
                          min: 1,
                          max: 6,
                          onChanged: (v) => setState(() {
                            _zoom = v;
                            // Zooming out can leave the old pan outside the
                            // frame, so re-clamp rather than allow a gap.
                            _offset = _clamp(_offset, frame);
                          }),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: _ink,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                        ),
                        onPressed: _busy ? null : () => _use(frame),
                        child: Text(
                          _busy ? 'Saving…' : 'Use photo',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// How much the image has to grow to cover the frame with nothing left over.
double _coverScale(ui.Image image, Size frame) {
  final byWidth = frame.width / image.width;
  final byHeight = frame.height / image.height;
  return byWidth > byHeight ? byWidth : byHeight;
}

/// Draws the image into the frame under the current zoom and pan. Used for
/// the preview and for the export, so what you see is what is saved.
void _paint(
  Canvas canvas,
  ui.Image image,
  Size frame,
  double zoom,
  Offset offset,
) {
  final scale = _coverScale(image, frame) * zoom;
  canvas.save();
  canvas.translate(frame.width / 2 + offset.dx, frame.height / 2 + offset.dy);
  canvas.scale(scale);
  canvas.drawImage(
    image,
    Offset(-image.width / 2, -image.height / 2),
    Paint()..filterQuality = FilterQuality.high,
  );
  canvas.restore();
}

class _CropPainter extends CustomPainter {
  final ui.Image image;
  final double zoom;
  final Offset offset;
  const _CropPainter({
    required this.image,
    required this.zoom,
    required this.offset,
  });

  @override
  void paint(Canvas canvas, Size size) =>
      _paint(canvas, image, size, zoom, offset);

  @override
  bool shouldRepaint(_CropPainter old) =>
      old.zoom != zoom || old.offset != offset || old.image != image;
}

/// The visible frame, rendered at print size and encoded as PNG. Public so the
/// crop can be checked without driving the screen: what comes out of here is
/// the whole contract.
Future<Uint8List?> renderCrop({
  required ui.Image image,
  required Size frame,
  required double zoom,
  required Offset offset,
}) async {
  // Output width is capped rather than matched to the source: a 12MP phone
  // photo cropped to a shopfront card is a few hundred KB of upload for
  // detail nobody sees at 140 logical pixels tall.
  const maxWidth = 1400.0;
  final outWidth = frame.width > maxWidth ? maxWidth : frame.width * 3;
  final ratio = outWidth / frame.width;
  final outHeight = frame.height * ratio;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.scale(ratio);
  _paint(canvas, image, frame, zoom, offset);
  final picture = recorder.endRecording();
  final rendered = await picture.toImage(outWidth.round(), outHeight.round());
  final data = await rendered.toByteData(format: ui.ImageByteFormat.png);
  return data?.buffer.asUint8List();
}
