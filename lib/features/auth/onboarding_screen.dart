import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
      'color': Color(0xFF7C3AED),
      'icon': Icons.auto_awesome,
    },
    {
      'img': 'https://images.unsplash.com/photo-1470229722913-7c0e2dbbafd3?w=800&h=640&fit=crop&auto=format',
      'title': 'Connect With\nYour People',
      'sub': 'Follow friends, join communities, and always know who is going where before you commit.',
      'color': Color(0xFFEC4899),
      'icon': Icons.people,
    },
    {
      'img': 'https://images.unsplash.com/photo-1506157786151-b8491531f063?w=800&h=640&fit=crop&auto=format',
      'title': 'Be the Moment',
      'sub': 'Secure tickets in seconds. QR check-in. No stress, no FOMO. Just pure experience.',
      'color': Color(0xFFF97316),
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
    final slide = _slides[_currentSlide];

    return Scaffold(
      backgroundColor: const Color(0xFF08080F),
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
                    color: const Color(0xFF1A0F3D),
                  ),
                ),
                // Dark gradient overlay
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x33080F),
                        Color(0x1A08080F),
                        Color(0xFF08080F),
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
                          color: Colors.white.withOpacity(0.15),
                        ),
                      ),
                      child: Text(
                        'Skip',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.6),
                        ),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon badge
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7C3AED).withOpacity(0.55),
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
                    slide['title'],
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Subtitle
                  Text(
                    slide['sub'],
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xFFF0EEFF).withOpacity(0.5),
                      height: 1.6,
                    ),
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
                                    Color(0xFF7C3AED),
                                    Color(0xFFEC4899)
                                  ],
                                )
                              : null,
                          color: isActive
                              ? null
                              : Colors.white.withOpacity(0.18),
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
                          colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF7C3AED).withOpacity(0.55),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _currentSlide < 2 ? 'Continue' : 'Get Started',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
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
        ],
      ),
    );
  }
}