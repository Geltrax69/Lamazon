import 'package:flutter/services.dart';

/// One version source for Help, Settings and diagnostics.
class AppInfo {
  static String version = '';
  static Future<void> load() async {
    final manifest = await rootBundle.loadString('pubspec.yaml');
    version =
        RegExp(
          r'^version:\s*([^+\s]+)',
          multiLine: true,
        ).firstMatch(manifest)?.group(1) ??
        '';
  }
}
