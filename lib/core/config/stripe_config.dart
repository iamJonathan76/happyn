/// Configuration Stripe côté client.
///
/// ⚠️ Seule la clé PUBLIABLE va ici (`pk_test_...` puis `pk_live_...`).
/// La clé SECRÈTE (`sk_...`) ne doit JAMAIS être dans l'app — elle vit
/// uniquement dans les secrets Supabase (Edge Functions).
class StripeConfig {
  // Clé publishable de TEST (publique). En prod, basculer sur pk_live_...
  static const String publishableKey =
      'pk_test_51Tl0WnEDCfJvgZ2B6CJGUb7qLorpchLTyvefE89ReHrvfEymZ3hehRNV69J2RYLH3VPnsAJYwHBNnZfYh7sqvJI600WsYwkrMn';

  static bool get isConfigured =>
      publishableKey.startsWith('pk_') && !publishableKey.contains('REMPLACE');
}
