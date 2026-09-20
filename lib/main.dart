import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:happyn/l10n/app_localizations.dart';
import 'package:happyn/core/providers/locale_provider.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/splash_screen.dart';
import 'features/auth/onboarding_screen.dart';
import 'features/auth/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:happyn/core/config/stripe_config.dart';
import 'package:happyn/features/main_shell.dart';
import 'package:happyn/core/push/push_service.dart';
import 'package:happyn/core/config/observability.dart';

/// Tout le demarrage passe par `runWithObservability` : sans lui, une erreur
/// survenant PENDANT l'initialisation (Supabase injoignable, Stripe mal
/// configure) ne serait remontee nulle part — or c'est exactement le moment ou
/// l'app est la plus fragile chez quelqu'un d'autre.
Future<void> main() async {
  await runWithObservability(_start);
}

/// Annonce une étape du démarrage, puis dit combien de temps elle a pris.
///
/// Une erreur au démarrage se lit ; un démarrage SUSPENDU ne donne rien à lire.
/// L'écran de lancement reste affiché, `runApp` n'est jamais atteint, et aucun
/// message n'indique laquelle des cinq étapes n'est pas revenue. Ces deux
/// lignes de journal transforment un blocage muet en une étape nommée.
Future<T> _step<T>(String label, Future<T> work) async {
  final startedAt = DateTime.now();
  debugPrint('demarrage: $label…');
  final result = await work;
  final ms = DateTime.now().difference(startedAt).inMilliseconds;
  debugPrint('demarrage: $label ok ($ms ms)');
  return result;
}

Future<void> _start() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Données de formatage des dates (mois/jours localisés FR/EN).
  await _step('formats de date', initializeDateFormatting());

  await _step(
    'Supabase',
    Supabase.initialize(
      url: 'https://jvjvuozvlzqqmcjanvnh.supabase.co',
      anonKey: 'sb_publishable_wkRU0rXDmrPaDyhP2b5Mdw_rkbXBrmO',
    ),
  );

  // Init Stripe (uniquement si la clé publishable est renseignée)
  if (StripeConfig.isConfigured) {
    Stripe.publishableKey = StripeConfig.publishableKey;
    await _step('Stripe', Stripe.instance.applySettings());
  }

  // Notifications poussees. Echoue silencieusement sans google-services.json
  // (absent du depot) : ne pas recevoir de notification est un desagrement,
  // ne pas demarrer serait une panne.
  //
  // Le delai n'est pas un ornement : sur iOS sans GoogleService-Info.plist,
  // l'appel peut ne jamais revenir plutot que lever une exception, et le
  // `try/catch` de PushService ne rattrape pas une attente infinie. Renoncer
  // aux notifications est deja le comportement prevu ici ; rester bloque sur
  // l'ecran d'ouverture ne l'est pas.
  try {
    await _step(
      'notifications',
      PushService.init().timeout(const Duration(seconds: 8)),
    );
  } on TimeoutException {
    debugPrint('demarrage: notifications abandonnees (8 s) — on continue');
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  await _step(
    'orientation',
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]),
  );

  debugPrint('demarrage: runApp');
  runApp(const ProviderScope(child: HappynApp()));
}

class HappynApp extends ConsumerWidget {
  const HappynApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    return MaterialApp(
      title: 'HAPPYN',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const MainShell(),
      },
    );
  }
}
