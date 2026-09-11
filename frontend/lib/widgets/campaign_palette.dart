import 'package:flutter/material.dart';

import '../data/season.dart';
import 'design_system.dart';

/// The shop's decorative colours for right now: a festival's, or its own.
///
/// A season used to repaint one widget. The result was a navy header bolted to
/// an otherwise forest-green page — the hero, the department tiles and the
/// navigation bar all kept the app's colours, so the feature read as a
/// rendering fault rather than as a theme.
///
/// Every *decorative* surface now reads these instead of naming
/// [LamazonTheme.forest] and [LamazonTheme.lime] directly. Prices, product
/// cards, stock and status colours deliberately do not: a shop that changes
/// colour everywhere for Diwali is a shop nobody can read a price in, and
/// green-means-in-stock has to survive a green festival.
abstract final class SeasonSkin {
  static Season? get _live => Seasons.instance.current;

  static bool get active => _live != null;

  /// The chrome: header, hero, empty category plates.
  static Color get ground => _live?.ground ?? LamazonTheme.forest;

  /// The same ground as a hex, for the campaign template which stores one.
  static String get groundHex =>
      '#${(ground.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  /// What actions on that ground use: the selected tile, the nav indicator.
  static Color get accent => _live?.accent ?? LamazonTheme.lime;

  /// Text over [ground]. The server refuses a season under 4.5:1 here.
  static Color get ink => _live?.ink ?? Colors.white;

  /// Text over [accent]. A season is only validated for ink-on-ground, and an
  /// accent dark enough to need white is allowed, so this is derived.
  static Color get onAccent => CampaignPalette.readable(accent);

  /// The ground, deepened — the second stop of every gradient drawn on it.
  static Color get groundShade =>
      Color.alphaBlend(Colors.black.withValues(alpha: .18), ground);
}

/// Named campaign palettes keep admin-managed images in one visual world while
/// preserving the existing hexadecimal field for API compatibility.
class CampaignPalette {
  final String name;
  final String hex;
  final Color background;
  final Color foreground;
  final Color action;
  final Color actionForeground;
  const CampaignPalette._(
    this.name,
    this.hex,
    this.background,
    this.foreground,
    this.action,
    this.actionForeground,
  );

  static const forest = CampaignPalette._(
    'Forest / Lime',
    '#143E32',
    Color(0xFF143E32),
    Colors.white,
    LamazonTheme.lime,
    LamazonTheme.forest,
  );
  static const cacao = CampaignPalette._(
    'Cacao / Peach',
    '#4A3029',
    Color(0xFF4A3029),
    Colors.white,
    Color(0xFFF7A38E),
    Color(0xFF4A3029),
  );
  static const ink = CampaignPalette._(
    'Ink / Mist',
    '#263244',
    Color(0xFF263244),
    Colors.white,
    Color(0xFFC8DBEE),
    Color(0xFF263244),
  );
  static const saffron = CampaignPalette._(
    'Saffron / Amber',
    '#7A2E12',
    Color(0xFF7A2E12),
    Colors.white,
    Color(0xFFFFC46B),
    Color(0xFF4A1B08),
  );
  static const marigold = CampaignPalette._(
    'Marigold / Maroon',
    '#7A1F12',
    Color(0xFF7A1F12),
    Colors.white,
    Color(0xFFF2B441),
    Color(0xFF4A1008),
  );
  static const berry = CampaignPalette._(
    'Berry / Blush',
    '#5B1D3D',
    Color(0xFF5B1D3D),
    Colors.white,
    Color(0xFFF7B7D2),
    Color(0xFF5B1D3D),
  );
  static const indigo = CampaignPalette._(
    'Indigo / Iris',
    '#2A2160',
    Color(0xFF2A2160),
    Colors.white,
    Color(0xFFC3B6FF),
    Color(0xFF2A2160),
  );
  static const reef = CampaignPalette._(
    'Teal / Reef',
    '#0E3B45',
    Color(0xFF0E3B45),
    Colors.white,
    Color(0xFF7FE3D4),
    Color(0xFF0E3B45),
  );

  /// Eight, not eighty. Every one of these was measured: the headline clears
  /// 4.5:1 on its ground and the button label clears 4.5:1 on the button, so
  /// there is no combination in this list that produces a banner nobody can
  /// read. A custom hex still works and is still derived rather than trusted.
  static const presets = <CampaignPalette>[
    forest,
    reef,
    ink,
    indigo,
    berry,
    marigold,
    saffron,
    cacao,
  ];

  /// The palette a banner is drawn in.
  ///
  /// A banner that never chose a colour — the default, or one of the legacy
  /// pastels that all translate to forest — follows the season instead. That
  /// is the difference between a festival header bolted onto a forest-green
  /// hero and a shop that looks dressed for the day. A banner an admin gave a
  /// deliberate colour keeps it: they chose it for a reason, and a season is
  /// not entitled to overrule the thing it is advertising.
  static CampaignPalette resolve(String hex) {
    final chosen = _resolve(hex);
    if (SeasonSkin.active && identical(chosen, forest)) {
      return _resolve(SeasonSkin.groundHex);
    }
    return chosen;
  }

  static CampaignPalette _resolve(String hex) {
    final normalized = hex.trim().toUpperCase();
    for (final preset in presets) {
      if (preset.hex == normalized) return preset;
    }
    // Existing pastel campaigns are translated into the new, tighter three
    // theme family. Custom valid colours still work, but the template derives
    // readable text and action contrast rather than relying on the editor.
    if (const ['#F2E8CE', '#DCEACD', '#1D4A3C'].contains(normalized)) {
      return forest;
    }
    if (const ['#F7DCCB', '#E7DFF3'].contains(normalized)) return cacao;
    if (normalized == '#DCE9F5') return ink;
    final value = int.tryParse(normalized.replaceFirst('#', ''), radix: 16);
    if (value == null || normalized.length != 7) return forest;
    var background = Color(0xFF000000 | value);

    // Staff can type any hex, and a luminance threshold guesses wrong in the
    // middle: #7F7F7F took white text at 4.00:1 and #A56F81 tops out at
    // 4.05:1 whichever of the two you pick. So light grounds keep their
    // colour and take ink, and everything else is deepened — hue intact —
    // until white clears 4.5:1. Refusing the colour outright would lose the
    // intent; this keeps it and makes it readable.
    if (_contrast(LamazonTheme.text, background) >= 4.5) {
      return CampaignPalette._(
        'Custom',
        normalized,
        background,
        LamazonTheme.text,
        LamazonTheme.forest,
        Colors.white,
      );
    }
    // Monotonic: every step raises the contrast with white, so it terminates.
    for (var i = 0; i < 24 && _contrast(Colors.white, background) < 4.5; i++) {
      background = Color.lerp(background, Colors.black, .08)!;
    }
    return CampaignPalette._(
      'Custom',
      normalized,
      background,
      Colors.white,
      LamazonTheme.lime,
      LamazonTheme.strong,
    );
  }

  /// Whichever of the app's two foregrounds can be read on [ground].
  static Color readable(Color ground) =>
      _contrast(LamazonTheme.text, ground) >= 4.5
      ? LamazonTheme.text
      : Colors.white;

  static double _contrast(Color a, Color b) {
    final x = a.computeLuminance(), y = b.computeLuminance();
    return ((x > y ? x : y) + .05) / ((x > y ? y : x) + .05);
  }
}
