import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:happyn/core/providers/user_profile_provider.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:happyn/core/push/push_service.dart';
import 'package:happyn/l10n/app_localizations.dart';
import 'package:happyn/features/home/home_screen.dart';
import 'package:happyn/features/profile/profile_screen.dart';
import 'package:happyn/features/events/create_event_screen.dart';
import 'package:happyn/features/social/create_post_screen.dart';
import 'package:happyn/features/discover/discover_screen.dart';
import 'package:happyn/features/ticketing/my_tickets_screen.dart';
import 'package:happyn/features/social/direct_messages_screen.dart';
import 'package:happyn/core/providers/notifications_provider.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  final ScrollController _homeScrollController = ScrollController();

  // Progression du panneau Messages : 0 = ferme (hors ecran a droite), 1 =
  // ouvert. Il vit ICI, au-dessus de MainShell, pour couvrir tout l'ecran,
  // barre d'onglets comprise (facon Instagram) ; et comme il reste SOUS les
  // routes poussees, une conversation ouverte depuis la liste passe par-dessus.
  // Pilote au doigt par le geste de bord de l'accueil (via MessagesPanelScope).
  late final AnimationController _msg = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    reverseDuration: const Duration(milliseconds: 220),
  );

  void _openMessages() => _msg.animateTo(1, curve: Curves.easeOutCubic);

  void _closeMessages() {
    _msg.animateBack(0, curve: Curves.easeOutCubic);
    ref.invalidate(unreadMessagesProvider);
  }

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

    // Si l'app a été ouverte depuis l'état fermé en touchant une notification,
    // c'est ici — session restaurée, navigateur prêt — qu'on ouvre son écran.
    // Après la première frame : pousser une route pendant l'`initState`
    // verrouillerait le navigateur en pleine construction.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PushService.consumePendingTap();
    });
  }

  @override
  void dispose() {
    _msg.dispose();
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
    // Le panneau est EMPILE par-dessus toute la coque (corps + barre d'onglets),
    // et le scope expose le controleur a l'accueil pour le geste de bord et
    // l'icone Messages. Les routes poussees (une conversation) restent au-dessus
    // du panneau car elles s'ajoutent au-dessus de la route MainShell entiere.
    return MessagesPanelScope(
      controller: _msg,
      open: _openMessages,
      close: _closeMessages,
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: AppColors.background,
            // Le corps passe SOUS la barre : contenu plein écran, et le nav en
            // verre dépoli floute ce qui défile derrière lui.
            extendBody: true,
            body: IndexedStack(
              index: _currentIndex == 2 ? 0 : _currentIndex,
              children: _pages,
            ),
            bottomNavigationBar: _buildBottomNav(),
          ),
          _messagesPanel(),
        ],
      ),
    );
  }

  /// Le panneau Messages : hors ecran a droite a 0, en place a 1. Non monte
  /// tant qu'il est ferme (comme une route depilee). Un voile assombrit la
  /// coque a mesure qu'il entre, pour la profondeur. Suivi LINEAIRE : la
  /// position colle au doigt ; la courbe n'intervient qu'au reglage (open/close).
  Widget _messagesPanel() => AnimatedBuilder(
        animation: _msg,
        child: DirectMessagesScreen(onClose: _closeMessages),
        builder: (context, child) {
          final v = _msg.value;
          if (v == 0) return const SizedBox.shrink();
          final w = MediaQuery.of(context).size.width;
          return Positioned.fill(
            child: Stack(children: [
              IgnorePointer(
                child: Opacity(
                  opacity: v * 0.45,
                  child: const ColoredBox(color: Colors.black),
                ),
              ),
              Transform.translate(
                offset: Offset(w * (1 - v), 0),
                child: child,
              ),
            ]),
          );
        },
      );

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
    final labels = [l.navHome, l.navDiscover, l.navCreate, l.navTickets, l.navProfile];
    const icons = [
      Icons.home_rounded,
      Icons.explore_outlined,
      Icons.add,
      Icons.confirmation_number_outlined,
      Icons.person_outline,
    ];

    Widget buildItem(int i) {
      final isActive = i == _currentIndex;
      final isCreate = i == 2;

      // Icônes seules : pas de libellé permanent. Le nom apparaît sur APPUI
      // LONG (Tooltip) — la barre reste épurée tout en restant découvrable.
      final Widget content;
      if (isCreate) {
        content = Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.add, color: Colors.white, size: 23),
        );
      } else {
        final iconWidget = i == 4
            ? _ProfileTabIcon(active: isActive)
            : Icon(icons[i],
                size: 24, color: isActive ? Colors.white : AppColors.textLow);
        content = Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          // L'onglet actif est posé dans une capsule sombre neutre.
          decoration: isActive
              ? BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                )
              : null,
          child: iconWidget,
        );
      }

      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (isCreate) {
              _openCreateSheet();
              return;
            }
            // Retaper Home en y étant déjà → remonter en haut.
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
          // `heightFactor: 1` : sans lui, l'`Align` prendrait toute la hauteur
          // lâche d'une barre d'onglets et la pilule mangerait l'écran (et le
          // flou baverait sur toute la page).
          child: Align(
            heightFactor: 1,
            child: Tooltip(
              message: labels[i],
              triggerMode: TooltipTriggerMode.longPress,
              preferBelow: false,
              child: content,
            ),
          ),
        ),
      );
    }

    // Pilule flottante en verre dépoli, posée BAS : on ne garde que ce qu'il
    // faut pour dégager l'indicateur d'accueil, sans le grand espace flottant
    // d'un SafeArea complet. (Pour la remonter : augmenter `navBottom`.)
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final navBottom = bottomInset > 20 ? bottomInset - 14 : 6.0;
    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, bottom: navBottom),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0x8C16161F),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.40),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            child: Row(children: List.generate(5, buildItem)),
          ),
        ),
      ),
    );
  }
}

/// Donne a l'accueil (geste de bord + icone Messages) la main sur le panneau
/// Messages porte par MainShell, sans remonter d'etat ni de cle globale.
class MessagesPanelScope extends InheritedWidget {
  const MessagesPanelScope({
    super.key,
    required this.controller,
    required this.open,
    required this.close,
    required super.child,
  });

  /// Progression du panneau (0 ferme → 1 ouvert) : le geste la pilote au doigt.
  final AnimationController controller;

  /// Ouvre / referme en animant jusqu'au bout (tap icone, fin de geste).
  final VoidCallback open;
  final VoidCallback close;

  static MessagesPanelScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MessagesPanelScope>()!;

  @override
  bool updateShouldNotify(MessagesPanelScope old) =>
      controller != old.controller;
}

/// L'onglet Profil : la photo de la personne si elle en a une, sinon l'icône
/// habituelle — pas d'initiales, qui chargeaient la barre pour rien.
///
/// Entourée de lavande quand l'onglet est actif, comme l'icône change de
/// couleur à côté.
class _ProfileTabIcon extends ConsumerWidget {
  const _ProfileTabIcon({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).asData?.value;
    final avatar = (profile?['avatar_url'] as String?) ?? '';
    final icon = Icon(
      Icons.person_outline,
      size: 22,
      color: active ? AppColors.lavender : AppColors.textLow,
    );
    if (avatar.isEmpty) return icon;

    // 22 points, comme les icônes voisines : plus grand, le libellé
    // « Profil » descendait sous la ligne des autres.
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
        child: CachedNetworkImage(
          imageUrl: avatar,
          width: 19,
          height: 19,
          fit: BoxFit.cover,
          errorWidget: (_, _, _) => icon,
        ),
      ),
    );
  }
}
