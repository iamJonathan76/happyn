import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    )..repeat(reverse: true);

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeController.forward();

    // Navigate after 2.6s
   Future.delayed(const Duration(milliseconds: 2600), () {
  final session = Supabase.instance.client.auth.currentSession;

  if (!mounted) return;

  if (session != null) {
    Navigator.of(context).pushReplacementNamed('/home');
  } else {
    Navigator.of(context).pushReplacementNamed('/onboarding');
  }
});
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.24),
            radius: 1.2,
            colors: [
              Color(0xFF3B0764),
              Color(0xFF1A0F3D),
              Color(0xFF08080F),
            ],
            stops: [0.0, 0.45, 0.80],
          ),
        ),
        child: Stack(
          children: [
            // Orb 1 — top left purple
            Positioned(
              top: -40,
              left: -60,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF7C3AED).withOpacity(0.28),
                ),
              ),
            ),
            // Orb 2 — bottom right pink
            Positioned(
              bottom: 120,
              right: -40,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFEC4899).withOpacity(0.22),
                ),
              ),
            ),
            // Orb 3 — bottom left orange
            Positioned(
              bottom: 80,
              left: 20,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFF97316).withOpacity(0.18),
                ),
              ),
            ),

            // Main content
            Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // HAPPYN logo with gradient
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds),
                      child: Text(
                        'HAPPYN',
                        style: GoogleFonts.poppins(
                          fontSize: 72,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -1,
                          height: 1,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Tagline
                    Text(
                      'FIND THE ONES. BE THE MOMENT.',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFF0EEFF).withOpacity(0.38),
                        letterSpacing: 3.2,
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Pulsing dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(3, (index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              final delay = index * 0.22;
                              final value = (_pulseController.value + delay) % 1.0;
                              final opacity = (value < 0.5)
                                  ? value * 2
                                  : (1.0 - value) * 2;
                              return Opacity(
                                opacity: opacity.clamp(0.2, 1.0),
                                child: Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [
                                        Color(0xFF7C3AED),
                                        Color(0xFFEC4899),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}