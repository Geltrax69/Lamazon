import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamazon/widgets/photo_cropper.dart';

/// A square image, top half red and bottom half blue, so a crop can be
/// checked by asking what colour came out of it.
Future<ui.Image> _twoTone() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 400, 200),
    Paint()..color = const Color(0xFFFF0000),
  );
  canvas.drawRect(
    const Rect.fromLTWH(0, 200, 400, 200),
    Paint()..color = const Color(0xFF0000FF),
  );
  return recorder.endRecording().toImage(400, 400);
}

Future<Color> _pixel(ui.Image image, int x, int y) async {
  final data = (await image.toByteData())!.buffer.asUint8List();
  final i = (y * image.width + x) * 4;
  return Color.fromARGB(data[i + 3], data[i], data[i + 1], data[i + 2]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the crop comes out at the frame’s shape', () async {
    final source = await _twoTone();
    final bytes = await renderCrop(
      image: source,
      frame: const Size(300, 150), // 2:1 out of a square
      zoom: 1,
      offset: Offset.zero,
    );
    expect(bytes, isNotNull);

    final out = await decodeImageFromList(bytes!);
    expect((out.width / out.height - 2).abs() < 0.02, isTrue,
        reason: 'got ${out.width}x${out.height}');
  });

  test('centred and unzoomed, it keeps the middle band', () async {
    final source = await _twoTone();
    final out = await decodeImageFromList((await renderCrop(
      image: source,
      frame: const Size(300, 150),
      zoom: 1,
      offset: Offset.zero,
    ))!);

    // The middle of a square is half red over half blue.
    expect(await _pixel(out, out.width ~/ 2, 2), const Color(0xFFFF0000));
    expect(
      await _pixel(out, out.width ~/ 2, out.height - 3),
      const Color(0xFF0000FF),
    );
  });

  test('dragging down brings the top of the picture into frame', () async {
    final source = await _twoTone();
    const frame = Size(300, 150);
    // Three fifths of the way down the frame: blue when centred, red once
    // the picture has been pushed down. Not the last row — that lands on the
    // seam between the two halves, where the sample is a blend of both.
    Future<Color> at(Offset offset) async {
      final out = await decodeImageFromList((await renderCrop(
        image: source,
        frame: frame,
        zoom: 1,
        offset: offset,
      ))!);
      return _pixel(out, out.width ~/ 2, (out.height * 0.6).round());
    }

    expect(await at(Offset.zero), const Color(0xFF0000FF));
    expect(await at(const Offset(0, 74)), const Color(0xFFFF0000));
  });
}
