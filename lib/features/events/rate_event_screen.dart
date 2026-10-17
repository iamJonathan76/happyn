import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:happyn/core/config/observability.dart';
import 'package:happyn/core/providers/rating_provider.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/core/utils/dates.dart';
import 'package:happyn/core/utils/places.dart';
import 'package:happyn/core/widgets/app_form.dart';
import 'package:happyn/l10n/app_localizations.dart';

/// Libellé d'un tag de note. Les clés viennent du serveur
/// (`rating_tags_for`), qui seul décide lesquelles proposer : une clé inconnue
/// de cette version de l'app s'affiche telle quelle plutôt que de disparaître.
String ratingTagLabel(AppLocalizations l, String key) => switch (key) {
      'ambiance' => l.rateTagAmbiance,
      'organization' => l.rateTagOrganization,
      'venue' => l.rateTagVenue,
      'value' => l.rateTagValue,
      'music' => l.rateTagMusic,
      'sound_light' => l.rateTagSoundLight,
      'speakers' => l.rateTagSpeakers,
      'content' => l.rateTagContent,
      'networking' => l.rateTagNetworking,
      'level' => l.rateTagLevel,
      'facilities' => l.rateTagFacilities,
      'food' => l.rateTagFood,
      'drinks' => l.rateTagDrinks,
      'artworks' => l.rateTagArtworks,
      'staging' => l.rateTagStaging,
      'message' => l.rateTagMessage,
      'worship' => l.rateTagWorship,
      _ => key,
    };

/// Noter un événement auquel on était — étoiles, tags facultatifs, mot pour
/// l'organisateur. Le serveur revérifie tout (billet scanné, fenêtre, tags) ;
/// l'écran ne fait que proposer ce qu'il a dit possible.
class RateEventScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> event;
  const RateEventScreen({super.key, required this.event});

  @override
  ConsumerState<RateEventScreen> createState() => _RateEventScreenState();
}

class _RateEventScreenState extends ConsumerState<RateEventScreen> {
  final _comment = TextEditingController();
  int _stars = 0;
  final Set<String> _tags = {};
  bool _prefilled = false;
  bool _sending = false;

  String get _eventId => widget.event['id'] as String;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  void _prefill(MyEventRating r) {
    if (_prefilled) return;
    _prefilled = true;
    _stars = r.stars ?? 0;
    _tags.addAll(r.tags);
    _comment.text = r.comment ?? '';
  }

  String _starLabel(AppLocalizations l) => switch (_stars) {
        1 => l.rateStars1,
        2 => l.rateStars2,
        3 => l.rateStars3,
        4 => l.rateStars4,
        5 => l.rateStars5,
        _ => l.rateTapStars,
      };

  Future<void> _send() async {
    final l = AppLocalizations.of(context);
    if (_stars == 0) {
      showAppSnack(context, l.rateTapStars);
      return;
    }
    setState(() => _sending = true);
    try {
      await rateEvent(
        eventId: _eventId,
        stars: _stars,
        tags: _tags.toList(),
        comment: _comment.text.trim().isEmpty ? null : _comment.text.trim(),
      );
      ref.invalidate(myEventRatingProvider(_eventId));
      if (mounted) {
        showAppSnack(context, l.rateThanks);
        Navigator.of(context).pop();
      }
    } catch (e, st) {
      reportCaught(e, st, where: 'rateEvent');
      if (!mounted) return;
      final msg = e.toString();
      showAppSnack(
          context,
          msg.contains('rating_closed') || msg.contains('not_ended')
              ? l.rateClosed
              : l.couldNotSaveRetry);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(myEventRatingProvider(_eventId));
    final ev = widget.event;
    final image = (ev['image_url'] ?? '') as String;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(l.rateTitle, style: AppText.h3),
      ),
      body: async.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (_, _) => Center(child: Text(l.couldNotLoadEvents, style: AppText.body)),
        data: (r) {
          if (!r.canRate) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(l.rateClosed,
                    textAlign: TextAlign.center, style: AppText.body),
              ),
            );
          }
          _prefill(r);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: image.isEmpty
                          ? Container(color: AppColors.imagePlaceholder)
                          : CachedNetworkImage(imageUrl: image, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text((ev['title'] ?? '') as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.h3.copyWith(color: Colors.white)),
                        const SizedBox(height: 2),
                        Text(
                          [
                            AppDates.dowDayMonthYear(context, ev['start_date'] as String?),
                            displayCity(ev['city'] as String?),
                          ].where((s) => s.isNotEmpty).join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.small,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 1; i <= 5; i++)
                    GestureDetector(
                      onTap: () => setState(() => _stars = i),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          i <= _stars ? Icons.star_rounded : Icons.star_outline_rounded,
                          size: 46,
                          color: i <= _stars ? AppColors.amber : AppColors.textMuted,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(_starLabel(l),
                  textAlign: TextAlign.center,
                  style: AppText.bodySm.copyWith(color: AppColors.lavenderLight)),
              const SizedBox(height: 28),
              if (r.tagsOffered.isNotEmpty) ...[
                Text(l.rateTagsTitle, style: AppText.small),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final key in r.tagsOffered)
                      GestureDetector(
                        onTap: () => setState(() =>
                            _tags.contains(key) ? _tags.remove(key) : _tags.add(key)),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(
                            color: _tags.contains(key) ? AppColors.action : AppColors.cardDark,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                                color: _tags.contains(key)
                                    ? AppColors.action
                                    : AppColors.border),
                          ),
                          child: Text(ratingTagLabel(l, key),
                              style: AppText.small.copyWith(
                                  color: _tags.contains(key)
                                      ? Colors.white
                                      : AppColors.textMed)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
              TextField(
                controller: _comment,
                maxLength: 500,
                maxLines: 4,
                minLines: 3,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: appInputDecoration(l.rateCommentHint)
                    .copyWith(counterStyle: AppText.micro),
              ),
              Row(
                children: [
                  const Icon(Icons.lock_outline, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Expanded(child: Text(l.rateCommentPrivacy, style: AppText.micro)),
                ],
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _sending ? null : _send,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.action,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _sending
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text(r.alreadyRated ? l.rateUpdate : l.rateSubmit,
                          style: AppText.h3),
                ),
              ),
              if (r.closesAt != null) ...[
                const SizedBox(height: 10),
                Text(
                  l.rateEditableUntil(AppDates.dowDayMonthYear(
                      context, r.closesAt!.toIso8601String())),
                  textAlign: TextAlign.center,
                  style: AppText.micro,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Sur la fiche d'un événement terminé : l'invitation à noter, ou la note
/// déjà donnée. Rien du tout si la personne ne peut pas noter — billet non
/// scanné, organisateur, fenêtre fermée.
class RateEventPrompt extends ConsumerWidget {
  final Map<String, dynamic> event;
  const RateEventPrompt({super.key, required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final r = ref.watch(myEventRatingProvider(event['id'] as String)).asData?.value;
    if (r == null || !r.canRate) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => RateEventScreen(event: event))),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Icon(r.alreadyRated ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: AppColors.amber, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  r.alreadyRated ? l.rateYourRating(r.stars!) : l.rateCta,
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
