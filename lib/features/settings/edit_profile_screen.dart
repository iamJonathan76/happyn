import 'dart:io';
import 'package:happyn/core/theme/app_colors.dart';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:happyn/l10n/app_localizations.dart';

/// Édition du profil : nom + photo (avatar). Stockés dans les user metadata
/// Supabase (`full_name`, `avatar_url`) et synchronisés dans la table profiles.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _supabase = Supabase.instance.client;
  late final TextEditingController _nameController;
  final _cityController = TextEditingController();
  final _bioController = TextEditingController();
  XFile? _pickedAvatar;
  String? _currentAvatarUrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final meta = _supabase.auth.currentUser?.userMetadata;
    _nameController =
        TextEditingController(text: (meta?['full_name'] ?? '') as String);
    _currentAvatarUrl = meta?['avatar_url'] as String?;
    _loadExtra();
  }

  Future<void> _loadExtra() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    try {
      final row = await _supabase
          .from('profiles')
          .select('city, bio')
          .eq('id', user.id)
          .maybeSingle();
      if (row != null && mounted) {
        _cityController.text = (row['city'] ?? '') as String;
        _bioController.text = (row['bio'] ?? '') as String;
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  String get _initials {
    final n = _nameController.text.trim();
    final parts = n.split(' ');
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
    if (picked != null) setState(() => _pickedAvatar = picked);
  }

  Future<String?> _uploadAvatar(String userId) async {
    final img = _pickedAvatar;
    if (img == null) return _currentAvatarUrl;
    final bytes = await img.readAsBytes();
    final ext = img.name.contains('.') ? img.name.split('.').last : 'jpg';
    final path = '$userId/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _supabase.storage.from('avatars').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: img.mimeType ?? 'image/jpeg',
            upsert: false,
          ),
        );
    return _supabase.storage.from('avatars').getPublicUrl(path);
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _snack(l.errEnterName);
      return;
    }

    setState(() => _saving = true);
    try {
      final user = _supabase.auth.currentUser!;
      final avatarUrl = await _uploadAvatar(user.id);

      await _supabase.auth.updateUser(UserAttributes(data: {
        'full_name': name,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
      }));
      // upsert : crée la ligne profiles si elle n'existe pas encore.
      await _supabase.from('profiles').upsert({
        'id': user.id,
        'email': user.email,
        'full_name': name,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        'city': _cityController.text.trim(),
        'bio': _bioController.text.trim(),
      });

      if (mounted) {
        _snack(l.profileUpdated);
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      _snack(l.couldNotSaveRetry);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: AppColors.card,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final email = _supabase.auth.currentUser?.email ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          l.editProfile,
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Avatar ────────────────────────────────────────────────
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
                    child: ClipOval(child: _avatarInner()),
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
          const SizedBox(height: 6),
          Center(
            child: Text(
              l.tapToChangePhoto,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: Colors.white.withOpacity(0.35),
              ),
            ),
          ),
          const SizedBox(height: 24),

          _label(l.fullNameLabel),
          TextField(
            controller: _nameController,
            onChanged: (_) => setState(() {}), // maj des initiales du placeholder
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: _dec(l.yourNameHint, Icons.person_outline),
          ),
          const SizedBox(height: 16),
          _label(l.cityLabel),
          TextField(
            controller: _cityController,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: _dec(l.cityHintShort, Icons.location_city_outlined),
          ),
          const SizedBox(height: 16),
          _label(l.bioLabel),
          TextField(
            controller: _bioController,
            maxLines: 3,
            maxLength: 160,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: _dec(l.bioHint, null).copyWith(
              counterStyle: GoogleFonts.inter(
                  color: Colors.white.withOpacity(0.3), fontSize: 10),
            ),
          ),
          const SizedBox(height: 16),
          _label(l.emailLabel),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Row(
              children: [
                Icon(Icons.mail_outline,
                    color: Colors.white.withOpacity(0.3), size: 18),
                const SizedBox(width: 12),
                Text(
                  email,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l.emailChangesSoon,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: Colors.white.withOpacity(0.3),
            ),
          ),
          const SizedBox(height: 32),
          GestureDetector(
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
                        l.saveChanges,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarInner() {
    if (_pickedAvatar != null) {
      return Image.file(File(_pickedAvatar!.path),
          width: 98, height: 98, fit: BoxFit.cover);
    }
    if (_currentAvatarUrl != null && _currentAvatarUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: _currentAvatarUrl!,
        width: 98,
        height: 98,
        fit: BoxFit.cover,
        errorWidget: (_, _, _) => _initialsCircle(),
      );
    }
    return _initialsCircle();
  }

  Widget _initialsCircle() => Container(
        width: 98,
        height: 98,
        color: AppColors.card,
        child: Center(
          child: Text(
            _initials,
            style: GoogleFonts.poppins(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white.withOpacity(0.6),
          ),
        ),
      );

  InputDecoration _dec(String hint, IconData? icon) => InputDecoration(
        hintText: hint,
        hintStyle:
            GoogleFonts.inter(color: Colors.white.withOpacity(0.25), fontSize: 14),
        prefixIcon: icon == null
            ? null
            : Icon(icon, color: Colors.white.withOpacity(0.3), size: 18),
        filled: true,
        fillColor: Colors.white.withOpacity(0.055),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.09)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.09)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      );
}
