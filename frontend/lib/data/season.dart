import 'package:flutter/material.dart';

import 'api.dart';

/// A date-bounded skin for the shop: a festival, a sale, a term.
///
/// Blinkit turns saffron for Ganesh Chaturthi and yellow again afterwards, and
/// nobody ships a build to make that happen. This is that. The server decides
/// what is live from its own clock, so a phone with a wrong date cannot summon
/// Diwali in March, and an admin who sets it up in October never has to
/// remember to switch it off.
///
/// Null is the normal case. Most of the year the shop is simply itself, and
/// every surface here falls back to [LamazonTheme] when nothing is running.
class Season {
  final String id;
  final String name;

  /// The chrome the service header and department strip sit on.
  final Color ground;

  /// What actions on that ground use.
  final Color accent;

  /// Text over the ground. The server refuses to save a season whose ink
  /// measures under 4.5:1 against its own ground, so this is safe to paint.
  final Color ink;

  /// Search placeholders, rotated through the field while the season runs.
  /// Blinkit cycles "decorative lights" and "ganesh idol" during the festival,
  /// which is the cheapest merchandising in the app.
  final List<String> hints;

  const Season({
    required this.id,
    required this.name,
    required this.ground,
    required this.accent,
    required this.ink,
    this.hints = const [],
  });

  factory Season.fromJson(Map<String, dynamic> r) => Season(
    id: r['id'] as String? ?? '',
    name: r['name'] as String? ?? '',
    ground: _colour(r['ground'], const Color(0xFF143E32)),
    accent: _colour(r['accent'], const Color(0xFFC6EE63)),
    ink: _colour(r['ink'], const Color(0xFFFFFDF8)),
    hints: (r['hints'] as List<dynamic>? ?? const []).cast<String>(),
  );

  static Color _colour(Object? raw, Color fallback) {
    final hex = (raw as String? ?? '').replaceFirst('#', '');
    if (hex.length != 6) return fallback;
    final value = int.tryParse(hex, radix: 16);
    return value == null ? fallback : Color(0xFF000000 | value);
  }
}

/// What season the shop is in, if any.
///
/// Loaded once at startup beside the catalogue. It is one small public GET and
/// it decides what colour the app is, so it happens before the first paint
/// rather than repainting the header a second later.
class Seasons extends ChangeNotifier {
  Seasons._();
  static final Seasons instance = Seasons._();

  Season? _current;

  /// The live season, or null when the shop is simply itself.
  Season? get current => _current;

  Future<void> load() async {
    try {
      final raw = await Api.instance.activeSeason();
      _current = raw == null ? null : Season.fromJson(raw);
    } catch (e) {
      // A festival is decoration. Failing to fetch one must never stop the
      // shop from opening, so this swallows and leaves the app in its own
      // colours.
      logApiFailure('season', e);
      _current = null;
    }
    notifyListeners();
  }
}
