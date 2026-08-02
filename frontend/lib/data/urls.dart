/// Clean URLs on the web (/admin/log_IN rather than /#/admin/log_IN), and
/// nothing at all everywhere else — flutter_web_plugins only compiles for the
/// browser, and importing it directly would break every other build and the
/// test suite with it.
library;

export 'urls_stub.dart' if (dart.library.js_interop) 'urls_web.dart';
