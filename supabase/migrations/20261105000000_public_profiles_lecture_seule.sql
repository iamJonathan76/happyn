-- public_profiles : vue de LECTURE seule, retirer les droits d'ecriture.
--
-- La vue n'expose que les colonnes publiques de `profiles` (nom, photo, ville,
-- bio, identifiant). Elle est SECURITY DEFINER par conception : c'est le seul
-- moyen de projeter des colonnes, ce que la RLS (ligne entiere ou rien) ne sait
-- pas faire. Lire n'importe quelle ligne via cette vue est donc voulu.
--
-- Mais Supabase attache par defaut a toute vue le jeu complet de droits
-- (INSERT/UPDATE/DELETE/TRUNCATE) pour anon ET authenticated. Sur une vue
-- definer AUTO-MODIFIABLE comme celle-ci, ces droits ECRIVENT dans `profiles`
-- en contournant sa RLS, parce que le proprietaire de la vue (postgres) n'est
-- pas soumis a la RLS non-FORCE de la table. Consequences demontrees sur
-- Postgres :
--   - tout compte connecte reecrivait le profil de n'importe qui (nom, bio…) ;
--   - anon reecrivait la bio de TOUS les profils d'un UPDATE sans WHERE
--     (un UPDATE sans WHERE ne demande pas le SELECT qu'on avait retire).
--
-- La vue n'a besoin que d'etre LUE. On retire tout droit d'ecriture ; seul
-- `authenticated` garde SELECT (anon l'avait deja perdu au durcissement
-- precedent). Le correctif ne touche pas a la nature definer de la vue : la
-- lecture inter-comptes, elle, reste voulue.

revoke insert, update, delete, truncate, references, trigger
  on public.public_profiles from anon;
revoke insert, update, delete, truncate, references, trigger
  on public.public_profiles from authenticated;
revoke all on public.public_profiles from public, service_role;

grant select on public.public_profiles to authenticated;
