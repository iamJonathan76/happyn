import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:happyn/core/providers/rating_provider.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/core/utils/dates.dart';
import 'package:happyn/features/events/rate_event_screen.dart';
import 'package:happyn/l10n/app_localizations.dart';

/// « ★ 4,6 · 38 notes » sous le nom d'un organisateur. Rien sous 5 notes.
class OrganizerRatingChip extends ConsumerWidget {
  final String organizerId;
  const OrganizerRatingChip({super.key, required this.organizerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(organizerRatingProvider(organizerId)).asData?.value;
    if (r == null) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final avg = r.average.toStringAsFixed(1).replaceAll(
        '.', Localizations.localeOf(context).languageCode == 'fr' ? ',' : '.');
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_rounded, size: 16, color: AppColors.amber),
            const SizedBox(width: 4),
            Text(avg,
                style: AppText.small.copyWith(
                    color: Colors.white, fontWeight: FontWeight.w700)),
            Text(' · ${l.ratingsCount(r.count)}', style: AppText.small),
          ],
        ),
      ),
    );
  }
}

/// Sur la fiche de SON événement terminé : l'entrée vers les retours.
class EventFeedbackEntry extends ConsumerWidget {
  final Map<String, dynamic> event;
  const EventFeedbackEntry({super.key, required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final f = ref.watch(eventFeedbackProvider(event['id'] as String)).asData?.value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => EventFeedbackScreen(event: event))),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.reviews_outlined, color: AppColors.lavenderLight),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  f == null || f.count == 0
                      ? l.feedbackEntryEmpty
                      : l.feedbackEntry(f.count),
                  style: AppText.bodySm.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Les retours des participants, pour l'organisateur. Anonymes : on voit ce
/// qui a été dit, jamais qui l'a dit.
class EventFeedbackScreen extends ConsumerWidget {
  final Map<String, dynamic> event;
  const EventFeedbackScreen({super.key, required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final async = ref.watch(eventFeedbackProvider(event['id'] as String));

    // Demi-étoiles : arrondi à l'entier, 4,5 s'affichait en cinq étoiles
    // pleines, ce qui ne correspond pas au chiffre écrit à côté.
    Widget stars(num n, {double size = 16}) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 1; i <= 5; i++)
              Icon(
                  i <= n
                      ? Icons.star_rounded
                      : i - 0.5 <= n
                          ? Icons.star_half_rounded
                          : Icons.star_outline_rounded,
                  size: size,
                  color: i - 0.5 <= n ? AppColors.amber : AppColors.textMuted),
          ],
        );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(l.feedbackTitle, style: AppText.h3),
      ),
      body: async.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (_, _) => Center(child: Text(l.couldNotLoadEvents, style: AppText.body)),
        data: (f) {
          if (f.count == 0) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(l.feedbackNone,
                    textAlign: TextAlign.center, style: AppText.body),
              ),
            );
          }
          final avg = (f.average ?? 0)
              .toStringAsFixed(1)
              .replaceAll('.', lang == 'fr' ? ',' : '.');
          final tags = f.tags.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text((event['title'] ?? '') as String,
                  style: AppText.h3.copyWith(color: Colors.white)),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(avg, style: AppText.display.copyWith(fontSize: 40, color: Colors.white)),
                  const SizedBox(width: 10),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        stars(f.average ?? 0, size: 18),
                        Text(l.ratingsCount(f.count), style: AppText.small),
                      ],
                    ),
                  ),
                ],
              ),
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 22),
                Text(l.feedbackMostCited, style: AppText.small),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in tags)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppColors.cardDark,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text('${ratingTagLabel(l, t.key)} · ${t.value}',
                            style: AppText.small.copyWith(color: AppColors.textMed)),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 26),
              Text(l.feedbackComments, style: AppText.small),
              const SizedBox(height: 8),
              if (f.comments.isEmpty)
                Text(l.feedbackNoComments, style: AppText.bodySm)
              else
                for (final c in f.comments)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.cardDark,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            stars(c.stars),
                            const SizedBox(width: 8),
                            Text(
                                c.at == null
                                    ? ''
                                    : AppDates.dayMonthYear(
                                        context, c.at!.toIso8601String()),
                                style: AppText.micro),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(c.comment,
                            style: AppText.bodySm.copyWith(color: Colors.white, height: 1.45)),
                      ],
                    ),
                  ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.lock_outline, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Expanded(child: Text(l.feedbackAnonymous, style: AppText.micro)),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
