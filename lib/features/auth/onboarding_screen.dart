import 'package:flutter/material.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:happyn/l10n/app_localizations.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentSlide = 0;

  final List<Map<String, dynamic>> _slides = [
    {
      'img': 'https://images.unsplash.com/photo-1574155376612-bfa4ed8aabfd?w=800&h=640&fit=crop&auto=format',
      'title': 'Discover Events\nNear You',
      'sub': 'From underground clubs to rooftop festivals — find what moves you, powered by real-time local intelligence.',
      'color': AppColors.primary,
      'icon': Icons.auto_awesome,
    },
    {
      'img': 'https://images.unsplash.com/photo-1470229722913-7c0e2dbbafd3?w=800&h=640&fit=crop&auto=format',
      'title': 'Connect With\nYour People',
      'sub': 'Follow friends, join communities, and always know who is going where before you commit.',
      'color': AppColors.pink,
      'icon': Icons.people,
    },
    {
      'img': 'https://images.unsplash.com/photo-1506157786151-b8491531f063?w=800&h=640&fit=crop&auto=format',
      'title': 'Be the Moment',
      'sub': 'Secure tickets in seconds. QR check-in. No stress, no FOMO. Just pure experience.',
      'color': AppColors.warning,
      'icon': Icons.bolt,
    },
  ];

  void _next() {
    if (_currentSlide < 2) {
      setState(() => _currentSlide++);
    } else {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final slide = _slides[_currentSlide];
    final titles = [l.onbTitle1, l.onbTitle2, l.onbTitle3];
    final subs = [l.onbSub1, l.onbSub2, l.onbSub3];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Image top 54%
          Expanded(
            flex: 54,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: slide['img'],
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: AppColors.imagePlaceholder,
                  ),
                ),
                // Dark gradient overlay
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x0033080f),
                        Color(0x1A08080F),
                        AppColors.background,
                      ],
                      stops: [0.0, 0.4, 1.0],
                    ),
                  ),
                ),
                // Color tint
                Container(
                  color: (slide['color'] as Color).withOpacity(0.18),
                ),
                // Skip button
                Positioned(
                  top: 52,
                  right: 20,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context)
                        .pushReplacementNamed('/login'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.textFaint,
                        ),
                      ),
                      child: Text(
                        l.skip,
                        style: AppText.captionBold.copyWith(color: AppColors.textMed),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content bottom 46%
          Expanded(
            flex: 46,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              // Ce bloc a une hauteur fixe (46 % de l'ecran) mais un contenu
              // qui varie : la traduction la plus longue, une grande taille de
              // police systeme ou un ecran court le faisaient deborder.
              //
              // Le defilement ne s'active que si necessaire : ConstrainedBox
              // impose au contenu au moins la hauteur disponible, et
              // IntrinsicHeight permet au Spacer de continuer a repousser le
              // bouton vers le bas quand il y a de la place. Sans lui, le
              // Spacer n'aurait aucune hauteur a distribuer dans une zone
              // defilante.
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                  // Icon badge
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.pink],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.55),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      slide['icon'] as IconData,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Title
                  Text(
                    titles[_currentSlide],
                    style: AppText.display.copyWith(color: Colors.white, height: 1.2),
                  ),

                  const SizedBox(height: 10),

                  // Subtitle
                  Text(
                    subs[_currentSlide],
                    style: AppText.body.copyWith(color: AppColors.textLight.withOpacity(0.5), height: 1.6),
                  ),

                  const Spacer(),

                  // Dots
                  Row(
                    children: List.generate(3, (i) {
                      final isActive = i == _currentSlide;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: 6),
                        width: isActive ? 28 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          gradient: isActive
                              ? const LinearGradient(
                                  colors: [
                                    AppColors.primary,
                                    AppColors.pink
                                  ],
                                )
                              : null,
                          color: isActive
                              ? null
                              : AppColors.textFaint,
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 20),

                  // CTA Button
                  GestureDetector(
                    onTap: _next,
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
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _currentSlide < 2 ? l.onbContinue : l.getStarted,
                            style: AppText.h3.copyWith(color: Colors.white),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward,
                              color: Colors.white, size: 18),
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
        ],
      ),
    );
  }
}