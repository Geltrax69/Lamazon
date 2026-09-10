import 'package:flutter/material.dart';

class Campaign {
  final String id, title, subtitle, cta, category, department, imageUrl, colour;
  final bool enabled;
  final int position;
  const Campaign({
    required this.id,
    required this.title,
    required this.subtitle,
    this.cta = 'Shop collection',
    this.category = '',
    this.department = '',
    this.imageUrl = '',
    this.colour = '#F2E8CE',
    this.enabled = true,
    this.position = 0,
  });

  factory Campaign.fromJson(Map<String, dynamic> r) => Campaign(
    id: r['id'] as String,
    title: r['title'] as String,
    subtitle: r['subtitle'] as String? ?? '',
    cta: r['cta'] as String? ?? 'Shop collection',
    category: r['category'] as String? ?? '',
    department: r['department'] as String? ?? '',
    imageUrl: r['imageUrl'] as String? ?? '',
    colour: r['colour'] as String? ?? '#F2E8CE',
    enabled: r['enabled'] as bool? ?? true,
    position: (r['position'] as num?)?.toInt() ?? 0,
  );
  /// The same banner with different artwork. The editor previews a URL that
  /// trails the field by a moment, and must not save that trailing copy.
  Campaign withArtwork(String url) => Campaign(
    id: id,
    title: title,
    subtitle: subtitle,
    cta: cta,
    category: category,
    department: department,
    imageUrl: url,
    colour: colour,
    enabled: enabled,
    position: position,
  );

  Color get background => Color(
    0xFF000000 |
        (int.tryParse(colour.replaceFirst('#', ''), radix: 16) ?? 0xF2E8CE),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'cta': cta,
    'category': category,
    'department': department,
    'imageUrl': imageUrl,
    'colour': colour,
    'enabled': enabled,
    'position': position,
  };
}

// Only for older/unreachable APIs. A successful empty response means staff
// deliberately hid every banner, and must stay empty.
const starterCampaign = Campaign(
  id: 'everyday',
  title: 'Little joys. Everyday.',
  subtitle: 'Your local favourites, all in one place.',
  cta: 'Explore the collection',
);
