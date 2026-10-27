import 'package:flutter_riverpod/flutter_riverpod.dart';

/// L'état des vidéos du fil, partagé entre toutes les cartes.
///
/// Deux choses à coordonner entre cartes, donc deux providers :
///  - le son, qui vaut pour tout le fil (préférence de session) ;
///  - « qui joue », car une seule vidéo tourne à la fois — celle qu'on regarde.

/// Muet par défaut. Dès que la personne active le son sur une vidéo, les
/// suivantes se lancent aussi avec le son en continuant de défiler : on ne
/// retape pas le haut-parleur à chaque fois.
final feedVideoMutedProvider = StateProvider<bool>((ref) => true);

/// Chaque carte vidéo déclare quelle fraction d'elle-même est visible. La carte
/// la plus visible (au centre de l'écran) sera la seule à jouer.
class FeedVideoVisibility extends StateNotifier<Map<String, double>> {
  FeedVideoVisibility() : super(const {});

  void report(String id, double fraction) {
    if (fraction <= 0.05) {
      remove(id);
      return;
    }
    if (state[id] == fraction) return;
    state = {...state, id: fraction};
  }

  void remove(String id) {
    if (!state.containsKey(id)) return;
    final next = Map<String, double>.from(state)..remove(id);
    state = next;
  }
}

final feedVideoVisibilityProvider =
    StateNotifierProvider<FeedVideoVisibility, Map<String, double>>(
        (ref) => FeedVideoVisibility());

/// L'identifiant de la vidéo à jouer : la plus visible, à condition qu'au moins
/// 60 % d'elle soit à l'écran. En dessous, aucune ne joue (on est entre deux).
final feedActiveVideoProvider = Provider<String?>((ref) {
  final fractions = ref.watch(feedVideoVisibilityProvider);
  String? best;
  var bestFraction = 0.6;
  fractions.forEach((id, fraction) {
    if (fraction >= bestFraction) {
      bestFraction = fraction;
      best = id;
    }
  });
  return best;
});
