import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:happyn/core/providers/payout_provider.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/core/utils/dates.dart';
import 'package:happyn/core/widgets/app_form.dart';
import 'package:happyn/l10n/app_localizations.dart';

/// « Recevoir mes paiements » — l'écran d'argent de l'organisateur.
///
/// Il répond à deux questions, et à rien d'autre :
///   1. Suis-je en mesure de recevoir mon argent ?
///   2. Combien, pour quel événement, et quand ?
///
/// La deuxième était la plus grosse absence du projet : un organisateur pouvait
/// vendre trente billets sans jamais voir ce que ça lui rapportait. Le détail
/// (brut, frais, commission) est affiché sans arrondi complaisant — annoncer un
/// net plus élevé que le virement réel serait pire que ne rien annoncer.
///
/// Le formulaire Stripe s'ouvre dans le navigateur et pas dans une WebView : il
/// demande des pièces d'identité et parfois une authentification bancaire, et
/// Stripe ne garantit ce parcours que dans un vrai navigateur. Au retour, l'app
/// rafraîchit l'état — d'où l'observateur de cycle de vie.
class PayoutsScreen extends ConsumerStatefulWidget {
  const PayoutsScreen({super.key});

  @override
  ConsumerState<PayoutsScreen> createState() => _PayoutsScreenState();
}

class _PayoutsScreenState extends ConsumerState<PayoutsScreen>
    with WidgetsBindingObserver {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Retour du navigateur : l'inscription a peut-être abouti entre-temps.
    // Sans ça, l'écran continuerait d'afficher « à terminer » sur un compte
    // désormais actif, et la personne relancerait le formulaire pour rien.
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(payoutAccountProvider);
      ref.invalidate(myPayoutsProvider);
    }
  }

  Future<void> _openLink({required bool dashboard}) async {
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    final link = await requestConnectLink(dashboard: dashboard);
    if (!mounted) return;
    setState(() => _busy = false);

    if (!link.ok) {
      showAppSnack(context, _linkError(l, link.error),
          background: AppColors.error);
      return;
    }
    final uri = Uri.tryParse(link.url!);
    if (uri == null) {
      showAppSnack(context, l.payoutLinkFailed, background: AppColors.error);
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      showAppSnack(context, l.payoutLinkFailed, background: AppColors.error);
    }
  }

  String _linkError(AppLocalizations l, String? code) => switch (code) {
        'suspended' => l.payoutAccountSuspended,
        'no_account' => l.payoutNoAccountYet,
        _ => l.payoutLinkFailed,
      };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final account = ref.watch(payoutAccountProvider);
    final payouts = ref.watch(myPayoutsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(l.payoutsTitle,
            style: AppText.h2.copyWith(color: Colors.white)),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.card,
        onRefresh: () async {
          ref.invalidate(payoutAccountProvider);
          ref.invalidate(myPayoutsProvider);
          // On attend vraiment le rechargement : sans ça l'indicateur
          // disparaîtrait aussitôt et le geste donnerait l'impression de
          // n'avoir rien fait. Les erreurs sont avalées ici parce que les
          // cartes les affichent déjà — les relancer ferait remonter une
          // exception non gérée depuis le RefreshIndicator.
          try {
            await Future.wait([
              ref.read(payoutAccountProvider.future),
              ref.read(myPayoutsProvider.future),
            ]);
          } catch (_) {}
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            account.when(
              loading: () => const _LoadingCard(),
              error: (_, __) => _MessageCard(
                icon: Icons.cloud_off,
                color: AppColors.textLow,
                title: l.payoutStatusUnknown,
                body: l.payoutStatusUnknownBody,
              ),
              data: (a) => _statusCard(l, a),
            ),
            const SizedBox(height: 26),
            Text(l.payoutsHistory.toUpperCase(),
                style: AppText.smallBold
                    .copyWith(color: AppColors.lavender, letterSpacing: 1)),
            const SizedBox(height: 10),
            payouts.when(
              loading: () => const _LoadingCard(),
              error: (_, __) => _MessageCard(
                icon: Icons.cloud_off,
                color: AppColors.textLow,
                title: l.payoutStatusUnknown,
                body: l.payoutStatusUnknownBody,
              ),
              data: (lines) => lines.isEmpty
                  ? _MessageCard(
                      icon: Icons.receipt_long_outlined,
                      color: AppColors.textLow,
                      title: l.payoutsEmpty,
                      body: l.payoutsEmptyBody,
                    )
                  : Column(
                      children: [
                        for (final line in lines) _payoutCard(l, line),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── L'état du compte ───────────────────────────────────────────────────────

  Widget _statusCard(AppLocalizations l, PayoutAccount a) {
    if (a.isReady) {
      return Column(
        children: [
          _MessageCard(
            icon: Icons.verified_outlined,
            color: AppColors.green,
            title: l.payoutReady,
            body: l.payoutReadyBody,
          ),
          const SizedBox(height: 12),
          _action(l.payoutManageAccount,
              filled: false, onTap: () => _openLink(dashboard: true)),
        ],
      );
    }

    // Formulaire envoyé, Stripe vérifie. Aucun bouton : il n'y a rien à faire,
    // et en proposer un ferait recommencer une démarche déjà terminée.
    if (a.isPending) {
      return _MessageCard(
        icon: Icons.hourglass_bottom,
        color: AppColors.amber,
        title: l.payoutPending,
        body: l.payoutPendingBody,
      );
    }

    final (icon, color, title, body, cta) = a.blocked
        ? (
            Icons.error_outline,
            AppColors.error,
            l.payoutBlocked,
            l.payoutBlockedBody,
            l.payoutFixAccount,
          )
        : a.isIncomplete
            ? (
                Icons.pending_actions,
                AppColors.warning,
                l.payoutIncomplete,
                l.payoutIncompleteBody,
                l.payoutResume,
              )
            : (
                Icons.account_balance_outlined,
                AppColors.lavender,
                l.payoutNotStarted,
                l.payoutNotStartedBody,
                l.payoutStart,
              );

    return Column(
      children: [
        _MessageCard(icon: icon, color: color, title: title, body: body),
        const SizedBox(height: 12),
        _action(cta, filled: true, onTap: () => _openLink(dashboard: false)),
      ],
    );
  }

  Widget _action(String label,
      {required bool filled, required VoidCallback onTap}) {
    return Opacity(
      opacity: _busy ? 0.5 : 1.0,
      child: GestureDetector(
        onTap: _busy ? null : onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            gradient: filled ? AppColors.primaryGradient : null,
            color: filled ? null : AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: filled
                ? null
                : Border.all(color: AppColors.border),
          ),
          child: Center(
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(label,
                    style: AppText.h5.copyWith(color: Colors.white)),
          ),
        ),
      ),
    );
  }

  // ── Une ligne de versement ────────────────────────────────────────────────

  Widget _payoutCard(AppLocalizations l, PayoutLine p) {
    final (statusLabel, statusColor) = switch (p.status) {
      'paid' => (l.payoutStatusPaid, AppColors.green),
      'failed' => (l.payoutStatusFailed, AppColors.error),
      'skipped' => (l.payoutStatusNothing, AppColors.textLow),
      _ => (l.payoutStatusScheduled, AppColors.amber),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  p.eventTitle.isEmpty ? l.payoutUntitledEvent : p.eventTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.h5.copyWith(color: Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(statusLabel,
                    style: AppText.microBold.copyWith(color: statusColor)),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Le net en gros, le détail en dessous : c'est le chiffre qui arrive
          // sur le compte bancaire, et c'est celui qu'on vient chercher.
          Text(_money(p.netCents),
              style: AppText.display.copyWith(fontSize: 26, color: Colors.white)),
          Text(l.payoutNetLabel,
              style: AppText.small.copyWith(color: AppColors.textLow)),

          const SizedBox(height: 14),
          _line(l.payoutGross, _money(p.grossCents)),
          if (p.withheldCents > 0)
            _line(l.payoutRefunded, '− ${_money(p.withheldCents)}'),
          if (p.stripeFeeCents > 0)
            _line(l.payoutProcessingFees, '− ${_money(p.stripeFeeCents)}'),
          _line(l.payoutCommission, '− ${_money(p.platformFeeCents)}'),

          const SizedBox(height: 10),
          Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 10),
          Text(
            _timing(context, l, p),
            style: AppText.small.copyWith(color: AppColors.textLow),
          ),
        ],
      ),
    );
  }

  Widget _line(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: AppText.bodySm.copyWith(color: AppColors.textSecondary)),
            Text(value,
                style: AppText.bodySm.copyWith(color: AppColors.textSecondary)),
          ],
        ),
      );

  /// Quand l'argent arrive — ou est arrivé. Une date manquante vaut mieux qu'une
  /// date inventée : on dit alors simplement « après l'événement ».
  String _timing(BuildContext context, AppLocalizations l, PayoutLine p) {
    if (p.isPaid && p.paidAt != null) {
      return l.payoutPaidOn(_day(context, p.paidAt!));
    }
    if (p.hasFailed) return l.payoutFailedBody;
    if (p.status == 'skipped') return l.payoutNothingBody;
    if (p.eligibleAt == null) return l.payoutAfterEvent;
    return l.payoutScheduledFor(_day(context, p.eligibleAt!));
  }

  /// `AppDates` prend une chaîne ISO, alors qu'on manipule des `DateTime` pour
  /// comparer les dates. L'aller-retour est volontaire : mieux vaut une
  /// conversion de plus qu'un deuxième format de date dans l'app, qui finirait
  /// par afficher « Jan 5 » à côté de « 5 janv. ».
  String _day(BuildContext context, DateTime d) =>
      AppDates.dayMonthYear(context, d.toIso8601String());

  /// Les cents viennent de Stripe ; la division n'a lieu qu'ici.
  String _money(int cents) => '\$${(cents / 100).toStringAsFixed(2)}';
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) => Container(
        height: 120,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
}

class _MessageCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  const _MessageCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(title,
                      style: AppText.h5.copyWith(color: Colors.white)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(body,
                style: AppText.bodySm.copyWith(color: AppColors.textSecondary)),
          ],
        ),
      );
}
