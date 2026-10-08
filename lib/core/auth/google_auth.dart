import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:happyn/core/config/auth_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Connexion Google, avec nonce.
///
/// ── Pourquoi un nonce ───────────────────────────────────────────────────────
///
/// Sans lui, Supabase accepte n'importe quel jeton Google valide dont
/// l'audience est un de nos client IDs : un jeton qui fuit (journal, appareil
/// compromis) se rejoue pour ouvrir une session au nom de son proprietaire,
/// pendant l'heure ou il vit. Il avait fallu activer « Skip Nonce Check » cote
/// Supabase, parce que google_sign_in 6.x ne permettait pas d'en fournir un.
///
/// Le nonce brut ne quitte jamais l'app. Google en recoit l'empreinte SHA-256
/// et la grave dans le jeton ; Supabase recoit le brut, le hache, et compare.
/// Un jeton vole ne sert donc a rien sans ce brut.
///
/// ── Pourquoi un nonce par lancement, et pas par tentative ───────────────────
///
/// google_sign_in 7 le prend dans `initialize()`, qu'on ne doit appeler qu'une
/// fois (« undefined behavior » sinon), et les deux plugins le reutilisent a
/// chaque connexion. Un nonce par lancement garde la protection qui compte —
/// le rejeu par quelqu'un d'autre, qui n'a pas le brut — sans sortir du
/// contrat de la bibliotheque.
class GoogleAuth {
  GoogleAuth._();

  static String? _rawNonce;
  static Future<void>? _ready;

  static Future<void> _ensureInitialized() {
    return _ready ??= () async {
      final raw = _randomNonce();
      _rawNonce = raw;
      await GoogleSignIn.instance.initialize(
        // Sur iOS, l'identifiant vient d'Info.plist (GIDClientID) ; le donner
        // ici aussi evite qu'une divergence entre les deux passe inapercue.
        clientId: !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
            ? AuthConfig.googleIosClientId
            : null,
        serverClientId: AuthConfig.googleWebClientId,
        nonce: sha256.convert(utf8.encode(raw)).toString(),
      );
    }();
  }

  static String _randomNonce() {
    final rand = Random.secure();
    final bytes = List<int>.generate(32, (_) => rand.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// Ouvre le selecteur de compte Google, puis une session Supabase.
  ///
  /// Renvoie faux si la personne a ferme le selecteur. Toute autre erreur est
  /// levee, pour que l'ecran la montre.
  static Future<bool> signIn() async {
    await _ensureInitialized();
    // Toujours proposer le choix du compte, plutot que de reconnecter en
    // silence le dernier utilise.
    await GoogleSignIn.instance.signOut();

    final GoogleSignInAccount account;
    try {
      account = await GoogleSignIn.instance
          .authenticate(scopeHint: const ['email', 'profile']);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        return false;
      }
      rethrow;
    }

    final idToken = account.authentication.idToken;
    if (idToken == null) throw StateError('missing_google_id_token');

    await Supabase.instance.client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      nonce: _rawNonce,
    );
    return true;
  }
}
