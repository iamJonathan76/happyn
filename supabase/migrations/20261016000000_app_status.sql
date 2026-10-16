-- État de l'app : maintenance et version minimale.
--
-- Une seule ligne, lue par tout le monde, connecté ou non : l'écran de
-- maintenance doit pouvoir s'afficher avant même la connexion. Personne ne
-- l'écrit directement — un administrateur passe par admin_set_app_status(),
-- qui vérifie lui-même le rôle. Une policy d'UPDATE « réservée aux admins »
-- aurait fait de la colonne profiles.is_admin la seule barrière ; la fonction
-- garde en plus la trace de qui a changé quoi.
--
-- Ce que ça bloque, honnêtement : l'APP. Quelqu'un qui appellerait l'API
-- directement passerait encore. Pour une vraie coupure (grosse migration), il
-- y a la pause du projet Supabase ; ceci sert à prévenir et à faire patienter.

create table if not exists public.app_status (
  id           boolean primary key default true check (id),
  maintenance  boolean not null default false,
  -- Le message affiché pendant la maintenance. Vide : texte par défaut de l'app.
  message_fr   text check (char_length(message_fr) <= 300),
  message_en   text check (char_length(message_en) <= 300),
  -- Version la plus ancienne encore acceptée, « 1.0.0 ». Vide : toutes.
  min_version  text check (min_version ~ '^\d+(\.\d+){0,2}$'),
  updated_at   timestamptz not null default now(),
  updated_by   uuid references auth.users(id) on delete set null
);

insert into public.app_status (id) values (true) on conflict (id) do nothing;

alter table public.app_status enable row level security;

drop policy if exists "app status readable by all" on public.app_status;
create policy "app status readable by all" on public.app_status
  as permissive for select to anon, authenticated using (true);

revoke all on public.app_status from public, anon, authenticated;
grant select on public.app_status to anon, authenticated;

-- Seule porte d'écriture. Les quatre champs sont remplacés à chaque appel :
-- l'écran admin envoie toujours l'état complet, pas un morceau.
create or replace function public.admin_set_app_status(
  p_maintenance boolean,
  p_message_fr  text default null,
  p_message_en  text default null,
  p_min_version text default null
)
returns void
language plpgsql security definer
set search_path = public
as $$
begin
  if not public.i_am_admin() then
    raise exception 'not_admin';
  end if;
  update public.app_status set
    maintenance = coalesce(p_maintenance, false),
    message_fr  = nullif(trim(p_message_fr), ''),
    message_en  = nullif(trim(p_message_en), ''),
    min_version = nullif(trim(p_min_version), ''),
    updated_at  = now(),
    updated_by  = auth.uid()
  where id;
end;
$$;

revoke all on function public.admin_set_app_status(boolean, text, text, text) from public, anon;
grant execute on function public.admin_set_app_status(boolean, text, text, text) to authenticated, service_role;

-- Temps réel : une app ouverte bascule dès que la maintenance est activée ou
-- levée, sans attendre d'être relancée. Ajout conditionnel : la table peut
-- déjà être membre de la publication (« already member »), et ce script doit
-- pouvoir être rejoué.
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1 from pg_publication_tables
       where pubname = 'supabase_realtime' and schemaname = 'public'
         and tablename = 'app_status')
  then
    alter publication supabase_realtime add table public.app_status;
  end if;
end;
$$;
