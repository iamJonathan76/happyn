/// Configuration OAuth côté client.
class AuthConfig {
  // Web client ID de Google Cloud Console (type "Web application").
  // Sert de `serverClientId` pour obtenir un idToken validé par Supabase.
  static const String googleWebClientId =
      '271216442225-34r8i0ehiaup5bgv917uk0tu5bfrvl8g.apps.googleusercontent.com';

  // iOS client ID (pour la config iOS plus tard).
  static const String googleIosClientId = '';

  static bool get isGoogleConfigured =>
      googleWebClientId.endsWith('.apps.googleusercontent.com') &&
      !googleWebClientId.startsWith('REMPLACE');
}
