import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'data/session.dart';
import 'data/urls.dart';
import 'data/staff.dart';
import 'widgets/app_shell.dart';
import 'screens/admin_screen.dart';
import 'screens/delivery_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

// ponytail: iOS 26 simulator breaks Dart TLS verify (CERTIFICATE_VERIFY_FAILED,
// simulator-only). Debug-only bypass; remove when the Flutter engine fix ships.
class _DevHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context)
        ..badCertificateCallback = (cert, host, port) => true;
}

void main() async {
  if (kDebugMode) HttpOverrides.global = _DevHttpOverrides();
  // Real paths rather than /#/: the staff panels are URLs people type, and
  // Vercel already rewrites everything to index.html.
  useCleanUrls();
  // The stored session decides whether the login screen shows at all, so it
  // has to be read before the first frame.
  WidgetsFlutterBinding.ensureInitialized();
  await Session.instance.restore();
  await StaffSession.admin.restore();
  await StaffSession.rider.restore();
  runApp(const LamazonApp());
}

/// Resolves the two staff addresses, or null for everything else — which is
/// what sends a shopper to the app they were asking for.
Route<dynamic>? _staffRoute(RouteSettings settings) {
  final path = (settings.name ?? '/').toLowerCase().replaceAll(
    RegExp(r'/+$'),
    '',
  );
  final screen = switch (path) {
    '/admin' || '/admin/log_in' => const AdminScreen(),
    '/delivery' => const DeliveryScreen(),
    _ => null,
  };
  if (screen == null) return null;
  return MaterialPageRoute<void>(builder: (_) => screen, settings: settings);
}

Route<dynamic> _shopRoute() => MaterialPageRoute<void>(
  settings: const RouteSettings(name: '/'),
  builder: (_) =>
      Session.instance.onboarded ? const HomeScreen() : const LoginScreen(),
);

class LamazonApp extends StatelessWidget {
  const LamazonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lamazon',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF1F1EF),
        colorScheme: ColorScheme.fromSeed(seedColor: kAccent),
      ),
      // One place to keep every screen phone-shaped, however wide the window.
      builder: (context, child) => AppShell(child: child!),
      // The staff panels are their own entrances, on purpose: nothing in the
      // shopper's app links to them, and neither one uses a shopper session.
      //
      // These are addresses people type, so they are matched forgivingly —
      // case and a trailing slash do not decide whether the panel opens.
      // Chrome autocompleting "/admin/Log_IN" missed a route table spelled
      // "/admin/log_IN" and dropped the admin on the shop's front page with
      // no explanation.
      // Every route is built here rather than through `home`, which cannot
      // coexist with onGenerateInitialRoutes — and an app whose first screen
      // depends on the address needs both to agree.
      onGenerateRoute: (settings) => _staffRoute(settings) ?? _shopRoute(),
      // A deep link would otherwise be built one segment at a time, leaving
      // /admin under /admin/log_IN in the stack. One address, one screen.
      onGenerateInitialRoutes: (initial) => [
        _staffRoute(RouteSettings(name: initial)) ?? _shopRoute(),
      ],
    );
  }
}
