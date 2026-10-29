import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:happyn/core/payments/pricing.dart';
import 'package:happyn/core/providers/organizer_dashboard_provider.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:happyn/core/utils/dates.dart';
import 'package:happyn/l10n/app_localizations.dart';

/// Le tableau de bord de l'organisateur : revenu, billets, présence et surtout
/// l'état de chaque versement (compte à rebours quand rien ne bloque, raison
/// quand c'est retenu). Les chiffres viennent de la RPC organizer_dashboard,
/// qui ne renvoie que les événements de l'appelant.
class OrganizerDashboardScreen extends ConsumerStatefulWidget {
  const OrganizerDashboardScreen({super.key});

  @override
  ConsumerState<OrganizerDashboardScreen> createState() =>
      _OrganizerDashboardScreenState();
}

class _OrganizerDashboardScreenState
    extends ConsumerState<OrganizerDashboardScreen> {
  DashboardRange _range = DashboardRange.month;

  static const _muted = AppColors.textMuted;
  static const _text2 = AppColors.textSecondary;

  String _money(int cents) =>
      Pricing.money(cents / 100, Localizations.localeOf(context).languageCode);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(organizerDashboardProvider(_range));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(l.dashTitle,
            style: const TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      body: async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.lavender)),
        error: (e, _) => Center(
            child: Text(l.errGeneric(e.toString()),
                style: const TextStyle(color: _text2))),
        data: (events) => _content(l, events),
      ),
    );
  }

  Widget _content(AppLocalizations l, List<OrganizerEventStat> events) {
    final sold = events.fold<int>(0, (s, e) => s + e.ticketsSold);
    final scanned = events.fold<int>(0, (s, e) => s + e.scanned);
    final net = events
        .where((e) => e.isPaid)
        .fold<int>(0, (s, e) => s + e.netCents);
    final rate = sold == 0 ? 0.0 : scanned / sold;

    final payouts = events.where((e) => e.hasPayout).toList()
      ..sort((a, b) => _payoutRank(a).compareTo(_payoutRank(b)));
    final ranking = [...events]..sort((a, b) => b.netCents.compareTo(a.netCents));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        Text(l.dashSubtitle,
            style: const TextStyle(color: _muted, fontSize: 12)),
        const SizedBox(height: 14),

        // Filtres de période
        Row(children: [
          _chip(l.dashWeek, DashboardRange.week),
          const SizedBox(width: 6),
          _chip(l.dashMonth, DashboardRange.month),
          const SizedBox(width: 6),
          _chip(l.dashAll, DashboardRange.all),
        ]),
        const SizedBox(height: 14),

        if (events.isEmpty)
          _empty(l)
        else ...[
          // Trois tuiles de synthèse
          Row(children: [
            _tile(_money(net), l.dashNetRevenue, AppColors.lavenderLight),
            const SizedBox(width: 6),
            _tile('$sold', l.dashTicketsSold, Colors.white),
            const SizedBox(width: 6),
            _tile('$scanned', l.dashAttendees, Colors.white),
          ]),
          const SizedBox(height: 10),

          _attendanceCard(l, rate, scanned, sold),
          const SizedBox(height: 10),

          if (payouts.isNotEmpty) ...[
            _payoutCard(l, payouts),
            const SizedBox(height: 10),
          ],

          _label(l.dashByEvent),
          const SizedBox(height: 8),
          ...ranking.map(_eventRow),
        ],
      ],
    );
  }

  // ── Blocs ──────────────────────────────────────────────────────────────

  Widget _chip(String label, DashboardRange range) {
    final on = _range == range;
    return GestureDetector(
      onTap: () => setState(() => _range = range),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: on ? AppColors.primary : AppColors.cardDark,
          borderRadius: BorderRadius.circular(999),
          border: on ? null : Border.all(color: AppColors.border),
        ),
        child: Text(label,
            style: TextStyle(
                color: on ? Colors.white : _text2,
                fontSize: 12,
                fontWeight: on ? FontWeight.w500 : FontWeight.w400)),
      ),
    );
  }

  Widget _tile(String value, String label, Color valueColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
            color: AppColors.cardDark, borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: valueColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(color: _muted, fontSize: 10)),
        ]),
      ),
    );
  }

  Widget _attendanceCard(
      AppLocalizations l, double rate, int scanned, int sold) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppColors.cardDark, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('${(rate * 100).round()} %',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w600)),
              Text(l.dashAttendanceRate,
                  style: const TextStyle(color: _muted, fontSize: 11)),
            ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: rate.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            valueColor: const AlwaysStoppedAnimation(AppColors.primary),
          ),
        ),
        const SizedBox(height: 8),
        Text(l.dashScannedOf(scanned, sold),
            style: const TextStyle(color: _muted, fontSize: 10)),
      ]),
    );
  }

  Widget _payoutCard(AppLocalizations l, List<OrganizerEventStat> payouts) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppColors.card, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label(l.dashNextPayout),
        const SizedBox(height: 10),
        for (var i = 0; i < payouts.length; i++) ...[
          if (i > 0)
            Divider(
                color: Colors.white.withValues(alpha: 0.07), height: 22),
          _payoutRow(l, payouts[i]),
        ],
      ]),
    );
  }

  Widget _payoutRow(AppLocalizations l, OrganizerEventStat e) {
    final held = _isHold(e.payoutStatus);
    final paid = e.payoutStatus == 'paid';
    final (sub, subColor) = _payoutSubtitle(l, e);
    return Row(children: [
      _payoutLeading(e),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(e.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: subColor, fontSize: 11)),
        ]),
      ),
      const SizedBox(width: 8),
      Text(_money(e.netCents),
          style: TextStyle(
              color: (held || paid) ? _text2 : Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600)),
    ]);
  }

  Widget _payoutLeading(OrganizerEventStat e) {
    switch (e.payoutStatus) {
      case 'counting':
        final days = e.payoutDaysLeft ?? 0;
        final progress = ((7 - days) / 7).clamp(0.0, 1.0).toDouble();
        return SizedBox(
          width: 50,
          height: 50,
          child: Stack(alignment: Alignment.center, children: [
            SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 4,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              ),
            ),
            Text(AppLocalizations.of(context).dashDaysShort(days),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ]),
        );
      case 'paid':
        return _badge(Icons.check_circle, AppColors.green);
      case 'ready':
        return _badge(Icons.check_circle_outline, AppColors.green);
      case 'scheduled':
        return _badge(Icons.schedule, AppColors.lavender);
      default: // retenues
        return _badge(Icons.pause_circle_outline, AppColors.amber);
    }
  }

  Widget _badge(IconData icon, Color color) => Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 24),
      );

  (String, Color) _payoutSubtitle(AppLocalizations l, OrganizerEventStat e) {
    switch (e.payoutStatus) {
      case 'counting':
        return (l.dashPayoutInDays(e.payoutDaysLeft ?? 0), _text2);
      case 'ready':
        return (l.dashPayoutReady, AppColors.green);
      case 'scheduled':
        return (l.dashPayoutScheduled, _text2);
      case 'no_scans':
        return (l.dashHoldNoScans, AppColors.amber);
      case 'first_event':
        return (l.dashHoldFirstEvent, AppColors.amber);
      case 'manual':
        return (l.dashHoldManual, AppColors.amber);
      case 'paid':
        return (
          l.dashPaidOn(AppDates.dayMonthYear(
              context, e.paidAt?.toIso8601String())),
          AppColors.green
        );
      default:
        return ('', _text2);
    }
  }

  Widget _eventRow(OrganizerEventStat e) {
    final l = AppLocalizations.of(context);
    final (payoutLabel, payoutColor) = e.isPaid
        ? _shortPayout(l, e)
        : (l.dashFree, _muted);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
          color: AppColors.cardDark, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 2),
            Text(
                '${e.ticketsSold} · ${(e.attendanceRate * 100).round()} %',
                style: const TextStyle(color: _muted, fontSize: 10)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(e.isPaid ? _money(e.netCents) : l.dashFree,
              style: TextStyle(
                  color: e.isPaid ? AppColors.lavenderLight : _text2,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 1),
          Text(payoutLabel,
              style: TextStyle(color: payoutColor, fontSize: 9)),
        ]),
      ]),
    );
  }

  (String, Color) _shortPayout(AppLocalizations l, OrganizerEventStat e) {
    switch (e.payoutStatus) {
      case 'paid':
        return (l.dashPayoutReady, AppColors.green); // déjà versé → libéré
      case 'ready':
        return (l.dashPayoutReady, AppColors.green);
      case 'counting':
        return (l.dashDaysShort(e.payoutDaysLeft ?? 0), _text2);
      case 'scheduled':
        return ('', _muted);
      default:
        return (l.dashHoldManual.split(' ').first, AppColors.amber); // « Retenu »
    }
  }

  Widget _label(String text) => Text(text.toUpperCase(),
      style: const TextStyle(
          color: _muted,
          fontSize: 10,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w500));

  Widget _empty(AppLocalizations l) => Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Column(children: [
          const Icon(Icons.insights_outlined, size: 40, color: _muted),
          const SizedBox(height: 12),
          Text(l.dashNoEvents,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _text2, fontSize: 14)),
        ]),
      );

  // Ordre d'affichage des versements : ce qui bouge d'abord.
  int _payoutRank(OrganizerEventStat e) {
    switch (e.payoutStatus) {
      case 'counting':
        return 0;
      case 'ready':
        return 1;
      case 'no_scans':
      case 'first_event':
      case 'manual':
        return 2;
      case 'scheduled':
        return 3;
      case 'paid':
        return 4;
      default:
        return 5;
    }
  }

  bool _isHold(String s) =>
      s == 'no_scans' || s == 'first_event' || s == 'manual';
}
