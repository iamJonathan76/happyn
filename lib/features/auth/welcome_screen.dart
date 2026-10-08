import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/l10n/app_localizations.dart';

/// Premier écran d'une personne sans session : la promesse, puis deux portes.
///
/// « Commencer » mène à l'onboarding ; « J'ai déjà un compte » va droit à la
/// connexion. Avant, tout le monde passait par les trois slides — y compris
/// quelqu'un qui revenait simplement après une déconnexion.
///
/// Pas de photo : un fond sombre, un halo aux couleurs de la marque et des
/// ondes qui partent du H. Une photo de foule, essayée d'abord, noyait le
/// slogan dans sa brume et pesait 350 Ko ; ici tout est dessiné.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  static const logoImage = AssetImage('assets/images/logo_h.png');

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waves = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Réglage « Réduire les animations » : les ondes restent figées, à mi-course.
    if (MediaQuery.disableAnimationsOf(context)) {
      _waves.stop();
      _waves.value = 0.5;
    } else if (!_waves.isAnimating) {
      _waves.repeat();
    }
  }

  @override
  void dispose() {
    _waves.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 3),
              // Le halo et les ondes débordent largement du logo : CustomPaint
              // ne découpe pas, et le texte qui suit se dessine par-dessus.
              CustomPaint(
                painter: _HaloPainter(_waves),
                child: const Image(
                    image: WelcomeScreen.logoImage, height: 120),
              ),
              const SizedBox(height: 28),
              Text(
                'HAPPYN',
                style: GoogleFonts.poppins(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 4,
                  color: Colors.white,
                  height: 1,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                l.welcomeLine1,
                textAlign: TextAlign.center,
                style: AppText.h1
                    .copyWith(fontWeight: FontWeight.w600, color: Colors.white),
              ),
              ShaderMask(
                shaderCallback: (bounds) =>
                    AppColors.brandGradient.createShader(bounds),
                child: Text(
                  l.welcomeLine2,
                  textAlign: TextAlign.center,
                  style: AppText.h1
                      .copyWith(fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
              const Spacer(flex: 4),
              GestureDetector(
                onTap: () => Navigator.of(context).pushNamed('/onboarding'),
                child: Container(
                  width: double.infinity,
                  height: 56,
                  alignment: Alignment.center,
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
                  child: Text(l.getStarted,
                      style: AppText.h3.copyWith(color: Colors.white)),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pushNamed('/login'),
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  foregroundColor: Colors.white,
                ),
                child: Text(l.welcomeHaveAccount,
                    style: AppText.body.copyWith(
                        color: Colors.white, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// Halo violet et rose centré sur le logo, et trois ondes qui s'en éloignent
/// en s'effaçant, décalées d'un tiers de cycle chacune.
class _HaloPainter extends CustomPainter {
  _HaloPainter(this.progress) : super(repaint: progress);

  final Animation<double> progress;

  static const _ringCount = 3;
  static const _ringStart = 95.0;
  static const _ringTravel = 190.0;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);

    void glow(Offset at, double radius, List<Color> colors) {
      final rect = Rect.fromCircle(center: at, radius: radius);
      canvas.drawCircle(
        at,
        radius,
        Paint()..shader = RadialGradient(colors: colors).createShader(rect),
      );
    }

    glow(c, 260, [
      AppColors.primary.withValues(alpha: 0.42),
      AppColors.primary.withValues(alpha: 0.12),
      AppColors.primary.withValues(alpha: 0),
    ]);
    // Le rose décalé vers le bas à droite, comme la fin du dégradé du H.
    glow(c + const Offset(50, 60), 170, [
      AppColors.pink.withValues(alpha: 0.22),
      AppColors.pink.withValues(alpha: 0),
    ]);

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (var i = 0; i < _ringCount; i++) {
      final p = (progress.value + i / _ringCount) % 1.0;
      // Apparaît en douceur, puis s'efface en s'éloignant : sans l'entrée en
      // fondu, chaque onde surgirait d'un coup au bord du logo.
      final fadeIn = (p / 0.15).clamp(0.0, 1.0);
      final alpha = 0.32 * fadeIn * math.pow(1 - p, 1.4);
      ring.color = AppColors.lavenderLight.withValues(alpha: alpha.toDouble());
      canvas.drawCircle(c, _ringStart + p * _ringTravel, ring);
    }
  }

  @override
  bool shouldRepaint(_HaloPainter old) => old.progress != progress;
}
