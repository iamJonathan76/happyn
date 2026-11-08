import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:happyn/core/payments/pricing.dart';
import 'package:happyn/core/providers/organizer_dashboard_provider.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:happyn/core/theme/app_text.dart';
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
            style: AppText.h2.copyWith(color: Colors.white)),
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
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 36),
      children: [
        Text(l.dashSubtitle,
            style: const TextStyle(color: _muted, fontSize: 12)),
        const SizedBox(height: 16),

        _periodSelector(l),
        const SizedBox(height: 22),

        if (events.isEmpty)
          _empty(l)
        else ...[
          // Le revenu net domine ; billets vendus et entrées passent en
          // dessous, au second plan.
          _hero(l, net, sold, scanned),
          const SizedBox(height: 20),

          _attendanceCard(l, rate, scanned, sold),

          if (payouts.isNotEmpty) ...[
            const SizedBox(height: 12),
            _nextPayoutCard(l, payouts),
          ],

          const SizedBox(height: 26),
          _label(l.dashByEvent),
          const SizedBox(height: 10),
          _byEventCard(ranking),
        ],
      ],
    );
  }

  // ── Sélecteur de période (segmenté) ─────────────────────────────────────

  Widget _periodSelector(AppLocalizations l) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(999)),
        child: Row(children: [
          _seg(l.dashWeek, DashboardRange.week),
          _seg(l.dashMonth, DashboardRange.month),
          _seg(l.dashAll, DashboardRange.all),
        ]),
      );

  Widget _seg(String label, DashboardRange range) {
    final on = _range == range;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _range = range),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: on ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: on ? Colors.white : _text2,
                  fontSize: 13,
                  fontWeight: on ? FontWeight.w600 : FontWeight.w500)),
        ),
      ),
    );
  }

  // ── Hero : revenu net + stats secondaires ────────────────────────────────

  Widget _hero(AppLocalizations l, int net, int sold, int scanned) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(_money(net),
                style: AppText.display
                    .copyWith(fontSize: 40, color: Colors.white, height: 1.0)),
          ),
          const SizedBox(height: 4),
          Text(l.dashNetRevenue,
              style: const TextStyle(color: _muted, fontSize: 13)),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: _heroStat('$sold', l.dashTicketsSold)),
            Expanded(child: _heroStat('$scanned', l.checkedInLabel)),
          ]),
        ],
      );

  Widget _heroStat(String value, String label) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.h1.copyWith(color: Colors.white)),
          const SizedBox(height: 2),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _muted, fontSize: 12)),
        ],
      );

  // ── Présence ─────────────────────────────────────────────────────────────

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
                  style: AppText.h1.copyWith(color: Colors.white)),
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

  // ── Prochain versement (bloc prioritaire) ────────────────────────────────

  Widget _nextPayoutCard(
      AppLocalizations l, List<OrganizerEventStat> payouts) {
    final next = payouts.first;
    final (reason, reasonColor) = _payoutSubtitle(l, next);
    final dimmed = _isHold(next.payoutStatus) || next.payoutStatus == 'paid';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.card, borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label(l.dashNextPayout),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(
            child: Text(_money(next.netCents),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.display.copyWith(
                    fontSize: 26,
                    color: dimmed ? _text2 : Colors.white)),
          ),
          const SizedBox(width: 10),
          _statusChip(l, next),
        ]),
        if (reason.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(reason,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: reasonColor, fontSize: 12)),
        ],
        // Les autres versements en attente, sans les cacher mais discrets.
        for (var i = 1; i < payouts.length; i++) ...[
          Divider(color: Colors.white.withValues(alpha: 0.07), height: 22),
          _payoutMiniRow(l, payouts[i]),
        ],
      ]),
    );
  }

  Widget _payoutMiniRow(AppLocalizations l, OrganizerEventStat e) {
    final (label, color) = _statusMeta(l, e);
    final dimmed = _isHold(e.payoutStatus) || e.payoutStatus == 'paid';
    return Row(children: [
      Expanded(
        child: Text(e.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
      ),
      const SizedBox(width: 8),
      Text(label, style: TextStyle(color: color, fontSize: 11)),
      const SizedBox(width: 10),
      Text(_money(e.netCents),
          style: TextStyle(
              color: dimmed ? _text2 : Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600)),
    ]);
  }

  /// Pastille de statut : un mot, une couleur. Ambre pour les retenues, vert
  /// pour prêt/versé, lavande pour en attente, et le compte à rebours sinon.
  Widget _statusChip(AppLocalizations l, OrganizerEventStat e) {
    final (label, color) = _statusMeta(l, e);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999)),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  (String, Color) _statusMeta(AppLocalizations l, OrganizerEventStat e) =>
      switch (e.payoutStatus) {
        'paid' => (l.payoutStatusPaid, AppColors.green),
        'ready' => (l.payoutStateReady, AppColors.green),
        'scheduled' => (l.payoutStateWaiting, AppColors.lavender),
        'counting' => (l.dashDaysShort(e.payoutDaysLeft ?? 0), AppColors.lavender),
        _ => (l.payoutStateHeld, AppColors.amber),
      };

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

  // ── Par événement (lignes séparées) ──────────────────────────────────────

  Widget _byEventCard(List<OrganizerEventStat> ranking) => Container(
        decoration: BoxDecoration(
            color: AppColors.cardDark, borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          for (var i = 0; i < ranking.length; i++) ...[
            if (i > 0)
              Divider(
                  color: Colors.white.withValues(alpha: 0.06),
                  height: 1,
                  indent: 16,
                  endIndent: 16),
            _eventRow(ranking[i]),
          ],
        ]),
      );

  Widget _eventRow(OrganizerEventStat e) {
    final l = AppLocalizations.of(context);
    final (payoutLabel, payoutColor) =
        e.isPaid ? _shortPayout(l, e) : (l.dashFree, _muted);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            Text('${e.ticketsSold} · ${(e.attendanceRate * 100).round()} %',
                style: const TextStyle(color: _muted, fontSize: 11)),
          ]),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(e.isPaid ? _money(e.netCents) : l.dashFree,
              style: TextStyle(
                  color: e.isPaid ? AppColors.lavenderLight : _text2,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(payoutLabel,
              style: TextStyle(color: payoutColor, fontSize: 10)),
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
        return (l.payoutStateHeld, AppColors.amber);
    }
  }

  Widget _label(String text) => Text(text.toUpperCase(),
      style: const TextStyle(
          color: _muted,
          fontSize: 10,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600));

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
