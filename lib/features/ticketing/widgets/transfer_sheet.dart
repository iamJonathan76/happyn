import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:happyn/core/providers/auth_provider.dart';
import 'package:happyn/core/providers/direct_messages_provider.dart';
import 'package:happyn/core/providers/people_provider.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/features/social/widgets/person_pick_tile.dart';
import 'package:happyn/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Donner un billet à quelqu'un qu'on suit.
///
/// La même grille que la feuille d'envoi, avec trois différences voulues : une
/// seule personne, un écran de confirmation (un billet donné ne revient pas),
/// et aucune ligne « autres apps » — un billet ne se partage pas sur WhatsApp,
/// c'est exactement ce que le QR signé empêche.
///
/// Renvoie la personne qui a reçu le billet, ou null si rien n'est parti.
Future<PersonSummary?> showTransferSheet(
  BuildContext context, {
  required String ticketId,
  required bool paid,
}) {
  return showModalBottomSheet<PersonSummary>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.sheet,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => _TransferSheet(ticketId: ticketId, paid: paid),
  );
}

class _TransferSheet extends ConsumerStatefulWidget {
  final String ticketId;
  final bool paid;
  const _TransferSheet({required this.ticketId, required this.paid});

  @override
  ConsumerState<_TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends ConsumerState<_TransferSheet> {
  final _search = TextEditingController();
  PersonSummary? _chosen;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _transfer() async {
    final person = _chosen!;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.rpc(
        'transfer_ticket_to_user',
        params: {'p_ticket_id': widget.ticketId, 'p_recipient': person.id},
      );
      if (mounted) Navigator.of(context).pop(person);
    } catch (e) {
      debugPrint('transfer_ticket_to_user failed: $e');
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = _message(e, AppLocalizations.of(context));
      });
    }
  }

  /// Les refus du serveur, un par un. Le message d'âge ne dit jamais l'âge de
  /// la personne : la base ne le renvoie pas, et l'écran n'a pas à le deviner.
  String _message(Object e, AppLocalizations l) {
    final msg = e.toString();
    if (msg.contains('not_following_recipient')) {
      return l.transferErrNotFollowing;
    }
    if (msg.contains('transfer_not_allowed')) return l.transferErrNotAllowed;
    if (msg.contains('recipient_age_requirement')) return l.transferErrAge;
    if (msg.contains('cannot_transfer_self')) return l.transferErrSelf;
    if (msg.contains('ticket_not_transferable')) {
      return l.transferErrNotTransferable;
    }
    if (msg.contains('event_cancelled')) return l.transferErrEventCancelled;
    if (msg.contains('event_ended')) return l.transferErrEventEnded;
    return l.transferFailed;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textFaint,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: _chosen == null ? _picker(l) : _confirmation(l, _chosen!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _picker(AppLocalizations l) {
    final me = ref.watch(currentUserIdProvider);
    final following = me == null
        ? const AsyncValue<List<PersonSummary>>.data([])
        : ref.watch(followListProvider((me, FollowListKind.following)));
    final recent = <String>[
      for (final c in ref.watch(directConversationsProvider).value ?? const [])
        if (c['other_user_id'] != null) c['other_user_id'] as String,
    ];
    final query = _search.text.trim().toLowerCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Text(
            l.transferTicket,
            style: AppText.h1.copyWith(fontSize: 19, color: Colors.white),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: Text(
            l.transferSheetBody,
            style: AppText.bodySm.copyWith(fontSize: 12.5, height: 1.4),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            style: AppText.bodySm.copyWith(color: Colors.white),
            decoration: InputDecoration(
              hintText: l.shareSearch,
              prefixIcon: Icon(Icons.search, color: AppColors.textLow),
              filled: true,
              fillColor: AppColors.card,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: following.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
            error: (_, _) => _centered(l.messagesLoadFailed),
            data: (people) {
              if (people.isEmpty) return _centered(l.shareNoFollowing);
              final sorted = [...people]
                ..sort((a, b) {
                  int rank(PersonSummary p) {
                    final i = recent.indexOf(p.id);
                    return i < 0 ? recent.length : i;
                  }

                  return rank(a).compareTo(rank(b));
                });
              final shown = query.isEmpty
                  ? sorted
                  : sorted
                        .where(
                          (p) =>
                              p.fullName.toLowerCase().contains(query) ||
                              p.username.toLowerCase().contains(query),
                        )
                        .toList();
              if (shown.isEmpty) return _centered(l.shareNoMatch);
              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.82,
                ),
                itemCount: shown.length,
                itemBuilder: (_, i) => PersonPickTile(
                  person: shown[i],
                  selected: false,
                  onTap: () => setState(() {
                    _chosen = shown[i];
                    _error = null;
                  }),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _confirmation(AppLocalizations l, PersonSummary person) {
    final url = person.avatarUrl ?? '';
    final initial = person.displayName.replaceFirst('@', '');
    final fallback = Container(
      color: AppColors.primary.withValues(alpha: 0.2),
      alignment: Alignment.center,
      child: Text(
        initial.isEmpty ? '?' : initial[0].toUpperCase(),
        style: AppText.h2.copyWith(color: AppColors.lavenderLight),
      ),
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
        child: Column(
          children: [
            ClipOval(
              child: SizedBox(
                width: 88,
                height: 88,
                child: url.isEmpty
                    ? fallback
                    : CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => fallback,
                        errorWidget: (_, _, _) => fallback,
                      ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              l.transferConfirmTitle(person.displayName),
              textAlign: TextAlign.center,
              style: AppText.h3.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              l.transferConfirmBody,
              textAlign: TextAlign.center,
              style: AppText.bodySm.copyWith(height: 1.45),
            ),
            // Dit AVANT d'envoyer, pas découvert au moment d'annuler.
            if (widget.paid) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 18,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l.transferNotRefundable,
                        style: AppText.small.copyWith(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: AppText.small.copyWith(color: AppColors.error),
              ),
            ],
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _sending ? null : _transfer,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        l.transferConfirm,
                        style: AppText.h4.copyWith(color: Colors.white),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _sending
                  ? null
                  : () => setState(() {
                      _chosen = null;
                      _error = null;
                    }),
              child: Text(
                l.cancel,
                style: AppText.bodySm.copyWith(color: AppColors.textMed),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _centered(String text) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppText.bodySm.copyWith(color: AppColors.textLow),
      ),
    ),
  );
}
