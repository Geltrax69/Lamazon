/// Device location. The web implementation uses the browser's Geolocation
/// API; everywhere else gets a stub, so callers never check the platform.
library;

export 'geo_stub.dart' if (dart.library.js_interop) 'geo_web.dart';
