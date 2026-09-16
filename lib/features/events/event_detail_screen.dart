import 'package:flutter/material.dart';
import 'package:happyn/core/widgets/app_form.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:happyn/core/providers/favorites_provider.dart';
import 'package:happyn/core/providers/events_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:happyn/core/categories/category_visuals.dart';
import 'package:happyn/core/events/event_utils.dart';
import 'package:happyn/features/events/create_event_screen.dart';
import 'package:happyn/features/ticketing/ticket_selection_screen.dart';
import 'package:happyn/l10n/app_localizations.dart';
import 'package:happyn/core/utils/dates.dart';
import 'package:happyn/core/utils/maps.dart';
import 'package:happyn/features/events/organizer_event_screen.dart';
import 'package:happyn/features/events/widgets/event_moments.dart';
import 'package:happyn/features/events/widgets/whos_going.dart';
import 'package:happyn/features/social/create_post_screen.dart';
import 'package:happyn/core/providers/address_provider.dart';
import 'package:happyn/core/providers/admin_provider.dart';
import 'package:happyn/core/providers/social_provider.dart';
import 'package:happyn/core/widgets/moderation_sheet.dart';
import 'package:happyn/features/ticketing/scanner_screen.dart';

class EventDetailScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> event;
  const EventDetailScreen({super.key, required this.event});

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  late String _status;

  @override
  void initState() {
    super.initState();
    _status = (widget.event['status'] ?? 'published') as String;
  }

  Widget _organizerMenu() {
    final l = AppLocalizations.of(context);
    return PopupMenuButton<String>(
      color: AppColors.card,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      position: PopupMenuPosition.under,
      onSelected: (v) {
        if (v == 'manage') {
          Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => OrganizerEventScreen(event: widget.event)));
        }
        if (v == 'moment') {
          _shareMoment(widget.event['id'] as String);
        }
      },
      // Publier, annuler, supprimer ne sont plus ici : ce sont des decisions
      // qu'on ne devrait pas prendre depuis l'ecran que voient les acheteurs,
      // sans avoir les ventes sous les yeux. Elles vivent dans « Gerer ».
      itemBuilder: (context) => [
        _menuItem('manage', Icons.insights_outlined, l.manageEvent),
        _menuItem('moment', Icons.add_a_photo_outlined, l.shareMoment),
      ],
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.45),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: const Icon(Icons.more_horiz, color: Colors.white, size: 18),
      ),
    );
  }

  /// Peut-on documenter cet événement ? (organisateur ou détenteur de billet)
  /// Même règle que `can_attach_event` côté base — ici c'est du confort d'UI.
  bool _canPost(String eventId) {
    final list = ref.watch(attachableEventsProvider).asData?.value ?? const [];
    return list.any((e) => e['id'] == eventId);
  }

  Future<void> _shareMoment(String eventId) async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CreatePostScreen(initialEventId: eventId)));
    if (!mounted) return;
    ref.invalidate(discoverFeedProvider);
    // Sans ca la section « Moments » de cette fiche resterait vide juste apres
    // qu'on vient d'y publier.
    ref.invalidate(eventPostsProvider(eventId));
  }

  /// Menu du visiteur : partager un moment, signaler, bloquer.
  Widget _visitorMenu(Map<String, dynamic> ev) {
    final l = AppLocalizations.of(context);
    final organizerId = ev['created_by'] as String?;
    return PopupMenuButton<String>(
      color: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      position: PopupMenuPosition.under,
      onSelected: (v) async {
        if (v == 'moment') {
          await _shareMoment(ev['id'] as String);
        } else if (v == 'admin_remove') {
          await _adminRemove(l, ev['id'] as String);
        } else if (v == 'report') {
          await showReportSheet(context,
              targetType: 'event', targetId: ev['id'] as String);
        } else if (v == 'block' && organizerId != null) {
          final blocked =
              await confirmBlockUser(context, ref, userId: organizerId);
          if (blocked && mounted) {
            ref.invalidate(eventsProvider);
            showAppSnack(context, l.userBlocked);
            Navigator.of(context).pop(); // on quitte la fiche masquée
          }
        }
      },
      itemBuilder: (context) => [
        if (_canPost(ev['id'] as String))
          _menuItem('moment', Icons.add_a_photo_outlined, l.shareMoment),
        // Visible des seuls moderateurs. Ce n'est pas ce qui protege :
        // removeContent revérifie le droit en base.
        if (ref.watch(isAdminProvider).asData?.value == true)
          _menuItem('admin_remove', Icons.shield_outlined, l.actionRemove,
              danger: true),
        _menuItem('report', Icons.flag_outlined, l.reportEvent),
        if (organizerId != null)
          _menuItem('block', Icons.block, l.blockOrganizer, danger: true),
      ],
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.45),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: const Icon(Icons.more_horiz, color: Colors.white, size: 18),
      ),
    );
  }

  /// Compteur de ventes, visible du seul organisateur.
  ///
  /// Sans plafond de quantite (`total == 0`), on affiche le nombre vendu seul :
  /// « 12 / 0 » n'aurait aucun sens.
  Widget _salesCounter(String eventId, AppLocalizations l) {
    final sales = ref.watch(eventSalesProvider(eventId)).asData?.value;
    if (sales == null) return const SizedBox(width: 16);

    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l.soldLabel, style: AppText.small),
          Text(
            sales.total > 0
                ? l.soldOfTotal(sales.sold, sales.total)
                : '${sales.sold}',
            style: AppText.display.copyWith(fontSize: 26, color: Colors.white),
          ),
        ],
      ),
    );
  }

  /// Retrait par un moderateur, depuis la fiche elle-meme.
  ///
  /// Un evenement est DEPUBLIE, pas supprime : des gens ont peut-etre achete
  /// des billets, et effacer la ligne les priverait de la trace de ce qu'ils
  /// ont paye. C'est la fonction admin_remove_content qui applique cette
  /// nuance, pas l'app.
  Future<void> _adminRemove(AppLocalizations l, String eventId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l.actionRemove,
            style: AppText.h4.copyWith(color: Colors.white)),
        content: Text(l.adminRemoveConfirm, style: AppText.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(l.keep, style: AppText.body),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(l.actionRemove,
                style: AppText.smallBold.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await removeContent('event', eventId);
      if (!mounted) return;
      ref.invalidate(eventsProvider);
      showAppSnack(context, l.contentRemoved);
      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('adminRemove failed: $e');
      if (mounted) showAppSnack(context, l.moderationFailed);
    }
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label,
      {bool danger = false}) {
    final c = danger ? AppColors.error : Colors.white;
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: c),
          const SizedBox(width: 10),
          Text(label,
              style: AppText.body.copyWith(fontWeight: FontWeight.w600, color: c)),
        ],
      ),
    );
  }

  /// Ouvre l'app Maps sur l'adresse de l'event (lieu + ville).
  Future<void> _openDirections(
      Map<String, dynamic> ev, String? exactAddress) async {
    // L'adresse exacte quand on y a droit, sinon le repere public et la ville.
    // Un itineraire vers « Ottawa » est inutile, mais c'est moins grave que de
    // reveler une adresse qu'on n'est pas cense connaitre.
    final address = [exactAddress ?? ev['location'], ev['city']]
        .where((s) => s != null && s.toString().trim().isNotEmpty)
        .join(', ');
    final ok = await openInMaps(address);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context).couldNotOpenMaps)),
      );
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return AppLocalizations.of(context).tbd;
    return AppDates.dowDayMonthYear(context, dateStr);
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return AppLocalizations.of(context).tbd;
    return AppDates.time(context, dateStr);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ev = widget.event;
    // Adresse precise, ou null si la base refuse de la donner.
    final exactAddress =
        ref.watch(eventAddressProvider(ev['id'] as String)).asData?.value?.addressLine;

    final imageUrl = (ev['image_url'] ?? '') as String;
    final price = ev['price'];
    final priceText = (price == null || price == 0) ? l.free : '\$$price';
    final cat = (ev['category'] ?? '') as String;
    final catColor = categoryColor(cat);
    final past = isEventPast(ev);
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isOrganizer =
        currentUserId != null && ev['created_by'] == currentUserId;
    final cancelled = _status == 'cancelled';
    // Un visiteur ne peut pas acheter un event terminé, annulé ou dépublié.
    final blocked = !isOrganizer && (past || _status != 'published');
    final ctaLabel = cancelled
        ? l.eventCancelledMsg
        : past
            ? l.eventEnded
            : l.ctaUnavailable;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Scrollable Content ───────────────────────────────────
          CustomScrollView(
            slivers: [
              // Hero Image
              SliverToBoxAdapter(
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.44,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Image
                      CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, _) =>
                            Container(color: AppColors.imagePlaceholder),
                        errorWidget: (_, _, _) => Container(
                          color: AppColors.imagePlaceholder,
                          child: const Center(
                            child: Icon(
                              Icons.event,
                              color: AppColors.primary,
                              size: 48,
                            ),
                          ),
                        ),
                      ),

                      // Gradient overlay
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x66080F0F),
                              Colors.transparent,
                              Color(0xCC08080F),
                              AppColors.background,
                            ],
                            stops: [0.0, 0.35, 0.78, 1.0],
                          ),
                        ),
                      ),

                      // Top bar
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 8,
                        left: 0,
                        right: 0,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Back
                              GestureDetector(
                                onTap: () => Navigator.of(context).pop(),
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.45),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.12),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.arrow_back_ios_new,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),

                              // Edit (organizer) + Share + Like
                              Row(
                                children: [
                                  if (isOrganizer) ...[
                                    GestureDetector(
                                      onTap: () async {
                                        final result =
                                            await Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                CreateEventScreen(event: ev),
                                          ),
                                        );
                                        // Event modifié → on revient à la liste
                                        // (déjà rafraîchie via le provider).
                                        if (result == true && mounted) {
                                          Navigator.of(context).pop();
                                        }
                                      },
                                      child: Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.45),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                              color: Colors.white
                                                  .withOpacity(0.12)),
                                        ),
                                        child: const Icon(Icons.edit_outlined,
                                            color: Colors.white, size: 16),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  GestureDetector(
                                    onTap: () {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(l.sharingSoon,
                                              style: AppText.body.copyWith(color: Colors.white)),
                                          backgroundColor:
                                              AppColors.card,
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12)),
                                          duration: const Duration(seconds: 1),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.45),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.12),
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.share_outlined,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (isOrganizer)
                                    _organizerMenu()
                                  else
                                  Consumer(
                                    builder: (context, ref, _) {
                                      final favIds = ref
                                              .watch(favoritesProvider)
                                              .asData
                                              ?.value ??
                                          <String>{};
                                      final isFav =
                                          favIds.contains(ev['id']);
                                      return GestureDetector(
                                        onTap: () async {
                                          await toggleFavorite(
                                              ev['id'] as String, isFav);
                                          ref.invalidate(favoritesProvider);
                                        },
                                        child: Container(
                                          width: 38,
                                          height: 38,
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.black.withOpacity(0.45),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                              color:
                                                  Colors.white.withOpacity(0.12),
                                            ),
                                          ),
                                          child: Icon(
                                            isFav
                                                ? Icons.favorite
                                                : Icons.favorite_border,
                                            color: isFav
                                                ? AppColors.pink
                                                : Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  // Modération : signaler / bloquer.
                                  // Exigé par Apple (règle 1.2) dès lors que
                                  // les utilisateurs publient du contenu.
                                  if (!isOrganizer) ...[
                                    const SizedBox(width: 8),
                                    _visitorMenu(ev),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Category badge
                      Positioned(
                        bottom: 20,
                        left: 20,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.pink, AppColors.warning],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '🔥 ${(ev['category'] ?? 'Event') as String}',
                            style: AppText.micro.copyWith(fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ),
                      ),

                      // Badge « Cancelled » / « Ended »
                      if (cancelled || past)
                        Positioned(
                          bottom: 20,
                          right: 20,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: cancelled
                                  ? AppColors.error.withOpacity(0.9)
                                  : Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: AppColors.textFaint),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                    cancelled
                                        ? Icons.cancel
                                        : Icons.event_busy,
                                    size: 12,
                                    color: AppColors.textHigh),
                                const SizedBox(width: 4),
                                Text(
                                  cancelled ? l.statusCancelled : l.statusEnded,
                                  style: AppText.micro.copyWith(fontWeight: FontWeight.w700, color: AppColors.textHigh),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Content
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        (ev['title'] ?? '') as String,
                        style: AppText.display.copyWith(color: Colors.white, height: 1.2),
                      ),

                      const SizedBox(height: 6),

                      // Category subtitle
                      Row(
                        children: [
                          Icon(categoryIcon(cat), size: 15, color: catColor),
                          const SizedBox(width: 6),
                          Text(
                            cat,
                            style: AppText.bodySm.copyWith(fontWeight: FontWeight.w600, color: catColor),
                          ),
                        ],
                      ),

                      const SizedBox(height: 22),

                      // Date & time
                      _infoRow(
                        Icons.calendar_today_outlined,
                        _formatDate(ev['start_date'] as String?),
                        '${_formatTime(ev['start_date'] as String?)} - ${_formatTime(ev['end_date'] as String?)}',
                      ),
                      const SizedBox(height: 12),

                      // Location — cliquable : ouvre l'app Maps (itinéraire).
                      //
                      // `address` est null quand la base refuse de la donner :
                      // evenement prive, et ni organisateur ni detenteur de
                      // billet. Le filtrage est en base, pas ici — l'app ne
                      // recoit tout simplement pas ce qu'elle n'a pas le droit
                      // d'afficher.
                      _infoRow(
                        Icons.location_on_outlined,
                        exactAddress ?? (ev['location'] ?? 'TBD') as String,
                        exactAddress == null && isEventPrivate(ev)
                            ? l.addressRevealedWithTicket
                            : (ev['city'] ?? '') as String,
                        onTap: () => _openDirections(ev, exactAddress),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: AppColors.primary.withOpacity(0.35)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.directions,
                                  color: AppColors.lavenderLight, size: 15),
                              const SizedBox(width: 5),
                              Text(
                                l.getDirections,
                                style: AppText.smallBold.copyWith(color: AppColors.lavenderLight),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Preuve sociale, placee au moment de la decision.
                      WhosGoing(eventId: ev['id'] as String),

                      // Preuve visuelle : ce que l'evenement a donne.
                      EventMoments(eventId: ev['id'] as String),

                      const SizedBox(height: 24),

                      // Description
                      if (ev['description'] != null &&
                          (ev['description'] as String).isNotEmpty) ...[
                        Text(
                          l.aboutThisEvent,
                          style: AppText.h2.copyWith(fontSize: 16, color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          ev['description'] as String,
                          style: AppText.body.copyWith(height: 1.6),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Tags
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _tag(ev['category'] ?? 'Event'),
                          if ((ev['city'] ?? '').toString().isNotEmpty)
                            _tag(ev['city']),
                          if ((ev['price'] ?? 0) == 0) _tag(l.freeEntry),
                          if (((ev['min_age'] ?? 0) as int) > 0)
                            _tag('${ev['min_age']}+'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ── Sticky Bottom CTA ────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                MediaQuery.of(context).padding.bottom + 16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.background.withOpacity(0),
                    AppColors.background,
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      // L'organisateur voit ses ventes la ou le visiteur voit
                      // le prix : meme emplacement, information adaptee au role.
                      if (isOrganizer)
                        _salesCounter(ev['id'] as String, l)
                      else ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l.startingFrom,
                          style: AppText.small,
                        ),
                        Text(
                          priceText,
                          style: AppText.display.copyWith(fontSize: 26, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                  ],

                  // CTA Button : Scan (organisateur) ou Get Tickets (visiteur)
                  Expanded(
                    child: GestureDetector(
                      onTap: blocked
                          ? null
                          : () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => isOrganizer
                                      ? ScannerScreen(event: ev)
                                      : TicketSelectionScreen(event: ev),
                                ),
                              );
                            },
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: blocked
                              ? null
                              : const LinearGradient(
                                  colors: [
                                    AppColors.primary,
                                    AppColors.pink
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          color: blocked ? Colors.white.withOpacity(0.08) : null,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: blocked
                              ? null
                              : [
                                  BoxShadow(
                                    color: AppColors.primary
                                        .withOpacity(0.55),
                                    blurRadius: 20,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              blocked
                                  ? Icons.event_busy
                                  : isOrganizer
                                      ? Icons.qr_code_scanner
                                      : Icons.confirmation_number_outlined,
                              color: blocked
                                  ? AppColors.textMed
                                  : Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  blocked
                                      ? ctaLabel
                                      : isOrganizer
                                          ? l.scanTickets
                                          : l.getTickets,
                                  maxLines: 1,
                                  style: AppText.h3.copyWith(color: blocked
                                        ? AppColors.textMed
                                        : Colors.white),
                                ),
                              ),
                            ),
                            if (!blocked) ...[
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.arrow_forward,
                                color: Colors.white,
                                size: 16,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  ],
                ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String top, String bottom,
      {VoidCallback? onTap, Widget? trailing}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.lavenderLight, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  top,
                  style: AppText.bodySm.copyWith(fontWeight: FontWeight.w700, color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (bottom.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    bottom,
                    style: AppText.caption.copyWith(fontSize: 11.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing,
          ],
        ],
      ),
      ),
    );
  }

  Widget _tag(dynamic label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.13),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.28)),
      ),
      child: Text(
        '#$label',
        style: AppText.small.copyWith(fontWeight: FontWeight.w600, color: AppColors.lavenderLight),
      ),
    );
  }
}
