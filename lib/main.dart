import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'data/session.dart';
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

void main() {
  if (kDebugMode) HttpOverrides.global = _DevHttpOverrides();
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
      home: Session.instance.onboarded
          ? const HomeScreen()
          : const LoginScreen(),
    );
  }
}
