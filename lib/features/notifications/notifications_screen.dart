import 'package:flutter/material.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/features/events/rate_event_screen.dart';
import 'package:happyn/features/settings/payouts_admin_screen.dart';
import 'package:happyn/features/settings/organizer_dashboard_screen.dart';
import 'package:happyn/core/config/observability.dart';
import 'package:happyn/core/widgets/app_form.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:happyn/core/providers/notifications_provider.dart';
import 'package:happyn/features/events/event_detail_screen.dart';
import 'package:happyn/features/social/direct_messages_screen.dart';
import 'package:happyn/features/social/post_view_screen.dart';
import 'package:happyn/l10n/app_localizations.dart';

/// Notifications effacées d'un glissement, retirées de la liste AVANT la
/// réponse du serveur : un `Dismissible` exige que l'élément disparaisse tout
/// de suite, sinon Flutter s'arrête sur une erreur.
final _dismissedNotificationsProvider =
    StateProvider.autoDispose<Set<String>>((ref) => <String>{});

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  Future<void> _markAllRead(WidgetRef ref) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      await Supabase.instance.client
          .from('notifications')
          .update({'read': true})
          .eq('user_id', user.id)
          .eq('read', false);
      ref.invalidate(notificationsProvider);
    } catch (e, st) {
      reportCaught(e, st, where: 'notifications.markAllRead');
    }
  }

  Future<void> _markRead(WidgetRef ref, String id) async {
    try {
      await Supabase.instance.client
          .from('notifications')
          .update({'read': true}).eq('id', id);
      ref.invalidate(notificationsProvider);
    } catch (e, st) {
      reportCaught(e, st, where: 'notifications.markRead');
    }
  }

  /// `rate` : la demande de note ouvre directement l'écran de notation.
  Future<void> _openEvent(BuildContext context, String eventId,
      {bool rate = false}) async {
    try {
      final row = await Supabase.instance.client
          .from('events')
          .select()
          .eq('id', eventId)
          .maybeSingle();
      if (row != null && context.mounted) {
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => rate
                ? RateEventScreen(event: Map<String, dynamic>.from(row))
                : EventDetailScreen(event: Map<String, dynamic>.from(row))));
      }
    } catch (e, st) {
      // Sans message, le tap semblait simplement ne rien faire.
      reportCaught(e, st, where: 'notifications.openEvent');
      if (context.mounted) {
        showAppSnack(context, AppLocalizations.of(context).couldNotOpenEvent);
      }
    }
  }

  /// La publication commentée, lue avec les droits de la personne : si elle a
  /// été retirée entre-temps, on le dit plutôt qu'un tap sans effet.
  Future<void> _openPost(BuildContext context, String postId) async {
    try {
      final row = await Supabase.instance.client
          .from('feed_posts')
          .select()
          .eq('id', postId)
          .maybeSingle();
      if (!context.mounted) return;
      if (row == null) {
        showAppSnack(
            context, AppLocalizations.of(context).sharedContentUnavailable);
        return;
      }
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              PostViewScreen(post: Map<String, dynamic>.from(row))));
    } catch (e, st) {
      reportCaught(e, st, where: 'notifications.openPost');
      if (context.mounted) {
        showAppSnack(context, AppLocalizations.of(context).couldNotOpenPost);
      }
    }
  }

  (IconData, Color) _visual(String type) {
    switch (type) {
      case 'ticket_confirmed':
        return (Icons.confirmation_number, AppColors.green);
      case 'ticket_received':
        return (Icons.card_giftcard, AppColors.green);
      case 'event_cancelled':
        return (Icons.cancel, AppColors.error);
      case 'event_updated':
        return (Icons.edit_calendar, AppColors.amber);
      case 'direct_message':
        return (Icons.chat_bubble, AppColors.lavender);
      case 'post_comment':
        return (Icons.mode_comment, AppColors.pink);
      case 'post_like':
        return (Icons.favorite, AppColors.pink);
      case 'rate_event':
        return (Icons.star_rounded, AppColors.amber);
      case 'payout_review':
        return (Icons.payments_outlined, AppColors.warning);
      case 'payout_held':
        return (Icons.schedule, AppColors.warning);
      case 'payout_paid':
        return (Icons.payments, AppColors.green);
      default:
        return (Icons.notifications, AppColors.lavender);
    }
  }

  String _ago(String? iso, AppLocalizations l) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return l.timeNow;
    if (d.inMinutes < 60) return l.timeMinutesShort(d.inMinutes);
    if (d.inHours < 24) return l.timeHoursShort(d.inHours);
    if (d.inDays < 7) return l.timeDaysShort(d.inDays);
    return l.timeWeeksShort((d.inDays / 7).floor());
  }

  /// La période d'une notification. La liste arrive triée du plus récent au plus
  /// ancien, donc les sections sortent dans l'ordre.
  String _group(String? iso, AppLocalizations l) {
    final dt = DateTime.tryParse(iso ?? '')?.toLocal();
    if (dt == null) return l.notifEarlier;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(day).inDays;
    if (diff <= 0) return l.notifToday;
    if (diff == 1) return l.notifYesterday;
    if (diff < 7) return l.notifThisWeek;
    return l.notifEarlier;
  }

  Widget _groupHeader(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 0, 6),
        child: Text(
          label,
          style: AppText.micro.copyWith(
              color: AppColors.textMuted,
              letterSpacing: 0.3,
              fontWeight: FontWeight.w600),
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(notificationsProvider);
    final unread = ref.watch(unreadCountProvider);

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
        title: Text(
          l.notificationsTitle,
          style: AppText.h2.copyWith(color: Colors.white),
        ),
        actions: [
          // Une liste qu'on ne peut que voir grossir finit ignorée en entier.
          if ((async.asData?.value ?? const []).isNotEmpty)
            IconButton(
              tooltip: l.clearAllNotifications,
              onPressed: () => _confirmClearAll(context, ref),
              icon: const Icon(Icons.delete_sweep_outlined,
                  color: AppColors.lavender, size: 22),
            ),
          if (unread > 0)
            TextButton(
              onPressed: () => _markAllRead(ref),
              child: Text(
                l.markAllRead,
                style: AppText.captionBold.copyWith(fontSize: 12.5, color: AppColors.lavender),
              ),
            ),
        ],
      ),
      body: async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
        error: (_, _) => _empty(l),
        data: (all) {
          final dismissed = ref.watch(_dismissedNotificationsProvider);
          final list =
              all.where((n) => !dismissed.contains(n['id'])).toList();
          if (list.isEmpty) return _empty(l);
          // Entrelacer des en-têtes de période. Un String = en-tête, une Map =
          // une notification.
          final items = <dynamic>[];
          String? currentGroup;
          for (final n in list) {
            final g = _group(n['created_at'] as String?, l);
            if (g != currentGroup) {
              items.add(g);
              currentGroup = g;
            }
            items.add(n);
          }
          return RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.card,
            onRefresh: () async {
              ref.invalidate(notificationsProvider);
              await ref.read(notificationsProvider.future);
            },
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final item = items[i];
                if (item is String) return _groupHeader(item);
                final n = item as Map<String, dynamic>;
                final id = n['id'] as String;
                return Dismissible(
                  key: ValueKey(id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.delete_outline,
                        color: Colors.white),
                  ),
                  onDismissed: (_) {
                    ref.read(_dismissedNotificationsProvider.notifier).state =
                        {...dismissed, id};
                    deleteNotifications(ref, id: id).catchError((e, st) {
                      reportCaught(e, st, where: 'notifications.delete');
                    });
                  },
                  child: _tile(context, ref, n),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmClearAll(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l.clearAllNotificationsTitle,
            style: AppText.h4.copyWith(color: Colors.white)),
        content: Text(l.clearAllNotificationsBody, style: AppText.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.cancel, style: AppText.body),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.clearAllNotifications,
                style: AppText.smallBold.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await deleteNotifications(ref);
    } catch (e, st) {
      reportCaught(e, st, where: 'notifications.clearAll');
      if (context.mounted) {
        showAppSnack(context, l.couldNotSaveRetry);
      }
    }
  }

  Widget _tile(
      BuildContext context, WidgetRef ref, Map<String, dynamic> n) {
    final l = AppLocalizations.of(context);
    final type = (n['type'] ?? '') as String;
    final (icon, color) = _visual(type);
    final unread = n['read'] == false;
    final eventId = n['event_id'] as String?;
    final conversationId = n['conversation_id'] as String?;
    final postId = n['post_id'] as String?;

    return GestureDetector(
      onTap: () {
        if (unread) _markRead(ref, n['id'] as String);
        // La conversation d'abord : une notification de message n'a pas
        // d'événement, et la laisser inerte serait pire que de ne rien
        // notifier du tout.
        if (conversationId != null) {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => DirectMessageThreadScreen(
              conversationId: conversationId,
              // Le titre de la notification EST le nom de l'expéditeur.
              // L'avatar, lui, se recharge dans l'écran.
              recipientName: (n['title'] ?? '') as String,
              recipientAvatar: '',
            ),
          ));
        } else if (type == 'payout_review') {
          Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const PayoutsAdminScreen()));
        } else if (type == 'payout_held' || type == 'payout_paid') {
          // Les deux mènent l'organisateur à « Mes revenus » : c'est là qu'il
          // voit l'état du versement et le compte à rebours de la retenue.
          Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const OrganizerDashboardScreen()));
        } else if (type == 'rate_event' && eventId != null) {
          _openEvent(context, eventId, rate: true);
        } else if (postId != null) {
          _openPost(context, postId);
        } else if (eventId != null) {
          _openEvent(context, eventId);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
        decoration: BoxDecoration(
          // Non-lu : un léger voile, pas tout un cadre. Lu : rien, pour que la
          // liste respire.
          color: unread
              ? AppColors.lavender.withValues(alpha: 0.07)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _avatar(type, (n['title'] ?? '') as String, icon, color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          (n['title'] ?? '') as String,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _ago(n['created_at'] as String?, l),
                        style: AppText.micro,
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    (n['body'] ?? '') as String,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption
                        .copyWith(height: 1.4, color: AppColors.textSecondary),
                  ),
                  if (type == 'rate_event' && eventId != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(l.rateAction,
                          style: AppText.smallBold
                              .copyWith(color: AppColors.lavenderLight)),
                    ),
                  ],
                ],
              ),
            ),
            if (unread) ...[
              const SizedBox(width: 8),
              Container(
                margin: const EdgeInsets.only(top: 6),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.pink,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Pour une notif sociale (commentaire, like) : une pastille d'initiales,
  /// comme un avatar, surmontée du petit badge du type. Pour le reste (billet,
  /// versement, événement) : un rond coloré portant l'icône du type.
  Widget _avatar(String type, String title, IconData icon, Color color) {
    final isActor = type == 'post_comment' || type == 'post_like';
    if (!isActor) {
      return Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 21),
      );
    }
    return SizedBox(
      width: 46,
      height: 46,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFF2A2150),
              shape: BoxShape.circle,
            ),
            child: Text(
              _initials(title),
              style: AppText.smallBold
                  .copyWith(color: AppColors.lavenderLight, fontSize: 15),
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.background, width: 2),
              ),
              child: Icon(icon, size: 10, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  Widget _empty(AppLocalizations l) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.notifications_none,
                  size: 42, color: AppColors.textFaint),
            ),
            const SizedBox(height: 18),
            Text(
              l.allCaughtUp,
              style: AppText.h3.copyWith(color: AppColors.textMed),
            ),
            const SizedBox(height: 6),
            Text(
              l.notifEmptyBody,
              textAlign: TextAlign.center,
              style: AppText.caption.copyWith(color: AppColors.textLow),
            ),
          ],
        ),
      );
}
