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
  // ponytail: in-memory only. Persist with shared_preferences the day a
  // setting has to survive a restart.
  bool _push = true;
  bool _email = false;
  bool _orderUpdates = true;
  bool _location = true;

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
                    const _SectionLabel('Notifications'),
                    _Card(
                      children: [
                        _Toggle(
                          icon: LucideIcons.bell,
                          title: 'Push notifications',
                          value: _push,
                          onChanged: (v) => setState(() => _push = v),
                        ),
                        _Toggle(
                          icon: LucideIcons.mail,
                          title: 'Email offers',
                          value: _email,
                          onChanged: (v) => setState(() => _email = v),
                        ),
                        _Toggle(
                          icon: LucideIcons.truck,
                          title: 'Order updates',
                          value: _orderUpdates,
                          onChanged: (v) => setState(() => _orderUpdates = v),
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
                        _Toggle(
                          icon: LucideIcons.navigation,
                          title: 'Use my location',
                          value: _location,
                          onChanged: (v) => setState(() => _location = v),
                        ),
                        _Link(
                          icon: LucideIcons.wallet,
                          title: 'Payment methods',
                          onTap: () => _soon(context, 'Payment methods'),
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
                          onTap: () => _soon(context, 'Language'),
                        ),
                        _Link(
                          icon: LucideIcons.indianRupee,
                          title: 'Currency',
                          value: 'INR (₹)',
                          onTap: () => _soon(context, 'Currency'),
                        ),
                      ],
                    ),
                    const _SectionLabel('About'),
                    _Card(
                      children: [
                        _Link(
                          icon: LucideIcons.shield,
                          title: 'Privacy policy',
                          onTap: () => _soon(context, 'Privacy policy'),
                        ),
                        _Link(
                          icon: LucideIcons.fileText,
                          title: 'Terms of service',
                          onTap: () => _soon(context, 'Terms of service'),
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

void _soon(BuildContext context, String what) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('$what — coming soon'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
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
  final ValueChanged<bool> onChanged;
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
