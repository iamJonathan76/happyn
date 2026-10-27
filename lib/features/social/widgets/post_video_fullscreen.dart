import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import 'package:happyn/core/providers/feed_video_provider.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:happyn/core/theme/app_text.dart';

/// La vidéo d'un moment, en plein écran et avec le son.
///
/// On l'ouvre au tap sur la vidéo du fil. Elle crée son propre lecteur à partir
/// de l'URL signée (le lecteur du fil reste muet et en boucle) : deux usages,
/// deux lecteurs, pas d'état partagé fragile. Le bouton son est synchronisé
/// avec la préférence du fil, pour que couper ici coupe aussi là-bas.
class PostVideoFullScreen extends ConsumerStatefulWidget {
  final String signedUrl;
  final String? posterUrl;
  final String authorName;
  final String authorAvatar;
  final String caption;
  final String? eventTitle;

  const PostVideoFullScreen({
    super.key,
    required this.signedUrl,
    this.posterUrl,
    this.authorName = '',
    this.authorAvatar = '',
    this.caption = '',
    this.eventTitle,
  });

  @override
  ConsumerState<PostVideoFullScreen> createState() =>
      _PostVideoFullScreenState();
}

class _PostVideoFullScreenState extends ConsumerState<PostVideoFullScreen> {
  VideoPlayerController? _controller;
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    // On arrive ici avec le son (le fil l'a activé en ouvrant) ; on reflète
    // quand même la préférence, au cas où.
    _muted = ref.read(feedVideoMutedProvider);
    _load();
  }

  Future<void> _load() async {
    final controller =
        VideoPlayerController.networkUrl(Uri.parse(widget.signedUrl));
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(_muted ? 0 : 1);
      await controller.play();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  void _toggleMute() {
    final muted = !_muted;
    setState(() => _muted = muted);
    _controller?.setVolume(muted ? 0 : 1);
    // Couper ou remettre le son ici vaut aussi pour le fil (préférence session).
    ref.read(feedVideoMutedProvider.notifier).state = muted;
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Widget _roundButton(IconData icon, VoidCallback onTap, String label) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: const BoxDecoration(
          color: Color(0x8C000000),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 22, semanticLabel: label),
      ),
    );
  }

  Widget _avatar() {
    if (widget.authorAvatar.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: widget.authorAvatar,
          width: 30,
          height: 30,
          fit: BoxFit.cover,
          errorWidget: (_, _, _) => _initials(),
        ),
      );
    }
    return _initials();
  }

  Widget _initials() {
    final letter =
        widget.authorName.isNotEmpty ? widget.authorName[0].toUpperCase() : '•';
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
      child: Text(letter,
          style: AppText.smallBold.copyWith(color: Colors.white)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready = controller != null && controller.value.isInitialized;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // La vidéo, centrée, tap = lecture/pause.
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                if (!ready) return;
                setState(() {
                  controller.value.isPlaying
                      ? controller.pause()
                      : controller.play();
                });
              },
              child: Center(
                child: ready
                    ? AspectRatio(
                        aspectRatio: controller.value.aspectRatio,
                        child: VideoPlayer(controller),
                      )
                    : (widget.posterUrl != null
                        ? CachedNetworkImage(
                            imageUrl: widget.posterUrl!, fit: BoxFit.contain)
                        : const CircularProgressIndicator(
                            color: AppColors.lavender)),
              ),
            ),
          ),

          // Grande pastille lecture quand on a mis en pause.
          if (ready && !controller.value.isPlaying)
            const IgnorePointer(
              child: Center(
                child: Icon(Icons.play_arrow, color: Colors.white, size: 64),
              ),
            ),

          // Haut : fermer (gauche), son (droite).
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _roundButton(
                        Icons.close, () => Navigator.of(context).pop(), 'Fermer'),
                    _roundButton(
                        _muted ? Icons.volume_off : Icons.volume_up,
                        _toggleMute,
                        _muted ? 'Activer le son' : 'Couper le son'),
                  ],
                ),
              ),
            ),
          ),

          // Bas : auteur, légende, barre de progression.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xCC000000), Color(0x00000000)],
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.authorName.isNotEmpty)
                      Row(
                        children: [
                          _avatar(),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              widget.eventTitle != null &&
                                      widget.eventTitle!.isNotEmpty
                                  ? '${widget.authorName} · ${widget.eventTitle}'
                                  : widget.authorName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.smallBold
                                  .copyWith(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    if (widget.caption.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        widget.caption,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.bodySm
                            .copyWith(color: Colors.white, height: 1.35),
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (ready)
                      ValueListenableBuilder<VideoPlayerValue>(
                        valueListenable: controller,
                        builder: (context, value, _) {
                          return Row(
                            children: [
                              Text(_fmt(value.position),
                                  style: AppText.micro
                                      .copyWith(color: Colors.white)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: VideoProgressIndicator(
                                  controller,
                                  allowScrubbing: true,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 6),
                                  colors: const VideoProgressColors(
                                    playedColor: Colors.white,
                                    bufferedColor: Color(0x55FFFFFF),
                                    backgroundColor: Color(0x33FFFFFF),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(_fmt(value.duration),
                                  style: AppText.micro
                                      .copyWith(color: Colors.white)),
                            ],
                          );
                        },
                      ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
