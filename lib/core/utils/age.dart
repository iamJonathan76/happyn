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

/// Âge minimum pour créer un compte HAPPYN (Loi 25 : dodge le consentement
/// parental requis pour les moins de 14 ans au Québec).
const int kMinAccountAge = 14;
