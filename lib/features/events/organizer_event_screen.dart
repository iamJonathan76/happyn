import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:happyn/core/providers/organizer_provider.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/core/events/event_utils.dart';
import 'package:happyn/core/providers/events_provider.dart';
import 'package:happyn/core/widgets/app_form.dart';
import 'package:happyn/features/events/create_event_screen.dart';
import 'package:happyn/features/ticketing/scanner_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:happyn/l10n/app_localizations.dart';

/// Tableau de bord d'un événement, pour son organisateur.
///
/// Il avait un menu, un scanner et un seul chiffre : le total vendu. Créer un
/// événement était possible, le gérer ne l'était pas — il ne savait ni comment
/// ses paliers se vendaient, ni qui venait, ni combien de personnes étaient
/// entrées pendant la soirée.
///
/// Toutes les données viennent de fonctions `SECURITY DEFINER` qui vérifient
/// elles-mêmes qu'on est bien l'organisateur : `tickets` n'est lisible que par
/// le détenteur de chaque billet, et ça doit le rester.
class OrganizerEventScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> event;
  const OrganizerEventScreen({super.key, required this.event});

  @override
  ConsumerState<OrganizerEventScreen> createState() =>
      _OrganizerEventScreenState();
}

class _OrganizerEventScreenState extends ConsumerState<OrganizerEventScreen> {
  final _search = TextEditingController();
  String _query = '';
  late String _status;

  String get _eventId => widget.event['id'] as String;

  @override
  void initState() {
    super.initState();
    _status = (widget.event['status'] ?? 'published') as String;
    _search.addListener(
        () => setState(() => _query = _search.text.trim().toLowerCase()));
  }

  // ── Cycle de vie de l'evenement ─────────────────────────────────
  //
  // Publier, depublier, annuler, supprimer vivent ici et nulle part ailleurs.
  // Ces actions etaient dispersees entre la fiche publique et l'onglet du
  // profil : on annulait un evenement depuis l'ecran que voient les acheteurs,
  // et on le supprimait depuis une liste qui ne montrait aucun chiffre. Or ce
  // sont precisement les decisions qu'on ne devrait prendre qu'en ayant les
  // ventes et les participants sous les yeux.

  Future<void> _setStatus(String newStatus, String toast) async {
    try {
      await Supabase.instance.client
          .from('events')
          .update({'status': newStatus}).eq('id', _eventId);
      widget.event['status'] = newStatus;
      if (!mounted) return;
      setState(() => _status = newStatus);
      ref.invalidate(eventsProvider);
      showAppSnack(context, toast);
    } catch (_) {
      if (mounted) {
        showAppSnack(context, AppLocalizations.of(context).actionFailed);
      }
    }
  }

  Future<void> _edit() async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CreateEventScreen(event: widget.event)));
    if (!mounted) return;
    ref.invalidate(eventsProvider);
    await _refresh();
  }

  Future<void> _confirmCancel() async {
    final l = AppLocalizations.of(context);
    final ok = await _confirm(l.cancelEventTitle, l.cancelEventBody,
        confirmLabel: l.cancelEvent, keepLabel: l.keep);
    if (ok) await _setStatus('cancelled', l.eventCancelledMsg);
  }

  /// La suppression echoue en base si des billets ont ete vendus — c'est la
  /// base qui tranche, pas cet ecran : un organisateur ne doit pas pouvoir
  /// faire disparaitre un evenement que des gens ont paye. On traduit alors
  /// l'erreur en conseil : annuler, ce qui declenche les remboursements.
  Future<void> _confirmDelete() async {
    final l = AppLocalizations.of(context);
    final ok = await _confirm(l.deleteEventTitle, l.deleteEventBody,
        confirmLabel: l.delete, keepLabel: l.keep);
    if (!ok) return;
    try {
      await Supabase.instance.client
          .from('events')
          .delete()
          .eq('id', _eventId);
      ref.invalidate(eventsProvider);
      if (!mounted) return;
      showAppSnack(context, l.eventDeleted);
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      showAppSnack(
          context,
          e.toString().contains('event_has_tickets')
              ? l.cantDeleteHasTickets
              : l.couldNotDeleteEvent);
    }
  }

  Future<bool> _confirm(String title, String body,
      {required String confirmLabel, required String keepLabel}) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: AppText.h4.copyWith(color: Colors.white)),
        content: Text(body, style: AppText.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(keepLabel, style: AppText.body),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel,
                style: AppText.body.copyWith(
                    fontWeight: FontWeight.w700, color: AppColors.error)),
          ),
        ],
      ),
    );
    return res == true;
  }

  Widget _lifecycleMenu(AppLocalizations l) {
    final past = isEventPast(widget.event);
    return PopupMenuButton<String>(
      color: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      position: PopupMenuPosition.under,
      icon: const Icon(Icons.more_horiz, color: Colors.white),
      onSelected: (v) {
        if (v == 'edit') _edit();
        if (v == 'unpublish') _setStatus('draft', l.eventUnpublishedMsg);
        if (v == 'publish') _setStatus('published', l.eventPublishedMsg);
        if (v == 'cancel') _confirmCancel();
        if (v == 'delete') _confirmDelete();
      },
      itemBuilder: (context) => [
        _menuItem('edit', Icons.edit_outlined, l.editEventTitle),
        // Un evenement termine ne se publie ni ne s'annule : proposer l'un ou
        // l'autre laisserait croire qu'on peut encore agir dessus.
        if (!past && _status != 'cancelled')
          _status == 'published'
              ? _menuItem(
                  'unpublish', Icons.visibility_off_outlined, l.unpublish)
              : _menuItem('publish', Icons.publish_outlined, l.publish),
        if (!past && _status != 'cancelled')
          _menuItem('cancel', Icons.cancel_outlined, l.cancelEvent,
              danger: true),
        _menuItem('delete', Icons.delete_outline, l.delete, danger: true),
      ],
    );
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label,
      {bool danger = false}) {
    final color = danger ? AppColors.error : Colors.white;
    return PopupMenuItem<String>(
      value: value,
      height: 42,
      child: Row(
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.bodySm.copyWith(color: color)),
          ),
        ],
      ),
    );
  }

  /// L'etat de l'evenement, a cote de son titre : c'est le contexte de toutes
  /// les actions du menu, il ne doit pas falloir l'ouvrir pour le connaitre.
  Widget _stateBadge(AppLocalizations l) {
    final (label, color) = switch (true) {
      _ when _status == 'cancelled' => (l.stateCancelled, AppColors.pink),
      _ when isEventPast(widget.event) =>
        (l.stateFinished, AppColors.textFaint),
      _ when _status == 'draft' => (l.stateDraft, AppColors.textLow),
      _ => (l.statePublished, AppColors.success),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(label, style: AppText.microBold.copyWith(color: color)),
    );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(organizerStatsProvider(_eventId));
    ref.invalidate(organizerAttendeesProvider(_eventId));
    await ref.read(organizerStatsProvider(_eventId).future);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final statsAsync = ref.watch(organizerStatsProvider(_eventId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(l.manageEventTitle, style: AppText.h3),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [_lifecycleMenu(l)],
      ),
      body: statsAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
        // On distingue l'echec du vide : les erreurs avalees de ce projet se
        // sont toutes deguisees en liste vide.
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Text('$e',
                textAlign: TextAlign.center,
                style: AppText.body.copyWith(color: AppColors.textLow)),
          ),
        ),
        data: (tiers) {
          final totals = EventTotals.from(tiers);
          return RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.card,
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
              children: [
                Text(widget.event['title'] as String? ?? '',
                    style: AppText.h2.copyWith(color: Colors.white)),
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerLeft, child: _stateBadge(l)),
                const SizedBox(height: 18),
                _overview(l, totals),
                const SizedBox(height: 24),
                _scanButton(l),
                const SizedBox(height: 26),
                Text(l.byTierSection,
                    style: AppText.h4.copyWith(color: Colors.white)),
                const SizedBox(height: 12),
                for (final tier in tiers) _tierCard(l, tier),
                const SizedBox(height: 26),
                Text(l.attendeesSection,
                    style: AppText.h4.copyWith(color: Colors.white)),
                const SizedBox(height: 4),
                Text(l.attendeePrivacyNote,
                    style: AppText.caption.copyWith(fontSize: 11.5, height: 1.4)),
                const SizedBox(height: 12),
                _attendeeList(l),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _overview(AppLocalizations l, EventTotals t) {
    return Row(
      children: [
        Expanded(
            child: _stat(l.ticketsSoldLabel,
                t.isCapped ? '${t.sold} / ${t.capacity}' : '${t.sold}')),
        const SizedBox(width: 10),
        Expanded(child: _stat(l.checkedInLabel, '${t.checkedIn}')),
        const SizedBox(width: 10),
        Expanded(
          child: _stat(
            l.grossSalesLabel,
            '\$${t.grossRevenue.toStringAsFixed(0)}',
            // « Ventes brutes » et non « revenu » : ce chiffre est avant les
            // frais Stripe et avant toute commission. L'appeler revenu ferait
            // croire a l'organisateur qu'il touchera cette somme.
            hint: l.grossSalesHint,
          ),
        ),
      ],
    );
  }

  Widget _stat(String label, String value, {String? hint}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.micro),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style:
                    AppText.display.copyWith(fontSize: 22, color: Colors.white)),
          ),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(hint,
                style: AppText.micro.copyWith(height: 1.3),
                maxLines: 3,
                overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
    );
  }

  Widget _scanButton(AppLocalizations l) => GestureDetector(
        onTap: () async {
          await Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ScannerScreen(event: widget.event)));
          // Au retour, les entrees ont change : sans ca, l'organisateur
          // regarderait un compteur fige pendant toute la soiree.
          if (mounted) await _refresh();
        },
        child: Container(
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.qr_code_scanner, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(l.openScanner,
                    style: AppText.h4.copyWith(color: Colors.white)),
              ],
            ),
          ),
        ),
      );

  Widget _tierCard(AppLocalizations l, TierStats tier) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(tier.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodySm.copyWith(color: Colors.white)),
              ),
              Text(
                tier.isCapped
                    ? l.soldOfCapacity(tier.sold, tier.total)
                    : l.noCapacity(tier.sold),
                style: AppText.smallBold.copyWith(color: AppColors.textMed),
              ),
            ],
          ),
          if (tier.isCapped) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: tier.fillRatio,
                minHeight: 6,
                backgroundColor: Colors.white.withOpacity(0.07),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            const SizedBox(height: 6),
            Text(l.remainingLabel(tier.remaining), style: AppText.micro),
          ],
          if (tier.cancelled > 0) ...[
            const SizedBox(height: 6),
            // Les annulations sont affichees : une place rendue est une place
            // revendable, et c'est une information que l'organisateur veut.
            Text('${tier.cancelled} ✕', style: AppText.micro),
          ],
        ],
      ),
    );
  }

  Widget _attendeeList(AppLocalizations l) {
    final async = ref.watch(organizerAttendeesProvider(_eventId));
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
      ),
      error: (e, _) => Text('$e', style: AppText.small),
      data: (all) {
        if (all.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Text(l.noAttendeesYet, style: AppText.body),
          );
        }

        final list = _query.isEmpty
            ? all
            : all
                .where((a) => a.fullName.toLowerCase().contains(_query))
                .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // La recherche apparait seulement quand elle sert : sous une
            // dizaine de noms, l'oeil est plus rapide qu'un champ de saisie.
            if (all.length > 10) ...[
              TextField(
                controller: _search,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: l.attendeeSearch,
                  hintStyle: AppText.small,
                  prefixIcon:
                      Icon(Icons.search, size: 18, color: AppColors.textLow),
                  filled: true,
                  fillColor: AppColors.card,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(l.attendeeNotFound, style: AppText.small),
              )
            else
              for (final a in list) _attendeeRow(l, a),
          ],
        );
      },
    );
  }

  Widget _attendeeRow(AppLocalizations l, Attendee a) {
    final avatar = a.avatarUrl ?? '';
    final initial = a.fullName.isEmpty ? '?' : a.fullName[0].toUpperCase();
    final fallback = Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      color: AppColors.primary.withOpacity(0.2),
      child: Text(initial,
          style:
              AppText.captionBold.copyWith(color: AppColors.lavenderLight)),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          ClipOval(
            child: avatar.isEmpty
                ? fallback
                : CachedNetworkImage(
                    imageUrl: avatar,
                    width: 34,
                    height: 34,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => fallback,
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodySm.copyWith(color: Colors.white)),
                Text(a.typeName, style: AppText.micro),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: a.checkedIn
                  ? AppColors.success.withOpacity(0.15)
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              a.checkedIn ? l.checkedInBadge : l.notCheckedInBadge,
              style: AppText.microBold.copyWith(
                  color: a.checkedIn ? AppColors.success : AppColors.textLow),
            ),
          ),
        ],
      ),
    );
  }
}
