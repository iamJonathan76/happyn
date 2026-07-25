import 'package:flutter/material.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
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

  Future<void> _setStatus(String newStatus, String toast) async {
    try {
      await Supabase.instance.client
          .from('events')
          .update({'status': newStatus}).eq('id', widget.event['id']);
      widget.event['status'] = newStatus; // maj locale pour l'affichage
      if (!mounted) return;
      setState(() => _status = newStatus);
      ref.invalidate(eventsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(toast, style: GoogleFonts.inter(color: Colors.white)),
          backgroundColor: AppColors.card,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).actionFailed)),
        );
      }
    }
  }

  Widget _organizerMenu() {
    final l = AppLocalizations.of(context);
    return PopupMenuButton<String>(
      color: AppColors.card,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      position: PopupMenuPosition.under,
      onSelected: (v) {
        if (v == 'unpublish') _setStatus('draft', l.eventUnpublishedMsg);
        if (v == 'publish') _setStatus('published', l.eventPublishedMsg);
        if (v == 'cancel') _confirmCancel();
      },
      itemBuilder: (context) => [
        if (_status == 'published')
          _menuItem('unpublish', Icons.visibility_off_outlined, l.unpublish)
        else
          _menuItem('publish', Icons.publish_outlined, l.publish),
        if (_status != 'cancelled')
          _menuItem('cancel', Icons.cancel_outlined, l.cancelEvent,
              danger: true),
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
              style: GoogleFonts.inter(color: c, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _confirmCancel() {
    final l = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l.cancelEventTitle,
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text(
          l.cancelEventBody,
          style: GoogleFonts.inter(color: AppColors.textMed),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.keep,
                style: GoogleFonts.inter(color: AppColors.textMed)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _setStatus('cancelled', l.eventCancelledMsg);
            },
            child: Text(l.cancelEvent,
                style: GoogleFonts.inter(
                    color: AppColors.error,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
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
                                              style: GoogleFonts.inter(
                                                  color: Colors.white)),
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
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
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
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textHigh,
                                  ),
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
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),

                      const SizedBox(height: 6),

                      // Category subtitle
                      Row(
                        children: [
                          Icon(categoryIcon(cat), size: 15, color: catColor),
                          const SizedBox(width: 6),
                          Text(
                            cat,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: catColor,
                            ),
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

                      // Location
                      _infoRow(
                        Icons.location_on_outlined,
                        (ev['location'] ?? 'TBD') as String,
                        (ev['city'] ?? '') as String,
                      ),

                      const SizedBox(height: 24),

                      // Description
                      if (ev['description'] != null &&
                          (ev['description'] as String).isNotEmpty) ...[
                        Text(
                          l.aboutThisEvent,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          ev['description'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppColors.textMed,
                            height: 1.6,
                          ),
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
                      // Price (masqué pour l'organisateur)
                      if (!isOrganizer) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l.startingFrom,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.textLow,
                          ),
                        ),
                        Text(
                          priceText,
                          style: GoogleFonts.poppins(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
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
                            Text(
                              blocked
                                  ? ctaLabel
                                  : isOrganizer
                                      ? l.scanTickets
                                      : l.getTickets,
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: blocked
                                    ? AppColors.textMed
                                    : Colors.white,
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

  Widget _infoRow(IconData icon, String top, String bottom) {
    return Container(
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
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (bottom.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    bottom,
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      color: AppColors.textMed,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
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
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.lavenderLight,
        ),
      ),
    );
  }
}
