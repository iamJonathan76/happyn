import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'package:happyn/core/theme/app_colors.dart';

/// La vidéo d'un moment, en plein écran et avec le son.
///
/// On ouvre cet écran au tap sur la vidéo du fil. Il crée son propre lecteur à
/// partir de l'URL signée (le lecteur du fil, lui, reste muet et en boucle) :
/// deux usages, deux lecteurs, pas d'état partagé fragile.
///
/// Version de base (écran 3) : lecture avec son, boucle, fermeture. Les
/// finitions — barre de progression, légende, bouton son — viennent à l'écran 4.
class PostVideoFullScreen extends StatefulWidget {
  final String signedUrl;
  final String? posterUrl;

  const PostVideoFullScreen({
    super.key,
    required this.signedUrl,
    this.posterUrl,
  });

  @override
  State<PostVideoFullScreen> createState() => _PostVideoFullScreenState();
}

class _PostVideoFullScreenState extends State<PostVideoFullScreen> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final controller =
        VideoPlayerController.networkUrl(Uri.parse(widget.signedUrl));
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.play();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready = controller != null && controller.value.isInitialized;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
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
                    : const CircularProgressIndicator(
                        color: AppColors.lavender),
              ),
            ),
          ),
          if (ready && !controller.value.isPlaying)
            const Center(
              child: Icon(Icons.play_arrow, color: Colors.white, size: 64),
            ),
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0x66000000),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 22),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
