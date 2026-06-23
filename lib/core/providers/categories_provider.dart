import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Catégories officielles, chargées depuis la table `categories`.
/// Source unique pour le dropdown de Create Event et les filtres Home/Discover.
final categoriesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final data = await Supabase.instance.client
      .from('categories')
      .select()
      .eq('is_active', true)
      .order('sort_order');
  return List<Map<String, dynamic>>.from(data);
});

/// Juste les noms des catégories (pratique pour les menus/filtres).
final categoryNamesProvider = Provider<List<String>>((ref) {
  final async = ref.watch(categoriesProvider);
  return async.maybeWhen(
    data: (cats) => cats.map((c) => c['name'] as String).toList(),
    orElse: () => const <String>[],
  );
});
