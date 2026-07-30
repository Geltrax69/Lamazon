import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'data/session.dart';
import 'widgets/app_shell.dart';
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
  await Session.instance.restore();
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
      home: Session.instance.onboarded
          ? const HomeScreen()
          : const LoginScreen(),
    );
  }
}
