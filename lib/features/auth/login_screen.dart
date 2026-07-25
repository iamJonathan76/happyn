import 'package:flutter/material.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:happyn/core/config/auth_config.dart';
import 'package:happyn/core/utils/age.dart';
import 'package:happyn/l10n/app_localizations.dart';
import 'package:happyn/features/auth/complete_profile_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLogin = true;
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

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(
        color: AppColors.textFaint,
        fontSize: 14,
      ),
      prefixIcon: Icon(icon, color: AppColors.textLow, size: 18),
      filled: true,
      fillColor: Colors.white.withOpacity(0.055),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.09)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.09)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg, style: GoogleFonts.inter(color: Colors.white))),
    );
  }

  /// Après auth : si le profil n'est pas encore « onboardé », on propose
  /// l'écran « Complete your profile » ; sinon on va direct au Home.
  Future<void> _routeAfterAuth() async {
    final user = Supabase.instance.client.auth.currentUser;
    bool onboarded = true;
    if (user != null) {
      try {
        final row = await Supabase.instance.client
            .from('profiles')
            .select('onboarded')
            .eq('id', user.id)
            .maybeSingle();
        onboarded = (row?['onboarded'] ?? false) as bool;
      } catch (_) {}
    }
    if (!mounted) return;
    if (onboarded) {
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const CompleteProfileScreen()),
      );
    }
  }

  /// Connexion native Google : on récupère un idToken via `google_sign_in`,
  /// puis on l'échange contre une vraie session Supabase (signInWithIdToken).
  Future<void> _signInWithGoogle() async {
    if (!AuthConfig.isGoogleConfigured) {
      _snack('Google sign-in is not set up yet');
      return;
    }
    try {
      setState(() => _isLoading = true);

      final googleSignIn = GoogleSignIn(
        serverClientId: AuthConfig.googleWebClientId,
        scopes: const ['email', 'profile'],
      );
      // Vide le compte mis en cache pour TOUJOURS afficher le sélecteur de
      // compte (sinon Google reconnecte silencieusement le même mail).
      await googleSignIn.signOut();
      final account = await googleSignIn.signIn();
      if (account == null) return; // annulé par l'utilisateur

      final googleAuth = await account.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) throw Exception('Missing Google ID token');

      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: googleAuth.accessToken,
      );

      if (mounted) await _routeAfterAuth();
    } on AuthException catch (e) {
      if (mounted) _snack(e.message);
    } catch (_) {
      if (mounted) _snack('Google sign-in failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
      helpText: 'Select your date of birth',
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
        _snack(l.errFillAllFields);
        return;
      }
      if (!_isLogin && _nameController.text.trim().isEmpty) {
        _snack(l.errEnterName);
        return;
      }
      if (!_isLogin) {
        if (_dob == null) {
          _snack(l.errEnterDob);
          return;
        }
        if ((ageFromDob(_dob) ?? 0) < kMinAccountAge) {
          _snack(l.errMinAccountAge(kMinAccountAge));
          return;
        }
      }

      setState(() => _isLoading = true);

      if (_isLogin) {
        await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );

        if (mounted) await _routeAfterAuth();
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
          if (mounted) await _routeAfterAuth();
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
                const SizedBox(height: 32),

                // Logo
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [AppColors.primary, AppColors.pink],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
                  child: Text(
                    'HAPPYN',
                    style: GoogleFonts.poppins(
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  _isLogin ? l.welcomeBack : l.joinExperience,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.textLight.withOpacity(0.42),
                  ),
                ),

                const SizedBox(height: 28),

                // Toggle Login / Sign Up
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Row(
                    children: [l.logIn, l.signUp].asMap().entries.map((e) {
                      final isActive = (e.key == 0) == _isLogin;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isLogin = e.key == 0),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              gradient: isActive
                                  ? const LinearGradient(
                                      colors: [
                                        AppColors.primary,
                                        AppColors.pink,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : null,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: isActive
                                  ? [
                                      BoxShadow(
                                        color: AppColors.primary.withOpacity(0.55),
                                        blurRadius: 16,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Text(
                              e.value,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isActive
                                    ? Colors.white
                                    : AppColors.textLow,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 20),

                // OAuth buttons
                Row(
                  children: [
                    _oauthButton(
                      Text('G',
                          style: GoogleFonts.poppins(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          )),
                      'Google',
                      _signInWithGoogle,
                    ),
                    const SizedBox(width: 12),
                    _oauthButton(
                      const Icon(Icons.apple, color: Colors.white, size: 22),
                      'Apple',
                      () => _snack(l.appleSignInSoon),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Divider
                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: Colors.white.withOpacity(0.07),
                        thickness: 1,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        l.orEmail,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.textFaint,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: Colors.white.withOpacity(0.07),
                        thickness: 1,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Name field (sign up only)
                if (!_isLogin) ...[
                  TextField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: _inputDecoration(
                      l.fullName,
                      Icons.person_outline,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Date of birth (sign up only)
                  GestureDetector(
                    onTap: _pickDob,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 15),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(14),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.08)),
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
                  decoration: _inputDecoration(
                    l.emailAddress,
                    Icons.mail_outline,
                  ),
                ),

                const SizedBox(height: 10),

                // Password
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: _inputDecoration(l.password, Icons.lock_outline)
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
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l.passwordResetSoon,
                                style: GoogleFonts.inter(color: Colors.white)),
                            backgroundColor: AppColors.card,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                      child: Text(
                        l.forgotPassword,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.lavender,
                        ),
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
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.pink],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.55),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _isLogin ? l.logIn : l.createAccount,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
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
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textFaint,
                      ),
                      children: [
                        TextSpan(text: l.bySigningUpAgree),
                        TextSpan(
                          text: l.termsWord,
                          style: const TextStyle(color: AppColors.lavender),
                        ),
                        TextSpan(text: l.andConnector),
                        TextSpan(
                          text: l.privacyWord,
                          style: const TextStyle(color: AppColors.lavender),
                        ),
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

  Widget _oauthButton(Widget icon, String label, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: _isLoading ? null : onTap,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.09)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
