import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Configuration OAuth côté client.
class AuthConfig {
  // Web client ID de Google Cloud Console (type "Web application").
  // Sert de `serverClientId` pour obtenir un idToken validé par Supabase.
  static const String googleWebClientId =
      '271216442225-34r8i0ehiaup5bgv917uk0tu5bfrvl8g.apps.googleusercontent.com';

  /// iOS client ID (type « iOS » dans Google Cloud Console).
  ///
  /// Le renseigner ici ne suffit pas : `google_sign_in` ne le lit pas dans ce
  /// fichier, mais dans `ios/Runner/Info.plist`. Il faut donc aussi y ajouter
  /// la clé `GIDClientID` avec cette même valeur, et un `CFBundleURLTypes`
  /// portant le client ID inversé — sans quoi Google n'a pas de chemin de
  /// retour vers l'app après l'authentification.
  ///
  /// Et une troisième fois, ailleurs : cet identifiant doit figurer dans les
  /// « Authorized Client IDs » du fournisseur Google de Supabase, à côté du
  /// web. Sur iOS, `serverClientId` ne sert qu'à obtenir un code pour le
  /// serveur : l'audience du jeton reste l'identifiant iOS. Sans lui dans la
  /// liste, Supabase refuse la session avec
  /// « unacceptable audience in id_token ». Sur Android c'est l'inverse,
  /// l'audience y est le web — d'où les deux valeurs dans le champ.
  ///
  /// Le même écran Supabase porte « Skip Nonce Check ». Il avait fallu
  /// l'ACTIVER : google_sign_in 6.x ne permettait pas de fournir un nonce, et
  /// le SDK iOS en mettait un, haché et irrécupérable, dans le jeton. Depuis
  /// google_sign_in 7 (`GoogleAuth`), l'app fournit son propre nonce : la case
  /// doit être DÉCOCHÉE, sans quoi Supabase accepte encore n'importe quel jeton
  /// Google valide, y compris un jeton volé rejoué. La décocher fait échouer
  /// la connexion Google des anciennes versions de l'app — voulu.
  static const String googleIosClientId =
      '271216442225-c40tfrbhn2u4rh458i7h9khd0o8e1jdp.apps.googleusercontent.com';

  static bool _isClientId(String value) =>
      value.endsWith('.apps.googleusercontent.com') &&
      !value.startsWith('REMPLACE');

  /// Peut-on proposer « Continuer avec Google » sur cette plateforme ?
  ///
  /// iOS exige, EN PLUS du web client ID, son propre identifiant déclaré dans
  /// `Info.plist`. Tant qu'il manque, l'appel ne lève pas une exception Dart :
  /// GIDSignIn lève une NSException native — « No active configuration. Make
  /// sure GIDClientID is set in Info.plist » — que le `try/catch` de l'écran
  /// de connexion ne peut pas rattraper. L'app se ferme d'un coup.
  ///
  /// Le garde-fou ne regardait que le web client ID, renseigné de longue date.
  /// Il répondait donc « configuré » sur un iPhone où rien ne l'était, et le
  /// bouton tuait l'app au lieu de s'excuser.
  ///
  /// Un bouton qui dit « pas encore disponible » est un désagrément ; un
  /// bouton qui ferme l'app est une panne.
  static bool get isGoogleConfigured {
    if (!_isClientId(googleWebClientId)) return false;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return _isClientId(googleIosClientId);
    }
    return true;
  }
}
