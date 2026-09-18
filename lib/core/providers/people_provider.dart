import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Ce qu'on montre d'une personne dans une liste : jamais plus que les champs
/// publics. L'e-mail n'est pas dans les fonctions qui remplissent ce modele,
/// il ne peut donc pas y arriver par erreur.
class PersonSummary {
  final String id;
  final String fullName;
  final String username;
  final String? avatarUrl;

  const PersonSummary({
    required this.id,
    required this.fullName,
    required this.username,
    this.avatarUrl,
  });

  factory PersonSummary.fromRow(Map<String, dynamic> r) => PersonSummary(
        id: r['id'] as String,
        fullName: ((r['full_name'] as String?) ?? '').trim(),
        username: (r['username'] as String?) ?? '',
        avatarUrl: r['avatar_url'] as String?,
      );

  /// Le nom, ou l'identifiant quand le nom est vide : une ligne sans rien
  /// d'ecrit ne se distingue pas d'une erreur.
  String get displayName => fullName.isNotEmpty ? fullName : '@$username';
}

/// Resultat de la verification d'un identifiant pendant la saisie.
///
/// `checking` : une verification est en route. L'ecran ne doit pas laisser
/// enregistrer pendant ce temps — le dernier statut connu porte sur un
/// texte qui n'est plus celui du champ.
enum UsernameStatus { ok, invalid, reserved, taken, unknown, checking }

/// Meme regle que la contrainte `username_format` en base. Verifiee ici pour
/// repondre sans aller-retour quand le format est manifestement faux ; la base
/// reste celle qui tranche.
final usernamePattern = RegExp(r'^[a-z0-9._]{3,20}$');

bool usernameLooksValid(String u) =>
    usernamePattern.hasMatch(u) &&
    !u.startsWith('.') &&
    !u.endsWith('.') &&
    !u.contains('..');

/// Ce que l'utilisateur tape, ramene a la forme stockee : minuscules, sans
/// « @ » de tete ni espaces. On normalise plutot que de refuser — taper
/// « @Jonathan » est une intention parfaitement claire.
String normalizeUsername(String raw) =>
    raw.trim().toLowerCase().replaceFirst(RegExp(r'^@+'), '');

/// Proposition d'identifiant a partir du nom, pour pre-remplir le champ. La
/// base fait la meme chose si on la laisse vide ; ici c'est pour que la
/// personne voie tout de suite ce qu'elle obtiendra, et puisse le changer.
String suggestUsername(String? fullName) {
  const from = 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿœæ';
  const to = 'aaaaaaceeeeiiiinooooouuuuyyoa';
  var s = (fullName ?? '').toLowerCase();
  for (var i = 0; i < from.length; i++) {
    s = s.replaceAll(from[i], to[i]);
  }
  s = s.replaceAll(RegExp(r'[^a-z0-9]+'), '');
  return s.length > 15 ? s.substring(0, 15) : s;
}

Future<UsernameStatus> checkUsername(String raw) async {
  final u = normalizeUsername(raw);
  if (!usernameLooksValid(u)) return UsernameStatus.invalid;
  try {
    final res = await Supabase.instance.client
        .rpc('username_status', params: {'p': u});
    return switch (res) {
      'ok' => UsernameStatus.ok,
      'reserved' => UsernameStatus.reserved,
      'taken' => UsernameStatus.taken,
      _ => UsernameStatus.invalid,
    };
  } catch (_) {
    // Reseau coupe : on ne pretend pas savoir. L'enregistrement tranchera.
    return UsernameStatus.unknown;
  }
}

/// Traduit l'echec d'un enregistrement de profil en statut d'identifiant.
/// L'index unique peut refuser un nom juge libre une seconde plus tot : deux
/// personnes peuvent viser le meme au meme moment.
UsernameStatus? usernameErrorFrom(Object e) {
  final msg = e.toString();
  if (msg.contains('username_reserved')) return UsernameStatus.reserved;
  // Le nom de l'index, pas le seul code 23505 : une autre contrainte d'unicite
  // violee ne doit pas s'afficher « identifiant deja pris ».
  if (msg.contains('profiles_username_key')) return UsernameStatus.taken;
  if (msg.contains('username_format')) return UsernameStatus.invalid;
  return null;
}

/// Recherche de personnes. `autoDispose` : les resultats d'une frappe n'ont
/// aucune raison de survivre a l'ecran.
final searchPeopleProvider = FutureProvider.autoDispose
    .family<List<PersonSummary>, String>((ref, query) async {
  final q = normalizeUsername(query);
  // Meme seuil qu'en base. En dessous, la requete renverrait une liste vide :
  // autant ne pas la faire.
  if (q.length < 2) return const [];
  final data = await Supabase.instance.client
      .rpc('search_profiles', params: {'q': q});
  return List<Map<String, dynamic>>.from(data as List)
      .map(PersonSummary.fromRow)
      .toList();
});

enum FollowListKind { followers, following }

/// Abonnes ou abonnements d'une personne.
final followListProvider = FutureProvider.autoDispose
    .family<List<PersonSummary>, (String, FollowListKind)>((ref, args) async {
  final (userId, kind) = args;
  final data = await Supabase.instance.client.rpc('profile_follows', params: {
    'p_user': userId,
    'p_kind': kind == FollowListKind.followers ? 'followers' : 'following',
  });
  return List<Map<String, dynamic>>.from(data as List)
      .map(PersonSummary.fromRow)
      .toList();
});
