/// Affichage des lieux, au même format partout dans l'app.
///
/// Une seule définition : la liste, l'accueil et la fiche d'un événement
/// écrivaient chacun la ville et l'adresse à leur façon, et la fiche finissait
/// par montrer une rue sans sa ville.
library;

/// « ottawa » → « Ottawa », « saint-jean-sur-richelieu » → « Saint-Jean-Sur-Richelieu ».
/// À l'affichage seulement : la donnée reste telle que l'organisateur l'a saisie.
String displayCity(String? city) {
  final t = (city ?? '').trim();
  if (t.isEmpty) return '';
  // Une ville déjà écrite avec des majuscules est laissée telle quelle :
  // « Saint-Jean-sur-Richelieu » ne doit pas devenir « …-Sur-… ».
  if (t != t.toLowerCase()) return t;
  return t.replaceAllMapped(
    RegExp(r"(^|[\s\-'])(\p{L})", unicode: true),
    (m) => '${m[1]}${m[2]!.toUpperCase()}',
  );
}

const _provinces = {
  'ontario': 'ON',
  'quebec': 'QC',
  'québec': 'QC',
  'british columbia': 'BC',
  'colombie-britannique': 'BC',
  'alberta': 'AB',
  'manitoba': 'MB',
  'saskatchewan': 'SK',
  'nova scotia': 'NS',
  'nouvelle-écosse': 'NS',
  'new brunswick': 'NB',
  'nouveau-brunswick': 'NB',
  'newfoundland and labrador': 'NL',
  'terre-neuve-et-labrador': 'NL',
  'prince edward island': 'PE',
  'île-du-prince-édouard': 'PE',
  'yukon': 'YT',
  'northwest territories': 'NT',
  'territoires du nord-ouest': 'NT',
  'nunavut': 'NU',
};

/// Première lettre du code postal → province (X couvre deux territoires :
/// on ne devine pas).
const _provinceFromPostal = {
  'A': 'NL', 'B': 'NS', 'C': 'PE', 'E': 'NB', 'G': 'QC', 'H': 'QC', 'J': 'QC',
  'K': 'ON', 'L': 'ON', 'M': 'ON', 'N': 'ON', 'P': 'ON', 'R': 'MB', 'S': 'SK',
  'T': 'AB', 'V': 'BC', 'Y': 'YT',
};

/// « Québec » → « QC », comme Postes Canada l'écrit. Inconnue : rendue telle quelle.
String provinceCode(String? province) {
  final t = (province ?? '').trim();
  if (t.isEmpty) return '';
  if (t.length == 2) return t.toUpperCase();
  return _provinces[t.toLowerCase()] ?? t;
}

/// « j8x2k1 » → « J8X 2K1 ». Un code qui n'a pas la forme canadienne est
/// rendu tel quel, en majuscules.
String postalCode(String? code) {
  final t = (code ?? '').replaceAll(' ', '').toUpperCase();
  if (RegExp(r'^[A-Z]\d[A-Z]\d[A-Z]\d$').hasMatch(t)) {
    return '${t.substring(0, 3)} ${t.substring(3)}';
  }
  return t;
}

/// La dernière ligne d'une adresse canadienne : « Gatineau, QC  J8X 2K1 ».
/// Chaque morceau est facultatif ; les absents disparaissent avec leur
/// séparateur.
String cityLine({String? city, String? province, String? postal}) {
  final c = displayCity(city);
  final z = postalCode(postal);
  // Des événements anciens n'ont pas de province enregistrée. La première
  // lettre d'un code postal canadien la donne sans ambiguïté.
  var p = provinceCode(province);
  if (p.isEmpty && z.isNotEmpty) p = _provinceFromPostal[z[0]] ?? '';
  final head = [c, p].where((s) => s.isNotEmpty).join(', ');
  return [head, z].where((s) => s.isNotEmpty).join('  ');
}
