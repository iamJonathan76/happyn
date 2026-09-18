import 'dart:io';
import 'package:happyn/core/widgets/app_form.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/core/theme/app_colors.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:happyn/l10n/app_localizations.dart';
import 'package:happyn/core/providers/categories_provider.dart';
import 'package:happyn/core/categories/category_visuals.dart';
import 'package:happyn/core/providers/people_provider.dart';
import 'package:happyn/core/widgets/username_field.dart';

/// Écran d'onboarding proposé après l'inscription : photo, ville, centres
/// d'intérêt, bio. Entièrement optionnel (bouton « Skip »).
class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  ConsumerState<CompleteProfileScreen> createState() =>
      _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  final _supabase = Supabase.instance.client;
  final _cityController = TextEditingController();
  final _bioController = TextEditingController();

  /// Pre-rempli a partir du nom, pour que la personne voie tout de suite ce
  /// qu'elle obtiendra. Si la proposition est deja prise, le champ le dit et
  /// elle la change ; si elle vide le champ, la base en genere un.
  late final TextEditingController _usernameController = TextEditingController(
      text: suggestUsername(
          _supabase.auth.currentUser?.userMetadata?['full_name'] as String?));
  UsernameStatus? _usernameStatus;
  UsernameStatus? _forcedUsernameStatus;
  final Set<String> _interests = {};
  XFile? _avatar;
  bool _saving = false;

  @override
  void dispose() {
    _cityController.dispose();
    _bioController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  String get _initials {
    final n =
        (_supabase.auth.currentUser?.userMetadata?['full_name'] ?? 'U') as String;
    final parts = n.trim().split(' ');
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return n.isNotEmpty ? n[0].toUpperCase() : 'U';
  }

  Future<void> _pickAvatar() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 600,
      imageQuality: 85,
    );
    if (picked != null) setState(() => _avatar = picked);
  }

  Future<String?> _uploadAvatar(String userId) async {
    final img = _avatar;
    if (img == null) return null;
    final bytes = await img.readAsBytes();
    final ext = img.name.contains('.') ? img.name.split('.').last : 'jpg';
    final path = '$userId/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _supabase.storage.from('avatars').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
              contentType: img.mimeType ?? 'image/jpeg', upsert: false),
        );
    return _supabase.storage.from('avatars').getPublicUrl(path);
  }

  void _goHome() {
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
  }

  Future<void> _skip() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        await _supabase.from('profiles').upsert({
          'id': user.id,
          'email': user.email,
          'full_name': user.userMetadata?['full_name'],
          'date_of_birth': user.userMetadata?['date_of_birth'],
          'onboarded': true,
        });
      } catch (_) {}
    }
    if (mounted) _goHome();
  }

  Future<void> _save() async {
    final username = normalizeUsername(_usernameController.text);
    // Vide : la base en attribue un. Rempli : il doit etre libre, ou au moins
    // non verifiable (reseau) — auquel cas la base tranche.
    if (username.isNotEmpty &&
        _usernameStatus != UsernameStatus.ok &&
        _usernameStatus != UsernameStatus.unknown) {
      showAppSnack(context, AppLocalizations.of(context).usernameFixFirst);
      return;
    }
    setState(() => _saving = true);
    try {
      final user = _supabase.auth.currentUser!;
      final avatarUrl = await _uploadAvatar(user.id);

      if (avatarUrl != null) {
        await _supabase.auth
            .updateUser(UserAttributes(data: {'avatar_url': avatarUrl}));
      }
      // upsert : crée la ligne profiles si elle n'existe pas encore.
      await _supabase.from('profiles').upsert({
        'id': user.id,
        'email': user.email,
        'full_name': user.userMetadata?['full_name'],
        'date_of_birth': user.userMetadata?['date_of_birth'],
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        'city': _cityController.text.trim(),
        'bio': _bioController.text.trim(),
        'interests': _interests.toList(),
        if (username.isNotEmpty) 'username': username,
        'onboarded': true,
      });

      if (mounted) _goHome();
    } catch (e) {
      if (mounted) {
        // Un nom pris entre la verification et l'envoi : on le dit sur le
        // champ, au lieu d'un « reessaie plus tard » qui echouerait pareil.
        final u = usernameErrorFrom(e);
        setState(() {
          _saving = false;
          if (u != null) {
            _forcedUsernameStatus = u;
            _usernameStatus = u;
          }
        });
        showAppSnack(
            context,
            u != null
                ? AppLocalizations.of(context).usernameFixFirst
                : AppLocalizations.of(context).couldNotSaveLater);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final categories = ref.watch(categoryNamesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l.completeYourProfile,
                    style: AppText.h1.copyWith(color: Colors.white),
                  ),
                  TextButton(
                    onPressed: _saving ? null : _skip,
                    child: Text(
                      l.skip,
                      style: AppText.body.copyWith(fontWeight: FontWeight.w600, color: AppColors.lavender),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l.optionalDoLater,
                  style: AppText.caption.copyWith(color: AppColors.textLow),
                ),
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                children: [
                  // Avatar
                  Center(
                    child: GestureDetector(
                      onTap: _pickAvatar,
                      child: Stack(
                        children: [
                          Container(
                            width: 104,
                            height: 104,
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [AppColors.primary, AppColors.pink],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: ClipOval(
                              child: _avatar != null
                                  ? Image.file(File(_avatar!.path),
                                      width: 98, height: 98, fit: BoxFit.cover)
                                  : Container(
                                      width: 98,
                                      height: 98,
                                      color: AppColors.card,
                                      child: Center(
                                        child: Text(
                                          _initials,
                                          style: AppText.display.copyWith(fontSize: 32, color: Colors.white),
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: AppColors.background, width: 2),
                              ),
                              child: const Icon(Icons.camera_alt,
                                  color: Colors.white, size: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Identifiant : c'est par lui qu'on sera retrouve.
                  AppLabel(l.usernameLabel),
                  UsernameField(
                    controller: _usernameController,
                    forcedStatus: _forcedUsernameStatus,
                    onStatus: (st) => setState(() {
                      _usernameStatus = st;
                      _forcedUsernameStatus = null;
                    }),
                  ),
                  const SizedBox(height: 20),

                  // City
                  AppLabel(l.cityLabel),
                  TextField(
                    controller: _cityController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration:
                        appInputDecoration(l.cityHintShort, icon: Icons.location_city_outlined),
                  ),
                  const SizedBox(height: 20),

                  // Interests
                  AppLabel(l.interestsLabel),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: categories.map((c) {
                      final selected = _interests.contains(c);
                      final color = categoryColor(c);
                      return GestureDetector(
                        onTap: () => setState(() {
                          if (selected) {
                            _interests.remove(c);
                          } else {
                            _interests.add(c);
                          }
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected
                                ? color.withOpacity(0.18)
                                : Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected
                                  ? color
                                  : Colors.white.withOpacity(0.1),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(categoryIcon(c),
                                  size: 13,
                                  color: selected
                                      ? color
                                      : AppColors.textMed),
                              const SizedBox(width: 5),
                              Text(
                                c,
                                style: AppText.captionBold.copyWith(color: selected
                                      ? Colors.white
                                      : AppColors.textMed),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Bio
                  AppLabel(l.bioLabel),
                  TextField(
                    controller: _bioController,
                    maxLines: 3,
                    maxLength: 160,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: appInputDecoration(l.bioHint)
                        .copyWith(counterStyle: AppText.micro),
                  ),
                ],
              ),
            ),

            // Save button
            Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 8, 20, MediaQuery.of(context).padding.bottom + 12),
              child: GestureDetector(
                onTap: _saving ? null : _save,
                child: Container(
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.pink],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            l.saveAndContinue,
                            style: AppText.h3.copyWith(color: Colors.white),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

    }
