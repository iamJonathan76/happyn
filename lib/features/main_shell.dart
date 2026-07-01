import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:happyn/features/home/home_screen.dart';
import 'package:happyn/features/profile/profile_screen.dart';
import 'package:happyn/features/events/create_event_screen.dart';
import 'package:happyn/features/discover/discover_screen.dart';
import 'package:happyn/features/ticketing/my_tickets_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  final ScrollController _homeScrollController = ScrollController();

  @override
  void dispose() {
    _homeScrollController.dispose();
    super.dispose();
  }

  // Plus besoin de GlobalKey : le refresh passe maintenant par
  // eventsProvider (Riverpod), invalidé directement dans
  // CreateEventScreen et ProfileScreen après chaque mutation.
  // La recherche du Home renvoie vers l'onglet Discover (vraie recherche).
  List<Widget> get _pages => [
        HomeScreen(
          onSearchTap: () => setState(() => _currentIndex = 1),
          scrollController: _homeScrollController,
        ),
        const DiscoverScreen(),
        const SizedBox(),
        const MyTicketsScreen(),
        const ProfileScreen(),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08080F),
      body: IndexedStack(
        index: _currentIndex == 2 ? 0 : _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    final items = [
      {'icon': Icons.home_rounded, 'label': 'Home'},
      {'icon': Icons.explore_outlined, 'label': 'Discover'},
      {'icon': Icons.add, 'label': ''},
      {'icon': Icons.confirmation_number_outlined, 'label': 'Tickets'},
      {'icon': Icons.person_outline, 'label': 'Profile'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF08080F).withOpacity(0.96),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.07))),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 8,
        top: 8,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          final isActive = i == _currentIndex;

          // FAB center button
          if (i == 2) {
            return GestureDetector(
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CreateEventScreen()),
                );
                // Le provider a déjà été invalidé dans CreateEventScreen.
                // On bascule juste l'utilisateur sur Home pour voir le résultat.
                if (mounted) {
                  setState(() => _currentIndex = 0);
                }
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7C3AED).withOpacity(0.55),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 24),
              ),
            );
          }

          return GestureDetector(
            onTap: () {
              // Retaper Home en y étant déjà → remonter en haut de la page.
              if (i == 0 &&
                  _currentIndex == 0 &&
                  _homeScrollController.hasClients) {
                _homeScrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOut,
                );
              } else {
                setState(() => _currentIndex = i);
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  item['icon'] as IconData,
                  size: 22,
                  color: isActive
                      ? const Color(0xFFA78BFA)
                      : Colors.white.withOpacity(0.32),
                ),
                const SizedBox(height: 2),
                Text(
                  item['label'] as String,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: isActive
                        ? const Color(0xFFA78BFA)
                        : Colors.white.withOpacity(0.3),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}