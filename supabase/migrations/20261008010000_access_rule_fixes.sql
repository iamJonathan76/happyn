-- Deux trous trouves par les tests automatiques des regles d'acces
-- (tests/rls), le premier jour ou ils ont tourne.
--
-- ── 1. Un compte suspendu pouvait se retablir lui-meme ──────────────────────
--
-- La politique de mise a jour de `profiles` est « c'est ton profil », sans
-- restriction de colonne. Un compte suspendu n'avait qu'a ecrire
-- `suspended_at = null` sur sa propre ligne pour annuler sa suspension : la
-- moderation exigee par Apple (guideline 1.2) ne tenait que tant que la
-- personne ignorait ce detail.
--
-- La garde regarde `current_user`, pas le reglage `role` : les fonctions de
-- moderation (`admin_set_suspended`, SECURITY DEFINER) s'executent sous leur
-- proprietaire et doivent passer ; une session de l'app, elle, est
-- `authenticated`. (C'est la difference avec `prevent_self_admin`, qui lit le
-- reglage `role` : ca suffit pour `is_admin`, qu'aucune fonction ne modifie.)

create or replace function public.profiles_guard_suspension()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.suspended_at is distinct from old.suspended_at
     and current_user in ('authenticated', 'anon') then
    raise exception 'suspension_admin_only';
  end if;
  return new;
end;
$$;

revoke all on function public.profiles_guard_suspension() from public, anon, authenticated;

drop trigger if exists profiles_guard_suspension on public.profiles;
create trigger profiles_guard_suspension
  before update of suspended_at on public.profiles
  for each row execute function public.profiles_guard_suspension();

-- ── 2. Les brouillons etaient lisibles par tout le monde ────────────────────
--
-- « Depublier » retirait l'evenement de la decouverte, mais la politique de
-- lecture ne regardait que la visibilite (public / prive), pas le statut :
-- l'API rendait un brouillon public a n'importe qui, visiteurs compris. Un
-- organisateur qui prepare une soiree avant de l'annoncer la croyait cachee.
--
-- Restent lisibles : l'organisateur (ses brouillons), et quiconque detient un
-- billet — un evenement depublie apres la vente doit rester consultable par
-- ceux qui y vont. Un evenement annule reste lisible : ses acheteurs doivent
-- voir qu'il l'est.

drop policy if exists "events readable" on public.events;
create policy "events readable"
  on public.events for select
  to authenticated, anon
  using (
    (coalesce(visibility, 'public') = 'public'
       and coalesce(status, 'published') <> 'draft')
    or created_by = auth.uid()
    or public.user_holds_ticket_for(id)
  );
