import 'package:flutter_web_plugins/url_strategy.dart';

/// Vercel already rewrites every path to index.html, so real paths work and
/// the staff panels get URLs people can type.
void useCleanUrls() => usePathUrlStrategy();
