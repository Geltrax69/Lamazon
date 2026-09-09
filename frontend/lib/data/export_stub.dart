import 'package:flutter/services.dart';

Future<String> exportCsv(String filename, String contents) async {
  await Clipboard.setData(ClipboardData(text: contents));
  return 'CSV copied to clipboard';
}
