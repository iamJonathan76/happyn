import 'package:supabase_flutter/supabase_flutter.dart';

/// Âge (en années révolues) à partir d'une date de naissance.
int? ageFromDob(DateTime? dob) {
  if (dob == null) return null;
  final now = DateTime.now();
  var age = now.year - dob.year;
  if (now.month < dob.month ||
      (now.month == dob.month && now.day < dob.day)) {
    age--;
  }
  return age;
}

/// Date de naissance de l'utilisateur connecté, lue depuis les métadonnées auth
/// (renseignée au signup). Renvoie null si inconnue (comptes anciens).
DateTime? currentUserDob() {
  final raw =
      Supabase.instance.client.auth.currentUser?.userMetadata?['date_of_birth'];
  if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw);
  return null;
}

/// Âge de l'utilisateur connecté (null si date de naissance inconnue).
int? currentUserAge() => ageFromDob(currentUserDob());

/// Âge minimum requis pour organiser / vendre des billets / recevoir des payouts.
const int kMinOrganizerAge = 18;

/// Âge minimum pour avoir un compte HAPPYN : la majorité, depuis le
/// 2026-10-09 (14 ans avant). La règle qui compte est en base
/// (`min_account_age()`, imposée par un déclencheur sur le profil) ; celle-ci
/// sert à refuser plus tôt, avec un message, plutôt qu'à l'erreur du serveur.
const int kMinAccountAge = 18;
