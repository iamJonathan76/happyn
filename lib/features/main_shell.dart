import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:happyn/core/providers/user_profile_provider.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'dart:async';
import 'package:happyn/core/push/push_service.dart';
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
  void initState() {
    super.initState();
    // Enregistrement du jeton de notification.
    //
    // Il ne se faisait qu'apres une connexion — or l'app restaure la session
    // au demarrage et vient directement ici. Un utilisateur deja connecte
    // n'avait donc AUCUN jeton enregistre : les notifications arrivaient dans
    // l'app et nulle part ailleurs.
    //
    // C'est bien ici et pas dans main() : a ce point la session est restauree,
    // et on sait que la personne est connectee.
    unawaited(PushService.registerForUser());
  }

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
            color: AppColors.primary.withValues(alpha: 0.15),
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

    // Cinq éléments côte à côte ne peuvent pas honorer une police système à
    // 300 % : les libellés se chevauchent et la barre devient illisible.
    //
    // On plafonne l'échelle ICI seulement, et pas dans toute l'app. Brider
    // globalement reviendrait à ignorer un réglage d'accessibilité que la
    // personne a choisi exprès, y compris sur les écrans qui savent très bien
    // grandir. Une barre d'onglets est le seul endroit où la contrainte est
    // physique : cinq colonnes, une largeur d'écran.
    //
    // 1.3 reste une augmentation réelle et lisible. Au-delà, iOS lui-même passe
    // ses barres d'onglets à une autre disposition plutôt que d'agrandir.
    final navScaler =
        MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.96),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.07))),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 8,
        top: 8,
      ),
      // `Expanded` sur chaque colonne plutôt que `spaceAround` : ainsi chaque
      // onglet reçoit exactement un cinquième de la largeur, quelle que soit la
      // longueur de son libellé. Avec `spaceAround`, les colonnes prenaient leur
      // largeur naturelle et « Discover » poussait « Profile » hors de l'écran
      // dès que la police grossissait.
      child: Row(
        children: items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          final isActive = i == _currentIndex;

          // FAB center button
          if (i == 2) {
            return Expanded(
              // `heightFactor: 1` : sans lui, ce `Center` prend TOUTE la
              // hauteur qu'on lui laisse. Dans une `Row` les enfants recoivent
              // des contraintes laches, et un `bottomNavigationBar` en recoit
              // de laches aussi — la barre occupait donc l'ecran entier, ses
              // icones se retrouvaient centrees au milieu, et il ne restait
              // plus aucune place pour la page. Avec ce facteur, le `Center`
              // se dimensionne sur son enfant : 48 points, la hauteur voulue.
              child: Center(
                heightFactor: 1,
                child: GestureDetector(
                  onTap: _openCreateSheet,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.pink.withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child:
                        const Icon(Icons.add, color: Colors.white, size: 24),
                  ),
                ),
              ),
            );
          }

          return Expanded(
            child: GestureDetector(
              // `opaque` : sans lui, seule la colonne dessinée réagit au
              // toucher, et les marges de l'onglet sont mortes. Sur une barre
              // d'onglets, rater sa cible d'un demi-millimètre est fréquent.
              behavior: HitTestBehavior.opaque,
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
                  if (i == 4)
                    _ProfileTabIcon(active: isActive)
                  else
                    Icon(
                      item['icon'] as IconData,
                      size: 22,
                      color: isActive ? AppColors.lavender : AppColors.textLow,
                    ),
                  const SizedBox(height: 2),
                  Padding(
                    // Deux libellés voisins ne doivent jamais se toucher :
                    // « TicketsProfile » se lit comme un seul mot.
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Text(
                      item['label'] as String,
                      textScaler: navScaler,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppText.microBold.copyWith(
                        fontWeight: FontWeight.w600,
                        color:
                            isActive ? AppColors.lavender : AppColors.textLow,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// L'onglet Profil montre la personne elle-même : sa photo, ou ses initiales.
///
/// Comme sur Instagram. Avant, sa photo était en haut de l'accueil, à une
/// place qui revient désormais aux messages ; ici, elle dit sans libellé à
/// quoi mène l'onglet. Entourée de lavande quand l'onglet est actif, à la
/// place du changement de couleur d'une icône.
class _ProfileTabIcon extends ConsumerWidget {
  const _ProfileTabIcon({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).asData?.value;
    final avatar = (profile?['avatar_url'] as String?) ?? '';
    final name = ((profile?['full_name'] as String?) ?? '').trim();
    final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final initials = parts.isEmpty
        ? ''
        : parts.length == 1
            ? parts.first[0].toUpperCase()
            : '${parts[0][0]}${parts[1][0]}'.toUpperCase();

    final fallback = initials.isEmpty
        ? Icon(Icons.person_outline,
            size: 15, color: active ? Colors.white : AppColors.textLow)
        : Text(initials,
            style: AppText.microBold.copyWith(
                fontSize: 8, color: Colors.white, height: 1));

    // 22 points, comme les icônes voisines : à 24, le libellé « Profil »
    // descendait sous la ligne des autres.
    return Container(
      width: 22,
      height: 22,
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: active ? AppColors.lavender : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: ClipOval(
        child: Container(
          color: AppColors.action,
          alignment: Alignment.center,
          child: avatar.isEmpty
              ? fallback
              : CachedNetworkImage(
                  imageUrl: avatar,
                  width: 19,
                  height: 19,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => fallback,
                ),
        ),
      ),
    );
  }
}
