// =============================================================================
// HAPPYN Web — Configuration
// =============================================================================
// Seules des clés PUBLIQUES vivent ici. C'est la même règle que dans l'app :
// la clé publishable/anon est conçue pour être exposée au client, tout le reste
// (service role, secrets Stripe, HMAC) reste dans les secrets Supabase et ne
// doit JAMAIS apparaître dans ce dossier.
//
// Le site est 100 % statique : pas de build, pas de serveur, pas de secret.
// =============================================================================

const HAPPYN = {
  supabaseUrl: 'https://jvjvuozvlzqqmcjanvnh.supabase.co',
  supabaseAnonKey: 'sb_publishable_wkRU0rXDmrPaDyhP2b5Mdw_rkbXBrmO',

  // Adresse de contact réelle, qui reçoit vraiment. À remplacer par une adresse
  // sur le domaine (contact@…) le jour où il est acheté — mais jamais par une
  // adresse qui n'existe pas : un lien de contact mort est pire que pas de lien.
  supportEmail: 'contact@happynevents.com',
  appStoreUrl: null, // null => badge « Bientôt disponible »
  playStoreUrl: null,
};

// ── Accès aux documents légaux ───────────────────────────────────────────────
// On tape directement l'API REST de Supabase (PostgREST) plutôt que d'embarquer
// supabase-js : une seule requête GET suffit, autant éviter une dépendance CDN
// sur les pages que les stores vont auditer.
//
// Colonnes de la table telle qu'elle existe réellement en base : `content` est
// du markdown simplifié (## titres, - puces, paragraphes), pas du JSON.

async function fetchLegalDocuments(slug = null) {
  const params = new URLSearchParams({
    select: 'slug,title,content,version,effective_date,sort_order,updated_at',
    order: 'sort_order.asc',
  });
  if (slug) params.set('slug', `eq.${slug}`);

  const response = await fetch(
    `${HAPPYN.supabaseUrl}/rest/v1/legal_documents?${params}`,
    {
      headers: {
        apikey: HAPPYN.supabaseAnonKey,
        Authorization: `Bearer ${HAPPYN.supabaseAnonKey}`,
      },
    },
  );

  if (!response.ok) {
    throw new Error(`legal_documents: HTTP ${response.status}`);
  }
  return response.json();
}
