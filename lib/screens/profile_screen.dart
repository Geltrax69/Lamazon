import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/session.dart';
import 'addresses_screen.dart';
import 'help_screen.dart';
import 'login_screen.dart';
import 'notifications_screen.dart';
import 'orders_screen.dart';
import 'settings_screen.dart';

const _ink = Color(0xFF1A1A1A);
const _muted = Color(0xFF6B6B6B);
const _green = Color(0xFF2E7D32);

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F1EF),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Session.instance,
          builder: (context, _) {
            final loggedIn = Session.instance.loggedIn;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: const BoxDecoration(
                            color: Colors.white, shape: BoxShape.circle),
                        child: const Icon(LucideIcons.arrowLeft,
                            size: 18, color: _ink),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Center(
                  child: Container(
                    width: 92,
                    height: 92,
                    decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: const Icon(LucideIcons.user, size: 44, color: _ink),
                  ),
                ),
                const SizedBox(height: 14),
                const Center(
                  child: Text('Your account',
                      style: TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    loggedIn
                        ? '+91 ${Session.instance.maskedPhone}'
                        : 'Log in to view your complete profile',
                    style: const TextStyle(fontSize: 14, color: _muted),
                  ),
                ),
                const SizedBox(height: 18),
                if (!loggedIn)
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _green,
                      side: const BorderSide(color: _green),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pushReplacement(context,
                        MaterialPageRoute(builder: (_) => const LoginScreen())),
                    child: const Text('Continue',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _Tile(
                      icon: LucideIcons.package,
                      label: 'Your orders',
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const OrdersScreen())),
                    ),
                    const SizedBox(width: 10),
                    _Tile(
                      icon: LucideIcons.wallet,
                      label: 'Lamazon Money',
                      onTap: () => _soon(context, 'Lamazon Money'),
                    ),
                    const SizedBox(width: 10),
                    _Tile(
                      icon: LucideIcons.messageCircle,
                      label: 'Need help?',
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const HelpScreen())),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _Card(children: [
                  _Row(
                    icon: LucideIcons.settings,
                    label: 'Settings',
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const SettingsScreen())),
                  ),
                ]),
                const _SectionTitle('Your information'),
                _Card(children: [
                  _Row(
                    icon: LucideIcons.bookOpen,
                    label: 'Address book',
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const AddressesScreen())),
                  ),
                  _Row(
                    icon: LucideIcons.bell,
                    label: 'Notifications',
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const NotificationsScreen())),
                  ),
                ]),
                const _SectionTitle('Other Information'),
                _Card(children: [
                  _Row(
                    icon: LucideIcons.share,
                    label: 'Share the app',
                    onTap: () => _soon(context, 'Share the app'),
                  ),
                  _Row(
                    icon: LucideIcons.info,
                    label: 'About us',
                    onTap: () => _soon(context, 'About us'),
                  ),
                  _Row(
                    icon: LucideIcons.store,
                    label: 'Sell on Lamazon',
                    onTap: () => _soon(context, 'Seller sign-up'),
                  ),
                ]),
                if (loggedIn) ...[
                  const SizedBox(height: 14),
                  _Card(children: [
                    _Row(
                      icon: LucideIcons.logOut,
                      label: 'Log out',
                      color: const Color(0xFFD32F2F),
                      onTap: () {
                        Session.instance.logout();
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(const SnackBar(
                            content: Text('Logged out'),
                            behavior: SnackBarBehavior.floating,
                            duration: Duration(seconds: 1),
                          ));
                      },
                    ),
                  ]),
                ],
                const SizedBox(height: 26),
                Center(
                  child: Opacity(
                    opacity: 0.25,
                    child: Image.asset('assets/banner.png', width: 190),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

void _soon(BuildContext context, String what) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text('$what — coming soon'),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 1),
    ));
}

/// One of the three square shortcuts under the account header.
class _Tile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Tile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
            child: Column(
              children: [
                Icon(icon, size: 24, color: _ink),
                const SizedBox(height: 10),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
      child: Text(text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
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
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, indent: 52, color: Color(0xFFF1F1EF)),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;
  const _Row(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.color});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 20, color: color ?? _ink),
      title: Text(label,
          style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: color ?? _ink)),
      trailing: const Icon(LucideIcons.chevronRight,
          size: 16, color: Color(0xFF9A9A9A)),
      onTap: onTap,
    );
  }
}
