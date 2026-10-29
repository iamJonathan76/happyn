import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// La fenêtre de temps du tableau de bord. On filtre les événements par date de
/// début : les événements à venir restent visibles (un organisateur veut aussi
/// voir ce qui arrive), seul le passé est borné.
enum DashboardRange { week, month, all }

/// Une ligne du tableau de bord organisateur : un de ses événements, avec son
/// revenu net (en CENTS), ses billets vendus/scannés, et l'état de son
/// versement. Vient de la RPC `organizer_dashboard`, qui ne renvoie que les
/// événements de l'appelant.
class OrganizerEventStat {
  final String eventId;
  final String title;
  final String? imageUrl;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? paidAt;
  final bool isPaid;
  final int netCents;
  final int ticketsSold;
  final int scanned;

  /// paid | none | manual | no_scans | first_event | scheduled | counting | ready
  final String payoutStatus;

  /// Jours avant le versement (pour le compte à rebours de l'état `counting`).
  final int? payoutDaysLeft;

  const OrganizerEventStat({
    required this.eventId,
    required this.title,
    required this.imageUrl,
    required this.startDate,
    required this.endDate,
    required this.paidAt,
    required this.isPaid,
    required this.netCents,
    required this.ticketsSold,
    required this.scanned,
    required this.payoutStatus,
    required this.payoutDaysLeft,
  });

  factory OrganizerEventStat.fromMap(Map<String, dynamic> m) {
    DateTime? date(String k) {
      final v = m[k];
      return v is String ? DateTime.tryParse(v) : null;
    }

    int intOf(String k) => (m[k] as num?)?.toInt() ?? 0;

    return OrganizerEventStat(
      eventId: m['event_id'] as String,
      title: (m['title'] as String?) ?? '',
      imageUrl: m['image_url'] as String?,
      startDate: date('start_date'),
      endDate: date('end_date'),
      paidAt: date('paid_at'),
      isPaid: m['is_paid'] == true,
      netCents: intOf('net_cents'),
      ticketsSold: intOf('tickets_sold'),
      scanned: intOf('scanned'),
      payoutStatus: (m['payout_status'] as String?) ?? 'none',
      payoutDaysLeft: (m['payout_days_left'] as num?)?.toInt(),
    );
  }

  double get attendanceRate =>
      ticketsSold == 0 ? 0 : scanned / ticketsSold;

  /// A un versement à suivre (payant, pas gratuit).
  bool get hasPayout => isPaid && payoutStatus != 'none';
}

final organizerDashboardProvider = FutureProvider.autoDispose
    .family<List<OrganizerEventStat>, DashboardRange>((ref, range) async {
  final now = DateTime.now();
  DateTime? from;
  if (range == DashboardRange.week) from = now.subtract(const Duration(days: 7));
  if (range == DashboardRange.month) from = now.subtract(const Duration(days: 30));

  final data = await Supabase.instance.client.rpc('organizer_dashboard', params: {
    'p_from': from?.toUtc().toIso8601String(),
    'p_to': null,
  });

  return List<Map<String, dynamic>>.from(data as List)
      .map(OrganizerEventStat.fromMap)
      .toList();
});
