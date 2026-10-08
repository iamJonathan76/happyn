-- Ce que Supabase fournit autour du schema `public`, reduit au strict
-- necessaire pour rejouer le schema de production sur un Postgres nu.
--
-- Fidele sur ce qui compte pour les regles d'acces : les trois roles, et
-- `auth.uid()` qui lit l'identifiant de la session comme le fait PostgREST
-- (le `sub` du jeton). Le reste — envoi HTTP, file des webhooks — est
-- remplace par des fonctions qui ne font rien : les tests verifient qui a le
-- droit de faire quoi, pas que la notification part.

do $$ begin create role anon nologin;          exception when duplicate_object then null; end $$;
do $$ begin create role authenticated nologin; exception when duplicate_object then null; end $$;
do $$ begin create role service_role nologin bypassrls; exception when duplicate_object then null; end $$;

create schema if not exists extensions;
create extension if not exists pgcrypto    with schema extensions;
create extension if not exists "uuid-ossp" with schema extensions;

create schema if not exists auth;
create table if not exists auth.users (
  id                 uuid primary key default gen_random_uuid(),
  email              text,
  raw_user_meta_data jsonb not null default '{}'::jsonb,
  raw_app_meta_data  jsonb not null default '{}'::jsonb,
  created_at         timestamptz not null default now()
);

-- Comme PostgREST : l'identifiant vient du jeton de la requete.
create or replace function auth.uid() returns uuid
language sql stable as $$
  select nullif(
    coalesce(
      current_setting('request.jwt.claim.sub', true),
      (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')
    ), '')::uuid
$$;

create or replace function auth.role() returns text
language sql stable as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim.role', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role')
  )
$$;

create or replace function auth.jwt() returns jsonb
language sql stable as $$
  select coalesce(nullif(current_setting('request.jwt.claims', true), ''), '{}')::jsonb
$$;

grant usage on schema auth, extensions to anon, authenticated, service_role;
grant execute on function auth.uid(), auth.role(), auth.jwt()
  to anon, authenticated, service_role;
grant select on auth.users to service_role;

-- pg_net : l'appel HTTP asynchrone, remplace par un no-op.
create schema if not exists net;
create or replace function net.http_post(
  url text, body jsonb default '{}'::jsonb, params jsonb default '{}'::jsonb,
  headers jsonb default '{}'::jsonb, timeout_milliseconds integer default 5000
) returns bigint language sql as $$ select 0::bigint $$;

-- Le declencheur de webhook cree dans le tableau de bord (send-push).
create schema if not exists supabase_functions;
create or replace function supabase_functions.http_request()
returns trigger language plpgsql as $$ begin return new; end $$;

-- La publication temps reel, que certaines migrations alimentent.
do $$ begin
  create publication supabase_realtime;
exception when duplicate_object then null; end $$;
