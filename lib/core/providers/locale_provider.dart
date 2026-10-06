import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:happyn/core/config/observability.dart';
import 'package:happyn/core/providers/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

/// Recopie la langue de l'app dans `profiles.language`.
///
/// Les notifications sont rédigées par la base, qui ne voit pas le téléphone :
/// sans cette copie, elle écrit tout en anglais (migration 20261006010000).
/// Recalculé à la connexion, au changement de compte et au changement de
/// langue — c'est-à-dire chaque fois que la réponse peut changer. À surveiller
/// depuis la racine de l'app.
final notificationLanguageSyncProvider = Provider<void>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  final locale = ref.watch(localeProvider);
  if (userId == null) return;
  _syncLanguage(userId, notificationLanguageFor(locale));
});

/// La langue que l'app affiche réellement, ramenée à « en » ou « fr ».
///
/// `null` (« langue du système ») se résout comme le fait Flutter : la première
/// langue préférée du téléphone que l'app sait afficher, l'anglais à défaut.
String notificationLanguageFor(Locale? chosen) {
  if (chosen != null) return chosen.languageCode == 'fr' ? 'fr' : 'en';
  for (final l in WidgetsBinding.instance.platformDispatcher.locales) {
    if (l.languageCode == 'fr') return 'fr';
    if (l.languageCode == 'en') return 'en';
  }
  return 'en';
}

// Les écritures passent l'une après l'autre. Au démarrage, la langue vaut
// d'abord `null` (système) puis le choix enregistré, lu un instant plus tard :
// deux écritures concurrentes pourraient arriver dans le désordre et laisser la
// mauvaise en base.
Future<void> _syncQueue = Future.value();
String? _lastSynced;

void _syncLanguage(String userId, String code) {
  final key = '$userId:$code';
  if (key == _lastSynced) return;
  _lastSynced = key;
  _syncQueue = _syncQueue.then((_) async {
    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'language': code}).eq('id', userId);
    } catch (e, st) {
      // Réessayé au prochain changement ou démarrage. Une langue pas encore
      // recopiée ne coûte qu'une notification en anglais.
      if (_lastSynced == key) _lastSynced = null;
      reportCaught(e, st, where: 'locale.syncLanguage');
    }
  });
}
