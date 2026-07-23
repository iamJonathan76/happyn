import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Langue choisie par l'utilisateur (persistée localement). `null` = suit la
/// langue du système (résolue contre les locales supportées : en, fr).
final localeProvider =
    StateNotifierProvider<LocaleController, Locale?>((ref) => LocaleController());

class LocaleController extends StateNotifier<Locale?> {
  LocaleController() : super(null) {
    _load();
  }

  static const _key = 'app_locale';
  final _storage = const FlutterSecureStorage();

  Future<void> _load() async {
    final code = await _storage.read(key: _key);
    if (code != null && code.isNotEmpty) state = Locale(code);
  }

  Future<void> setLocale(Locale? locale) async {
    state = locale;
    if (locale == null) {
      await _storage.delete(key: _key);
    } else {
      await _storage.write(key: _key, value: locale.languageCode);
    }
  }
}
