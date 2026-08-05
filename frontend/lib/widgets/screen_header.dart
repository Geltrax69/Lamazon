import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Back button + centred title, the header every sub-screen uses.
class ScreenHeader extends StatelessWidget {
  final String title;
  final Widget? action;

  /// Runs instead of popping straight away. Return false to stay put — a
  /// screen with unsaved work uses this to ask first.
  final Future<bool> Function()? onBack;
  const ScreenHeader({
    super.key,
    required this.title,
    this.action,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () async {
              if (onBack != null && !await onBack!()) return;
              if (context.mounted) Navigator.pop(context);
            },
            child: Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.arrowLeft,
                size: 18,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ),
          // Flexible, so a long title or a wide action shortens the title
          // rather than running off the edge of a narrow phone.
          Flexible(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          SizedBox(width: 46, child: action),
        ],
      ),
    );
  }
}
