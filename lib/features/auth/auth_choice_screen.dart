import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:happyn/core/auth/google_auth.dart';
import 'package:happyn/core/config/auth_config.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/core/widgets/app_form.dart';
import 'package:happyn/features/auth/auth_routing.dart';
import 'package:happyn/features/auth/login_screen.dart';
import 'package:happyn/features/auth/welcome_screen.dart';
import 'package:happyn/features/settings/legal_page_screen.dart';
import 'package:happyn/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Le choix de la porte d'entrée : Apple, Google ou e-mail.
///
/// Un seul écran pour l'inscription et la connexion, parce qu'Apple et Google
/// ne font pas la différence : le même bouton crée le compte la première fois
/// et l'ouvre les suivantes. Seul le titre change — et ce que demandera le
/// formulaire e-mail, où la différence existe vraiment.
class AuthChoiceScreen extends StatefulWidget {
  const AuthChoiceScreen({super.key, this.signUp = false});

  /// Vrai en arrivant de « Commencer » (après l'onboarding).
  final bool signUp;

  @override
  State<AuthChoiceScreen> createState() => _AuthChoiceScreenState();
}

class _AuthChoiceScreenState extends State<AuthChoiceScreen> {
  late bool _signUp = widget.signUp;
  bool _busy = false;

  /// Connexion native Google : jeton Google avec nonce, echange contre une
  /// session Supabase. Le detail vit dans `GoogleAuth`.
  Future<void> _google() async {
    if (!AuthConfig.isGoogleConfigured) {
      showAppSnack(context, 'Google sign-in is not set up yet');
      return;
    }
    try {
      setState(() => _busy = true);
      final signedIn = await GoogleAuth.signIn();
      if (!signedIn) return; // annule par l'utilisateur
      if (mounted) await routeAfterAuth(context);
    } on AuthException catch (e) {
      debugPrint('Google sign-in — Supabase a refuse le jeton : ${e.message}');
      if (mounted) showAppSnack(context, e.message);
    } catch (error, stackTrace) {
      // Le message affiché reste volontairement générique — « DEVELOPER_ERROR »
      // ne veut rien dire pour la personne qui essaie de se connecter. Mais
      // l'avaler SANS TRACE rendait tout diagnostic impossible.
      //
      // Les deux causes à reconnaître ici :
      //   * `status code: 10` (DEVELOPER_ERROR) → l'empreinte SHA-1 de l'APK
      //     n'est pas déclarée pour ce client OAuth Android.
      //   * `access_denied` / écran Google « n'a pas terminé la vérification »
      //     → l'écran de consentement est en mode Test et ce compte n'est pas
      //     dans la liste des testeurs.
      debugPrint('Google sign-in echoue : $error');
      debugPrintStack(
        label: 'Google sign-in failure details',
        stackTrace: stackTrace,
      );
      if (mounted) {
        showAppSnack(
          context,
          kDebugMode
              ? 'Google sign-in failed: $error'
              : 'Google sign-in failed. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _email() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LoginScreen(initialSignUp: _signUp),
    ));
  }

  void _openLegal(String docId) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LegalPageScreen(docId: docId),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // Sur iPhone, Apple passe en tête : ses règles veulent que sa connexion
    // soit au moins aussi visible que les autres. Sur Android, elle passerait
    // par une page web — lourde et peu utilisée —, on ne la propose pas.
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -1.1),
            radius: 1.1,
            colors: [Color(0xFF2D1B69), AppColors.background],
            stops: [0.0, 0.6],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            // Défile seulement s'il le faut (petit écran, grande police
            // système) ; sinon les Spacer centrent le bloc et collent la
            // mention légale en bas.
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Navigator.of(context).canPop()
                              ? IconButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: const Icon(Icons.arrow_back_ios_new,
                                      color: Colors.white, size: 20),
                                )
                              : const SizedBox(height: 48),
                        ),
                        const Spacer(),
                        const Image(
                            image: WelcomeScreen.logoImage, height: 64),
                        const SizedBox(height: 24),
                        Text(
                          _signUp ? l.authSignUpTitle : l.authLoginTitle,
                          textAlign: TextAlign.center,
                          style: AppText.display
                              .copyWith(fontSize: 28, color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _signUp ? l.authSignUpSub : l.authLoginSub,
                          textAlign: TextAlign.center,
                          style: AppText.body.copyWith(color: AppColors.textMed),
                        ),
                        const SizedBox(height: 36),
                        if (isIOS) ...[
                          _AuthButton(
                            icon: FontAwesomeIcons.apple.data,
                            label: l.continueWithApple,
                            filled: true,
                            onTap: _busy
                                ? null
                                : () => showAppSnack(context, l.appleSignInSoon),
                          ),
                          const SizedBox(height: 12),
                        ],
                        _AuthButton(
                          icon: FontAwesomeIcons.google.data,
                          label: l.continueWithGoogle,
                          // Sans Apple, Google devient la porte principale.
                          filled: !isIOS,
                          busy: _busy,
                          onTap: _busy ? null : _google,
                        ),
                        const SizedBox(height: 12),
                        _AuthButton(
                          icon: Icons.mail_outline,
                          label: l.continueWithEmail,
                          onTap: _busy ? null : _email,
                        ),
                        const SizedBox(height: 20),
                        TextButton(
                          onPressed: () => setState(() => _signUp = !_signUp),
                          child: Text.rich(
                            TextSpan(
                              style: AppText.bodySm
                                  .copyWith(color: AppColors.textMed),
                              children: [
                                TextSpan(
                                    text: _signUp
                                        ? l.authHaveAccount
                                        : l.authNoAccount),
                                const TextSpan(text: ' '),
                                TextSpan(
                                  text: _signUp ? l.logIn : l.createAccount,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(flex: 2),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text.rich(
                            textAlign: TextAlign.center,
                            TextSpan(
                              style: AppText.small
                                  .copyWith(color: AppColors.textLow),
                              children: [
                                TextSpan(text: l.authContinueAgree),
                                _link(l.termsWord, 'terms'),
                                TextSpan(text: l.andConnector),
                                _link(l.privacyWord, 'privacy'),
                                const TextSpan(text: '.'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  TextSpan _link(String text, String docId) => TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          decoration: TextDecoration.underline,
          decorationColor: Colors.white,
        ),
        recognizer: TapGestureRecognizer()..onTap = () => _openLegal(docId),
      );
}

/// Bouton de connexion pleine largeur. [filled] : fond blanc, texte noir —
/// la présentation standard d'Apple, réservée à la porte principale.
class _AuthButton extends StatelessWidget {
  const _AuthButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool filled;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final fg = filled ? Colors.black : Colors.white;
    return Material(
      color: filled ? Colors.white : Colors.transparent,
      shape: StadiumBorder(
        side: filled
            ? BorderSide.none
            : BorderSide(color: Colors.white.withValues(alpha: 0.35)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        // Pleine largeur explicite : dans la colonne centrée, le bouton se
        // réduisait à la largeur de son texte, et l'icône le chevauchait.
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // L'icône à gauche, le texte centré : les trois libellés
              // restent alignés quelle que soit leur longueur.
              Positioned(
                left: 22,
                child: busy
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: fg),
                      )
                    : Icon(icon, color: fg, size: 20),
              ),
              Text(label,
                  style: AppText.h5
                      .copyWith(color: fg, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
