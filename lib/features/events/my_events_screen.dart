import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:happyn/core/events/event_utils.dart';
import 'package:happyn/core/providers/events_provider.dart';
import 'package:happyn/core/utils/dates.dart';
import 'package:happyn/features/events/organizer_event_screen.dart';
import 'package:happyn/l10n/app_localizations.dart';

/// Mes evenements, cote organisateur.
///
/// Acheter un billet avait sa propre porte d'entree (« Mes billets ») ; en
/// organiser un n'en avait aucune. Il fallait passer par son profil, ouvrir la
/// fiche publique, puis trouver « Gerer » dans un menu — quatre gestes dont
/// aucun n'annonce qu'il mene a des chiffres de vente. Or c'est l'organisateur
/// qui revient le plus souvent : il regarde ses ventes tous les jours la
/// semaine precedant son evenement.
///
/// Chaque ligne ouvre directement le tableau de bord, pas la fiche publique.
class MyEventsScreen extends ConsumerWidget {
  const MyEventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final events = ref.watch(myOrganizedEventsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(l.myEventsTitle, style: AppText.h3),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.card,
        onRefresh: () async {
          ref.invalidate(eventsProvider);
          await ref.read(eventsProvider.future);
        },
        child: events.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (_, __) => _empty(l.couldNotLoadEvents, ''),
          data: (list) => list.isEmpty
              ? _empty(l.myEventsEmpty, l.myEventsEmptyBody)
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 90),
                  itemCount: list.length,
                  itemBuilder: (context, i) => _EventRow(event: list[i]),
                ),
        ),
      ),
    );
  }

  /// Toujours defilable, sinon le geste de rafraichissement ne part pas sur un
  /// ecran vide — precisement celui ou on a envie de reessayer.
  Widget _empty(String title, String body) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 100),
        children: [
          Icon(Icons.event_outlined, size: 48, color: AppColors.textFaint),
          const SizedBox(height: 14),
          Text(title,
              textAlign: TextAlign.center,
              style: AppText.bodySm.copyWith(color: Colors.white)),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(body, textAlign: TextAlign.center, style: AppText.small),
          ],
        ],
      );
}

class _EventRow extends StatelessWidget {
  final Map<String, dynamic> event;
  const _EventRow({required this.event});

  /// Un seul etat par evenement, dans l'ordre ou il compte pour l'organisateur.
  /// « Termine » passe avant « publie » : une fois la date passee, savoir que
  /// c'etait publie n'apprend plus rien.
  (String, Color) _state(AppLocalizations l) {
    if (isEventCancelled(event)) {
      return (l.stateCancelled, AppColors.pink);
    }
    if (isEventPast(event)) {
      return (l.stateFinished, AppColors.textFaint);
    }
    if (eventStatus(event) == 'draft') {
      return (l.stateDraft, AppColors.textLow);
    }
    return (l.statePublished, AppColors.success);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final (stateLabel, stateColor) = _state(l);
    final cover = event['cover_url'] as String?;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => OrganizerEventScreen(event: event))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 58,
                height: 58,
                child: cover == null || cover.isEmpty
                    ? Container(
                        color: AppColors.card,
                        child: Icon(Icons.event_outlined,
                            color: AppColors.textFaint, size: 22),
                      )
                    : CachedNetworkImage(
                        imageUrl: cover,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            Container(color: AppColors.card),
                        errorWidget: (_, __, ___) =>
                            Container(color: AppColors.card),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (event['title'] ?? '') as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodySm.copyWith(
                        color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    AppDates.dayMonthYear(
                        context, event['start_date'] as String?),
                    style: AppText.small,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: stateColor.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(stateLabel,
                        style: AppText.microBold.copyWith(color: stateColor)),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: AppColors.textFaint, size: 18),
          ],
        ),
      ),
    );
  }
}
