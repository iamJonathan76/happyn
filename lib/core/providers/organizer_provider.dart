import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Ventes d'un palier de billets.
class TierStats {
  final String name;
  final double price;
  final int total;
  final int sold;
  final int used;
  final int cancelled;
  final double grossRevenue;

  const TierStats({
    required this.name,
    required this.price,
    required this.total,
    required this.sold,
    required this.used,
    required this.cancelled,
    required this.grossRevenue,
  });

  /// `total == 0` signifie « sans plafond » : il reste toujours des places, et
  /// afficher un pourcentage n'aurait aucun sens.
  bool get isCapped => total > 0;
  int get remaining => isCapped ? (total - sold).clamp(0, total) : 0;
  double get fillRatio => isCapped && total > 0 ? sold / total : 0;
}

/// Une personne attendue à la porte.
class Attendee {
  final String ticketId;
  final String fullName;
  final String? avatarUrl;
  final String typeName;
  final String status;
  final DateTime? purchasedAt;

  const Attendee({
    required this.ticketId,
    required this.fullName,
    this.avatarUrl,
    required this.typeName,
    required this.status,
    this.purchasedAt,
  });

  bool get checkedIn => status == 'used';
}

/// Ventes par palier, pour l'organisateur uniquement.
///
/// `autoDispose` : un organisateur ouvre cet écran justement pour voir où il en
/// est. Un chiffre mis en cache serait pire que pas de chiffre — il déciderait
/// sur une information périmée.
final organizerStatsProvider =
    FutureProvider.autoDispose.family<List<TierStats>, String>((ref, eventId) async {
  final data = await Supabase.instance.client
      .rpc('organizer_event_stats', params: {'p_event': eventId});
  return List<Map<String, dynamic>>.from(data as List)
      .map((r) => TierStats(
            name: (r['name'] as String?) ?? '',
            price: (r['price'] as num?)?.toDouble() ?? 0,
            total: (r['quantity_total'] as num?)?.toInt() ?? 0,
            sold: (r['quantity_sold'] as num?)?.toInt() ?? 0,
            used: (r['used_count'] as num?)?.toInt() ?? 0,
            cancelled: (r['cancelled_count'] as num?)?.toInt() ?? 0,
            grossRevenue: (r['gross_revenue'] as num?)?.toDouble() ?? 0,
          ))
      .toList();
});

/// Qui vient, et qui est déjà entré.
final organizerAttendeesProvider =
    FutureProvider.autoDispose.family<List<Attendee>, String>((ref, eventId) async {
  final data = await Supabase.instance.client
      .rpc('organizer_attendees', params: {'p_event': eventId});
  return List<Map<String, dynamic>>.from(data as List)
      .map((r) => Attendee(
            ticketId: r['ticket_id'] as String,
            fullName: (r['full_name'] as String?) ?? '',
            avatarUrl: r['avatar_url'] as String?,
            typeName: (r['type_name'] as String?) ?? '',
            status: (r['status'] as String?) ?? 'valid',
            purchasedAt: r['purchased_at'] == null
                ? null
                : DateTime.tryParse(r['purchased_at'] as String),
          ))
      .toList();
});

/// Totaux, calculés à partir des paliers plutôt que demandés séparément :
/// deux requêtes pourraient se contredire d'une seconde à l'autre.
class EventTotals {
  final int sold;
  final int capacity;
  final int checkedIn;
  final double grossRevenue;

  const EventTotals({
    required this.sold,
    required this.capacity,
    required this.checkedIn,
    required this.grossRevenue,
  });

  bool get isCapped => capacity > 0;
  double get checkInRatio => sold > 0 ? checkedIn / sold : 0;

  factory EventTotals.from(List<TierStats> tiers) => EventTotals(
        sold: tiers.fold(0, (a, t) => a + t.sold),
        capacity: tiers.fold(0, (a, t) => a + t.total),
        checkedIn: tiers.fold(0, (a, t) => a + t.used),
        grossRevenue: tiers.fold(0.0, (a, t) => a + t.grossRevenue),
      );
}
