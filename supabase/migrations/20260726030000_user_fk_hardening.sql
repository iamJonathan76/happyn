-- =============================================================================
-- HAPPYN — Durcissement des clés étrangères vers auth.users
-- =============================================================================
-- Constat après audit (pg_constraint) :
--
--   events.created_by  -> CASCADE     🔴 dangereux
--   tickets.user_id    -> NO ACTION   🟡 fragile
--
-- Problème 1 (le grave) : `events.created_by` en CASCADE signifie que
-- supprimer un utilisateur DÉTRUIT tous ses événements — y compris les
-- événements passés auxquels des gens ont assisté, et par effet de chaîne
-- leurs billets. Notre fonction `delete_my_account_data()` s'en protège en
-- détachant avant de supprimer, mais toute suppression faite AUTREMENT
-- (dashboard Supabase, script, support) provoquerait une perte de données
-- irréversible pour des tiers.
--
-- La règle doit refléter la politique produit : « événement passé = conservé,
-- organisateur anonymisé ». Donc SET NULL.
--
-- Problème 2 : `tickets.user_id` en NO ACTION bloque la suppression d'un
-- compte si un billet le référence encore. Notre fonction le neutralise, mais
-- SET NULL est cohérent avec la conservation anonymisée des billets passés.
--
-- Les deux colonnes sont nullables, SET NULL est donc applicable.
-- À exécuter dans le SQL Editor du dashboard Supabase.
-- =============================================================================

do $$
declare
  r record;
begin
  for r in
    select c.conname, c.conrelid::regclass::text as tbl, a.attname as col
    from pg_constraint c
    join lateral unnest(c.conkey) as k(attnum) on true
    join pg_attribute a
      on a.attrelid = c.conrelid and a.attnum = k.attnum
    where c.contype = 'f'
      and c.confrelid = 'auth.users'::regclass
      and (
        (c.conrelid = 'public.events'::regclass  and a.attname = 'created_by')
        or (c.conrelid = 'public.tickets'::regclass and a.attname = 'user_id')
      )
  loop
    execute format('alter table %s drop constraint %I', r.tbl, r.conname);
    execute format(
      'alter table %s add constraint %I foreign key (%I) '
      'references auth.users(id) on delete set null',
      r.tbl, r.conname, r.col);
    raise notice 'Contrainte % (%.%) -> ON DELETE SET NULL', r.conname, r.tbl, r.col;
  end loop;
end $$;
