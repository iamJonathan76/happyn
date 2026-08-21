import 'package:flutter/material.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:happyn/features/events/event_detail_screen.dart';
import 'package:happyn/core/categories/category_visuals.dart';
import 'package:happyn/core/providers/favorites_provider.dart';
import 'package:happyn/l10n/app_localizations.dart';
import 'package:happyn/core/utils/dates.dart';

class HeroEventCard extends ConsumerWidget {
  final Map<String, dynamic> event;
  const HeroEventCard({required this.event});

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
    final city = (ev['city'] ?? ev['location'] ?? '') as String;
    final favIds = ref.watch(favoritesProvider).asData?.value ?? <String>{};
    final isFav = favIds.contains(eventId);

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => EventDetailScreen(event: ev)),
      ),
      child: Container(
        width: 290,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.45),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Image + badge date + cœur ─────────────────────────
              Stack(
                children: [
                  SizedBox(
                    height: 150,
                    width: double.infinity,
                    child: CachedNetworkImage(
                      imageUrl: (ev['image_url'] ?? '') as String,
                      fit: BoxFit.cover,
                      placeholder: (_, _) =>
                          Container(color: AppColors.imagePlaceholder),
                      errorWidget: (_, _, _) => Container(
                        color: AppColors.imagePlaceholder,
                        child: Center(
                          child: Icon(categoryIcon(cat),
                              color: AppColors.primary, size: 38),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      width: 44,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(mon,
                              style: AppText.microBold.copyWith(fontWeight: FontWeight.w800, color: AppColors.pink, letterSpacing: 0.5)),
                          Text(day,
                              style: AppText.h2.copyWith(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.background, height: 1)),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: GestureDetector(
                      onTap: () async {
                        await toggleFavorite(eventId, isFav);
                        ref.invalidate(favoritesProvider);
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isFav ? Icons.favorite : Icons.favorite_border,
                          color: isFav ? AppColors.pink : Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // ── Infos ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (ev['title'] ?? '') as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.h3.copyWith(fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(categoryIcon(cat), size: 12, color: color),
                        const SizedBox(width: 5),
                        Text(
                          cat,
                          style: AppText.small.copyWith(fontWeight: FontWeight.w600, color: color),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(Icons.location_on,
                                  size: 12,
                                  color: AppColors.textLow),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  city,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.small.copyWith(color: AppColors.textMed),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          priceText,
                          style: AppText.h4.copyWith(fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
