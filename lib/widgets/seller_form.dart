import 'package:flutter/material.dart';

const _ink = Color(0xFF1A1A1A);
const _muted = Color(0xFF6B6B6B);
const _green = Color(0xFF2E7D32);

/// Section heading with an optional line of guidance under it.
class SellerSection extends StatelessWidget {
  final String title;
  final String? hint;
  const SellerSection({super.key, required this.title, this.hint});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 14.5, fontWeight: FontWeight.w800)),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(hint!,
                style: const TextStyle(fontSize: 12.5, color: _muted)),
          ],
        ],
      ),
    );
  }
}

/// White rounded text field with a leading icon, used across both seller
/// forms so they stay one visual language.
class SellerField extends StatelessWidget {
  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final VoidCallback onChanged;
  final TextInputType? keyboard;
  final int maxLines;
  final String? prefix;
  const SellerField({
    super.key,
    required this.controller,
    required this.icon,
    required this.hint,
    required this.onChanged,
    this.keyboard,
    this.maxLines = 1,
    this.prefix,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 15),
            child: Icon(icon, size: 18, color: _muted),
          ),
          const SizedBox(width: 10),
          if (prefix != null)
            Padding(
              padding: const EdgeInsets.only(top: 14, right: 4),
              child: Text(prefix!,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboard,
              maxLines: maxLines,
              onChanged: (_) => onChanged(),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hint,
                hintStyle: const TextStyle(color: Color(0xFF9A9A9A)),
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
              ),
              style:
                  const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sticky bottom action. When something is missing it says what, rather
/// than leaving a dead grey button.
class SellerSubmitBar extends StatelessWidget {
  final String label;
  final String? blocker;
  final VoidCallback onSubmit;
  const SellerSubmitBar({
    super.key,
    required this.label,
    required this.blocker,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final ready = blocker == null;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F1EF),
        border: Border(top: BorderSide(color: Colors.black.withValues(alpha: 0.06))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!ready) ...[
            Text(blocker!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12.5, color: _muted)),
            const SizedBox(height: 8),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _green,
                disabledBackgroundColor: const Color(0xFFDDDDD9),
                disabledForegroundColor: const Color(0xFF8E8E88),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28)),
              ),
              onPressed: ready ? onSubmit : null,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Selectable pill used for single-choice rows (product category).
class SellerChoice extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const SellerChoice(
      {super.key,
      required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _ink : Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : _ink,
            )),
      ),
    );
  }
}
