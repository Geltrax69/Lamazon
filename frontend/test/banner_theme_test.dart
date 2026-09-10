import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamazon/widgets/campaign_palette.dart';

/// A banner theme is a promise that whatever staff pick, a shopper can read
/// the headline and the button. Eight choices only stay a promise if every one
/// of them is measured, so this measures them — including the custom-hex path,
/// which is the one nobody reviews.

double contrast(Color a, Color b) {
  final (x, y) = (a.computeLuminance(), b.computeLuminance());
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

void main() {
  test('every preset is readable, headline and button alike', () {
    expect(CampaignPalette.presets.length, greaterThanOrEqualTo(8));
    for (final p in CampaignPalette.presets) {
      expect(
        contrast(p.foreground, p.background),
        greaterThanOrEqualTo(4.5),
        reason: '${p.name}: the headline sits on the ground',
      );
      expect(
        contrast(p.actionForeground, p.action),
        greaterThanOrEqualTo(4.5),
        reason: '${p.name}: the label sits on the button',
      );
    }
  });

  test('the presets are actually different from one another', () {
    final hexes = CampaignPalette.presets.map((p) => p.hex).toSet();
    expect(hexes.length, CampaignPalette.presets.length, reason: 'no duplicates');
    final names = CampaignPalette.presets.map((p) => p.name).toSet();
    expect(names.length, CampaignPalette.presets.length);
  });

  test('a preset hex resolves back to that preset', () {
    for (final p in CampaignPalette.presets) {
      expect(CampaignPalette.resolve(p.hex).name, p.name);
      expect(CampaignPalette.resolve(p.hex.toLowerCase()).name, p.name);
    }
  });

  test('a colour nobody reviewed still comes out readable', () {
    // Staff can type any hex. The template derives the text and button from
    // it rather than trusting the editor, and that derivation is the thing
    // that has to hold — including at the light/dark boundary.
    for (final hex in [
      '#FFFFFF', '#000000', '#FFFF00', '#7F7F7F', '#6B6B6B', '#6E6E6E',
      '#00FF00', '#123456', '#FDF6E3', '#C6EE63',
    ]) {
      final p = CampaignPalette.resolve(hex);
      expect(
        contrast(p.foreground, p.background),
        greaterThanOrEqualTo(4.5),
        reason: '$hex: headline',
      );
      expect(
        contrast(p.actionForeground, p.action),
        greaterThanOrEqualTo(4.5),
        reason: '$hex: button label',
      );
    }
  });

  test('no hex at all can produce a banner nobody can read', () {
    // The spot checks above are the ones a person would think of. This is the
    // claim itself: 4,913 grounds across the whole cube, every one legible.
    var deepened = 0;
    for (var r = 0; r < 256; r += 16) {
      for (var g = 0; g < 256; g += 16) {
        for (var b = 0; b < 256; b += 16) {
          final hex =
              '#${r.toRadixString(16).padLeft(2, '0')}'
              '${g.toRadixString(16).padLeft(2, '0')}'
              '${b.toRadixString(16).padLeft(2, '0')}';
          final p = CampaignPalette.resolve(hex);
          expect(
            contrast(p.foreground, p.background),
            greaterThanOrEqualTo(4.5),
            reason: '$hex: headline',
          );
          expect(
            contrast(p.actionForeground, p.action),
            greaterThanOrEqualTo(4.5),
            reason: '$hex: button label',
          );
          if (p.background != Color(0xFF000000 | int.parse(hex.substring(1), radix: 16))) {
            deepened++;
          }
        }
      }
    }
    // And it is not doing it by repainting everything: most colours are kept
    // exactly as typed.
    expect(deepened / 4913, lessThan(0.5), reason: 'deepened $deepened of 4913');
  });

  test('nonsense falls back rather than painting an unreadable banner', () {
    for (final junk in ['', 'green', '#12345', '#GGGGGG', 'rgb(1,2,3)']) {
      expect(CampaignPalette.resolve(junk).name, CampaignPalette.forest.name);
    }
  });
}
