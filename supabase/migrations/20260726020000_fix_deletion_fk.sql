-- =============================================================================
-- HAPPYN — Correctif : la suppression de compte échouait sur une clé étrangère
-- =============================================================================
-- Symptôme : `auth.admin.deleteUser()` renvoyait « Database error deleting user »
-- alors que toutes les données métier avaient bien été détachées.
--
-- Cause : la colonne `tickets.transferred_from` (ajoutée par la migration du
-- transfert de billet) référençait `auth.users(id)` SANS clause `on delete`.
-- Postgres applique alors NO ACTION, ce qui bloque la suppression du compte
-- dès qu'un billet garde la trace de cet utilisateur comme expéditeur.
--
-- Deux correctifs, volontairement redondants :
--   1. la contrainte passe en ON DELETE SET NULL (la trace du transfert n'a
--      aucune raison d'empêcher un effacement de compte) ;
--   2. `delete_my_account_data()` détache explicitement la colonne, pour ne
--      pas dépendre de la contrainte.
-- À exécuter dans le SQL Editor du dashboard Supabase.
-- =============================================================================

-- 1. Recréer la contrainte avec ON DELETE SET NULL
do $$
declare
  v_name text;
begin
  select c.conname into v_name
  from pg_constraint c
  join pg_attribute a
    on a.attrelid = c.conrelid and a.attnum = any(c.conkey)
  where c.contype = 'f'
    and c.conrelid = 'public.tickets'::regclass
    and a.attname = 'transferred_from';

  if v_name is not null then
    execute format('alter table public.tickets drop constraint %I', v_name);
  end if;

  alter table public.tickets
    add constraint tickets_transferred_from_fkey
    foreign key (transferred_from)
    references auth.users(id)
    on delete set null;
end $$;

-- 2. Détacher explicitement dans la procédure d'effacement
create or replace function public.delete_my_account_data()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then
    raise exception 'not_authenticated';
  end if;

  -- Garde-fou : on ne supprime pas un organisateur qui doit de l'argent.
  if exists (
    select 1
    from public.events e
    join public.ticket_types tt on tt.event_id = e.id
    where e.created_by = v_user
      and coalesce(e.status, 'published') <> 'cancelled'
      and coalesce(e.end_date, e.start_date) >= now()
      and coalesce(tt.price, 0) > 0
      and coalesce(tt.quantity_sold, 0) > 0
  ) then
    raise exception 'has_paid_sales';
  end if;

  -- 1. Billets sur des événements À VENIR : la place retourne au stock.
  update public.ticket_types tt
     set quantity_sold = greatest(coalesce(tt.quantity_sold, 0) - sub.n, 0)
  from (
    select t.ticket_type_id, count(*)::int as n
    from public.tickets t
    join public.events e on e.id = t.event_id
    where t.user_id = v_user
      and coalesce(e.end_date, e.start_date) >= now()
    group by t.ticket_type_id
  ) sub
  where tt.id = sub.ticket_type_id;

  delete from public.tickets t
  using public.events e
  where t.event_id = e.id
    and t.user_id = v_user
    and coalesce(e.end_date, e.start_date) >= now();

  -- 2. Billets passés : ligne conservée, détachée du profil.
  update public.tickets set user_id = null where user_id = v_user;

  -- 2 bis. Trace d'un transfert émis par cet utilisateur : on la détache
  --        aussi, sinon la contrainte bloque la suppression du compte auth.
  update public.tickets
     set transferred_from = null
   where transferred_from = v_user;

  -- 3. Événements À VENIR avec participants : annulation (trigger = notifs).
  update public.events
     set status = 'cancelled', created_by = null
   where created_by = v_user
     and coalesce(end_date, start_date) >= now()
     and exists (select 1 from public.tickets t where t.event_id = events.id);

  -- 4. Événements À VENIR sans participant : suppression.
  delete from public.events
   where created_by = v_user
     and coalesce(end_date, start_date) >= now();

  -- 5. Événements PASSÉS : anonymisation (« Organisateur supprimé »).
  update public.events set created_by = null where created_by = v_user;

  -- 6. Profil.
  delete from public.profiles where id = v_user;
end;
$$;

revoke all on function public.delete_my_account_data() from public, anon;
grant execute on function public.delete_my_account_data() to authenticated;
