import 'dart:io';

import 'package:flutter/material.dart';
import 'package:happyn/core/config/observability.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_compress/video_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:happyn/core/providers/social_provider.dart';
import 'package:happyn/core/utils/post_image.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/core/widgets/app_form.dart';
import 'package:happyn/l10n/app_localizations.dart';

/// Les formats proposes au recadrage : l'original, et les trois qu'Instagram a
/// rendus familiers. Le fil affiche ensuite chaque image dans sa forme.
const List<CropAspectRatioPresetData> _kCropPresets = [
  CropAspectRatioPreset.original,
  CropAspectRatioPreset.square,
  _CropRatio('4:5', 4, 5),
  _CropRatio('1.91:1', 191, 100),
];

class _CropRatio implements CropAspectRatioPresetData {
  @override
  final String name;
  final int x;
  final int y;
  const _CropRatio(this.name, this.x, this.y);

  @override
  (int, int) get data => (x, y);
}

/// Publier une photo / un message, éventuellement rattaché à un événement.
///
/// Le rattachement est ce qui rend le fil utile au produit : une publication
/// « J-3 avant ce concert » devient un point d'entrée vers la billetterie.
class CreatePostScreen extends ConsumerStatefulWidget {
  /// Pré-sélectionne un événement (depuis sa fiche, par exemple).
  final String? initialEventId;
  const CreatePostScreen({super.key, this.initialEventId});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _captionController = TextEditingController();
  XFile? _image;
  String? _eventId;
  bool _saving = false;
  // La photo telle que choisie, pour pouvoir la recadrer a nouveau sans la
  // rechoisir — et sans recadrer un recadrage.
  XFile? _original;
  // Largeur / hauteur de l'image recadree (ou de la video), enregistree avec
  // la publication pour que le fil connaisse la forme avant le chargement.
  double? _aspect;

  // Un moment est une photo OU une video, jamais les deux : _image et _video
  // s'excluent. Pour la video : le clip compresse a 720p et coupe a 60 s, son
  // image de couverture (vignette du fil), et un drapeau si on a du couper.
  XFile? _video;
  File? _poster;
  bool _videoTrimmed = false;
  bool _processingVideo = false;

  @override
  void initState() {
    super.initState();
    _eventId = widget.initialEventId;
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    // Pleine qualite ici : c'est le recadrage qui reduit, une seule fois.
    // Reduire avant puis recadrer degraderait deux fois la meme photo.
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    _original = picked;
    await _crop();
  }

  /// Placer la photo dans le cadre avant de publier : la deplacer, zoomer,
  /// choisir sa forme. Ecrans natifs (uCrop sur Android, TOCropViewController
  /// sur iOS). Annuler garde l'image precedente, s'il y en avait une.
  Future<void> _crop() async {
    final original = _original;
    if (original == null) return;
    final l = AppLocalizations.of(context);
    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: original.path,
        maxWidth: 1400,
        maxHeight: 1400,
        compressQuality: 82,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: l.cropTitle,
            toolbarColor: AppColors.background,
            toolbarWidgetColor: Colors.white,
            statusBarLight: false,
            backgroundColor: Colors.black,
            activeControlsWidgetColor: AppColors.primary,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
            aspectRatioPresets: _kCropPresets,
          ),
          IOSUiSettings(
            title: l.cropTitle,
            doneButtonTitle: l.done,
            cancelButtonTitle: l.cancel,
            aspectRatioPresets: _kCropPresets,
          ),
        ],
      );
      if (cropped == null) return;
      final bytes = await cropped.readAsBytes();
      final decoded = await decodeImageFromList(bytes);
      if (!mounted) return;
      setState(() {
        _image = XFile(cropped.path, mimeType: 'image/jpeg', name: 'post.jpg');
        _aspect = decoded.width / decoded.height;
      });
    } catch (e, st) {
      reportCaught(e, st, where: 'createPost.crop');
      if (mounted) showAppSnack(context, l.postFailed);
    }
  }

  Future<String?> _uploadImage(String userId) async {
    final image = _image;
    if (image == null) return null;
    final bytes = await image.readAsBytes();
    final ext = image.name.contains('.') ? image.name.split('.').last : 'jpg';
    final path = '$userId/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await Supabase.instance.client.storage.from('posts').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: image.mimeType ?? 'image/jpeg',
            upsert: false,
          ),
        );
    return Supabase.instance.client.storage.from('posts').getPublicUrl(path);
  }

  /// Choisir une vidéo dans la galerie, la préparer sur l'appareil (natif, sans
  /// ffmpeg) : couper aux 60 premières secondes si elle est plus longue,
  /// compresser à 720p, et tirer une image de couverture. Tout est fait AVANT
  /// l'upload — on n'envoie jamais le fichier d'origine, qui peut peser 100 Mo.
  Future<void> _pickVideo() async {
    final l = AppLocalizations.of(context);
    final picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() {
      _processingVideo = true;
      _image = null;
      _original = null;
      _video = null;
      _poster = null;
    });
    try {
      final info = await VideoCompress.getMediaInfo(picked.path);
      // duration est en millisecondes.
      final tooLong = (info.duration ?? 0) > 60000;
      final result = await VideoCompress.compressVideo(
        picked.path,
        quality: VideoQuality.Res1280x720Quality,
        includeAudio: true,
        startTime: 0,
        // En secondes. On ne coupe que si ça dépasse : sinon on garde tout.
        duration: tooLong ? 60 : null,
      );
      final outPath = result?.path;
      if (outPath == null) throw StateError('compressVideo a renvoyé null');
      final poster = await VideoCompress.getFileThumbnail(outPath,
          quality: 75, position: -1);
      final w = result?.width, h = result?.height;
      if (!mounted) return;
      setState(() {
        _video = XFile(outPath, mimeType: 'video/mp4', name: 'moment.mp4');
        _poster = poster;
        _aspect = (w != null && h != null && h != 0) ? w / h : null;
        _videoTrimmed = tooLong;
        _processingVideo = false;
      });
      if (tooLong && mounted) showAppSnack(context, l.videoTrimmedNotice);
    } catch (e, st) {
      reportCaught(e, st, where: 'createPost.pickVideo');
      if (!mounted) return;
      setState(() => _processingVideo = false);
      showAppSnack(context, l.videoFailed);
    }
  }

  /// Le clip va dans le bucket privé event-videos, au chemin
  /// `<event>/<auteur>/…` qu'exige sa politique d'accès. On stocke ce chemin
  /// dans video_url (pas une URL publique) : la lecture passe par une URL
  /// signée, comme la vidéo d'organisateur.
  Future<String?> _uploadVideo(String userId, String eventId) async {
    final video = _video;
    if (video == null) return null;
    final bytes = await video.readAsBytes();
    final path = '$eventId/$userId/${DateTime.now().millisecondsSinceEpoch}.mp4';
    await Supabase.instance.client.storage.from('event-videos').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(contentType: 'video/mp4', upsert: false),
        );
    return path;
  }

  /// La couverture va dans le bucket public posts : c'est elle, la vignette du
  /// fil, visible sans URL signée.
  Future<String?> _uploadPoster(String userId) async {
    final poster = _poster;
    if (poster == null) return null;
    final bytes = await poster.readAsBytes();
    final path = '$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await Supabase.instance.client.storage.from('posts').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: false),
        );
    return Supabase.instance.client.storage.from('posts').getPublicUrl(path);
  }

  Future<void> _publish() async {
    final l = AppLocalizations.of(context);
    final caption = _captionController.text.trim();
    // La base refuse une publication vide ; on prévient avant l'aller-retour.
    if (caption.isEmpty && _image == null && _video == null) {
      showAppSnack(context, l.postNeedsContent);
      return;
    }
    // On n'envoie rien tant que la vidéo n'est pas prête.
    if (_processingVideo) {
      showAppSnack(context, l.videoPreparing);
      return;
    }
    // Une publication documente toujours une expérience.
    final eventId = _eventId;
    if (eventId == null) {
      showAppSnack(context, l.postNeedsEvent);
      return;
    }

    setState(() => _saving = true);
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      if (_video != null) {
        // Vidéo : la couverture (publique) sert de vignette, le clip (privé)
        // va dans event-videos. On envoie la couverture d'abord : si le clip
        // échoue, on n'a pas de vignette orpheline qui pointe vers rien.
        final posterUrl = await _uploadPoster(uid);
        final videoPath = await _uploadVideo(uid, eventId);
        await createPost(
          eventId: eventId,
          caption: caption,
          imageUrl: posterUrl,
          imageAspect: _aspect,
          videoUrl: videoPath,
        );
      } else {
        final imageUrl = await _uploadImage(uid);
        await createPost(
          eventId: eventId,
          caption: caption,
          imageUrl: imageUrl,
          imageAspect: imageUrl == null ? null : _aspect,
        );
      }

      ref.invalidate(discoverFeedProvider);
      ref.invalidate(userPostsProvider(uid));

      if (!mounted) return;
      showAppSnack(context, l.postCreated);
      Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('createPost failed: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      showAppSnack(context, l.postFailed);
    }
  }

  BoxDecoration get _mediaBox => BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      );

  /// Petit bouton rond foncé posé sur un média (fermer, recadrer…).
  Widget _overlayButton({
    required IconData icon,
    String? label,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: label == null
            ? const EdgeInsets.all(6)
            : const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(label == null ? 40 : 20),
          shape: label == null ? BoxShape.circle : BoxShape.rectangle,
        ),
        child: label == null
            ? Icon(icon, color: Colors.white, size: 16)
            : Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, color: Colors.white, size: 15),
                const SizedBox(width: 6),
                Text(label,
                    style: AppText.smallBold.copyWith(color: Colors.white)),
              ]),
      ),
    );
  }

  void _clearMedia() => setState(() {
        _image = null;
        _original = null;
        _video = null;
        _poster = null;
        _videoTrimmed = false;
        _aspect = null;
      });

  Widget _mediaPicker(AppLocalizations l) {
    // En préparation de la vidéo : on montre que ça travaille, rien d'autre.
    if (_processingVideo) {
      return Container(
        height: 210,
        decoration: _mediaBox,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                  strokeWidth: 2.4, color: AppColors.lavender),
            ),
            const SizedBox(height: 12),
            Text(l.videoPreparing, style: AppText.small),
          ],
        ),
      );
    }

    // Aperçu vidéo : la couverture, un repère « lecture », et le rappel de coupe.
    if (_video != null && _poster != null) {
      return AspectRatio(
        aspectRatio: displayAspect(_aspect),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(fit: StackFit.expand, children: [
            Image.file(_poster!, fit: BoxFit.cover),
            const Center(
              child: Icon(Icons.play_circle_fill,
                  color: Colors.white, size: 54),
            ),
            Positioned(
              left: 8,
              bottom: 8,
              child: _overlayButton(
                  icon: Icons.videocam,
                  label: _videoTrimmed ? l.videoTrimmedBadge : l.videoBadge,
                  onTap: null),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: _overlayButton(
                  icon: Icons.close, onTap: _saving ? null : _clearMedia),
            ),
          ]),
        ),
      );
    }

    // Aperçu photo (inchangé) : recadrer, retirer.
    if (_image != null) {
      return AspectRatio(
        aspectRatio: displayAspect(_aspect),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(fit: StackFit.expand, children: [
            Image.file(File(_image!.path), fit: BoxFit.cover),
            Positioned(
              left: 8,
              bottom: 8,
              child: _overlayButton(
                  icon: Icons.crop,
                  label: l.cropAction,
                  onTap: _saving ? null : _crop),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: _overlayButton(
                  icon: Icons.close, onTap: _saving ? null : _clearMedia),
            ),
          ]),
        ),
      );
    }

    // Rien de choisi : on propose photo OU vidéo.
    return Container(
      height: 210,
      decoration: _mediaBox,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _mediaChoice(
              icon: Icons.add_photo_alternate_outlined,
              label: l.postAddPhoto,
              onTap: _saving ? null : _pickImage),
          Container(
            width: 1,
            height: 64,
            margin: const EdgeInsets.symmetric(horizontal: 18),
            color: Colors.white.withValues(alpha: 0.09),
          ),
          _mediaChoice(
              icon: Icons.videocam_outlined,
              label: l.postAddVideo,
              onTap: _saving ? null : _pickVideo),
        ],
      ),
    );
  }

  Widget _mediaChoice({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 34, color: AppColors.textLow),
        const SizedBox(height: 10),
        Text(label, style: AppText.small),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // Uniquement les événements que l'utilisateur organise ou pour lesquels il
    // a un billet. La base applique la même règle (`can_attach_event`).
    final events = ref.watch(attachableEventsProvider).asData?.value ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(l.newPost, style: AppText.h2),
        actions: [
          TextButton(
            onPressed: _saving ? null : _publish,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.2, color: AppColors.lavender),
                  )
                : Text(l.postShare,
                    style: AppText.h4.copyWith(color: AppColors.lavender)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          // Média (optionnel) : une photo OU une vidéo.
          _mediaPicker(l),
          const SizedBox(height: 18),

          AppLabel(l.postCaptionHint),
          TextField(
            controller: _captionController,
            enabled: !_saving,
            maxLines: 5,
            maxLength: 500,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: appInputDecoration(l.postCaptionHint),
          ),
          const SizedBox(height: 10),

          AppLabel(l.attachEventRequired),
          // Sans billet ni evenement organise, il n'y a rien a raconter :
          // on le dit clairement plutot que d'afficher une liste vide.
          if (events.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
              ),
              child: Text(l.noAttachableEvents,
                  style: AppText.bodySm.copyWith(height: 1.45)),
            )
          else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _eventId,
                isExpanded: true,
                dropdownColor: AppColors.card,
                icon: Icon(Icons.keyboard_arrow_down, color: AppColors.textLow),
                style: AppText.bodySm.copyWith(color: Colors.white),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(l.chooseEvent, style: AppText.bodySm),
                  ),
                  ...events.map((e) => DropdownMenuItem<String?>(
                        value: e['id'] as String,
                        child: Text(
                          (e['title'] ?? '') as String,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.bodySm.copyWith(color: Colors.white),
                        ),
                      )),
                ],
                onChanged:
                    _saving ? null : (v) => setState(() => _eventId = v),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
