import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../data/api.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/catalog.dart';
import '../data/session.dart';
import '../widgets/app_shell.dart';
import '../widgets/image_marquee.dart';
import 'home_screen.dart';
import 'policy_screen.dart';
import 'profile_setup_screen.dart';

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

/// What the sign-in card is asking for right now.
enum _Step { email, code, password }

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();

  /// What the card is asking for. The address decides: one that has a
  /// password is asked for it, everyone else gets a code in the post.
  _Step _step = _Step.email;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _valid => switch (_step) {
    _Step.email => Session.isValidEmail(_email.text),
    _Step.code => _code.text.trim().length == 6,
    _Step.password => _password.text.isNotEmpty,
  };

  /// Step one: find out what this address is signed in with.
  Future<void> _start() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final next = await Api.instance.startLogin(_email.text.trim());
      // The server can sign someone in on the spot when it is running with
      // the code switched off; asking for one that was never sent would be a
      // dead end.
      if (next.tokens != null) {
        await Session.instance.signIn(next.tokens!);
        _go();
        return;
      }
      setState(() => _step = next.needsPassword ? _Step.password : _Step.code);
    } on http.ClientException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      // Say so. This used to wave the person through as a guest, on the
      // theory that browsing beats a dead end — but from where they sit,
      // asking for a code and being handed the shop with no code and no
      // message is indistinguishable from the button not working.
      logApiFailure('login code', e);
      setState(
        () => _error =
            'Could not reach the server, so no code went out. Try again, or '
            'use Skip login to browse.',
      );
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
      final tokens = await Api.instance.verifyLoginCode(
        _email.text.trim(),
        _code.text.trim(),
      );
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

  /// The password path, for an address that has one.
  Future<void> _verifyPassword() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final tokens = await Api.instance.passwordLogin(
        _email.text.trim(),
        _password.text,
      );
      await Session.instance.signIn(tokens);
      _go();
    } on http.ClientException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      logApiFailure('password login', e);
      setState(() => _error = 'Could not reach the server. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// One button, whichever step it is on.
  void _submit() => switch (_step) {
    _Step.email => _start(),
    _Step.code => _verifyCode(),
    _Step.password => _verifyPassword(),
  };

  void _enter({required bool skip}) {
    if (skip) Session.instance.skip();
    _go();
  }

  /// Leaves the login screen for wherever the user came from — via the
  /// details form when this is somebody's first time, since an order needs a
  /// name, a number and an address and now is the one moment they will fill
  /// them in.
  Future<void> _go() async {
    if (!mounted) return;
    if (Session.instance.loggedIn && !Session.instance.ready) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
      );
      if (!mounted) return;
    }
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
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    12,
                                    0,
                                  ),
                                  child: Icon(
                                    switch (_step) {
                                      _Step.email => LucideIcons.mail,
                                      _Step.code => LucideIcons.keyRound,
                                      _Step.password => LucideIcons.lock,
                                    },
                                    size: 18,
                                    color: _muted,
                                  ),
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: switch (_step) {
                                      _Step.email => _email,
                                      _Step.code => _code,
                                      _Step.password => _password,
                                    },
                                    keyboardType: switch (_step) {
                                      _Step.email => TextInputType.emailAddress,
                                      _Step.code => TextInputType.number,
                                      _Step.password => TextInputType.text,
                                    },
                                    obscureText: _step == _Step.password,
                                    autocorrect: false,
                                    onChanged: (_) => setState(() {}),
                                    onSubmitted: (_) {
                                      if (_valid && !_busy) _submit();
                                    },
                                    decoration: InputDecoration(
                                      border: InputBorder.none,
                                      hintText: switch (_step) {
                                        _Step.email => 'Enter email address',
                                        _Step.code => 'Enter the 6-digit code',
                                        _Step.password => 'Enter password',
                                      },
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
                                    : switch (_step) {
                                        _Step.email => 'Continue',
                                        _Step.code => 'Verify code',
                                        _Step.password => 'Sign in',
                                      },
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
                                switch (_step) {
                                  _Step.email =>
                                    'We only use your email for order updates '
                                        'and receipts.',
                                  _Step.code =>
                                    'We sent a code to ${_email.text.trim()}. '
                                        'It expires in 10 minutes.',
                                  _Step.password =>
                                    'Signing in as ${_email.text.trim()}.',
                                },
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
                // Named and reachable. Agreeing to two documents you cannot
                // open is not agreeing to anything.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        'By continuing, you agree to our ',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9A9A9A),
                        ),
                      ),
                      _PolicyLink(slug: 'terms', label: 'Terms and Conditions'),
                      const Text(
                        ' & ',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9A9A9A),
                        ),
                      ),
                      _PolicyLink(slug: 'privacy', label: 'Privacy Policy'),
                    ],
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

/// One underlined policy name in the sign-in footer.
class _PolicyLink extends StatelessWidget {
  final String slug;
  final String label;
  const _PolicyLink({required this.slug, required this.label});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PolicyScreen(slug: slug)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          color: Color(0xFF6B6B6B),
          fontWeight: FontWeight.w700,
          decoration: TextDecoration.underline,
          decorationColor: Color(0xFF9A9A9A),
        ),
      ),
    );
  }
}
