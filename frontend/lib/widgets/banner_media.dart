import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../data/catalog.dart';
import 'design_system.dart';

/// A campaign banner's artwork: a photograph, an animation, or a short clip.
///
/// Which one it is comes off the URL, so nothing about a banner row changes
/// when staff swap a picture for a video — the same field holds both.
///
/// Anything with frames — a GIF as much as an MP4 — is played as a video.
/// GIF as a delivery format is the difference between 6.2 MB and 134 KB for
/// the same seconds of animation, which is a real cost to a real shopper on a
/// real phone; see [bannerVideo].
///
/// Motion here is decoration behind a headline, not something anyone came to
/// watch, so a clip is muted, looped and has no controls. Under reduced
/// motion it does not play at all: WCAG 2.2.2 asks for a way to stop anything
/// that moves by itself for more than five seconds, and someone who has
/// already asked the system for stillness has given that answer in advance.
/// They get the first frame, which is the same picture without the movement.
class BannerMedia extends StatelessWidget {
  final String url;
  const BannerMedia({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    // An animation goes to the player only when it can actually be delivered
    // as a clip. A GIF hosted somewhere we cannot transform stays a GIF, and
    // Image.network animates one of those natively — which also means such a
    // banner keeps moving under reduced motion, the one hole here. Everything
    // staff upload goes through Cloudinary, so it is a hole you have to paste
    // a foreign URL to reach.
    final kind = bannerKind(url);
    final plays =
        kind == BannerKind.video ||
        (kind == BannerKind.animation && bannerVideo(url) != url);
    if (!still && plays) return _Clip(url: url);
    return _poster(url, still: still);
  }
}

/// The banner drawn as a picture. For an animation this is the animation
/// itself unless [still], which asks Cloudinary for its first frame.
Widget _poster(String url, {required bool still}) {
  if (url.trim().isEmpty) return const ColoredBox(color: Color(0xFFF0F1EB));
  return Image.network(
    bannerArtwork(url, still: still),
    fit: BoxFit.cover,
    excludeFromSemantics: true,
    loadingBuilder: (_, child, progress) =>
        progress == null ? child : const Skeleton(),
    errorBuilder: (_, error, _) {
      debugPrint('BannerMedia error [$url]: $error');
      return const ColoredBox(color: Color(0xFFF0F1EB));
    },
  );
}

class _Clip extends StatefulWidget {
  final String url;
  const _Clip({required this.url});
  @override
  State<_Clip> createState() => _ClipState();
}

class _ClipState extends State<_Clip> {
  VideoPlayerController? _player;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(_Clip old) {
    super.didUpdateWidget(old);
    if (old.url == widget.url) return;
    _player?.dispose();
    _player = null;
    _start();
  }

  Future<void> _start() async {
    final player = VideoPlayerController.networkUrl(
      Uri.parse(bannerVideo(widget.url)),
    );
    try {
      await player.initialize();
    } catch (error) {
      // A banner is not worth a broken home screen. The poster stays up.
      debugPrint('BannerMedia clip [${widget.url}]: $error');
      await player.dispose();
      return;
    }
    if (!mounted) {
      await player.dispose();
      return;
    }
    // Muted before it plays, not after: a browser only grants autoplay to a
    // video that is already silent, and setVolume(0) is what sets `muted`.
    await player.setVolume(0);
    await player.setLooping(true);
    // A blocked autoplay is a still frame, which is a banner. It is not a
    // failure worth tearing the player down for.
    unawaited(player.play());
    setState(() => _player = player);
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = _player;
    // The poster carries the banner until the first frame arrives, and keeps
    // carrying it if the clip never does — a dead video element is a hole in
    // the middle of the home screen.
    if (player == null) return _poster(widget.url, still: true);
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: player.value.size.width,
        height: player.value.size.height,
        child: VideoPlayer(player),
      ),
    );
  }
}
