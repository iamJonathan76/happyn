import 'package:flutter/material.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:happyn/core/categories/category_visuals.dart';
import 'package:happyn/core/providers/favorites_provider.dart';
import 'package:happyn/features/events/event_detail_screen.dart';
import 'package:happyn/l10n/app_localizations.dart';
import 'package:happyn/core/utils/dates.dart';

/// Carte d'event en ligne (vignette + badge date + titre + lieu + cœur/prix).
/// Partagée par le Home (« Popular near you ») et Discover. Le cœur est
/// persisté via `favoritesProvider`.
class EventListCard extends ConsumerWidget {
  final Map<String, dynamic> event;
  const EventListCard({super.key, required this.event});

  (String, String) _dateParts(BuildContext context, String? s) {
    final dt = s == null ? null : DateTime.tryParse(s);
    if (dt == null) return ('', '');
    return (AppDates.monthBadge(context, s), dt.day.toString());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ev = event;
    final eventId = ev['id'] as String;
    final cat = (ev['category'] ?? '') as String;
    final color = categoryColor(cat);
    final (mon, day) = _dateParts(context, ev['start_date'] as String?);
    final priceText = (ev['price'] == 0 || ev['price'] == null)
        ? AppLocalizations.of(context).free
        : '\$${ev['price']}';
    final city = (ev['city'] ?? '') as String;
    final venue = (ev['location'] ?? '') as String;

    final favIds = ref.watch(favoritesProvider).asData?.value ?? <String>{};
    final isFav = favIds.contains(eventId);

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => EventDetailScreen(event: ev)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Row(
          children: [
            // Vignette + badge date
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                children: [
                  SizedBox(
                    width: 58,
                    height: 58,
                    child: CachedNetworkImage(
                      imageUrl: (ev['image_url'] ?? '') as String,
                      fit: BoxFit.cover,
                      placeholder: (_, _) =>
                          Container(color: AppColors.imagePlaceholder),
                      errorWidget: (_, _, _) => Container(
                        color: AppColors.imagePlaceholder,
                        child: Icon(categoryIcon(cat),
                            color: AppColors.primary, size: 22),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      color: Colors.black.withOpacity(0.55),
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        '$mon $day',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Infos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    (ev['title'] ?? '') as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(categoryIcon(cat), size: 11, color: color),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          venue.isNotEmpty ? venue : cat,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.55),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (city.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      city,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.white.withOpacity(0.38),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Cœur (persisté) + prix
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    await toggleFavorite(eventId, isFav);
                    ref.invalidate(favoritesProvider);
                  },
                  child: Icon(
                    isFav ? Icons.favorite : Icons.favorite_border,
                    color: isFav
                        ? AppColors.pink
                        : Colors.white.withOpacity(0.35),
                    size: 18,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  priceText,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: AppColors.lavenderLight,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
