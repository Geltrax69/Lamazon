/// Browser notifications. The real implementation imports dart:js_interop,
/// which does not compile for Android or iOS, so the platform picks one here
/// and every caller writes the same code either way.
library;

export 'push_stub.dart' if (dart.library.js_interop) 'push_web.dart';
