import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:happyn/core/providers/categories_provider.dart';
import 'package:happyn/core/categories/category_visuals.dart';

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
  final Set<String> _interests = {};
  XFile? _avatar;
  bool _saving = false;

  @override
  void dispose() {
    _cityController.dispose();
    _bioController.dispose();
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
        await _supabase
            .from('profiles')
            .update({'onboarded': true}).eq('id', user.id);
      } catch (_) {}
    }
    if (mounted) _goHome();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final user = _supabase.auth.currentUser!;
      final avatarUrl = await _uploadAvatar(user.id);

      if (avatarUrl != null) {
        await _supabase.auth
            .updateUser(UserAttributes(data: {'avatar_url': avatarUrl}));
      }
      await _supabase.from('profiles').update({
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        'city': _cityController.text.trim(),
        'bio': _bioController.text.trim(),
        'interests': _interests.toList(),
        'onboarded': true,
      }).eq('id', user.id);

      if (mounted) _goHome();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save. You can do it later in settings.',
                style: GoogleFonts.inter(color: Colors.white)),
            backgroundColor: const Color(0xFF1A1535),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoryNamesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF08080F),
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
                    'Complete your profile',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  TextButton(
                    onPressed: _saving ? null : _skip,
                    child: Text(
                      'Skip',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFA78BFA),
                      ),
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
                  'Optional — you can do this later in settings.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.4),
                  ),
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
                                colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
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
                                      color: const Color(0xFF1A1535),
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
                                    ),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7C3AED),
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: const Color(0xFF08080F), width: 2),
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

                  // City
                  _label('City'),
                  TextField(
                    controller: _cityController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration:
                        _dec('e.g. Ottawa, ON', Icons.location_city_outlined),
                  ),
                  const SizedBox(height: 20),

                  // Interests
                  _label('Interests'),
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
                                      : Colors.white.withOpacity(0.5)),
                              const SizedBox(width: 5),
                              Text(
                                c,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: selected
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.55),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Bio
                  _label('Bio'),
                  TextField(
                    controller: _bioController,
                    maxLines: 3,
                    maxLength: 160,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: _dec('A few words about you...', null)
                        .copyWith(counterStyle: GoogleFonts.inter(
                            color: Colors.white.withOpacity(0.3), fontSize: 10)),
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
                      colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
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
                            'Save & Continue',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
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
        hintStyle: GoogleFonts.inter(
            color: Colors.white.withOpacity(0.25), fontSize: 14),
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
          borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
        ),
      );
}
