import 'dart:js_interop';

@JS('downloadLamazonCSV')
external void _download(JSString name, JSString contents);
Future<String> exportCsv(String filename, String contents) async {
  _download(filename.toJS, contents.toJS);
  return 'CSV downloaded';
}
