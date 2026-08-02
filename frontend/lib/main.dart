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
  // The stored session decides whether the login screen shows at all, so it
  // has to be read before the first frame.
  WidgetsFlutterBinding.ensureInitialized();
  // Real paths rather than /#/: the staff panels are URLs people type, and
  // Vercel already rewrites everything to index.html.
  useCleanUrls();
  await Session.instance.restore();
  await StaffSession.admin.restore();
  await StaffSession.rider.restore();
  runApp(const LamazonApp());
}

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
      routes: {
        '/admin/log_IN': (_) => const AdminScreen(),
        '/admin': (_) => const AdminScreen(),
        '/delivery': (_) => const DeliveryScreen(),
      },
      home: Session.instance.onboarded
          ? const HomeScreen()
          : const LoginScreen(),
    );
  }
}
