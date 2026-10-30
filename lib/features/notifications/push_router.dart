import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:happyn/core/config/observability.dart';
import 'package:happyn/core/push/push_service.dart';
import 'package:happyn/features/events/event_detail_screen.dart';
import 'package:happyn/features/events/rate_event_screen.dart';
import 'package:happyn/features/settings/organizer_dashboard_screen.dart';
import 'package:happyn/features/settings/payouts_admin_screen.dart';
import 'package:happyn/features/social/direct_messages_screen.dart';
import 'package:happyn/features/social/post_view_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Ouvre le bon écran au toucher d'une bannière de notification.
///
/// Même logique que la liste de notifs in-app (`NotificationsScreen`), mais
/// déclenchée par la bannière système : on n'a pas de `BuildContext`, on passe
/// par le navigateur racine (`navigatorKey`). Le payload, posé par la fonction
/// Edge `send-push`, ne porte que des chaînes : `type`, `event_id`,
/// `conversation_id`. Le nom de l'expéditeur, lui, EST le titre de la bulle.
Future<void> handlePushTap(RemoteMessage message) async {
  final nav = navigatorKey.currentState;
  if (nav == null) return;

  final data = message.data;
  final type = (data['type'] ?? '').toString();
  final conversationId = (data['conversation_id'] ?? '').toString();
  final eventId = (data['event_id'] ?? '').toString();
  final postId = (data['post_id'] ?? '').toString();
  final title = message.notification?.title ?? '';

  // Un message privé : droit à la conversation. Son titre est le nom de
  // l'expéditeur ; l'avatar se recharge dans l'écran.
  if (conversationId.isNotEmpty) {
    nav.push(MaterialPageRoute(
      builder: (_) => DirectMessageThreadScreen(
        conversationId: conversationId,
        recipientName: title,
        recipientAvatar: '',
      ),
    ));
    return;
  }

  // Versement retenu ou versé : l'écran « Mes revenus ».
  if (type == 'payout_held' || type == 'payout_paid') {
    nav.push(MaterialPageRoute(
        builder: (_) => const OrganizerDashboardScreen()));
    return;
  }

  // Versement à vérifier : la file de l'administrateur.
  if (type == 'payout_review') {
    nav.push(
        MaterialPageRoute(builder: (_) => const PayoutsAdminScreen()));
    return;
  }

  // Un like ou un commentaire : ouvrir le moment concerné. Relu avec les droits
  // de la personne — s'il a disparu, on n'ouvre rien.
  if (postId.isNotEmpty) {
    try {
      final row = await Supabase.instance.client
          .from('feed_posts')
          .select()
          .eq('id', postId)
          .maybeSingle();
      final navNow = navigatorKey.currentState;
      if (row != null && navNow != null) {
        navNow.push(MaterialPageRoute(
            builder: (_) =>
                PostViewScreen(post: Map<String, dynamic>.from(row))));
      }
    } catch (e, st) {
      reportCaught(e, st, where: 'push.openPost');
    }
    return;
  }

  // Tout ce qui porte un événement (annulation, mise à jour, demande de note…).
  // On relit l'événement avec les droits de la personne : s'il a disparu, on
  // n'ouvre rien plutôt que d'échouer.
  if (eventId.isNotEmpty) {
    try {
      final row = await Supabase.instance.client
          .from('events')
          .select()
          .eq('id', eventId)
          .maybeSingle();
      final navNow = navigatorKey.currentState;
      if (row != null && navNow != null) {
        final event = Map<String, dynamic>.from(row);
        navNow.push(MaterialPageRoute(
          builder: (_) => type == 'rate_event'
              ? RateEventScreen(event: event)
              : EventDetailScreen(event: event),
        ));
      }
    } catch (e, st) {
      reportCaught(e, st, where: 'push.openEvent');
    }
  }
}
