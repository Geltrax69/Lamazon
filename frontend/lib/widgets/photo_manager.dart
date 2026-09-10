import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'design_system.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'photo_cropper.dart';
import 'photo_picker.dart';
import 'product_card.dart';

const _ink = LamazonTheme.text;
const _muted = LamazonTheme.muted;
const _red = LamazonTheme.danger;

/// Every product photo goes in at this shape, so a grid of them lines up
/// instead of each tile cropping its own way. Square, because a product tile
/// and a search result are both square and the details gallery is happy with
/// either.
const productAspect = 1.0;

/// One picture in a listing, whether it is already on the server or was picked
/// a moment ago and has not been uploaded yet.
///
/// Both live in one list because reordering has to work across the join: a
/// photo added today can be dragged in front of one added last week, and a
/// model that kept them apart could not express that.
class Shot {
  /// Set for a photo the server already has.
  final String? url;

  /// Set for one picked on this screen and not yet uploaded.
  final Uint8List? bytes;

  const Shot.remote(this.url) : bytes = null;
  const Shot.local(this.bytes) : url = null;

  bool get isNew => bytes != null;
}

/// The photos of one product: reorder by dragging, remove with the ×, add more
/// with the last tile. The first is the cover and says so.
///
/// Nothing here talks to the network. The screen owns saving, because the
/// seller's add-product form has no item to upload to yet and the edit screens
/// do — one widget, two lifetimes.
class PhotoManager extends StatelessWidget {
  final List<Shot> shots;
  final ValueChanged<List<Shot>> onChanged;

  /// Shown while an upload or a reorder is in flight, so the grid cannot be
  /// dragged into a different order than the one being saved.
  final bool busy;
  const PhotoManager({
    super.key,
    required this.shots,
    required this.onChanged,
    this.busy = false,
  });

  Future<void> _add(BuildContext context) async {
    final picked = await pickPhotos(multiple: true);
    if (picked.isEmpty || !context.mounted) return;
    final out = <Shot>[...shots];
    for (final photo in picked) {
      if (!context.mounted) break;
      // Cropped one at a time rather than in a batch: framing five photos
      // before seeing any of them land is a lot to ask on faith.
      final cropped = await cropPhoto(
        context,
        photo,
        aspect: productAspect,
        title: 'Frame the photo',
      );
      out.add(Shot.local(cropped ?? photo));
    }
    onChanged(out);
  }

  Future<void> _recrop(BuildContext context, int i) async {
    final shot = shots[i];
    if (shot.bytes == null) return; // an uploaded one is already square
    final cropped = await cropPhoto(
      context,
      shot.bytes!,
      aspect: productAspect,
      title: 'Frame the photo',
    );
    if (cropped == null) return;
    final out = [...shots];
    out[i] = Shot.local(cropped);
    onChanged(out);
  }

  @override
  Widget build(BuildContext context) {
    if (shots.isEmpty) {
      return _AddBox(onTap: busy ? null : () => _add(context));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 128,
          child: ReorderableListView.builder(
            scrollDirection: Axis.horizontal,
            buildDefaultDragHandles: false,
            itemCount: shots.length,
            onReorder: busy
                ? (_, _) {}
                : (from, to) {
                    final out = [...shots];
                    // ReorderableListView reports the destination as if the
                    // dragged item were still in place, so moving right is
                    // one index too far.
                    if (to > from) to -= 1;
                    out.insert(to, out.removeAt(from));
                    onChanged(out);
                  },
            proxyDecorator: (child, _, _) => Material(
              color: Colors.transparent,
              elevation: 6,
              borderRadius: BorderRadius.circular(14),
              child: child,
            ),
            itemBuilder: (context, i) => ReorderableDragStartListener(
              key: ValueKey(shots[i].url ?? shots[i].bytes.hashCode),
              index: i,
              enabled: !busy,
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _Tile(
                  shot: shots[i],
                  cover: i == 0,
                  onRemove: busy
                      ? null
                      : () => onChanged([...shots]..removeAt(i)),
                  onRecrop: busy || !shots[i].isNew
                      ? null
                      : () => _recrop(context, i),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            TextButton.icon(
              onPressed: busy ? null : () => _add(context),
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text('Add photos'),
              style: TextButton.styleFrom(foregroundColor: _ink),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                busy
                    ? 'Saving…'
                    : 'Drag to reorder — the first one is the cover.',
                style: const TextStyle(fontSize: 12, color: _muted),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  final Shot shot;
  final bool cover;
  final VoidCallback? onRemove;
  final VoidCallback? onRecrop;
  const _Tile({
    required this.shot,
    required this.cover,
    required this.onRemove,
    required this.onRecrop,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 112,
      height: 128,
      child: Stack(
        children: [
          Positioned.fill(
            bottom: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: shot.isNew
                  ? Image.memory(shot.bytes!, fit: BoxFit.cover)
                  : NetImage(url: shot.url!),
            ),
          ),
          if (cover)
            Positioned(
              left: 6,
              top: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _ink,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Cover',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          Positioned(
            right: 4,
            top: 4,
            child: _Round(icon: LucideIcons.x, colour: _red, onTap: onRemove),
          ),
          if (onRecrop != null)
            Positioned(
              right: 4,
              bottom: 22,
              child: _Round(icon: LucideIcons.crop, onTap: onRecrop),
            ),
          // Under the picture rather than over it: a handle on top of a photo
          // is a handle covering the thing you are trying to look at.
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Icon(LucideIcons.gripHorizontal, size: 14, color: _muted),
          ),
        ],
      ),
    );
  }
}

class _Round extends StatelessWidget {
  final IconData icon;
  final Color colour;
  final VoidCallback? onTap;
  const _Round({required this.icon, required this.onTap, this.colour = _ink});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)],
        ),
        child: Icon(icon, size: 12, color: onTap == null ? _muted : colour),
      ),
    );
  }
}

class _AddBox extends StatelessWidget {
  final VoidCallback? onTap;
  const _AddBox({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFDDDDD8)),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
              'Every photo is framed square, so the shop lines up',
              style: TextStyle(fontSize: 12, color: _muted),
            ),
          ],
        ),
      ),
    );
  }
}
