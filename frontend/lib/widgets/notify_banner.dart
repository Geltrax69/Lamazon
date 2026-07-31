import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/push.dart';

/// Notifications, in three steps the person can see: explain and ask, then
/// prove it by sending one, then confirm they actually got it.
///
/// Shown wherever notifications are worth having — the shopper's home screen
/// once they are signed in, and the seller dashboard — because the seller
/// screen alone meant most people were never asked.
///
/// Hidden where the browser cannot do it at all — including iOS Safari until
/// the site is added to the Home Screen — because offering a button that
/// cannot work is worse than offering nothing.
class NotifyBanner extends StatefulWidget {
  const NotifyBanner({super.key});

  @override
  State<NotifyBanner> createState() => _NotifyBannerState();
}

enum _NotifyStep { ask, sending, waiting, confirmed, failed }

class _NotifyBannerState extends State<NotifyBanner> {
  static const _confirmTimeout = Duration(seconds: 25);

  _NotifyStep _step = _NotifyStep.ask;
  bool _hidden = false;
  bool _delivered = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // The service worker tells us when the test notification was answered,
    // including when the app was opened from it.
    Push.instance.onConfirmed(
      () {
        if (mounted) setState(() => _step = _NotifyStep.confirmed);
      },
      onDelivered: () {
        if (mounted) _delivered = true;
      },
    );
  }

  Future<void> _turnOn() async {
    setState(() {
      _step = _NotifyStep.sending;
      _error = null;
    });

    if (!await Push.instance.enable()) {
      setState(() {
        _step = _NotifyStep.failed;
        _error = Push.instance.denied
            ? 'Your browser is blocking notifications. Allow them for this '
                'site in its settings, then try again.'
            : 'Could not turn notifications on. You will still get emails.';
      });
      return;
    }

    if (!await Push.instance.sendTest()) {
      setState(() {
        _step = _NotifyStep.failed;
        _error = 'Notifications are on, but the test one did not send. '
            'Emails are unaffected.';
      });
      return;
    }
    setState(() {
      _step = _NotifyStep.waiting;
      _delivered = false;
    });
    Future<void>.delayed(_confirmTimeout, () {
      if (!mounted || _step != _NotifyStep.waiting) return;
      setState(() {
        // Knowing it was drawn is the difference between push being broken
        // and nobody having tapped it — say which one happened.
        _step = _delivered ? _NotifyStep.confirmed : _NotifyStep.failed;
        _error = _delivered
            ? null
            : 'FCM accepted it but no notification appeared. Check that '
                'Chrome is allowed to notify you in macOS System Settings, '
                'then try again.';
      });
    });
  }

  /// The explanation lives in a dialog rather than the banner, so the banner
  /// stays small and the ask is a deliberate choice.
  Future<void> _openDialog() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Notify me about orders'),
        content: const Text(
          'Your browser will show a notification the moment someone orders '
          'from your store, so you can accept it before they change their '
          'mind.\n\n'
          'Your browser will ask you to allow it. We always email you as well, '
          'so nothing is missed either way.',
          style: TextStyle(fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Allow notifications'),
          ),
        ],
      ),
    );
    if (yes == true) await _turnOn();
  }

  @override
  Widget build(BuildContext context) {
    final push = Push.instance;
    final done = _step == _NotifyStep.confirmed;
    if (_hidden || !push.supported) return const SizedBox.shrink();
    // Already granted and nothing to prove: stay out of the way.
    if (push.granted && _step == _NotifyStep.ask) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: done ? const Color(0xFFE8F3EC) : Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(
            done ? LucideIcons.circleCheck : LucideIcons.bell,
            size: 18,
            color: done ? const Color(0xFF1D4A3C) : null,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(_message(), style: const TextStyle(fontSize: 12.5, height: 1.35))),
          _action(),
          IconButton(
            icon: const Icon(LucideIcons.x, size: 15),
            onPressed: () => setState(() => _hidden = true),
          ),
        ],
      ),
    );
  }

  String _message() => switch (_step) {
        _NotifyStep.ask =>
          'Get notified the moment an order arrives.\nWe email you either way.',
        _NotifyStep.sending => 'Setting notifications up…',
        _NotifyStep.waiting =>
          'Sent you a test notification. Tap “Yes, got it” on it to finish.',
        _NotifyStep.confirmed =>
          'Notifications are working. You will hear about new orders here.',
        _NotifyStep.failed => _error ?? 'Something went wrong.',
      };

  Widget _action() => switch (_step) {
        _NotifyStep.ask => TextButton(
            onPressed: _openDialog,
            child: const Text('Turn on'),
          ),
        _NotifyStep.sending || _NotifyStep.waiting => const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        _NotifyStep.confirmed => const SizedBox(width: 8),
        _NotifyStep.failed => TextButton(
            onPressed: _turnOn,
            child: const Text('Retry'),
          ),
      };
}
