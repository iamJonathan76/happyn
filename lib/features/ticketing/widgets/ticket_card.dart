import 'package:flutter/material.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:happyn/core/categories/category_visuals.dart';
import 'package:happyn/l10n/app_localizations.dart';
import 'package:happyn/core/utils/dates.dart';

class TicketCard extends StatelessWidget {
  final Map<String, dynamic> ticket;
  final VoidCallback onTap;

  const TicketCard({required this.ticket, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final event = ticket['events'] as Map<String, dynamic>? ?? {};
    final ticketType = ticket['ticket_types'] as Map<String, dynamic>? ?? {};
    final imageUrl = (event['image_url'] ?? '') as String;
    final status = (ticket['status'] ?? 'valid') as String;
    final eventCancelled = (event['status'] ?? 'published') == 'cancelled';
    final cat = (event['category'] ?? '') as String;
    final accent = categoryColor(cat);
    final isValid = status == 'valid' && !eventCancelled;
    const bg = AppColors.cardDark;

    String formatDate(String? d) {
      if (d == null) return l.tbd;
      return AppDates.dayMonthYear(context, d);
    }

    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: isValid ? 1 : 0.6,
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: isValid
                ? [
                    BoxShadow(
                      color: accent.withOpacity(0.22),
                      blurRadius: 26,
                      offset: const Offset(0, 8),
                    )
                  ]
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Column(
              children: [
                // ── Image (moitié haute du billet) ──────────────────
                SizedBox(
                  height: 130,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, _) =>
                            Container(color: AppColors.imagePlaceholder),
                        errorWidget: (_, _, _) => Container(
                          color: AppColors.imagePlaceholder,
                          child: Icon(categoryIcon(cat),
                              color: AppColors.primary, size: 34),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.15),
                              Colors.transparent,
                              bg,
                            ],
                            stops: const [0, 0.4, 1],
                          ),
                        ),
                      ),
                      // Status badge
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: eventCancelled
                                ? AppColors.error
                                : isValid
                                    ? AppColors.success
                                    : Colors.black.withOpacity(0.55),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            eventCancelled
                                ? l.statusCancelled
                                : isValid
                                    ? '✓ Valid'
                                    : status.toUpperCase(),
                            style: AppText.micro.copyWith(fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                        ),
                      ),
                      // Category + title
                      Positioned(
                        bottom: 10,
                        left: 14,
                        right: 14,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(categoryIcon(cat),
                                    size: 12, color: accent),
                                const SizedBox(width: 5),
                                Text(
                                  cat,
                                  style: AppText.micro.copyWith(fontWeight: FontWeight.w700, color: accent),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              (event['title'] ?? '') as String,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.h2.copyWith(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Perforation (encoches + pointillés) ─────────────
                _perforation(bg),

                // ── Bas du billet ───────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  color: bg,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.calendar_today_outlined,
                                    color: accent, size: 12),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    formatDate(event['start_date'] as String?),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppText.caption.copyWith(fontSize: 11.5),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(
                              (ticketType['name'] ?? 'Ticket') as String,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.h5.copyWith(fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          gradient: isValid
                              ? const LinearGradient(
                                  colors: [
                                    AppColors.primary,
                                    AppColors.pink
                                  ],
                                )
                              : null,
                          color: isValid ? null : Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.qr_code,
                                color: Colors.white, size: 15),
                            const SizedBox(width: 5),
                            Text(
                              l.viewQR,
                              style: AppText.caption.copyWith(fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }

  // Bande de perforation : encoches sur les côtés + pointillés (look billet).
  Widget _perforation(Color bg) {
    const notchColor = AppColors.background;
    return Container(
      color: bg,
      height: 22,
      child: Row(
        children: [
          Container(
            width: 14,
            height: 22,
            decoration: const BoxDecoration(
              color: notchColor,
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(14),
                bottomRight: Radius.circular(14),
              ),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) => Flex(
                direction: Axis.horizontal,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  (c.maxWidth / 11).floor(),
                  (_) => Container(
                    width: 5,
                    height: 1.5,
                    color: Colors.white.withOpacity(0.14),
                  ),
                ),
              ),
            ),
          ),
          Container(
            width: 14,
            height: 22,
            decoration: const BoxDecoration(
              color: notchColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(14),
                bottomLeft: Radius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
