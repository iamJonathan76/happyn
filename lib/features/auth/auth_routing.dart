import 'dart:async';

import 'package:flutter/material.dart';
import 'package:happyn/core/config/observability.dart';
import 'package:happyn/core/push/push_service.dart';
import 'package:happyn/features/auth/birth_date_screen.dart';
import 'package:happyn/features/auth/complete_profile_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Où aller une fois la session ouverte, quelle que soit la porte d'entrée
/// (Apple, Google, e-mail) : le profil à compléter s'il ne l'est pas, sinon
/// l'accueil de l'app.
///
/// Dans les deux cas la pile est vidée : l'accueil, le choix de connexion et
/// le formulaire restaient dessous, et le retour Android y ramenait une
/// personne déjà connectée.
Future<void> routeAfterAuth(BuildContext context) async {
  // Avant tout le reste : sans date de naissance, aucune règle d'âge ne
  // s'applique. Cas de toute inscription par Google.
  if (BirthDateScreen.isMissing()) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
          builder: (_) => const BirthDateScreen(onDone: routeAfterAuth)),
      (_) => false,
    );
    return;
  }
  final user = Supabase.instance.client.auth.currentUser;
  bool onboarded = true;
  if (user != null) {
    try {
      final row = await Supabase.instance.client
          .from('profiles')
          .select('onboarded')
          .eq('id', user.id)
          .maybeSingle();
      onboarded = (row?['onboarded'] ?? false) as bool;
    } catch (e, st) {
      // Lecture impossible : on laisse entrer plutot que de bloquer la
      // connexion. Au pire, l'onboarding est saute cette fois-ci.
      reportCaught(e, st, where: 'login.routeAfterAuth');
    }
  }
  if (!context.mounted) return;
  if (onboarded) {
    // Apres la connexion, pas au premier lancement : demander la permission
    // avant que la personne sache ce qu'est l'app la fait refuser, et un
    // refus Android est definitif jusqu'aux reglages systeme.
    unawaited(PushService.registerForUser());
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
  } else {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const CompleteProfileScreen()),
      (_) => false,
    );
  }
}
