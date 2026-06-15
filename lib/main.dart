import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/splash_screen.dart';
import 'features/auth/onboarding_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/home/home_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:happyn/features/main_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://jvjvuozvlzqqmcjanvnh.supabase.co',
    anonKey: 'sb_publishable_wkRU0rXDmrPaDyhP2b5Mdw_rkbXBrmO',
  );
  print('Supabase connecté !');
  print(Supabase.instance.client);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(const ProviderScope(child: HappynApp()));
}

class HappynApp extends StatelessWidget {
  const HappynApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HAPPYN',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
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
