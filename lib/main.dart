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
import 'package:happyn/core/config/observability.dart';

/// Tout le demarrage passe par `runWithObservability` : sans lui, une erreur
/// survenant PENDANT l'initialisation (Supabase injoignable, Stripe mal
/// configure) ne serait remontee nulle part — or c'est exactement le moment ou
/// l'app est la plus fragile chez quelqu'un d'autre.
Future<void> main() async {
  await runWithObservability(_start);
}

Future<void> _start() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Données de formatage des dates (mois/jours localisés FR/EN).
  await initializeDateFormatting();

  await Supabase.initialize(
    url: 'https://jvjvuozvlzqqmcjanvnh.supabase.co',
    anonKey: 'sb_publishable_wkRU0rXDmrPaDyhP2b5Mdw_rkbXBrmO',
  );

  // Init Stripe (uniquement si la clé publishable est renseignée)
  if (StripeConfig.isConfigured) {
    Stripe.publishableKey = StripeConfig.publishableKey;
    await Stripe.instance.applySettings();
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

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
