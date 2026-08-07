-- =============================================================================
-- HAPPYN — Suppression de compte (droit à l'effacement)
-- =============================================================================
-- Exigé par Apple (règle 5.1.1(v)) et Google Play pour toute app permettant de
-- créer un compte. Traduit la politique produit convenue :
--
--   Utilisateur sans billet actif ......... suppression immédiate
--   Billet gratuit futur .................. annulé, la place retourne au stock
--   Événement futur sans participant ...... supprimé
--   Événement futur avec participants ..... annulé (les détenteurs sont notifiés)
--   Événement passé ....................... conservé, « Organisateur supprimé »
--   Billet passé .......................... conservé, détaché du profil
--   Ventes PAYANTES en cours .............. bloqué (remboursement d'abord)
--
-- Principe de minimisation (PIPEDA / Loi 25) : une transaction passée justifie
-- de garder la ligne comptable, PAS le profil, la photo ni les centres
-- d'intérêt. On détache donc au lieu de tout conserver.
--
-- On détache AVANT de supprimer le compte auth : ainsi, quelle que soit la
-- règle ON DELETE des clés étrangères, rien d'utile n'est emporté.
--
-- La suppression du compte auth lui-même et le nettoyage du Storage sont faits
-- par l'Edge Function `delete-account` (elle seule a la clé service_role).
-- À exécuter dans le SQL Editor du dashboard Supabase.
-- =============================================================================

-- ── Aperçu : ce qui va se passer (pour l'écran de confirmation) ─────────────
create or replace function public.account_deletion_preview()
returns json
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

  return json_build_object(
    'upcoming_tickets', (
      select count(*) from public.tickets t
      join public.events e on e.id = t.event_id
      where t.user_id = v_user
        and coalesce(e.end_date, e.start_date) >= now()
    ),
    'events_to_cancel', (
      select count(*) from public.events e
      where e.created_by = v_user
        and coalesce(e.end_date, e.start_date) >= now()
        and exists (select 1 from public.tickets t where t.event_id = e.id)
    ),
    'events_to_delete', (
      select count(*) from public.events e
      where e.created_by = v_user
        and coalesce(e.end_date, e.start_date) >= now()
        and not exists (select 1 from public.tickets t where t.event_id = e.id)
    ),
    'blocked_paid_sales', (
      select count(*) from public.events e
      join public.ticket_types tt on tt.event_id = e.id
      where e.created_by = v_user
        and coalesce(e.status, 'published') <> 'cancelled'
        and coalesce(e.end_date, e.start_date) >= now()
        and coalesce(tt.price, 0) > 0
        and coalesce(tt.quantity_sold, 0) > 0
    )
  );
end;
$$;

revoke all on function public.account_deletion_preview() from public, anon;
grant execute on function public.account_deletion_preview() to authenticated;

-- ── Effacement des données (tout sauf le compte auth et le Storage) ─────────
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
  -- (Inerte tant que Stripe est en test ; c'est le point d'accroche du futur
  --  flux de remboursement.)
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

  -- 1. Billets de l'utilisateur sur des événements À VENIR : la place doit
  --    retourner au stock, sinon l'organisateur la perd silencieusement.
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

  -- 2. Billets passés : on garde la ligne (comptabilité, anti-fraude) mais on
  --    la détache du profil.
  update public.tickets set user_id = null where user_id = v_user;

  -- 3. Événements À VENIR avec participants : annulation. Le trigger
  --    `notify_event_change` prévient automatiquement chaque détenteur.
  --    (Doit passer AVANT la suppression ci-dessous : une fois created_by mis
  --     à null, ces lignes ne matchent plus.)
  update public.events
     set status = 'cancelled', created_by = null
   where created_by = v_user
     and coalesce(end_date, start_date) >= now()
     and exists (select 1 from public.tickets t where t.event_id = events.id);

  -- 4. Événements À VENIR sans aucun participant : personne n'est impacté.
  delete from public.events
   where created_by = v_user
     and coalesce(end_date, start_date) >= now();

  -- 5. Événements PASSÉS : conservés pour l'historique des participants,
  --    affichés « Organisateur supprimé ».
  update public.events set created_by = null where created_by = v_user;

  -- 6. Profil (favoris, notifications et consentements partent en cascade
  --    lors de la suppression du compte auth par l'Edge Function).
  delete from public.profiles where id = v_user;
end;
$$;

revoke all on function public.delete_my_account_data() from public, anon;
grant execute on function public.delete_my_account_data() to authenticated;
