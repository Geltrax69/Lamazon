import 'dart:async';

/// Everywhere that is not the web. The Push API is a browser thing, so the
/// calls exist and do nothing rather than making callers check the platform.
class Push {
  Push._();
  static final Push instance = Push._();

  bool get supported => false;
  bool get denied => false;
  bool get granted => false;

  Future<bool> enable() async => false;
}
