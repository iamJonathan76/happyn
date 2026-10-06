/// Regles de saisie d'une adresse e-mail, cote app.
///
/// Elles ne remplacent pas la verification par courriel — seule l'arrivee du
/// message prouve qu'une adresse existe. Elles servent a arreter les fautes
/// qu'on peut voir sans rien envoyer, et c'est important ici : un changement
/// d'adresse mal tape n'echoue pas, il part vers une boite que personne ne
/// relevera. L'utilisateur garde alors son ancienne adresse sans comprendre
/// pourquoi, ou se retrouve avec un changement en attente indefiniment.
///
/// Volontairement permissif sur le domaine : il existe des adresses valides
/// qui ne ressemblent a rien (`.museum`, nouveaux TLD, sous-domaines). Un
/// filtre trop zele refuse de vraies adresses, et c'est pire qu'un filtre
/// trop large, puisque la verification par courriel suit de toute facon.
library;

/// Ce qui empeche un changement d'adresse d'aboutir.
enum EmailProblem {
  /// Rien n'a ete tape.
  empty,

  /// Ne ressemble pas a une adresse (pas de « @ », pas de point apres, …).
  malformed,

  /// C'est deja l'adresse du compte — il n'y a rien a changer.
  unchanged,

  /// La confirmation ne correspond pas a la premiere saisie.
  mismatch,
}

/// Exigences minimales : une partie locale, un « @ », un domaine avec au
/// moins un point et deux lettres apres le dernier. Pas d'espace, pas de
/// second « @ », pas de point double ni en bord de domaine.
///
/// Les majuscules sont exclues partout, pas par pruderie : c'est ce qui rend
/// verifiable la precondition de [emailLooksValid]. Sans cela, un appel sur la
/// saisie brute passerait les tests et echouerait en vrai, la comparaison avec
/// l'adresse actuelle se faisant, elle, sur la forme normalisee.
final emailPattern =
    RegExp(r'^[^@\sA-Z]+@[^@\s.A-Z]+(\.[^@\s.A-Z]+)*\.[a-z]{2,}$');

/// L'adresse ramenee a la forme comparable et stockee : sans espaces autour,
/// en minuscules.
///
/// On normalise au lieu de refuser : taper « Jonathan@Gmail.COM » est une
/// intention parfaitement claire, et les claviers mobiles mettent une
/// majuscule au premier caractere sans qu'on le demande. Un espace de fin
/// vient du copier-coller, jamais d'une volonte.
///
/// La casse de la partie locale est theoriquement significative (RFC 5321),
/// mais aucun fournisseur courant ne la distingue, et Supabase stocke les
/// adresses en minuscules : comparer autrement ferait croire a un changement
/// la ou il n'y en a pas.
String normalizeEmail(String raw) => raw.trim().toLowerCase();

/// Vrai si l'adresse a la forme d'une adresse. Attend une valeur deja passee
/// par [normalizeEmail].
bool emailLooksValid(String e) => emailPattern.hasMatch(e);

/// Ce qui bloque le changement de [current] vers [next], ou `null` si rien.
///
/// [confirm] est la seconde saisie. La demander n'est pas une politesse : le
/// lien de confirmation part vers [next], donc une faute de frappe rend le
/// changement invisible — aucun message d'erreur, juste un courriel qui
/// n'arrive jamais. Deux saisies identiques sont la seule verification
/// possible avant l'envoi.
EmailProblem? emailChangeProblem({
  required String current,
  required String next,
  required String confirm,
}) {
  final a = normalizeEmail(next);
  if (a.isEmpty) return EmailProblem.empty;
  if (!emailLooksValid(a)) return EmailProblem.malformed;
  if (a == normalizeEmail(current)) return EmailProblem.unchanged;
  if (a != normalizeEmail(confirm)) return EmailProblem.mismatch;
  return null;
}
