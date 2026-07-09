import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:happyn/core/providers/notifications_provider.dart';
import 'package:happyn/features/events/event_detail_screen.dart';

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
    } catch (_) {}
  }

  Future<void> _markRead(WidgetRef ref, String id) async {
    try {
      await Supabase.instance.client
          .from('notifications')
          .update({'read': true}).eq('id', id);
      ref.invalidate(notificationsProvider);
    } catch (_) {}
  }

  Future<void> _openEvent(BuildContext context, String eventId) async {
    try {
      final row = await Supabase.instance.client
          .from('events')
          .select()
          .eq('id', eventId)
          .maybeSingle();
      if (row != null && context.mounted) {
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) =>
                EventDetailScreen(event: Map<String, dynamic>.from(row))));
      }
    } catch (_) {}
  }

  (IconData, Color) _visual(String type) {
    switch (type) {
      case 'event_cancelled':
        return (Icons.cancel, const Color(0xFFFF4B4B));
      case 'event_updated':
        return (Icons.edit_calendar, const Color(0xFFFBBF24));
      default:
        return (Icons.notifications, const Color(0xFFA78BFA));
    }
  }

  String _ago(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return 'now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    if (d.inDays < 7) return '${d.inDays}d';
    return '${(d.inDays / 7).floor()}w';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsProvider);
    final unread = ref.watch(unreadCountProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF08080F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF08080F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Notifications',
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: () => _markAllRead(ref),
              child: Text(
                'Mark all read',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFA78BFA),
                ),
              ),
            ),
        ],
      ),
      body: async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: Color(0xFF7C3AED))),
        error: (_, __) => _empty(),
        data: (list) {
          if (list.isEmpty) return _empty();
          return RefreshIndicator(
            color: const Color(0xFF7C3AED),
            backgroundColor: const Color(0xFF1A1535),
            onRefresh: () async {
              ref.invalidate(notificationsProvider);
              await ref.read(notificationsProvider.future);
            },
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
              itemCount: list.length,
              itemBuilder: (context, i) =>
                  _tile(context, ref, list[i]),
            ),
          );
        },
      ),
    );
  }

  Widget _tile(
      BuildContext context, WidgetRef ref, Map<String, dynamic> n) {
    final type = (n['type'] ?? '') as String;
    final (icon, color) = _visual(type);
    final unread = n['read'] == false;
    final eventId = n['event_id'] as String?;

    return GestureDetector(
      onTap: () {
        if (unread) _markRead(ref, n['id'] as String);
        if (eventId != null) _openEvent(context, eventId);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: unread
              ? LinearGradient(
                  colors: [
                    color.withOpacity(0.12),
                    color.withOpacity(0.04),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: unread ? null : Colors.white.withOpacity(0.035),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: unread
                ? color.withOpacity(0.35)
                : Colors.white.withOpacity(0.06),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withOpacity(0.16),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
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
                          style: GoogleFonts.poppins(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Text(
                        _ago(n['created_at'] as String?),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: Colors.white.withOpacity(0.4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    (n['body'] ?? '') as String,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      height: 1.45,
                      color: Colors.white.withOpacity(0.62),
                    ),
                  ),
                  if (eventId != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          'View event',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                        Icon(Icons.chevron_right, size: 14, color: color),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (unread) ...[
              const SizedBox(width: 6),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _empty() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.notifications_none,
                  size: 42, color: Colors.white.withOpacity(0.25)),
            ),
            const SizedBox(height: 18),
            Text(
              "You're all caught up",
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Cancellations and event changes will show up here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.white.withOpacity(0.3),
              ),
            ),
          ],
        ),
      );
}
