import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:happyn/core/config/observability.dart';
import 'package:happyn/core/payments/pricing.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/core/utils/dates.dart';
import 'package:happyn/core/widgets/app_form.dart';
import 'package:happyn/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Ce qui n'est pas encore versé, tel que le serveur le voit. Réservé aux
/// administrateurs : `admin_payout_queue` refuse tout autre compte.
final payoutQueueProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final rows = await Supabase.instance.client.rpc('admin_payout_queue') as List;
  return rows.map((r) => Map<String, dynamic>.from(r as Map)).toList();
});

/// Les versements à surveiller. Par défaut tout part seul, 7 jours après la
/// fin ; l'administrateur n'agit que sur ce qui est retenu (aucun billet
/// scanné, premier événement payant, blocage) ou a échoué chez Stripe.
class PayoutsAdminScreen extends ConsumerWidget {
  const PayoutsAdminScreen({super.key});

  Future<void> _decide(BuildContext context, WidgetRef ref, String eventId,
      String decision) async {
    final l = AppLocalizations.of(context);
    String? reason;
    if (decision == 'held') {
      final c = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.sheet,
          title: Text(l.payoutHoldTitle, style: AppText.h3),
          content: TextField(
            controller: c,
            maxLength: 300,
            style: const TextStyle(color: Colors.white),
            decoration: appInputDecoration(l.payoutHoldReasonHint),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(l.cancel)),
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(l.payoutHold,
                    style: const TextStyle(color: AppColors.error))),
          ],
        ),
      );
      if (ok != true) return;
      reason = c.text;
    }
    try {
      await Supabase.instance.client.rpc('admin_set_payout_review', params: {
        'p_event': eventId,
        'p_decision': decision,
        'p_reason': reason,
      });
      ref.invalidate(payoutQueueProvider);
      if (context.mounted) {
        showAppSnack(context,
            decision == 'released' ? l.payoutReleasedDone : l.payoutHeldDone);
      }
    } catch (e, st) {
      reportCaught(e, st, where: 'payoutReview');
      if (context.mounted) showAppSnack(context, l.couldNotSaveRetry);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final async = ref.watch(payoutQueueProvider);

    String reasonLabel(String? r) => switch (r) {
          'no_scans' => l.payoutReasonNoScans,
          'first_event' => l.payoutReasonFirstEvent,
          'manual' => l.payoutReasonManual,
          _ => '',
        };
    (String, Color) stateLabel(String s) => switch (s) {
          'held' => (l.payoutStateHeld, AppColors.warning),
          'failed' => (l.payoutStateFailed, AppColors.error),
          'waiting' => (l.payoutStateWaiting, AppColors.lavender),
          'no_account' => (l.payoutStateNoAccount, AppColors.textMuted),
          _ => (l.payoutStateReady, AppColors.green),
        };

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(l.payoutsAdminTitle, style: AppText.h3),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async => ref.invalidate(payoutQueueProvider),
        child: async.when(
          loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.primary)),
          error: (_, _) => ListView(children: [
            Padding(
                padding: const EdgeInsets.all(32),
                child: Text(l.couldNotLoadEvents,
                    textAlign: TextAlign.center, style: AppText.body)),
          ]),
          data: (rows) => rows.isEmpty
              ? ListView(children: [
                  Padding(
                    padding: const EdgeInsets.all(40),
                    child: Text(l.payoutsAdminEmpty,
                        textAlign: TextAlign.center, style: AppText.body),
                  ),
                ])
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final r = rows[i];
                    final state = (r['state'] ?? '') as String;
                    final (label, color) = stateLabel(state);
                    final net = Pricing.money(
                        ((r['net_cents'] as num?) ?? 0) / 100, lang);
                    final actionable = state == 'held' || state == 'ready' ||
                        state == 'waiting';
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.cardDark,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: state == 'held' || state == 'failed'
                                ? color.withValues(alpha: 0.6)
                                : AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text((r['event_title'] ?? '') as String,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppText.bodySm.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700)),
                              ),
                              Text(net,
                                  style: AppText.bodySm.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${r['organizer_name'] ?? ''} · '
                            '${l.payoutScanned(((r['tickets_scanned'] as num?) ?? 0).toInt(), ((r['tickets_sold'] as num?) ?? 0).toInt())}',
                            style: AppText.small,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(label,
                                    style: AppText.micro.copyWith(color: color)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  state == 'failed'
                                      ? (r['failure_reason'] ?? '') as String
                                      : state == 'waiting'
                                          ? '${l.payoutDue(AppDates.dowDayMonthYear(context, r['due_at'] as String?))}'
                                              '${(r['hold_reason'] as String?) != null ? ' · ${reasonLabel(r['hold_reason'] as String?)}' : ''}'
                                          : reasonLabel(r['hold_reason'] as String?),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.micro,
                                ),
                              ),
                            ],
                          ),
                          if (actionable) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                if (state == 'held')
                                  Expanded(
                                    child: _btn(l.payoutRelease, AppColors.action,
                                        () => _decide(context, ref,
                                            r['event_id'] as String, 'released')),
                                  ),
                                if (state == 'held') const SizedBox(width: 8),
                                if (r['hold_reason'] != 'manual')
                                  Expanded(
                                    child: _btn(l.payoutHold, AppColors.cardDark,
                                        () => _decide(context, ref,
                                            r['event_id'] as String, 'held'),
                                        outlined: true),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _btn(String label, Color color, VoidCallback onTap,
      {bool outlined = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          border: outlined ? Border.all(color: AppColors.error.withValues(alpha: 0.6)) : null,
        ),
        child: Text(label,
            style: AppText.small.copyWith(
                color: outlined ? AppColors.error : Colors.white,
                fontWeight: FontWeight.w700)),
      ),
    );
  }
}
