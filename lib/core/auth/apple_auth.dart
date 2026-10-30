import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Connexion Apple, avec nonce.
///
/// ── Pourquoi un nonce ───────────────────────────────────────────────────────
///
/// Même raison que pour Google : sans lui, un jeton Apple valide qui fuit se
/// rejoue pour ouvrir une session au nom de son propriétaire pendant qu'il vit.
/// Le brut ne quitte jamais l'app ; Apple reçoit son empreinte SHA-256 et la
/// grave dans le jeton ; Supabase reçoit le brut, le hache, et compare.
///
/// Contrairement à google_sign_in, `getAppleIDCredential` accepte un nonce à
/// CHAQUE appel : on en tire donc un neuf par tentative, et non un par
/// lancement.
///
/// ── Le piège du nom ─────────────────────────────────────────────────────────
///
/// Apple ne renvoie le nom (et parfois l'e-mail réel) qu'à la TOUTE PREMIÈRE
/// autorisation, jamais aux suivantes, et il n'est pas dans le jeton. Si on le
/// laisse filer là, le compte n'aura jamais de nom venant d'Apple. On le pose
/// donc sur le profil quand il est présent ; sinon, l'écran de complétion de
/// profil prend le relais, comme pour n'importe quel compte incomplet.
class AppleAuth {
  AppleAuth._();

  static String _randomNonce() {
    final rand = Random.secure();
    final bytes = List<int>.generate(32, (_) => rand.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// Ouvre la feuille Apple, puis une session Supabase.
  ///
  /// Renvoie faux si la personne a annulé. Toute autre erreur est levée, pour
  /// que l'écran la montre.
  static Future<bool> signIn() async {
    final rawNonce = _randomNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    final AuthorizationCredentialAppleID cred;
    try {
      cred = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return false;
      rethrow;
    }

    final idToken = cred.identityToken;
    if (idToken == null) throw StateError('missing_apple_id_token');

    await Supabase.instance.client.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
      nonce: rawNonce,
    );

    final name = [cred.givenName, cred.familyName]
        .whereType<String>()
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .join(' ');
    if (name.isNotEmpty) {
      try {
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(data: {'full_name': name}),
        );
      } catch (_) {
        // Un nom non enregistré n'empêche pas de se connecter : la personne
        // le complétera dans son profil.
      }
    }
    return true;
  }
}
