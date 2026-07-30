import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../data/api.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/catalog.dart';
import '../data/session.dart';
import '../widgets/app_shell.dart';
import '../widgets/image_marquee.dart';
import 'home_screen.dart';

const _ink = Color(0xFF1A1A1A);
const _muted = Color(0xFF6B6B6B);
const _yellow = Color(0xFFFFC220); // the logo's yellow

/// Opening screen: drifting product tiles, the Lamazon mark, and an email
/// sign-in that can be skipped.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();

  /// Null until a code has been mailed; then the card asks for the code.
  bool _codeSent = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  bool get _valid => _codeSent
      ? _code.text.trim().length == 6
      : Session.isValidEmail(_email.text);

  /// Step one: ask the backend to mail a code.
  Future<void> _sendCode() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Api.instance.requestLoginCode(_email.text.trim());
      setState(() => _codeSent = true);
    } on http.ClientException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      // Offline: the app still works on bundled data, so let people browse.
      logApiFailure('login code', e);
      Session.instance.skip();
      _go();
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Step two: the code buys a session token.
  Future<void> _verifyCode() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final tokens = await Api.instance
          .verifyLoginCode(_email.text.trim(), _code.text.trim());
      await Session.instance.signIn(tokens);
      _go();
    } on http.ClientException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      logApiFailure('verify code', e);
      setState(() => _error = 'Could not reach the server. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// One button, two steps: mail the code, then check it.
  void _submit() => _codeSent ? _verifyCode() : _sendCode();

  void _enter({required bool skip}) {
    if (skip) Session.instance.skip();
    _go();
  }

  /// Leaves the login screen for wherever the user came from.
  void _go() {
    if (!mounted) return;
    // Opened from the account screen: go back to it, now signed in. At app
    // launch there is nothing to go back to, so home takes over instead.
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The categories the app sells, drifting past behind the sign-in card.
    final urls = [
      for (final tab in ['Electronics', 'Grocery', 'Food', 'Gifts', 'Beauty'])
        // Thumbnails: the backdrop tiles are ~104px, so full photos would
        // burn megabytes on first paint for no visible gain.
        ...products
            .where((p) => p.tab == tab)
            .map((p) => thumb(p.imageUrl, 200)),
    ];
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              // Fades the drifting tiles into the background so the logo and
              // sign-in card sit on clean space.
              child: ShaderMask(
                shaderCallback: (rect) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.55, 1],
                  colors: [Colors.white, Colors.transparent],
                ).createShader(rect),
                blendMode: BlendMode.dstIn,
                child: ImageMarquee(urls: urls.isEmpty ? _fallback : urls),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 8, 16, 0),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _enter(skip: true),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 11,
                          ),
                          child: Text(
                            'Skip login',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _ink,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Image.asset(
                    'assets/logo.png',
                    width: 96,
                    height: 96,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Local choice. Global experience.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 22),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ReadableBody(
                    maxWidth: 440,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 22,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Log in or sign up',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4F5F7),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                const Padding(
                                  padding: EdgeInsets.fromLTRB(16, 0, 12, 0),
                                  child: Icon(
                                    LucideIcons.mail,
                                    size: 18,
                                    color: _muted,
                                  ),
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: _codeSent ? _code : _email,
                                    keyboardType: _codeSent
                                        ? TextInputType.number
                                        : TextInputType.emailAddress,
                                    autocorrect: false,
                                    onChanged: (_) => setState(() {}),
                                    onSubmitted: (_) {
                                      if (_valid && !_busy) _submit();
                                    },
                                    decoration: InputDecoration(
                                      border: InputBorder.none,
                                      hintText: _codeSent
                                          ? 'Enter the 6-digit code'
                                          : 'Enter email address',
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                    ),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: _valid ? _ink : _yellow,
                                foregroundColor: _valid ? Colors.white : _ink,
                                disabledBackgroundColor: const Color(
                                  0xFFE6E8EC,
                                ),
                                disabledForegroundColor: _muted,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 15,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: _valid && !_busy ? _submit : null,
                              child: Text(
                                _busy
                                    ? 'Please wait…'
                                    : _codeSent
                                        ? 'Verify code'
                                        : 'Send me a code',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _error ??
                                (_codeSent
                                    ? 'We sent a code to ${_email.text.trim()}. It expires in 10 minutes.'
                                    : 'We only use your email for order updates and receipts.'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: _error == null
                                  ? _muted
                                  : const Color(0xFFD03A3A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'By continuing, you agree to our Terms of service & '
                    'Privacy policy',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Color(0xFF9A9A9A)),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Used only if the catalog ever ships without these categories.
const _fallback = [
  'https://images.unsplash.com/photo-1498049794561-7780e7231661?w=300',
  'https://images.unsplash.com/photo-1542838132-92c53300491e?w=300',
  'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=300',
];
