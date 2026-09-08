import '../data/api.dart';
import 'policy_screen.dart';
import 'package:flutter/material.dart';

import '../widgets/app_shell.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../widgets/screen_header.dart';
import 'addresses_screen.dart';
import 'notifications_screen.dart';

const _ink = Color(0xFF1A1A1A);
const _muted = Color(0xFF6B6B6B);

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _push = true;
  bool _email = false;
  bool _orderUpdates = true;
  bool _busy = true;
  bool _loaded = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _save();
  }

  Future<void> _save([Map<String, bool>? changes]) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final preferences = await Api.instance.preferences(changes);
      if (!mounted) return;
      setState(() {
        _push = preferences['push'] == true;
        _email = preferences['emailOffers'] == true;
        _orderUpdates = preferences['orderUpdates'] == true;
        _loaded = true;
      });
    } catch (e) {
      if (mounted)
        setState(
          () => _error = e.toString().replaceFirst('ClientException: ', ''),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F1EF),
      body: ReadableBody(
        maxWidth: 620,
        child: SafeArea(
          child: Column(
            children: [
              const ScreenHeader(title: 'Settings'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  children: [
                    if (_busy) const LinearProgressIndicator(),
                    if (_error != null)
                      ListTile(
                        title: Text(_error!),
                        trailing: TextButton(
                          onPressed: _busy ? null : () => _save(),
                          child: const Text('Retry'),
                        ),
                      ),
                    const _SectionLabel('Notifications'),
                    _Card(
                      children: [
                        _Toggle(
                          icon: LucideIcons.bell,
                          title: 'Push notifications',
                          value: _push,
                          onChanged: _busy || !_loaded
                              ? null
                              : (v) => _save({'push': v}),
                        ),
                        _Toggle(
                          icon: LucideIcons.mail,
                          title: 'Email offers',
                          value: _email,
                          onChanged: _busy || !_loaded
                              ? null
                              : (v) => _save({'emailOffers': v}),
                        ),
                        _Toggle(
                          icon: LucideIcons.truck,
                          title: 'Order updates',
                          value: _orderUpdates,
                          onChanged: _busy || !_loaded
                              ? null
                              : (v) => _save({'orderUpdates': v}),
                        ),
                        _Link(
                          icon: LucideIcons.inbox,
                          title: 'View notifications',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const NotificationsScreen(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const _SectionLabel('Account'),
                    _Card(
                      children: [
                        _Link(
                          icon: LucideIcons.mapPin,
                          title: 'Saved addresses',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AddressesScreen(),
                            ),
                          ),
                        ),
                        _Link(
                          icon: LucideIcons.wallet,
                          title: 'Online payments',
                          value: 'Not available',
                        ),
                      ],
                    ),
                    const _SectionLabel('Preferences'),
                    _Card(
                      children: [
                        _Link(
                          icon: LucideIcons.languages,
                          title: 'Language',
                          value: 'English',
                        ),
                        _Link(
                          icon: LucideIcons.indianRupee,
                          title: 'Currency',
                          value: 'INR (₹)',
                        ),
                      ],
                    ),
                    const _SectionLabel('About'),
                    _Card(
                      children: [
                        _Link(
                          icon: LucideIcons.shield,
                          title: 'Privacy policy',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  const PolicyScreen(slug: 'privacy'),
                            ),
                          ),
                        ),
                        _Link(
                          icon: LucideIcons.fileText,
                          title: 'Terms of service',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const PolicyScreen(slug: 'terms'),
                            ),
                          ),
                        ),
                        const _Link(
                          icon: LucideIcons.info,
                          title: 'App version',
                          value: '1.0.0',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 10),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: _muted,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, indent: 56, color: Color(0xFFF1F1EF)),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool>? onChanged;
  const _Toggle({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      activeTrackColor: const Color(0xFFA6D544),
      secondary: Icon(icon, size: 20, color: _ink),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _Link extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback? onTap;
  const _Link({
    required this.icon,
    required this.title,
    this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 20, color: _ink),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null)
            Text(value!, style: const TextStyle(fontSize: 13, color: _muted)),
          if (onTap != null) ...[
            const SizedBox(width: 6),
            const Icon(
              LucideIcons.chevronRight,
              size: 16,
              color: Color(0xFF9A9A9A),
            ),
          ],
        ],
      ),
      onTap: onTap,
    );
  }
}
