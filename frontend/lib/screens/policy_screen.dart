import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/api.dart';
import '../data/policy_text.dart';
import '../widgets/app_shell.dart';
import '../widgets/design_system.dart';
import '../widgets/screen_header.dart';

const _ink = LamazonTheme.text;
// The system's muted, not a cool grey of this screen's own.
const _muted = LamazonTheme.muted;

/// One written document. The text lives in the database so an admin can change
/// it without a deploy — a refund policy that needs an engineer is a refund
/// policy that stays wrong.
class PolicyDoc {
  final String slug;
  final String title;
  final String body;

  /// False while the draft still has blanks in it, in which case the server
  /// sends a placeholder rather than a half-written contract. The sign-in
  /// screen reads this before deciding whether it can ask anyone to agree.
  final bool published;

  /// When it last changed. Null for the bundled offline copies, which have
  /// no date to claim.
  final DateTime? updatedAt;
  const PolicyDoc({
    required this.slug,
    required this.title,
    required this.body,
    this.published = false,
    this.updatedAt,
  });

  factory PolicyDoc.fromJson(Map<String, dynamic> r) => PolicyDoc(
    slug: r['slug'] as String? ?? '',
    title: r['title'] as String? ?? '',
    body: r['body'] as String? ?? '',
    published: r['published'] as bool? ?? false,
    updatedAt: DateTime.tryParse(r['updatedAt'] as String? ?? ''),
  );

  IconData get icon => switch (slug) {
    'privacy' => LucideIcons.shieldCheck,
    'shipping' => LucideIcons.truck,
    'refunds' => LucideIcons.receipt,
    'contact' => LucideIcons.mail,
    _ => LucideIcons.fileText,
  };
}

/// What the app shipped with, for a phone with no signal and for the first
/// frame before the server answers.
///
/// It shows the text rather than an apology for not having it. That apology
/// was right while the shipped copy was a template full of blanks; it is the
/// wrong answer now that the bundled copy is the same document the server
/// seeds. The live text is still the database's — this is only what a phone
/// with no signal reads — and the date at the top is absent rather than
/// guessed, which is the honest difference between the two.
List<PolicyDoc> get bundledPolicies => [
  for (final p in shippedPolicies)
    PolicyDoc(
      slug: p['slug']!,
      title: p['title']!,
      body: p['body']!,
      published: true,
    ),
];

/// Loaded once and kept, so opening a second policy does not re-fetch.
List<PolicyDoc>? _cache;

Future<List<PolicyDoc>> loadPolicies({
  bool refresh = false,
  bool admin = false,
}) async {
  if (admin) {
    return [
      for (final row in await Api.instance.adminPolicies())
        PolicyDoc.fromJson(row as Map<String, dynamic>),
    ];
  }
  if (_cache != null && !refresh) return _cache!;
  try {
    final rows = await Api.instance.policies();
    if (rows.isNotEmpty) {
      _cache = [
        for (final r in rows) PolicyDoc.fromJson(r as Map<String, dynamic>),
      ];
      return _cache!;
    }
  } catch (e) {
    logApiFailure('policies', e);
  }
  // Not cached: the bundled text is a stand-in, and the next open should try
  // the server again rather than settle for it.
  return bundledPolicies;
}

class PolicyScreen extends StatefulWidget {
  final String slug;
  const PolicyScreen({super.key, required this.slug});

  @override
  State<PolicyScreen> createState() => _PolicyScreenState();
}

class _PolicyScreenState extends State<PolicyScreen> {
  late final Future<List<PolicyDoc>> _future = loadPolicies();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LamazonTheme.canvas,
      body: ReadableBody(
        maxWidth: 700,
        child: SafeArea(
          child: FutureBuilder<List<PolicyDoc>>(
            future: _future,
            builder: (context, snap) {
              final docs = snap.data ?? bundledPolicies;
              final doc = docs.firstWhere(
                (d) => d.slug == widget.slug,
                orElse: () => bundledPolicies.firstWhere(
                  (d) => d.slug == widget.slug,
                  orElse: () => const PolicyDoc(
                    slug: '',
                    title: 'Policy',
                    body: 'This policy has not been written yet.',
                  ),
                ),
              );
              return Column(
                children: [
                  ScreenHeader(title: doc.title),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                      children: [
                        // A policy with no date is a policy you cannot tell
                        // is current. The API has always returned it.
                        if (doc.published && doc.updatedAt != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Text(
                              'Last updated ${_asDate(doc.updatedAt!)}',
                              style: LamazonTheme.mutedBodyText,
                            ),
                          ),
                        PolicyBody(text: doc.body),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Renders the one piece of formatting the text has: a line beginning "## "
/// is a heading, everything else is a paragraph. Anything more would be a
/// markdown dependency for a document nobody writes markdown in.
class PolicyBody extends StatelessWidget {
  final String text;
  const PolicyBody({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final blocks = text.split(RegExp(r'\n\s*\n'));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final block in blocks)
          if (block.trim().isNotEmpty)
            if (block.trimLeft().startsWith('## '))
              Padding(
                padding: const EdgeInsets.only(top: 18, bottom: 6),
                child: Text(
                  block.trimLeft().substring(3).trim(),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  // Hard-wrapped source, soft-wrapped on screen: the text is
                  // stored at 78 columns and a phone is not 78 columns wide.
                  block.trim().replaceAll(RegExp(r'(?<!\n)\n(?![-\n])'), ' '),
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.55,
                    color: Color(0xFF3A3A3A),
                  ),
                ),
              ),
      ],
    );
  }
}

/// Every policy, for a settings or help screen to list.
class PolicyLinks extends StatelessWidget {
  const PolicyLinks({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PolicyDoc>>(
      future: loadPolicies(),
      builder: (context, snap) {
        final docs = snap.data ?? bundledPolicies;
        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final (i, doc) in docs.indexed) ...[
                if (i > 0) const Divider(height: 1, indent: 56),
                ListTile(
                  leading: Icon(doc.icon, size: 19, color: _ink),
                  title: Text(
                    doc.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: const Icon(
                    LucideIcons.chevronRight,
                    size: 16,
                    color: _muted,
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PolicyScreen(slug: doc.slug),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// "3 September 2026". No intl dependency for one date on one screen.
String _asDate(DateTime d) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  final local = d.toLocal();
  return '${local.day} ${months[local.month - 1]} ${local.year}';
}
