import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:happyn/core/events/event_utils.dart';
import 'package:happyn/core/providers/events_provider.dart';
import 'package:happyn/core/providers/social_provider.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/core/widgets/app_form.dart';
import 'package:happyn/l10n/app_localizations.dart';

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
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1400,
      imageQuality: 82,
    );
    if (picked != null) setState(() => _image = picked);
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

  Future<void> _publish() async {
    final l = AppLocalizations.of(context);
    final caption = _captionController.text.trim();
    // La base refuse une publication vide ; on prévient avant l'aller-retour.
    if (caption.isEmpty && _image == null) {
      showAppSnack(context, l.postNeedsContent);
      return;
    }

    setState(() => _saving = true);
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      final imageUrl = await _uploadImage(uid);
      await createPost(
        caption: caption,
        imageUrl: imageUrl,
        eventId: _eventId,
      );

      ref.invalidate(discoverFeedProvider);
      ref.invalidate(followingFeedProvider);
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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // Seuls les événements à venir ont du sens à rattacher.
    final events = (ref.watch(eventsProvider).asData?.value ?? [])
        .where(isEventVisible)
        .toList();

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
          // Image (optionnelle)
          GestureDetector(
            onTap: _saving ? null : _pickImage,
            child: Container(
              height: 210,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(0.09)),
              ),
              child: _image == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined,
                            size: 34, color: AppColors.textLow),
                        const SizedBox(height: 10),
                        Text(l.tapToChoosePhoto, style: AppText.small),
                      ],
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.file(File(_image!.path),
                              fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: () => setState(() => _image = null),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.55),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close,
                                  color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
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

          AppLabel(l.attachEvent),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.09)),
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
                    child: Text(l.noEventAttached, style: AppText.bodySm),
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
