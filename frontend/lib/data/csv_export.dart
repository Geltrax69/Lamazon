import 'dart:convert';
export 'export_stub.dart' if (dart.library.js_interop) 'export_web.dart';

String rowsToCsv(List<Map<String, dynamic>> rows) {
  if (rows.isEmpty) return '';
  final columns = rows.expand((r) => r.keys).toSet().toList()..sort();
  String cell(dynamic value) {
    var text = value == null
        ? ''
        : value is Map || value is List
        ? jsonEncode(value)
        : value.toString();
    // Prevent spreadsheet formulas in user-supplied names, addresses and titles.
    if (RegExp(r'^\s*[=+@-]').hasMatch(text)) text = "'$text";
    return '"${text.replaceAll('"', '""')}"';
  }

  return [
    columns.map(cell).join(','),
    for (final row in rows) columns.map((c) => cell(row[c])).join(','),
  ].join('\r\n');
}
