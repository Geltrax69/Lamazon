import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'photo_cropper.dart';

const _ink = Color(0xFF1A1A1A);
const _muted = Color(0xFF6B6B6B);

/// ponytail: images live in memory as bytes, which is all a device-picked
/// file is before an upload API exists. Swap _pick() for the upload call
/// and keep returning something renderable.
Future<List<Uint8List>> pickPhotos({required bool multiple}) async {
  final picker = ImagePicker();
  final files = multiple
      ? await picker.pickMultiImage(imageQuality: 80)
      : [
          ?await picker.pickImage(
            source: ImageSource.gallery,
            imageQuality: 80,
          ),
        ];
  return [for (final f in files) await f.readAsBytes()];
}

/// One big tappable tile for a single photo — empty prompt, or the picture
/// with replace and remove over it.
class PhotoTile extends StatelessWidget {
  final Uint8List? photo;
  final String emptyLabel;
  final String emptyHint;
  final double height;
  final ValueChanged<Uint8List?> onChanged;

  /// The shape the photo will be shown in. Cropping to it here means the
  /// person decides what gets cut off, rather than BoxFit.cover deciding for
  /// them at the moment a shopper looks at the card.
  final double aspect;

  const PhotoTile({
    super.key,
    required this.photo,
    required this.onChanged,
    this.emptyLabel = 'Add a photo',
    this.emptyHint = 'JPG or PNG from your device',
    this.height = 150,
    this.aspect = 16 / 9,
  });

  Future<void> _pick(BuildContext context) async {
    final picked = await pickPhotos(multiple: false);
    if (picked.isEmpty || !context.mounted) return;
    // Straight into the cropper: framing it is part of choosing it, and a
    // separate "now adjust it" step is one most people would skip.
    final cropped = await cropPhoto(context, picked.first, aspect: aspect);
    onChanged(cropped ?? picked.first);
  }

  Future<void> _adjust(BuildContext context) async {
    final cropped = await cropPhoto(context, photo!, aspect: aspect);
    if (cropped != null) onChanged(cropped);
  }

  @override
  Widget build(BuildContext context) {
    if (photo == null) {
      return _DashedBox(
        height: height,
        onTap: () => _pick(context),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.imagePlus, size: 26, color: _muted),
            const SizedBox(height: 8),
            Text(
              emptyLabel,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              emptyHint,
              style: const TextStyle(fontSize: 12, color: _muted),
            ),
          ],
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(photo!, fit: BoxFit.cover),
            Positioned(
              right: 10,
              bottom: 10,
              child: Row(
                children: [
                  _OverlayButton(
                    icon: LucideIcons.crop,
                    label: 'Adjust',
                    onTap: () => _adjust(context),
                  ),
                  const SizedBox(width: 8),
                  _OverlayButton(
                    icon: LucideIcons.repeat2,
                    onTap: () => _pick(context),
                  ),
                  const SizedBox(width: 8),
                  _OverlayButton(
                    icon: LucideIcons.trash2,
                    onTap: () => onChanged(null),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A scrolling strip of product photos: first one is the cover, plus a tile
/// to add more. No cap on how many.
class PhotoStrip extends StatelessWidget {
  final List<Uint8List> photos;
  final ValueChanged<List<Uint8List>> onChanged;
  const PhotoStrip({super.key, required this.photos, required this.onChanged});

  Future<void> _add() async {
    final picked = await pickPhotos(multiple: true);
    if (picked.isNotEmpty) onChanged([...photos, ...picked]);
  }

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
      return _DashedBox(
        height: 150,
        onTap: _add,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(LucideIcons.imagePlus, size: 26, color: _muted),
            SizedBox(height: 8),
            Text(
              'Add photos',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Pick as many as you like — first one is the cover',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: _muted),
            ),
          ],
        ),
      );
    }
    return SizedBox(
      height: 116,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          if (i == photos.length) {
            return _DashedBox(
              width: 104,
              height: 116,
              onTap: _add,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(LucideIcons.plus, size: 22, color: _muted),
                  SizedBox(height: 6),
                  Text(
                    'Add more',
                    style: TextStyle(fontSize: 12, color: _muted),
                  ),
                ],
              ),
            );
          }
          return SizedBox(
            width: 104,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.memory(photos[i], fit: BoxFit.cover),
                  ),
                ),
                if (i == 0)
                  Positioned(
                    left: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Text(
                        'Cover',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  right: 4,
                  top: 4,
                  child: _OverlayButton(
                    icon: LucideIcons.x,
                    small: true,
                    onTap: () => onChanged([...photos]..removeAt(i)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Renders a seller photo, falling back to a neutral placeholder so a row
/// never collapses when there is no picture yet.
class PhotoOrPlaceholder extends StatelessWidget {
  final Uint8List? photo;
  final double size;
  final double radius;
  const PhotoOrPlaceholder({
    super.key,
    required this.photo,
    required this.size,
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: photo == null
            ? Container(
                color: const Color(0xFFE8E8E4),
                alignment: Alignment.center,
                child: Icon(
                  LucideIcons.image,
                  size: size * 0.34,
                  color: Colors.grey,
                ),
              )
            : Image.memory(photo!, fit: BoxFit.cover),
      ),
    );
  }
}

class _DashedBox extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final double height;
  final double? width;
  const _DashedBox({
    required this.child,
    required this.onTap,
    required this.height,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: height,
        width: width ?? double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD9D9D4), width: 1.4),
        ),
        child: child,
      ),
    );
  }
}

class _OverlayButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final VoidCallback onTap;
  final bool small;
  const _OverlayButton({
    required this.icon,
    required this.onTap,
    this.label,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: small ? 5 : 12,
            vertical: small ? 5 : 8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: small ? 13 : 15, color: Colors.white),
              if (label != null) ...[
                const SizedBox(width: 6),
                Text(
                  label!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
