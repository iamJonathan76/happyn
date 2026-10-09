/// Lecture des documents légaux stockés en base (`legal_documents`).
///
/// Le texte lui-même n'est plus ici. Une copie écrite à la main y vivait, pour
/// le hors-ligne ; elle avait divergé de la base et aurait affiché, sans
/// connexion, des conditions que plus personne n'acceptait. La copie de
/// secours est désormais `assets/legal/legal-fallback.json`, générée depuis la
/// base par `web/tools/sync-legal-fallback.mjs` — la même que celle du site.
library;

class LegalSection {
  final String? heading;
  final List<String> paragraphs;
  final List<String> bullets;
  const LegalSection({
    this.heading,
    this.paragraphs = const [],
    this.bullets = const [],
  });
}

/// Convertit le markdown léger stocké en base (## titres, - puces, paragraphes
/// séparés par une ligne vide) en sections rendues par LegalPageScreen.
List<LegalSection> parseLegalMarkdown(String md) {
  final sections = <LegalSection>[];
  String? heading;
  var paragraphs = <String>[];
  var bullets = <String>[];

  void flush() {
    if (heading != null || paragraphs.isNotEmpty || bullets.isNotEmpty) {
      sections.add(LegalSection(
        heading: heading,
        paragraphs: List.of(paragraphs),
        bullets: List.of(bullets),
      ));
    }
    heading = null;
    paragraphs = [];
    bullets = [];
  }

  for (final rawLine in md.split('\n')) {
    final line = rawLine.trimRight();
    if (line.trim().isEmpty) {
      // Ligne vide = fin d'un bloc de paragraphes (mais on garde le heading en
      // cours tant qu'aucun nouveau titre n'apparaît).
      if (bullets.isEmpty && heading == null && paragraphs.isNotEmpty) flush();
      continue;
    }
    if (line.startsWith('## ')) {
      flush();
      heading = line.substring(3).trim();
    } else if (line.startsWith('- ')) {
      bullets.add(line.substring(2).trim());
    } else {
      paragraphs.add(line.trim());
    }
  }
  flush();
  return sections;
}
