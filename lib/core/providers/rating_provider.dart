import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Ce que l'écran de notation doit savoir, tel que le serveur le décide :
/// peut-on noter (billet scanné, fenêtre ouverte, pas l'organisateur),
/// jusqu'à quand, quels tags proposer, et la note déjà donnée.
class MyEventRating {
  final bool canRate;
  final DateTime? closesAt;
  final List<String> tagsOffered;
  final int? stars;
  final List<String> tags;
  final String? comment;

  const MyEventRating({
    required this.canRate,
    required this.closesAt,
    required this.tagsOffered,
    this.stars,
    this.tags = const [],
    this.comment,
  });

  bool get alreadyRated => stars != null;

  static const none = MyEventRating(canRate: false, closesAt: null, tagsOffered: []);
}

/// `autoDispose` : la fenêtre se ferme avec le temps, et une note vient
/// d'être envoyée — un état figé montrerait un bouton qui ne marche plus.
final myEventRatingProvider = FutureProvider.autoDispose
    .family<MyEventRating, String>((ref, eventId) async {
  final rows = await Supabase.instance.client
      .rpc('my_event_rating', params: {'p_event': eventId}) as List;
  if (rows.isEmpty) return MyEventRating.none;
  final r = Map<String, dynamic>.from(rows.first as Map);
  List<String> list(Object? v) =>
      v == null ? const [] : List<String>.from(v as List);
  return MyEventRating(
    canRate: r['can_rate'] == true,
    closesAt: DateTime.tryParse((r['closes_at'] ?? '') as String),
    tagsOffered: list(r['tags_offered']),
    stars: (r['stars'] as num?)?.toInt(),
    tags: list(r['tags']),
    comment: r['comment'] as String?,
  );
});

Future<void> rateEvent({
  required String eventId,
  required int stars,
  required List<String> tags,
  String? comment,
}) async {
  await Supabase.instance.client.rpc('rate_event', params: {
    'p_event': eventId,
    'p_stars': stars,
    'p_tags': tags,
    'p_comment': comment,
  });
}

/// La moyenne publique d'un organisateur. `null` sous 5 notes : le serveur ne
/// la donne pas, pour qu'une seule mauvaise soirée ne juge pas quelqu'un.
final organizerRatingProvider = FutureProvider.autoDispose
    .family<({double average, int count})?, String>((ref, organizerId) async {
  final rows = await Supabase.instance.client.rpc('organizer_public_rating',
      params: {'p_organizer': organizerId}) as List;
  if (rows.isEmpty) return null;
  final r = Map<String, dynamic>.from(rows.first as Map);
  final avg = (r['average'] as num?)?.toDouble();
  final n = (r['ratings'] as num?)?.toInt() ?? 0;
  return avg == null ? null : (average: avg, count: n);
});

/// Le détail des retours d'un événement, pour son organisateur seulement —
/// sans l'identité de ceux qui ont noté.
class EventFeedback {
  final int count;
  final double? average;
  final Map<String, int> tags;
  final List<({int stars, String comment, DateTime? at})> comments;
  const EventFeedback(this.count, this.average, this.tags, this.comments);
}

final eventFeedbackProvider = FutureProvider.autoDispose
    .family<EventFeedback, String>((ref, eventId) async {
  final raw = await Supabase.instance.client
      .rpc('event_rating_summary', params: {'p_event': eventId});
  final m = Map<String, dynamic>.from((raw ?? const {}) as Map);
  final tags = <String, int>{
    for (final e in Map<String, dynamic>.from((m['tags'] ?? const {}) as Map).entries)
      e.key: (e.value as num).toInt(),
  };
  final comments = [
    for (final c in (m['comments'] ?? const []) as List)
      (
        stars: ((c as Map)['stars'] as num).toInt(),
        comment: (c['comment'] ?? '') as String,
        at: DateTime.tryParse((c['at'] ?? '') as String),
      ),
  ];
  return EventFeedback(
    ((m['count'] ?? 0) as num).toInt(),
    (m['average'] as num?)?.toDouble(),
    tags,
    comments,
  );
});
