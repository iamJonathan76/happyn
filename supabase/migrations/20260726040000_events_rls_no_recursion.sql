-- =============================================================================
-- HAPPYN — Correctif : la policy RLS des events cassait la lecture
-- =============================================================================
-- Symptôme : après le durcissement RLS, « Mes événements » s'affichait vide
-- alors que les données étaient intactes en base.
--
-- Cause : la policy SELECT sur `events` contenait un sous-select sur `tickets`.
-- Or `tickets` a lui aussi une RLS, qui peut à son tour référencer `events` —
-- Postgres détecte alors une récursion (« infinite recursion detected in policy
-- for relation ... ») et la requête échoue. Le client recevait donc une erreur,
-- pas une liste vide, mais l'app l'affichait comme « aucun événement ».
--
-- Correctif standard : sortir le test dans une fonction SECURITY DEFINER, qui
-- contourne la RLS de `tickets`. Plus de récursion possible, et c'est aussi
-- plus rapide (la policy n'évalue plus une politique imbriquée par ligne).
-- À exécuter dans le SQL Editor du dashboard Supabase.
-- =============================================================================

create or replace function public.user_holds_ticket_for(p_event uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.tickets
    where event_id = p_event
      and user_id = auth.uid()
  );
$$;

revoke all on function public.user_holds_ticket_for(uuid) from public;
grant execute on function public.user_holds_ticket_for(uuid) to anon, authenticated;

drop policy if exists "events readable" on public.events;

create policy "events readable"
  on public.events for select
  to anon, authenticated
  using (
    coalesce(visibility, 'public') = 'public'
    or created_by = auth.uid()
    or public.user_holds_ticket_for(id)
  );
