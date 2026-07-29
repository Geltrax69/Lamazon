import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Back button + centred title, the header every sub-screen uses.
class ScreenHeader extends StatelessWidget {
  final String title;
  final Widget? action;
  const ScreenHeader({super.key, required this.title, this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
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
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          SizedBox(width: 46, child: action),
        ],
      ),
    );
  }
}
