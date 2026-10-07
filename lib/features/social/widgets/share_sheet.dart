import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:happyn/core/config/observability.dart';
import 'package:happyn/core/providers/auth_provider.dart';
import 'package:happyn/core/providers/direct_messages_provider.dart';
import 'package:happyn/core/providers/people_provider.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/core/utils/dates.dart';
import 'package:happyn/core/utils/support.dart';
import 'package:happyn/core/widgets/app_form.dart';
import 'package:happyn/l10n/app_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Ce qu'on partage : une publication (ligne de `feed_posts`) ou un événement
/// (ligne de `events`). La feuille ne garde que la ligne telle quelle et en
/// tire ce dont elle a besoin.
class ShareTarget {
  final String kind; // 'post' | 'event'
  final Map<String, dynamic> row;

  const ShareTarget.post(this.row) : kind = 'post';
  const ShareTarget.event(this.row) : kind = 'event';

  String get id => row['id'] as String;

  /// L'image propre, sinon l'affiche de l'événement auquel la publication est
  /// rattachée : une publication texte se partage mieux avec un visuel.
  String? get imageUrl {
    final url = row['image_url'] as String?;
    if (url != null && url.isNotEmpty) return url;
    return row['event_image'] as String?;
  }
}

/// La feuille d'envoi : en haut, les gens qu'on suit ; en bas, les autres
/// apps. Une seule porte de sortie pour tout ce qui se partage.
Future<void> showShareSheet(BuildContext context, ShareTarget target) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.sheet,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => _ShareSheet(target: target),
  );
}

class _ShareSheet extends ConsumerStatefulWidget {
  final ShareTarget target;
  const _ShareSheet({required this.target});

  @override
  ConsumerState<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends ConsumerState<_ShareSheet> {
  final _search = TextEditingController();
  final _note = TextEditingController();
  final _selected = <String>{};
  final _shareButtonKey = GlobalKey();
  late final Future<bool> _externalAllowed = _isPublic();
  bool _sending = false;

  @override
  void dispose() {
    _search.dispose();
    _note.dispose();
    super.dispose();
  }

  /// Hors de l'app, seulement ce que tout le monde peut voir dans l'app.
  ///
  /// Un événement privé, ou une publication que l'organisateur a réservée aux
  /// participants, ne doit pas pouvoir partir sur WhatsApp : ce serait
  /// contourner son choix. Lu en base plutôt que déduit de l'écran, parce que
  /// `feed_posts` ne porte pas `posts_visibility`. En cas de doute (réseau),
  /// on refuse : un partage manqué se refait, une fuite ne se rattrape pas.
  Future<bool> _isPublic() async {
    final eventId = widget.target.kind == 'event'
        ? widget.target.id
        : widget.target.row['event_id'] as String?;
    if (eventId == null) return false;
    try {
      final row = await Supabase.instance.client
          .from('events')
          .select('visibility, posts_visibility')
          .eq('id', eventId)
          .maybeSingle();
      if (row == null) return false;
      final eventPublic = (row['visibility'] ?? 'public') == 'public';
      if (widget.target.kind == 'event') return eventPublic;
      return eventPublic && row['posts_visibility'] == 'public';
    } catch (e, st) {
      reportCaught(e, st, where: 'share.isPublic');
      return false;
    }
  }

  String _externalText(AppLocalizations l) {
    final r = widget.target.row;
    if (widget.target.kind == 'event') {
      final date = AppDates.dowDayMonthYear(
        context,
        r['start_date'] as String?,
      );
      return '${l.shareEventText((r['title'] as String?) ?? 'HAPPYN', date)} $kSiteUrl';
    }
    final caption = ((r['caption'] as String?) ?? '').trim();
    final author = ((r['author_name'] as String?) ?? '').trim();
    final event = ((r['event_title'] as String?) ?? '').trim();
    final line =
        '${l.sharePostText(author.isEmpty ? 'HAPPYN' : author, event)} $kSiteUrl';
    return caption.isEmpty ? line : '$caption\n\n$line';
  }

  Future<void> _send() async {
    final l = AppLocalizations.of(context);
    final total = _selected.length;
    setState(() => _sending = true);
    final sent = await shareToPeople(
      recipientIds: _selected.toList(),
      sharedKind: widget.target.kind,
      contentId: widget.target.id,
      note: _note.text,
    );
    if (!mounted) return;
    ref.invalidate(directConversationsProvider);
    final messenger = ScaffoldMessenger.of(context);
    if (sent == 0) {
      setState(() => _sending = false);
      showAppSnack(context, l.shareFailed);
      return;
    }
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          sent == total ? l.shareSent(sent) : l.shareSentPartly(sent, total),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else if (_selected.length < kMaxShareRecipients) {
        _selected.add(id);
      } else {
        showAppSnack(
          context,
          AppLocalizations.of(context).shareMaxPeople(kMaxShareRecipients),
        );
      }
    });
  }

  Future<void> _whatsApp(String text) async {
    // wa.me plutôt que whatsapp:// : il ouvre l'app si elle est installée, le
    // site sinon, et ne demande aucune déclaration de schéma sur iOS/Android.
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    showAppSnack(context, AppLocalizations.of(context).shareCopied);
  }

  Future<void> _more(String text) async {
    // L'image voyage avec le texte quand on l'a : c'est elle qui donne envie
    // d'ouvrir. Si le téléchargement échoue, le texte seul part quand même.
    final files = <XFile>[];
    final url = widget.target.imageUrl;
    if (url != null && url.isNotEmpty) {
      try {
        final res = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          files.add(
            XFile.fromData(
              res.bodyBytes,
              mimeType: res.headers['content-type'] ?? 'image/jpeg',
              name: 'happyn.jpg',
            ),
          );
        }
      } catch (e, st) {
        reportCaught(e, st, where: 'share.downloadImage');
      }
    }
    // iPad : le menu de partage doit savoir d'où il sort, sinon il plante.
    final box =
        _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        files: files.isEmpty ? null : files,
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final me = ref.watch(currentUserIdProvider);
    final following = me == null
        ? const AsyncValue<List<PersonSummary>>.data([])
        : ref.watch(followListProvider((me, FollowListKind.following)));
    // Les gens à qui on a écrit récemment d'abord : c'est à eux qu'on envoie.
    final recent = <String>[
      for (final c in ref.watch(directConversationsProvider).value ?? const [])
        if (c['other_user_id'] != null) c['other_user_id'] as String,
    ];
    final query = _search.text.trim().toLowerCase();

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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
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
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 14,
                          childAspectRatio: 0.82,
                        ),
                    itemCount: shown.length,
                    itemBuilder: (_, i) => _PersonTile(
                      person: shown[i],
                      selected: _selected.contains(shown[i].id),
                      onTap: () => _toggle(shown[i].id),
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            SafeArea(
              top: false,
              child: _selected.isNotEmpty
                  ? _sendBar(l)
                  : FutureBuilder<bool>(
                      future: _externalAllowed,
                      builder: (_, snap) {
                        if (!snap.hasData) {
                          return const SizedBox(height: 96);
                        }
                        if (snap.data != true) {
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                            child: Text(
                              l.shareInAppOnly,
                              textAlign: TextAlign.center,
                              style: AppText.caption.copyWith(
                                color: AppColors.textLow,
                              ),
                            ),
                          );
                        }
                        final text = _externalText(l);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _ExternalAction(
                                // Le vrai logo : c'est lui que l'oeil cherche
                                // dans une feuille de partage. Ni recolore ni
                                // deforme, comme le demande WhatsApp.
                                icon: FontAwesomeIcons.whatsapp.data,
                                color: const Color(0xFF25D366),
                                label: 'WhatsApp',
                                onTap: () => _whatsApp(text),
                              ),
                              _ExternalAction(
                                icon: Icons.link_rounded,
                                label: l.shareCopy,
                                onTap: () => _copy(text),
                              ),
                              _ExternalAction(
                                key: _shareButtonKey,
                                icon: Icons.ios_share,
                                label: l.shareMore,
                                onTap: () => _more(text),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sendBar(AppLocalizations l) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: _note,
            maxLength: 2000,
            minLines: 1,
            maxLines: 3,
            style: AppText.bodySm.copyWith(color: Colors.white),
            decoration: InputDecoration(
              hintText: l.shareNoteHint,
              counterText: '',
              filled: true,
              fillColor: AppColors.card,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        FilledButton(
          onPressed: _sending ? null : _send,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: _sending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  l.shareSendCount(_selected.length),
                  style: AppText.smallBold.copyWith(color: Colors.white),
                ),
        ),
      ],
    ),
  );

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

class _PersonTile extends StatelessWidget {
  final PersonSummary person;
  final bool selected;
  final VoidCallback onTap;

  const _PersonTile({
    required this.person,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final url = person.avatarUrl ?? '';
    final initial = person.displayName.replaceFirst('@', '');
    final fallback = Container(
      color: AppColors.primary.withValues(alpha: 0.2),
      alignment: Alignment.center,
      child: Text(
        initial.isEmpty ? '?' : initial[0].toUpperCase(),
        style: AppText.h4.copyWith(color: AppColors.lavenderLight),
      ),
    );
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 72,
                height: 72,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? AppColors.primary : Colors.transparent,
                    width: 2.5,
                  ),
                ),
                child: ClipOval(
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
              if (selected)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            person.displayName,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: AppText.caption.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _ExternalAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _ExternalAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 84,
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color ?? AppColors.card,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppText.caption.copyWith(color: AppColors.textMed),
            ),
          ],
        ),
      ),
    );
  }
}
