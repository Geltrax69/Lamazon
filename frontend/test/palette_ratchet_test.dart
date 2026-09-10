import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// A ratchet, not a ban.
///
/// CHECK 2 measured 229 hardcoded colour literals against 200 theme
/// references, and 62 distinct hex values in a system that names 8. The debt
/// is now 83 against 389, and this test is what stops it growing back: a
/// new `Color(0xFF…)` fails here, and the fix is either a token in
/// `LamazonTheme` or a deliberate lowering of the number below.
///
/// ponytail: a test rather than a custom analyzer plugin. Same effect at the
/// same moment (CI), no plugin to build or keep working across SDK bumps.
/// Lower these as screens are migrated; never raise them.
const _maxLiterals = 69;
const _maxDistinctHex = 41;

/// Where the palette is defined. It is allowed to hold hex; that is the point.
const _tokenFile = 'lib/widgets/design_system.dart';

void main() {
  test('hardcoded colours do not grow back', () {
    final literal = RegExp(r'Color\(0x[Ff][Ff][0-9A-Fa-f]{6}\)');
    final offenders = <String, int>{};
    final distinct = <String>{};
    var total = 0;

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith(_tokenFile.split('/').last) &&
          entity.path.contains('widgets')) {
        continue;
      }
      final found = literal.allMatches(entity.readAsStringSync());
      if (found.isEmpty) continue;
      offenders[entity.path] = found.length;
      distinct.addAll(found.map((m) => m.group(0)!));
      total += found.length;
    }

    final worst = offenders.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    expect(
      total,
      lessThanOrEqualTo(_maxLiterals),
      reason:
          'New hardcoded Color(0xFF…) literals. Use a LamazonTheme token, or '
          'lower _maxLiterals if you are paying the debt down.\n'
          'Worst files: ${worst.take(5).map((e) => "${e.key} (${e.value})").join(", ")}',
    );
    expect(
      distinct.length,
      lessThanOrEqualTo(_maxDistinctHex),
      reason:
          'A new distinct hex value entered the palette. The system names 8 '
          'colours; anything else needs a token first.',
    );
  });
}
