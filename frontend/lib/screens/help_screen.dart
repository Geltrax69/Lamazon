import 'package:flutter/material.dart';

import '../widgets/app_shell.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../widgets/screen_header.dart';

const _ink = Color(0xFF1A1A1A);
const _muted = Color(0xFF6B6B6B);

const _faqs = [
  (
    'Where is my order?',
    'Open My Orders and tap an order to see live status. Most deliveries '
        'arrive within 12–30 minutes of confirmation.',
  ),
  (
    'How do I cancel an order?',
    'You can cancel free of charge until the store accepts it. After that, '
        'contact support and we will check with the store.',
  ),
  (
    'When do I get my refund?',
    'Refunds are issued to the original payment method and usually land in '
        '3–5 business days.',
  ),
  (
    'Can I change my delivery address?',
    'Yes — pick a different saved address before checkout, or add a new one '
        'from Saved Addresses.',
  ),
  (
    'Why do prices differ between shops?',
    'Each shop sets its own price. Use Compare Prices on any product to see '
        'every nearby shop selling it.',
  ),
];

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F1EF),
      body: ReadableBody(
        maxWidth: 620,
        child: SafeArea(
          child: Column(
            children: [
              const ScreenHeader(title: 'Help & Support'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  children: [
                    Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          _ContactTile(
                            icon: LucideIcons.messageCircle,
                            title: 'Chat with us',
                            subtitle: 'Typically replies in under 2 minutes',
                          ),
                          const Divider(
                            height: 1,
                            indent: 56,
                            color: Color(0xFFF1F1EF),
                          ),
                          _ContactTile(
                            icon: LucideIcons.phone,
                            title: 'Call support',
                            subtitle: '1800-000-1234 · 8am – 11pm',
                          ),
                          const Divider(
                            height: 1,
                            indent: 56,
                            color: Color(0xFFF1F1EF),
                          ),
                          _ContactTile(
                            icon: LucideIcons.mail,
                            title: 'Email us',
                            subtitle: 'help@lamazon.app',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 10),
                      child: Text(
                        'Frequently asked',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      clipBehavior: Clip.antiAlias,
                      child: Theme(
                        // Hide the default ExpansionTile divider lines.
                        data: Theme.of(
                          context,
                        ).copyWith(dividerColor: Colors.transparent),
                        child: Column(
                          children: [
                            for (var i = 0; i < _faqs.length; i++) ...[
                              if (i > 0)
                                const Divider(
                                  height: 1,
                                  indent: 20,
                                  color: Color(0xFFF1F1EF),
                                ),
                              ExpansionTile(
                                title: Text(
                                  _faqs[i].$1,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                iconColor: _ink,
                                collapsedIconColor: const Color(0xFF9A9A9A),
                                childrenPadding: const EdgeInsets.fromLTRB(
                                  20,
                                  0,
                                  20,
                                  14,
                                ),
                                expandedCrossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _faqs[i].$2,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: _muted,
                                      height: 1.45,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Center(
                      child: Text(
                        'Lamazon · v1.0.0',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9A9A9A),
                        ),
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
  }
}

class _ContactTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _ContactTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 20, color: _ink),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: _muted),
      ),
      trailing: const Icon(
        LucideIcons.chevronRight,
        size: 16,
        color: Color(0xFF9A9A9A),
      ),
      onTap: () {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('$title — coming soon'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 1),
            ),
          );
      },
    );
  }
}
