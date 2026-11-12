import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:happyn/core/config/observability.dart';
import 'package:happyn/core/providers/auth_provider.dart';
import 'package:happyn/core/providers/direct_messages_provider.dart';
import 'package:happyn/core/providers/people_provider.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/core/widgets/app_form.dart';
import 'package:happyn/features/social/direct_messages_screen.dart';
import 'package:happyn/l10n/app_localizations.dart';

/// « Nouveau message » : choisir avec qui démarrer une conversation.
///
/// La liste = tes ABONNEMENTS, et rien d'autre. La base n'ouvre une
/// conversation qu'avec les gens qu'on suit : `start_direct_conversation` lève
/// `must_follow_recipient` sinon. Montrer qui que ce soit d'autre reviendrait à
/// proposer un tap qui échoue — un repli « tous les utilisateurs » ne ferait
/// que des erreurs. Les gens à qui on a écrit récemment remontent en premier :
/// c'est à eux qu'on réécrit le plus souvent.
class NewMessageScreen extends ConsumerStatefulWidget {
  const NewMessageScreen({super.key});

  @override
  ConsumerState<NewMessageScreen> createState() => _NewMessageScreenState();
}

class _NewMessageScreenState extends ConsumerState<NewMessageScreen> {
  final _search = TextEditingController();

  // Id de la personne dont on ouvre la conversation, pour neutraliser un
  // second tap pendant l'aller-retour réseau.
  String? _opening;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _open(PersonSummary p) async {
    if (_opening != null) return;
    setState(() => _opening = p.id);
    try {
      final convId = await startDirectConversation(p.id);
      if (!mounted) return;
      // pushReplacement : revenir depuis le fil ramène à la LISTE Messages, pas
      // à ce sélecteur — il a fait son travail.
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => DirectMessageThreadScreen(
          conversationId: convId,
          recipientName: p.displayName,
          recipientAvatar: p.avatarUrl ?? '',
        ),
      ));
    } catch (e, st) {
      reportCaught(e, st, where: 'newMessage.open');
      if (!mounted) return;
      setState(() => _opening = null);
      showAppSnack(context, AppLocalizations.of(context).messagesLoadFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final me = ref.watch(currentUserIdProvider);
    final following = me == null
        ? const AsyncValue<List<PersonSummary>>.data([])
        : ref.watch(followListProvider((me, FollowListKind.following)));
    // Les gens à qui on a écrit récemment, dans l'ordre, pour les remonter.
    final recent = <String>[
      for (final c in ref.watch(directConversationsProvider).value ?? const [])
        if (c['other_user_id'] != null) c['other_user_id'] as String,
    ];
    final query = _search.text.trim().toLowerCase();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(l.newMessage, style: AppText.h3),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            autofocus: true,
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
              if (people.isEmpty) return _centered(l.newMessageEmpty);
              final sorted = [...people]..sort((a, b) {
                  int rank(PersonSummary p) {
                    final i = recent.indexOf(p.id);
                    return i < 0 ? recent.length : i;
                  }

                  return rank(a).compareTo(rank(b));
                });
              final shown = query.isEmpty
                  ? sorted
                  : sorted
                      .where((p) =>
                          p.fullName.toLowerCase().contains(query) ||
                          p.username.toLowerCase().contains(query))
                      .toList();
              if (shown.isEmpty) return _centered(l.shareNoMatch);
              return ListView.separated(
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: shown.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  indent: 74,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
                itemBuilder: (_, i) => _row(shown[i]),
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _row(PersonSummary p) {
    final opening = _opening == p.id;
    return InkWell(
      onTap: opening ? null : () => _open(p),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(children: [
          _avatar(p),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  p.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodySm.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (p.username.isNotEmpty)
                  Text(
                    '@${p.username}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption.copyWith(color: AppColors.textLow),
                  ),
              ],
            ),
          ),
          if (opening)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
        ]),
      ),
    );
  }

  Widget _avatar(PersonSummary p) {
    const size = 46.0;
    final name = p.displayName;
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      color: AppColors.primary.withValues(alpha: 0.2),
      child: Text(initial,
          style: AppText.bodySm.copyWith(color: AppColors.lavenderLight)),
    );
    final url = p.avatarUrl ?? '';
    return ClipOval(
      child: url.isEmpty
          ? fallback
          : CachedNetworkImage(
              imageUrl: url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              placeholder: (_, _) => fallback,
              errorWidget: (_, _, _) => fallback,
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
