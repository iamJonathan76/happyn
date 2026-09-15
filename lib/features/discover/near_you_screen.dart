import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:happyn/core/providers/nearby_provider.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/core/widgets/app_form.dart';
import 'package:happyn/core/widgets/event_list_card.dart';
import 'package:happyn/l10n/app_localizations.dart';

/// « Autour de toi » — trois états, jamais une erreur.
///
/// L'écran existe **même sans permission de localisation**. Un refus n'est pas
/// une panne : c'est une réponse, et elle mérite une alternative plutôt qu'un
/// message d'échec.
///
/// Règle non négociable : **aucune distance affichée si la position réelle est
/// inconnue.** Annoncer « 2,3 km » à partir d'un centre-ville choisi à la main
/// serait un chiffre inventé, et ça se remarque dès qu'on regarde par la
/// fenêtre.
class NearYouScreen extends ConsumerStatefulWidget {
  const NearYouScreen({super.key});

  @override
  ConsumerState<NearYouScreen> createState() => _NearYouScreenState();
}

class _NearYouScreenState extends ConsumerState<NearYouScreen> {
  bool _asking = false;

  Future<void> _askLocation(AppLocalizations l) async {
    setState(() => _asking = true);
    final ok = await ref.read(nearbyProvider.notifier).useDeviceLocation();
    if (!mounted) return;
    setState(() => _asking = false);
    if (!ok) {
      // Pas « permission refusée » : on propose la suite plutôt que de
      // constater l'échec.
      showAppSnack(context, l.locationRefused);
      _openCityPicker(l);
    }
  }

  Future<void> _openCityPicker(AppLocalizations l) async {
    final cities = await ref.read(citiesProvider.future);
    if (!mounted) return;
    await showModalBottomSheet<void>(
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
            Text(l.chooseYourCity, style: AppText.h3),
            const SizedBox(height: 10),
            for (final city in cities)
              ListTile(
                leading: Icon(Icons.location_city_outlined,
                    size: 20, color: AppColors.textMed),
                title: Text(city.label,
                    style: AppText.bodySm.copyWith(color: Colors.white)),
                onTap: () {
                  ref.read(nearbyProvider.notifier).useCity(city);
                  Navigator.of(sheetCtx).pop();
                },
              ),
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final near = ref.watch(nearbyProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(l.nearYouTitle, style: AppText.h3),
        actions: [
          if (near.mode != LocationMode.unset)
            TextButton(
              onPressed: () => _openCityPicker(l),
              child: Text(l.changeLocation,
                  style: AppText.smallBold
                      .copyWith(color: AppColors.lavenderLight)),
            ),
        ],
      ),
      body: near.mode == LocationMode.unset
          ? _intro(l)
          : _results(l, near),
    );
  }

  /// État 1 — rien n'a été choisi.
  ///
  /// On ne montre AUCUN événement ici : prétendre que quelque chose est
  /// « près de toi » sans connaître ta position serait faux.
  Widget _intro(AppLocalizations l) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.explore_outlined, size: 56, color: AppColors.textFaint),
              const SizedBox(height: 18),
              Text(l.nearYouIntro,
                  textAlign: TextAlign.center,
                  style: AppText.h3.copyWith(color: Colors.white)),
              const SizedBox(height: 10),
              Text(l.nearYouIntroBody,
                  textAlign: TextAlign.center,
                  style: AppText.body.copyWith(height: 1.5)),
              const SizedBox(height: 26),
              GestureDetector(
                onTap: _asking ? null : () => _askLocation(l),
                child: Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.pink],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: _asking
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : Text(l.useMyLocation,
                            style: AppText.h4.copyWith(color: Colors.white)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => _openCityPicker(l),
                child: Text(l.chooseACity,
                    style: AppText.smallBold
                        .copyWith(color: AppColors.lavenderLight)),
              ),
            ],
          ),
        ),
      );

  /// États 2 et 3 — on connaît un point de référence.
  Widget _results(AppLocalizations l, NearbyState near) {
    final async = ref.watch(nearbyEventsProvider);

    return async.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary)),
      // On distingue l'echec du vide : les trois erreurs avalees de ce projet
      // se sont toutes deguisees en liste vide.
      error: (e, _) => _message(Icons.error_outline, '$e', null, l),
      data: (list) {
        if (list.isEmpty) {
          return _message(Icons.travel_explore_outlined, l.nothingNearby,
              l.nothingNearbyBody, l);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                near.mode == LocationMode.city
                    ? l.eventsIn(near.cityName ?? '')
                    : l.eventsAround(near.cityName ?? l.nearYouTitle),
                style: AppText.captionBold.copyWith(color: AppColors.textLow),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 90),
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final item = list[i];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      EventListCard(event: item.event),
                      // La distance n'apparaît QUE si elle est réelle.
                      if (near.canShowDistance)
                        Padding(
                          padding:
                              const EdgeInsets.only(left: 4, bottom: 10, top: 2),
                          child: Row(
                            children: [
                              Icon(Icons.near_me_outlined,
                                  size: 13, color: AppColors.textLow),
                              const SizedBox(width: 5),
                              Text(
                                l.kmAway(item.distanceKm.toStringAsFixed(1)),
                                style: AppText.micro,
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _message(
      IconData icon, String title, String? body, AppLocalizations l) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: AppColors.textFaint),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: AppText.h4.copyWith(color: Colors.white)),
            if (body != null) ...[
              const SizedBox(height: 8),
              Text(body,
                  textAlign: TextAlign.center,
                  style: AppText.body.copyWith(height: 1.5)),
            ],
            const SizedBox(height: 20),
            // On ne fabrique pas de faux « événements proches » pour remplir
            // l'écran : on propose d'aller voir ailleurs, ce qui est honnête.
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l.exploreAllEvents,
                  style: AppText.smallBold
                      .copyWith(color: AppColors.lavenderLight)),
            ),
          ],
        ),
      ),
    );
  }
}
