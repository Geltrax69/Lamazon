import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

const _ink = Color(0xFF1A1A1A);

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const _items = [
    (LucideIcons.package, 'My Orders'),
    (LucideIcons.mapPin, 'Saved Addresses'),
    (LucideIcons.wallet, 'Payment Methods'),
    (LucideIcons.bell, 'Notifications'),
    (LucideIcons.circleHelp, 'Help & Support'),
    (LucideIcons.settings, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F1EF),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
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
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                      color: Color(0xFFA6D544), shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: const Text('L',
                      style: TextStyle(
                          fontSize: 26, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Lalit Singh',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                    SizedBox(height: 2),
                    Text('lalitsinghnoaim@gmail.com',
                        style: TextStyle(
                            fontSize: 13, color: Color(0xFF6B6B6B))),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < _items.length; i++) ...[
                    if (i > 0)
                      const Divider(
                          height: 1, indent: 56, color: Color(0xFFF1F1EF)),
                    ListTile(
                      leading: Icon(_items[i].$1, size: 20, color: _ink),
                      title: Text(_items[i].$2,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      trailing: const Icon(LucideIcons.chevronRight,
                          size: 16, color: Color(0xFF9A9A9A)),
                      onTap: () {
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(SnackBar(
                            content:
                                Text('${_items[i].$2} — coming soon'),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 1),
                          ));
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: ListTile(
                leading: const Icon(LucideIcons.logOut,
                    size: 20, color: Color(0xFFD32F2F)),
                title: const Text('Log Out',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFD32F2F))),
                onTap: () {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(const SnackBar(
                      content: Text('Sign-in flow coming soon'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 1),
                    ));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
