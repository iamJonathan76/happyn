import 'package:flutter/material.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:happyn/l10n/app_localizations.dart';
import 'package:happyn/features/home/home_screen.dart';
import 'package:happyn/features/profile/profile_screen.dart';
import 'package:happyn/features/events/create_event_screen.dart';
import 'package:happyn/features/social/create_post_screen.dart';
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
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _currentIndex == 2 ? 0 : _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  /// Le « + » propose les deux créations.
  ///
  /// Cacher « publier » dans le menu d'une fiche événement etait plus pur mais
  /// introuvable. La legitimite n'a plus besoin d'etre defendue par l'interface :
  /// le composeur ne propose que les evenements de l'utilisateur, et la base
  /// refuse le reste (`can_attach_event`).
  Future<void> _openCreateSheet() async {
    final l = AppLocalizations.of(context);
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.sheet,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 18),
            Text(l.createWhat, style: AppText.h3),
            const SizedBox(height: 10),
            _createOption(sheetCtx, Icons.event_outlined,
                l.createEventChoice, 'event'),
            _createOption(sheetCtx, Icons.add_a_photo_outlined,
                l.shareMoment, 'post'),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );

    if (!mounted || choice == null) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => choice == 'event'
          ? const CreateEventScreen()
          : const CreatePostScreen(),
    ));
    if (mounted) setState(() => _currentIndex = 0);
  }

  Widget _createOption(
          BuildContext ctx, IconData icon, String label, String value) =>
      ListTile(
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.lavenderLight, size: 20),
        ),
        title: Text(label, style: AppText.bodySm.copyWith(color: Colors.white)),
        trailing: Icon(Icons.chevron_right, color: AppColors.textLow, size: 18),
        onTap: () => Navigator.of(ctx).pop(value),
      );

  Widget _buildBottomNav() {
    final l = AppLocalizations.of(context);
    final items = [
      {'icon': Icons.home_rounded, 'label': l.navHome},
      {'icon': Icons.explore_outlined, 'label': l.navDiscover},
      {'icon': Icons.add, 'label': ''},
      {'icon': Icons.confirmation_number_outlined, 'label': l.navTickets},
      {'icon': Icons.person_outline, 'label': l.navProfile},
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background.withOpacity(0.96),
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
              onTap: _openCreateSheet,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.pink],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.55),
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
                      ? AppColors.lavender
                      : AppColors.textLow,
                ),
                const SizedBox(height: 2),
                Text(
                  item['label'] as String,
                  style: AppText.microBold.copyWith(fontWeight: FontWeight.w600, color: isActive
                        ? AppColors.lavender
                        : AppColors.textLow),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}