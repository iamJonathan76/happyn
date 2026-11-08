import 'package:flutter/material.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:happyn/core/categories/category_visuals.dart';
import 'package:happyn/core/providers/favorites_provider.dart';
import 'package:happyn/features/events/event_detail_screen.dart';
import 'package:happyn/l10n/app_localizations.dart';
import 'package:happyn/core/utils/dates.dart';
import 'package:happyn/core/utils/places.dart';
import 'package:happyn/core/payments/pricing.dart';

/// Carte d'event en ligne (vignette + badge date + titre + catégorie + ville + cœur/prix).
/// Partagée par le Home (« Popular near you ») et Discover. Le cœur est
/// persisté via `favoritesProvider`.
class EventListCard extends ConsumerWidget {
  final Map<String, dynamic> event;
  const EventListCard({super.key, required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final ev = event;
    final eventId = ev['id'] as String;
    final cat = (ev['category'] ?? '') as String;
    final date = AppDates.dowDayMonth(context, ev['start_date'] as String?);
    final price = ev['price'] as num?;
    final isFree = price == null || price == 0;
    final priceText = isFree
        ? l.free
        : Pricing.ticketPrice(price, Localizations.localeOf(context).languageCode);
    // La ville seulement : le nom du lieu et l'adresse sont sur la fiche, qui
    // sait quand les cacher (événement privé, adresse saisie comme lieu).
    final city = displayCity(ev['city'] as String?);

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
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Photo généreuse à gauche, à son ratio (carré), coins arrondis.
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: CachedNetworkImage(
                    imageUrl: (ev['image_url'] ?? '') as String,
                    fit: BoxFit.cover,
                    placeholder: (_, _) =>
                        Container(color: AppColors.imagePlaceholder),
                    errorWidget: (_, _, _) => Container(
                      color: AppColors.imagePlaceholder,
                      child: Icon(categoryIcon(cat),
                          color: AppColors.primary, size: 24),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Titre, puis date et lieu.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      (ev['title'] ?? '') as String,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.h5.copyWith(color: Colors.white, height: 1.2),
                    ),
                    if (date.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _metaRow(Icons.calendar_today_outlined, date),
                    ],
                    if (city.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      _metaRow(Icons.location_on_outlined, city),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Favori (haut) et prix (bas), alignés à droite.
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () async {
                      await toggleFavorite(eventId, isFav);
                      ref.invalidate(favoritesProvider);
                    },
                    child: Icon(
                      isFav ? Icons.bookmark : Icons.bookmark_border,
                      color: isFav ? AppColors.lavender : AppColors.textLow,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    priceText,
                    style: AppText.h5.copyWith(
                      color: isFree ? AppColors.textMed : Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Une ligne méta : petite icône + texte réduit, tronqué.
  Widget _metaRow(IconData icon, String text) => Row(
        children: [
          Icon(icon, size: 12, color: AppColors.textLow),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption.copyWith(color: AppColors.textMed),
            ),
          ),
        ],
      );
}
