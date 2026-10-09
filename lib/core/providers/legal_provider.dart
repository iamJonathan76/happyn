import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Liste des documents légaux (Terms, Privacy, …) depuis la table
/// `legal_documents`, triés par `sort_order`, chacun avec ses traductions sous
/// `translations` (`{'fr': {...}}`). Source de vérité pour la section Legal du
/// Settings et pour LegalPageScreen. Éditable côté DB sans update app.
///
/// L'affichage choisit la langue avec [localizedLegalDoc].
final legalDocsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = Supabase.instance.client;
  final docs = await client
      .from('legal_documents')
      .select()
      .order('sort_order', ascending: true);
  List<dynamic> translations = const [];
  try {
    translations = await client.from('legal_document_translations').select();
  } catch (_) {
    // Sans traductions, on affiche l'anglais — jamais rien du tout.
  }
  return _withTranslations(
      List<Map<String, dynamic>>.from(docs), translations);
});

/// La copie embarquée des mêmes documents, pour le hors-ligne.
///
/// Générée depuis la base (`web/tools/sync-legal-fallback.mjs`), jamais éditée
/// à la main : hors connexion, on doit lire le texte que les gens ont accepté,
/// pas une version qui a dérivé.
final legalFallbackProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final raw = await rootBundle.loadString('assets/legal/legal-fallback.json');
  List<dynamic> translations = const [];
  try {
    translations = jsonDecode(await rootBundle
        .loadString('assets/legal/legal-translations.json')) as List;
  } catch (_) {}
  return _withTranslations(
      List<Map<String, dynamic>>.from(jsonDecode(raw) as List), translations);
});

List<Map<String, dynamic>> _withTranslations(
    List<Map<String, dynamic>> docs, List<dynamic> translations) {
  final bySlug = <String, Map<String, dynamic>>{};
  for (final t in translations.cast<Map<String, dynamic>>()) {
    (bySlug[t['slug'] as String] ??= {})[t['locale'] as String] = t;
  }
  return [
    for (final d in docs) {...d, 'translations': bySlug[d['slug']] ?? const {}},
  ];
}

/// Le document dans la langue [lang] si sa traduction porte LA MÊME version
/// que l'original, sinon l'original anglais.
///
/// Une traduction en retard sur l'anglais n'est pas une traduction : c'est un
/// autre texte. L'afficher ferait lire — et accepter — des conditions qui ne
/// sont plus en vigueur.
Map<String, dynamic> localizedLegalDoc(Map<String, dynamic> doc, String lang) {
  final t = (doc['translations'] as Map?)?[lang] as Map?;
  if (t == null || t['version'] != doc['version']) return doc;
  return {...doc, 'title': t['title'], 'content': t['content']};
}
