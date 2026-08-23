-- Modération : rôle administrateur, file de traitement, actions tracées.
--
-- Apple (guideline 1.2) n'exige pas seulement un bouton « signaler » : il exige
-- une modération EFFECTIVE, sous 24 h, avec retrait du contenu fautif et
-- possibilité d'écarter l'auteur. Jusqu'ici `reports` se remplissait et
-- personne ne la lisait — le bouton existait, la modération non.
--
-- Trois principes :
--
--   1. Toute action de modération passe par une fonction, jamais par du SQL à
--      la main. Du SQL manuel ne laisse aucune trace : le jour où Apple ou un
--      utilisateur demande ce qui a été fait d'un signalement, il faut pouvoir
--      répondre.
--   2. Chaque fonction vérifie elle-même que l'appelant est administrateur.
--      Le contrôle ne peut pas vivre dans l'app : la clé anon est publique.
--   3. Un administrateur ne peut pas se nommer lui-même. `is_admin` ne
--      s'accorde que depuis le tableau de bord, avec le rôle `service_role`.

-- ── Le rôle ─────────────────────────────────────────────────────────────────

alter table public.profiles
  add column if not exists is_admin boolean not null default false;

comment on column public.profiles.is_admin is
  'Droit de modération. Ne s''accorde QUE depuis le tableau de bord Supabase '
  '(service_role) : aucune policy ni fonction ne permet de se l''octroyer.';

-- La policy d'UPDATE de `profiles` autorise chacun à modifier sa propre ligne.
-- Sans ce garde-fou, n'importe qui se nommerait administrateur en une requête.
create or replace function public.prevent_self_admin()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.is_admin is distinct from old.is_admin
     and current_setting('role', true) <> 'service_role' then
    raise exception 'is_admin ne peut pas etre modifie par le client';
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_prevent_self_admin on public.profiles;
create trigger profiles_prevent_self_admin
  before update on public.profiles
  for each row execute function public.prevent_self_admin();

-- Lecture seule, et seulement pour soi-même : l'app a besoin de savoir s'il
-- faut afficher l'écran de modération.
create or replace function public.i_am_admin()
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select coalesce(
    (select p.is_admin from public.profiles p where p.id = auth.uid()),
    false
  );
$$;

revoke all on function public.i_am_admin() from public, anon;
grant execute on function public.i_am_admin() to authenticated;

-- ── Journal des actions ─────────────────────────────────────────────────────

create table if not exists public.admin_actions (
  id          uuid primary key default gen_random_uuid(),
  admin_id    uuid references auth.users(id) on delete set null,
  action      text not null,
  target_type text not null,
  target_id   uuid,
  report_id   uuid references public.reports(id) on delete set null,
  note        text,
  created_at  timestamptz not null default now()
);

create index if not exists admin_actions_created_idx
  on public.admin_actions (created_at desc);

alter table public.admin_actions enable row level security;

-- Aucune policy : la table n'est lisible et écrivable que par les fonctions
-- ci-dessous (SECURITY DEFINER) et depuis le tableau de bord. Un journal
-- d'audit que l'audité peut modifier ne vaut rien.

-- ── Suspension d'un compte ──────────────────────────────────────────────────

alter table public.profiles
  add column if not exists suspended_at timestamptz;

create or replace function public.is_suspended()
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select coalesce(
    (select p.suspended_at is not null
       from public.profiles p where p.id = auth.uid()),
    false
  );
$$;

revoke all on function public.is_suspended() from public, anon;
grant execute on function public.is_suspended() to authenticated;

-- Un compte suspendu ne peut plus rien publier. On ne supprime pas son compte
-- et on ne touche pas à ses billets : il a payé, il garde ce qu'il a acheté.
-- Ce qu'on lui retire, c'est la capacité de nuire à nouveau.
drop policy if exists "own posts insert" on public.posts;
create policy "own posts insert"
  on public.posts for insert
  to authenticated
  with check (
    auth.uid() = author_id
    and public.can_attach_event(event_id)
    and not public.is_suspended()
  );

drop policy if exists "Authenticated users can create events" on public.events;
create policy "Authenticated users can create events"
  on public.events for insert
  to authenticated
  with check (auth.uid() = created_by and not public.is_suspended());

-- ── La file de modération ───────────────────────────────────────────────────
-- Renvoie les signalements avec juste assez de contexte pour décider sans
-- ouvrir dix écrans : de quoi il s'agit, et qui en est l'auteur.

create or replace function public.admin_reports(p_status text default 'pending')
returns table (
  id            uuid,
  target_type   text,
  target_id     uuid,
  reason        text,
  details       text,
  status        text,
  created_at    timestamptz,
  target_label  text,
  target_author uuid,
  author_name   text
)
language plpgsql
security definer
stable
set search_path = public
as $$
begin
  if not public.i_am_admin() then
    raise exception 'not_admin';
  end if;

  return query
  with base as (
    select
      r.id, r.target_type, r.target_id, r.reason, r.details, r.status,
      r.created_at,
      case r.target_type
        when 'event' then (select e.title from public.events e where e.id = r.target_id)
        when 'post'  then (select coalesce(nullif(p.caption, ''), '(image)')
                             from public.posts p where p.id = r.target_id)
        when 'user'  then (select pr.full_name from public.profiles pr where pr.id = r.target_id)
      end as target_label,
      case r.target_type
        when 'event' then (select e.created_by from public.events e where e.id = r.target_id)
        when 'post'  then (select p.author_id from public.posts p where p.id = r.target_id)
        when 'user'  then r.target_id
      end as target_author
    from public.reports r
    where r.status = p_status
  )
  select b.id, b.target_type, b.target_id, b.reason, b.details, b.status,
         b.created_at, b.target_label, b.target_author,
         (select pr.full_name from public.profiles pr where pr.id = b.target_author)
  from base b
  -- Le plus ancien d'abord : c'est lui qui approche des 24 h.
  order by b.created_at asc;
end;
$$;

revoke all on function public.admin_reports(text) from public, anon;
grant execute on function public.admin_reports(text) to authenticated;

-- ── Les actions ─────────────────────────────────────────────────────────────

create or replace function public.admin_resolve_report(
  p_report uuid,
  p_status text,
  p_note   text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.i_am_admin() then
    raise exception 'not_admin';
  end if;
  if p_status not in ('reviewed', 'actioned', 'dismissed') then
    raise exception 'invalid_status';
  end if;

  update public.reports set status = p_status where id = p_report;

  insert into public.admin_actions (admin_id, action, target_type, target_id,
                                    report_id, note)
  values (auth.uid(), 'resolve_report', 'report', p_report, p_report, p_note);
end;
$$;

revoke all on function public.admin_resolve_report(uuid, text, text)
  from public, anon;
grant execute on function public.admin_resolve_report(uuid, text, text)
  to authenticated;

-- Retirer un contenu. On dépublie l'événement plutôt que de le supprimer :
-- des gens ont peut-être acheté des billets, et effacer la ligne les priverait
-- de la trace de ce qu'ils ont payé. Une publication, elle, se supprime.
create or replace function public.admin_remove_content(
  p_type   text,
  p_id     uuid,
  p_report uuid default null,
  p_note   text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.i_am_admin() then
    raise exception 'not_admin';
  end if;

  if p_type = 'post' then
    delete from public.posts where id = p_id;
  elsif p_type = 'event' then
    update public.events set status = 'draft' where id = p_id;
  else
    raise exception 'invalid_type';
  end if;

  insert into public.admin_actions (admin_id, action, target_type, target_id,
                                    report_id, note)
  values (auth.uid(), 'remove_content', p_type, p_id, p_report, p_note);
end;
$$;

revoke all on function public.admin_remove_content(text, uuid, uuid, text)
  from public, anon;
grant execute on function public.admin_remove_content(text, uuid, uuid, text)
  to authenticated;

-- Suspendre ou réactiver un compte.
create or replace function public.admin_set_suspended(
  p_user      uuid,
  p_suspended boolean,
  p_report    uuid default null,
  p_note      text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.i_am_admin() then
    raise exception 'not_admin';
  end if;
  -- Se suspendre soi-même verrouillerait la modération : plus personne ne
  -- pourrait rien traiter.
  if p_user = auth.uid() then
    raise exception 'cannot_suspend_self';
  end if;

  update public.profiles
  set suspended_at = case when p_suspended then now() else null end
  where id = p_user;

  insert into public.admin_actions (admin_id, action, target_type, target_id,
                                    report_id, note)
  values (auth.uid(),
          case when p_suspended then 'suspend_user' else 'unsuspend_user' end,
          'user', p_user, p_report, p_note);
end;
$$;

revoke all on function public.admin_set_suspended(uuid, boolean, uuid, text)
  from public, anon;
grant execute on function public.admin_set_suspended(uuid, boolean, uuid, text)
  to authenticated;
