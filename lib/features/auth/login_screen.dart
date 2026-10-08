import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:happyn/features/settings/legal_page_screen.dart';
import 'package:happyn/core/widgets/app_form.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:happyn/core/utils/age.dart';
import 'package:happyn/core/utils/support.dart';
import 'package:happyn/l10n/app_localizations.dart';
import 'package:happyn/features/auth/auth_routing.dart';

/// Le formulaire e-mail, connexion ou inscription. On y arrive depuis le
/// choix de la porte d'entrée (`AuthChoiceScreen`), qui garde Apple et Google.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.initialSignUp = false});

  final bool initialSignUp;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late bool _isLogin = !widget.initialSignUp;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  DateTime? _dob; // date de naissance (signup)
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  String _formatDob(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    // Par défaut on ouvre sur ~18 ans en arrière (cas le plus courant).
    final initial = _dob ?? DateTime(now.year - 18, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 100),
      lastDate: now,
      helpText: AppLocalizations.of(context).selectDateOfBirth,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            surface: AppColors.sheet,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _authenticate() async {
    final l = AppLocalizations.of(context);
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      if (email.isEmpty || password.isEmpty) {
        showAppSnack(context, l.errFillAllFields);
        return;
      }
      if (!_isLogin && _nameController.text.trim().isEmpty) {
        showAppSnack(context, l.errEnterName);
        return;
      }
      if (!_isLogin) {
        if (_dob == null) {
          showAppSnack(context, l.errEnterDob);
          return;
        }
        if ((ageFromDob(_dob) ?? 0) < kMinAccountAge) {
          showAppSnack(context, l.errMinAccountAge(kMinAccountAge));
          return;
        }
      }

      setState(() => _isLoading = true);

      if (_isLogin) {
        await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );

        if (mounted) await routeAfterAuth(context);
      } else {
        final res = await Supabase.instance.client.auth.signUp(
          email: email,
          password: password,
          data: {
            'full_name': _nameController.text.trim(),
            'date_of_birth':
                _dob!.toIso8601String().split('T').first, // YYYY-MM-DD
          },
        );

        // Si une session est créée direct (confirmation email désactivée),
        // on enchaîne sur l'onboarding. Sinon, message « check email ».
        if (res.session != null) {
          if (mounted) await routeAfterAuth(context);
          return;
        }

       /* final user = response.user;

        if (user != null) {
          await Supabase.instance.client.from('profiles').insert({
            'id': user.id,
            'email': email,
            'full_name': _nameController.text.trim(),
            'created_at': DateTime.now().toIso8601String(),
          });
        } */

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.accountCreatedCheckEmail)),
          );
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Envoie le courriel de reinitialisation.
  ///
  /// Le message de confirmation est volontairement le meme que l'adresse ait
  /// un compte ou non : repondre « aucun compte avec cette adresse »
  /// permettrait a n'importe qui de savoir qui est inscrit sur HAPPYN.
  Future<void> _sendPasswordReset(AppLocalizations l) async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      showAppSnack(context, l.resetNeedEmail);
      return;
    }
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        // Ou l'utilisateur atterrit en cliquant le lien. Cette URL doit etre
        // declaree dans Supabase (Authentication > URL Configuration) : sinon
        // la redirection est refusee — ce qui empeche qu'on fasse pointer le
        // lien vers un site tiers pour recuperer la session.
        redirectTo: kPasswordResetUrl,
      );
    } on AuthException catch (e) {
      debugPrint('resetPasswordForEmail: $e');
      // Un 5xx n'est pas une reponse sur le compte, c'est une panne chez nous
      // (courriel sortant mal configure, service indisponible). Le dire ne
      // revele rien : l'adresse n'a meme pas ete regardee.
      //
      // En dessous, on garde le message neutre. Un 4xx distingue les comptes
      // existants des autres, et l'annoncer transformerait ce bouton en
      // detecteur d'adresses inscrites.
      final code = e.statusCode?.toString() ?? '';
      if (code.isEmpty || code.startsWith('5')) {
        if (mounted) showAppSnack(context, l.resetFailed);
        return;
      }
    } catch (e) {
      // Panne reseau, delai depasse : rien n'est parti, et le dire n'apprend
      // rien sur le compte non plus.
      debugPrint('resetPasswordForEmail: $e');
      if (mounted) showAppSnack(context, l.resetFailed);
      return;
    }
    // Message volontairement neutre (« si cette adresse a un compte… ») : il
    // ne dit pas si le compte existe, sinon n'importe qui saurait quelles
    // adresses sont inscrites en les essayant une par une.
    if (mounted) showAppSnack(context, l.resetSent);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -1.0),
            radius: 1.2,
            colors: [Color(0xFF2D1B69), AppColors.background],
            stops: [0.0, 0.55],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: Colors.white, size: 20),
                  ),
                ),

                const SizedBox(height: 24),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _isLogin ? l.authLoginTitle : l.authSignUpTitle,
                    style: AppText.display
                        .copyWith(fontSize: 28, color: Colors.white),
                  ),
                ),

                // Bascule connexion / inscription : un lien sous le titre
                // plutôt que des onglets, comme sur l'écran précédent.
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 40),
                    ),
                    onPressed: () => setState(() => _isLogin = !_isLogin),
                    child: Text.rich(
                      TextSpan(
                        style: AppText.bodySm.copyWith(color: AppColors.textMed),
                        children: [
                          TextSpan(
                              text: _isLogin
                                  ? l.authNoAccount
                                  : l.authHaveAccount),
                          const TextSpan(text: ' '),
                          TextSpan(
                            text: _isLogin ? l.createAccount : l.logIn,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Name field (sign up only)
                if (!_isLogin) ...[
                  TextField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: appInputDecoration(l.fullName, icon: Icons.person_outline, radius: 16, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
                  ),
                  const SizedBox(height: 10),
                  // Date of birth (sign up only)
                  GestureDetector(
                    onTap: _pickDob,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 15),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(14),
                        border:
                            Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.cake_outlined,
                              color: AppColors.textLow, size: 18),
                          const SizedBox(width: 12),
                          Text(
                            _dob == null ? l.dateOfBirth : _formatDob(_dob!),
                            style: TextStyle(
                              color: _dob == null
                                  ? AppColors.textLow
                                  : Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Email
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: appInputDecoration(l.emailAddress, icon: Icons.mail_outline, radius: 16, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
                ),

                const SizedBox(height: 10),

                // Password
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: appInputDecoration(l.password, icon: Icons.lock_outline, radius: 16, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16))
                      .copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppColors.textLow,
                            size: 18,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                ),

                // Forgot password
                if (_isLogin) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => _sendPasswordReset(l),
                      child: Text(
                        l.forgotPassword,
                        style: AppText.bodySm.copyWith(fontWeight: FontWeight.w600, color: AppColors.lavender),
                      ),
                    ),
                  ),
                ] else
                  const SizedBox(height: 16),

                // CTA Button
                GestureDetector(
                  onTap: _isLoading ? null : _authenticate,
                  child: Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.pink.withValues(alpha: 0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _isLogin ? l.logIn : l.createAccount,
                        style: AppText.h3.copyWith(color: Colors.white),
                      ),
                    ),
                  ),
                ),

                // Terms (sign up only)
                if (!_isLogin) ...[
                  const SizedBox(height: 16),
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: AppText.small.copyWith(color: AppColors.textFaint),
                      children: [
                        TextSpan(text: l.bySigningUpAgree),
                        _legalLink(l.termsWord, 'terms'),
                        TextSpan(text: l.andConnector),
                        _legalLink(l.privacyWord, 'privacy'),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// On accepte ces documents en s'inscrivant : il faut pouvoir les lire.
  TextSpan _legalLink(String text, String docId) => TextSpan(
        text: text,
        style: const TextStyle(color: AppColors.lavender),
        recognizer: TapGestureRecognizer()
          ..onTap = () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => LegalPageScreen(docId: docId),
              )),
      );
}
