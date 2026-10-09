import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Liste des documents légaux (Terms, Privacy, …) depuis la table
/// `legal_documents`, triés par `sort_order`. Source de vérité pour la section
/// Legal du Settings et pour LegalPageScreen. Éditable côté DB sans update app.
final legalDocsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final data = await Supabase.instance.client
      .from('legal_documents')
      .select()
      .order('sort_order', ascending: true);
  return List<Map<String, dynamic>>.from(data);
});

/// La copie embarquée des mêmes documents, pour le hors-ligne.
///
/// Générée depuis la base (`web/tools/sync-legal-fallback.mjs`), jamais éditée
/// à la main : hors connexion, on doit lire le texte que les gens ont accepté,
/// pas une version qui a dérivé.
final legalFallbackProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final raw = await rootBundle.loadString('assets/legal/legal-fallback.json');
  return List<Map<String, dynamic>>.from(jsonDecode(raw) as List);
});
