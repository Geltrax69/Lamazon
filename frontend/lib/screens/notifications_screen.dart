import 'package:flutter/material.dart';

import '../widgets/app_shell.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../widgets/screen_header.dart';

const _ink = Color(0xFF1A1A1A);
const _muted = Color(0xFF6B6B6B);

class AppNotification {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final String time;
  bool read;

  AppNotification({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    required this.time,
    this.read = false,
  });
}

// ponytail: top-level list so read state survives navigation. Swap for a
// server feed later; only this list changes.
final notifications = [
  AppNotification(
    icon: LucideIcons.truck,
    color: const Color(0xFF43A047),
    title: 'Order out for delivery',
    body: 'Your order #LMZ-2481 arrives in about 12 mins.',
    time: '2m ago',
  ),
  AppNotification(
    icon: LucideIcons.tag,
    color: const Color(0xFFEF6C00),
    title: '40% off at Velora Store',
    body: 'Trending fashion picks are discounted till midnight.',
    time: '1h ago',
  ),
  AppNotification(
    icon: LucideIcons.wallet,
    color: const Color(0xFF1E88E5),
    title: 'Payment successful',
    body: '₹1,299 paid for order #LMZ-2475.',
    time: '5h ago',
    read: true,
  ),
  AppNotification(
    icon: LucideIcons.heart,
    color: const Color(0xFFD81B60),
    title: 'Back in stock',
    body: 'An item on your wishlist is available again.',
    time: 'Yesterday',
    read: true,
  ),
  AppNotification(
    icon: LucideIcons.star,
    color: const Color(0xFFA6D544),
    title: 'Rate your last order',
    body: 'Tell us how Spice Kitchen did.',
    time: '2d ago',
    read: true,
  ),
];

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  Widget build(BuildContext context) {
    final unread = notifications.where((n) => !n.read).length;
    return Scaffold(
      backgroundColor: const Color(0xFFF1F1EF),
      body: ReadableBody(
        maxWidth: 620,
        child: SafeArea(
          child: Column(
            children: [
              ScreenHeader(
                title: 'Notifications',
                action: unread == 0
                    ? null
                    : IconButton(
                        tooltip: 'Mark all read',
                        icon: const Icon(
                          LucideIcons.checkCheck,
                          size: 20,
                          color: _ink,
                        ),
                        onPressed: () => setState(() {
                          for (final n in notifications) {
                            n.read = true;
                          }
                        }),
                      ),
              ),
              if (unread > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '$unread unread',
                    style: const TextStyle(fontSize: 12, color: _muted),
                  ),
                ),
              Expanded(
                child: notifications.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              LucideIcons.bellOff,
                              size: 44,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'No notifications yet',
                              style: TextStyle(fontSize: 15, color: _muted),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                        itemCount: notifications.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final n = notifications[i];
                          return Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => setState(() => n.read = true),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: n.color.withValues(alpha: 0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        n.icon,
                                        size: 18,
                                        color: n.color,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  n.title,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: n.read
                                                        ? FontWeight.w600
                                                        : FontWeight.w800,
                                                  ),
                                                ),
                                              ),
                                              if (!n.read)
                                                Container(
                                                  width: 8,
                                                  height: 8,
                                                  decoration:
                                                      const BoxDecoration(
                                                        color: Color(
                                                          0xFFA6D544,
                                                        ),
                                                        shape: BoxShape.circle,
                                                      ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            n.body,
                                            style: const TextStyle(
                                              fontSize: 12.5,
                                              color: _muted,
                                              height: 1.35,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            n.time,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF9A9A9A),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
