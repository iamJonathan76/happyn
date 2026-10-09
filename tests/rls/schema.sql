-- GENERE par tests/rls/snapshot_schema.py — ne pas editer a la main.

-- Structure de la base de production, sans aucune donnee.

set check_function_bodies = off;

set client_min_messages = warning;

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


create schema if not exists private;

create table private."settings" (
  "key" text not null,
  "value" text not null
);

create table public."admin_actions" (
  "id" uuid not null,
  "admin_id" uuid,
  "action" text not null,
  "target_type" text not null,
  "target_id" uuid,
  "report_id" uuid,
  "note" text,
  "created_at" timestamp with time zone not null
);

create table public."blocked_users" (
  "blocker_id" uuid not null,
  "blocked_id" uuid not null,
  "created_at" timestamp with time zone not null
);

create table public."categories" (
  "id" uuid not null,
  "name" text not null,
  "icon" text,
  "created_at" timestamp with time zone,
  "emoji" text,
  "sort_order" integer not null,
  "is_active" boolean not null
);

create table public."cities" (
  "slug" text not null,
  "name" text not null,
  "province" text not null,
  "country" text not null,
  "latitude" double precision not null,
  "longitude" double precision not null,
  "radius_km" double precision not null,
  "sort_order" integer not null
);

create table public."device_tokens" (
  "token" text not null,
  "user_id" uuid not null,
  "platform" text not null,
  "created_at" timestamp with time zone not null,
  "updated_at" timestamp with time zone not null
);

create table public."direct_conversations" (
  "id" uuid not null,
  "member_a" uuid,
  "member_b" uuid,
  "created_at" timestamp with time zone not null
);

create table public."direct_messages" (
  "id" uuid not null,
  "conversation_id" uuid not null,
  "sender_id" uuid,
  "body" text not null,
  "created_at" timestamp with time zone not null,
  "shared_kind" text,
  "post_id" uuid,
  "event_id" uuid
);

create table public."event_addresses" (
  "event_id" uuid not null,
  "address_line" text,
  "postal_code" text,
  "latitude" double precision,
  "longitude" double precision,
  "place_id" text,
  "created_at" timestamp with time zone not null,
  "updated_at" timestamp with time zone not null
);

create table public."event_attendance" (
  "user_id" uuid not null,
  "event_id" uuid not null,
  "status" text not null,
  "visible_to_connections" boolean not null,
  "created_at" timestamp with time zone not null,
  "updated_at" timestamp with time zone not null
);

create table public."event_payouts" (
  "id" uuid not null,
  "event_id" uuid not null,
  "organizer_id" uuid,
  "account_id" text not null,
  "gross_cents" bigint not null,
  "refunded_cents" bigint not null,
  "stripe_fee_cents" bigint not null,
  "platform_fee_cents" bigint not null,
  "net_cents" bigint not null,
  "status" text not null,
  "transfer_id" text,
  "failure_reason" text,
  "created_at" timestamp with time zone not null,
  "paid_at" timestamp with time zone
);

create table public."event_unlocks" (
  "user_id" uuid not null,
  "event_id" uuid not null,
  "created_at" timestamp with time zone not null
);

create table public."events" (
  "id" uuid not null,
  "title" text not null,
  "description" text,
  "category" text,
  "location" text,
  "city" text,
  "start_date" timestamp with time zone,
  "end_date" timestamp with time zone,
  "price" numeric,
  "image_url" text,
  "created_by" uuid,
  "created_at" timestamp with time zone,
  "status" text not null,
  "visibility" text not null,
  "access_code" text,
  "min_age" integer not null,
  "posts_visibility" text not null,
  "cancellation_hours" integer not null,
  "province" text,
  "country" text,
  "platform_fee_bps" integer not null
);

create table public."favorites" (
  "id" uuid not null,
  "user_id" uuid not null,
  "event_id" uuid not null,
  "created_at" timestamp with time zone not null
);

create table public."follows" (
  "follower_id" uuid not null,
  "following_id" uuid not null,
  "created_at" timestamp with time zone not null
);

create table public."legal_document_translations" (
  "slug" text not null,
  "locale" text not null,
  "title" text not null,
  "content" text not null,
  "version" text not null,
  "updated_at" timestamp with time zone not null
);

create table public."legal_documents" (
  "slug" text not null,
  "title" text not null,
  "content" text not null,
  "version" text not null,
  "effective_date" date not null,
  "requires_acceptance" boolean not null,
  "sort_order" integer not null,
  "updated_at" timestamp with time zone not null
);

create table public."notifications" (
  "id" uuid not null,
  "user_id" uuid not null,
  "type" text not null,
  "title" text not null,
  "body" text,
  "event_id" uuid,
  "read" boolean not null,
  "created_at" timestamp with time zone not null,
  "conversation_id" uuid,
  "post_id" uuid
);

create table public."payments" (
  "payment_intent_id" text not null,
  "event_id" uuid not null,
  "ticket_type_id" uuid,
  "organizer_id" uuid,
  "buyer_id" uuid,
  "quantity" integer not null,
  "gross_cents" bigint not null,
  "stripe_fee_cents" bigint,
  "platform_fee_bps" integer not null,
  "refunded_cents" bigint not null,
  "disputed_at" timestamp with time zone,
  "created_at" timestamp with time zone not null,
  "retained_fee_cents" bigint not null
);

create table public."post_comments" (
  "id" uuid not null,
  "post_id" uuid not null,
  "author_id" uuid not null,
  "body" text not null,
  "created_at" timestamp with time zone not null
);

create table public."post_likes" (
  "post_id" uuid not null,
  "user_id" uuid not null,
  "created_at" timestamp with time zone not null
);

create table public."posts" (
  "id" uuid not null,
  "author_id" uuid not null,
  "caption" text,
  "image_url" text,
  "event_id" uuid not null,
  "created_at" timestamp with time zone not null,
  "edited_at" timestamp with time zone,
  "comments_disabled" boolean not null,
  "image_aspect" real
);

create table public."profiles" (
  "id" uuid not null,
  "email" text,
  "full_name" text,
  "username" text,
  "avatar_url" text,
  "bio" text,
  "city" text,
  "created_at" timestamp with time zone,
  "interests" text[] not null,
  "onboarded" boolean not null,
  "date_of_birth" date,
  "is_admin" boolean not null,
  "suspended_at" timestamp with time zone,
  "language" text
);

create table public."reports" (
  "id" uuid not null,
  "reporter_id" uuid,
  "target_type" text not null,
  "target_id" uuid not null,
  "reason" text not null,
  "details" text,
  "status" text not null,
  "created_at" timestamp with time zone not null,
  "target_label" text
);

create table public."stripe_accounts" (
  "user_id" uuid not null,
  "account_id" text not null,
  "transfers_enabled" boolean not null,
  "payouts_enabled" boolean not null,
  "details_submitted" boolean not null,
  "disabled_reason" text,
  "created_at" timestamp with time zone not null,
  "updated_at" timestamp with time zone not null
);

create table public."ticket_types" (
  "id" uuid not null,
  "event_id" uuid,
  "name" text not null,
  "price" numeric(10,2),
  "quantity_total" integer,
  "quantity_sold" integer,
  "perks" text[],
  "created_at" timestamp with time zone,
  "max_per_order" integer not null
);

create table public."tickets" (
  "id" uuid not null,
  "ticket_type_id" uuid,
  "event_id" uuid,
  "user_id" uuid,
  "qr_token" text,
  "status" text,
  "purchased_at" timestamp with time zone,
  "used_at" timestamp with time zone,
  "payment_intent_id" text,
  "transferred_from" uuid,
  "transferred_at" timestamp with time zone,
  "cancelled_at" timestamp with time zone,
  "refunded_at" timestamp with time zone,
  "refund_id" text
);

create table public."user_legal_acceptances" (
  "id" uuid not null,
  "user_id" uuid not null,
  "slug" text not null,
  "version" text not null,
  "accepted_at" timestamp with time zone not null,
  "locale" text
);

CREATE OR REPLACE FUNCTION public.accept_legal_documents(p_versions jsonb, p_locale text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_user uuid := auth.uid();
  d      record;
begin
  if v_user is null then
    raise exception 'not_authenticated';
  end if;

  -- Les documents en attente pour CE compte : exigés, à la bonne version.
  for d in
    select l.slug, l.version from public.legal_documents l
    where l.requires_acceptance
      and not exists (
        select 1 from public.user_legal_acceptances a
        where a.user_id = v_user and a.slug = l.slug and a.version = l.version)
  loop
    if not (p_versions ? d.slug) then
      raise exception 'version_changed';
    end if;
    if p_versions ->> d.slug is distinct from d.version then
      raise exception 'version_changed';
    end if;
  end loop;

  insert into public.user_legal_acceptances (user_id, slug, version, accepted_at, locale)
  select v_user, l.slug, l.version, now(),
         case when exists (
                select 1 from public.legal_document_translations t
                where t.slug = l.slug and t.locale = p_locale and t.version = l.version)
              then p_locale else 'en' end
  from public.legal_documents l
  where l.requires_acceptance
    and p_versions ->> l.slug = l.version
  on conflict (user_id, slug, version) do nothing;
end;
$function$;

CREATE OR REPLACE FUNCTION public.account_deletion_preview()
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
        and t.status = 'valid'
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
    'blocked_paid_sales',       public.deletion_paid_sales(v_user),
    'blocked_pending_earnings', public.deletion_pending_earnings(v_user),
    'blocked_paid_tickets',     public.deletion_paid_tickets(v_user)
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.admin_remove_content(p_type text, p_id uuid, p_report uuid DEFAULT NULL::uuid, p_note text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not public.i_am_admin() then
    raise exception 'not_admin';
  end if;

  if p_type = 'post' then
    delete from public.posts where id = p_id;
  elsif p_type = 'event' then
    update public.events set status = 'draft' where id = p_id;
  elsif p_type = 'message' then
    delete from public.direct_messages where id = p_id;
  elsif p_type = 'comment' then
    delete from public.post_comments where id = p_id;
  else
    raise exception 'invalid_type';
  end if;

  insert into public.admin_actions (admin_id, action, target_type, target_id,
                                    report_id, note)
  values (auth.uid(), 'remove_content', p_type, p_id, p_report, p_note);
end;
$function$;

CREATE OR REPLACE FUNCTION public.admin_report_target(p_report uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  r      public.reports;
  result jsonb;
begin
  if not public.i_am_admin() then
    raise exception 'not_admin';
  end if;

  select * into r from public.reports where id = p_report;
  if not found then
    return null;
  end if;

  if r.target_type = 'event' then
    select jsonb_build_object(
      'type',        'event',
      'title',       e.title,
      'description', e.description,
      'image_url',   e.image_url,
      'start_date',  e.start_date,
      'end_date',    e.end_date,
      'city',        e.city,
      'location',    e.location,
      'category',    e.category,
      'price',       e.price,
      'status',      e.status,
      'visibility',  coalesce(e.visibility, 'public'),
      'author_id',   e.created_by,
      'author_name', (select pr.full_name from public.profiles pr where pr.id = e.created_by),
      'tickets_sold', (
        select count(*) from public.tickets t
        where t.event_id = e.id
          and coalesce(t.status, '') <> 'cancelled'
      )
    )
    into result
    from public.events e
    where e.id = r.target_id;

  elsif r.target_type = 'post' then
    select jsonb_build_object(
      'type',        'post',
      'caption',     p.caption,
      'image_url',   p.image_url,
      'created_at',  p.created_at,
      'edited_at',   p.edited_at,
      'author_id',   p.author_id,
      'author_name', (select pr.full_name from public.profiles pr where pr.id = p.author_id),
      'event_title', (select e.title from public.events e where e.id = p.event_id),
      'like_count',  (select count(*) from public.post_likes l where l.post_id = p.id)
    )
    into result
    from public.posts p
    where p.id = r.target_id;

  elsif r.target_type = 'user' then
    select jsonb_build_object(
      'type',         'user',
      'full_name',    pr.full_name,
      'username',     pr.username,
      'avatar_url',   pr.avatar_url,
      'is_suspended', pr.is_suspended,
      'author_id',    pr.id,
      'post_count',   (select count(*) from public.posts p where p.author_id = pr.id),
      'event_count',  (select count(*) from public.events e where e.created_by = pr.id)
    )
    into result
    from public.profiles pr
    where pr.id = r.target_id;

  elsif r.target_type = 'message' then
    select jsonb_build_object(
      'type',        'message',
      'body',        m.body,
      'created_at',  m.created_at,
      'author_id',   m.sender_id,
      'author_name', (select pr.full_name from public.profiles pr
                       where pr.id = m.sender_id),
      'context', (
        select coalesce(jsonb_agg(x order by x_created), '[]'::jsonb)
        from (
          select jsonb_build_object(
                   'body', prev.body,
                   'mine', prev.sender_id is not distinct from m.sender_id,
                   'created_at', prev.created_at
                 ) as x,
                 prev.created_at as x_created
          from public.direct_messages prev
          where prev.conversation_id = m.conversation_id
            and prev.created_at < m.created_at
          order by prev.created_at desc
          limit 3
        ) q
      )
    )
    into result
    from public.direct_messages m
    where m.id = r.target_id;
  elsif r.target_type = 'comment' then
    -- La publication sous laquelle le commentaire a ete ecrit : « bravo » sous
    -- une photo de soiree et sous la photo d'une personne ne se jugent pas
    -- pareil.
    select jsonb_build_object(
      'type',         'comment',
      'body',         c.body,
      'created_at',   c.created_at,
      'author_id',    c.author_id,
      'author_name',  (select pr.full_name from public.profiles pr
                        where pr.id = c.author_id),
      'post_caption', p.caption,
      'post_image',   p.image_url,
      'post_author',  (select pr.full_name from public.profiles pr
                        where pr.id = p.author_id)
    )
    into result
    from public.post_comments c
    left join public.posts p on p.id = c.post_id
    where c.id = r.target_id;
  end if;

  return result;
end;
$function$;

CREATE OR REPLACE FUNCTION public.admin_reports(p_status text DEFAULT 'pending'::text)
 RETURNS TABLE(id uuid, target_type text, target_id uuid, reason text, details text, status text, created_at timestamp with time zone, target_label text, target_author uuid, author_name text, target_image text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
        when 'message' then (select left(m.body, 120) from public.direct_messages m where m.id = r.target_id)
        when 'comment' then (select left(c.body, 120) from public.post_comments c where c.id = r.target_id)
      end as target_label,
      case r.target_type
        when 'event' then (select e.created_by from public.events e where e.id = r.target_id)
        when 'post'  then (select p.author_id from public.posts p where p.id = r.target_id)
        when 'user'  then r.target_id
        when 'message' then (select m.sender_id from public.direct_messages m where m.id = r.target_id)
        when 'comment' then (select c.author_id from public.post_comments c where c.id = r.target_id)
      end as target_author,
      -- Ce que le signalement vise, en image. Null si le contenu a déjà été
      -- retiré, ou s'il n'en a jamais eu : la carte affiche alors une pastille
      -- de repli plutôt qu'un trou.
      case r.target_type
        when 'event' then (select e.image_url from public.events e where e.id = r.target_id)
        when 'post'  then (select p.image_url from public.posts p where p.id = r.target_id)
        when 'user'  then (select pr.avatar_url from public.profiles pr where pr.id = r.target_id)
        -- Un commentaire n'a pas d'image a lui : celle de la publication dit
        -- ou il a ete ecrit.
        when 'comment' then (select p.image_url from public.post_comments c
                               join public.posts p on p.id = c.post_id
                              where c.id = r.target_id)
      end as target_image
    from public.reports r
    where r.status = p_status
  )
  select b.id, b.target_type, b.target_id, b.reason, b.details, b.status,
         b.created_at, b.target_label, b.target_author,
         (select pr.full_name from public.profiles pr where pr.id = b.target_author),
         b.target_image
  from base b
  -- Le plus ancien d'abord : c'est lui qui approche des 24 h.
  order by b.created_at asc;
end;
$function$;

CREATE OR REPLACE FUNCTION public.admin_resolve_report(p_report uuid, p_status text, p_note text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.admin_set_suspended(p_user uuid, p_suspended boolean, p_report uuid DEFAULT NULL::uuid, p_note text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.blocked_either_way(p_a uuid, p_b uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1 from public.blocked_users b
    where (b.blocker_id = p_a and b.blocked_id = p_b)
       or (b.blocker_id = p_b and b.blocked_id = p_a)
  );
$function$;

CREATE OR REPLACE FUNCTION public.blocked_users_details()
 RETURNS TABLE(id uuid, full_name text, avatar_url text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select p.id, p.full_name, p.avatar_url
  from public.blocked_users b
  join public.profiles p on p.id = b.blocked_id
  where b.blocker_id = auth.uid()
  order by b.created_at desc;
$function$;

CREATE OR REPLACE FUNCTION public.can_access_direct_conversation(p_conversation uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1
    from public.direct_conversations c
    where c.id = p_conversation
      and auth.uid() in (c.member_a, c.member_b)
      and not exists (
        select 1
        from public.blocked_users b
        where (b.blocker_id = c.member_a and b.blocked_id = c.member_b)
           or (b.blocker_id = c.member_b and b.blocked_id = c.member_a)
      )
  );
$function$;

CREATE OR REPLACE FUNCTION public.can_attach_event(p_event uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1 from public.events e
    where e.id = p_event and e.created_by = auth.uid()
  )
  or exists (
    select 1 from public.event_attendance a
    where a.event_id = p_event and a.user_id = auth.uid()
  );
$function$;

CREATE OR REPLACE FUNCTION public.can_cancel_ticket(p_ticket uuid)
 RETURNS TABLE(allowed boolean, reason text, deadline timestamp with time zone, amount numeric, fee numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_user        uuid;
  v_status      text;
  v_start       timestamptz;
  v_ev          text;
  v_hours       integer;
  v_price       numeric;
  v_fee         numeric;
  v_transferred boolean;
begin
  select t.user_id, t.status, e.start_date, e.status,
         coalesce(e.cancellation_hours, 24),
         public.ticket_paid_cents(t.id)::numeric / 100,
         public.cancellation_fee_cents(public.ticket_paid_cents(t.id))::numeric / 100,
         t.transferred_from is not null
    into v_user, v_status, v_start, v_ev, v_hours, v_price, v_fee, v_transferred
  from public.tickets t
  join public.events e on e.id = t.event_id
  where t.id = p_ticket;

  if v_user is null then
    return query select false, 'not_found'::text, null::timestamptz, 0::numeric, 0::numeric;
    return;
  end if;
  if v_user <> auth.uid() then
    return query select false, 'not_owner'::text, null::timestamptz, 0::numeric, 0::numeric;
    return;
  end if;
  if v_status <> 'valid' then
    return query select false, 'ticket_not_valid'::text, null::timestamptz, v_price, v_fee;
    return;
  end if;

  -- Paye puis transfere : plus remboursable a la demande. Stripe ne saurait
  -- rembourser que la carte de l'acheteur, pas la personne qui annule.
  if v_transferred and v_price > 0 then
    return query select false, 'transferred'::text, null::timestamptz, v_price, v_fee;
    return;
  end if;

  -- Evenement annule par l'organisateur : le remboursement part tout seul
  -- (`cancel-event`), et il est integral. Ce n'est pas a l'acheteur de le
  -- demander — ni de payer des frais pour une annulation qui n'est pas la
  -- sienne.
  if v_ev = 'cancelled' then
    return query select false, 'event_cancelled'::text, null::timestamptz, v_price, 0::numeric;
    return;
  end if;

  if v_hours = 0 then
    return query select false, 'not_allowed_by_organizer'::text,
                        null::timestamptz, v_price, v_fee;
    return;
  end if;

  return query
  select now() < (v_start - make_interval(hours => v_hours)),
         case when now() < (v_start - make_interval(hours => v_hours))
              then 'ok' else 'deadline_passed' end,
         v_start - make_interval(hours => v_hours),
         v_price,
         v_fee;
end;
$function$;

CREATE OR REPLACE FUNCTION public.can_see_exact_address(p_event uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1 from public.events e
    where e.id = p_event
      and (
        coalesce(e.visibility, 'public') = 'public'
        or e.created_by = auth.uid()
        or public.user_holds_ticket_for(e.id)
      )
  );
$function$;

CREATE OR REPLACE FUNCTION public.cancel_event(p_event uuid, p_actor uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_owner uuid;
begin
  select created_by into v_owner from public.events where id = p_event;
  if v_owner is null then raise exception 'not_found'; end if;
  if v_owner <> p_actor then raise exception 'not_organizer'; end if;

  if exists (
    select 1 from public.event_payouts
    where event_id = p_event
      and status in ('pending', 'paid')
  ) then
    raise exception 'already_paid_out';
  end if;

  update public.events
     set status = 'cancelled'
   where id = p_event
     and status <> 'cancelled';
end;
$function$;

CREATE OR REPLACE FUNCTION public.cancel_ticket(p_ticket uuid, p_actor uuid, p_refund_id text DEFAULT NULL::text, p_retained_fee_cents bigint DEFAULT 0)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_user   uuid;
  v_status text;
  v_type   uuid;
  v_pi     text;
begin
  select user_id, status, ticket_type_id, payment_intent_id
    into v_user, v_status, v_type, v_pi
  from public.tickets
  where id = p_ticket
  for update;  -- verrou : deux annulations simultanées ne rendraient qu'une place

  if v_user is null then raise exception 'not_found'; end if;
  if v_user <> p_actor then raise exception 'not_owner'; end if;
  if v_status <> 'valid' then raise exception 'ticket_not_valid'; end if;

  update public.tickets
  set status       = 'cancelled',
      cancelled_at = now(),
      refunded_at  = case when p_refund_id is not null then now() else null end,
      refund_id    = p_refund_id
  where id = p_ticket;

  -- Ce qui n'a pas été rendu reste sur le paiement : `event_ledger` doit savoir
  -- que ces cents compensent les frais de Stripe et ne sont pas une vente —
  -- sinon l'organisateur paierait une commission sur un billet annulé.
  if coalesce(p_retained_fee_cents, 0) > 0 and v_pi is not null then
    update public.payments
    set retained_fee_cents = retained_fee_cents + p_retained_fee_cents
    where payment_intent_id = v_pi;
  end if;

  -- La place retourne au stock. `greatest` par prudence : un compteur négatif
  -- casserait l'affichage « x / y vendus » sans qu'on sache pourquoi.
  if v_type is not null then
    update public.ticket_types
    set quantity_sold = greatest(0, quantity_sold - 1)
    where id = v_type;
  end if;

  insert into public.notifications (user_id, type, title, body, event_id)
  select p_actor, 'ticket_cancelled', 'Ticket cancelled',
         'Your ticket for ' || e.title || ' has been cancelled.', t.event_id
  from public.tickets t join public.events e on e.id = t.event_id
  where t.id = p_ticket;
end;
$function$;

CREATE OR REPLACE FUNCTION public.cancel_ticket_for_event(p_ticket uuid, p_refund_id text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_status text;
  v_type   uuid;
begin
  select status, ticket_type_id
    into v_status, v_type
  from public.tickets
  where id = p_ticket
  for update;

  if v_status is null then raise exception 'not_found'; end if;
  if v_status <> 'valid' then return; end if;

  update public.tickets
     set status       = 'cancelled',
         cancelled_at = now(),
         refunded_at  = case when p_refund_id is not null then now() else null end,
         refund_id    = p_refund_id
   where id = p_ticket;

  if v_type is not null then
    update public.ticket_types
       set quantity_sold = greatest(quantity_sold - 1, 0)
     where id = v_type;
  end if;
end;
$function$;

CREATE OR REPLACE FUNCTION public.cancellation_fee_cents(p_price_cents bigint)
 RETURNS bigint
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  select case
    when coalesce(p_price_cents, 0) <= 0 then 0
    else least(p_price_cents,
               round(p_price_cents * t.bps / 10000.0)::bigint + t.fixed_cents)
  end
  from public.cancellation_fee_terms() t
$function$;

CREATE OR REPLACE FUNCTION public.cancellation_fee_terms(OUT bps integer, OUT fixed_cents integer)
 RETURNS record
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$ select 290, 30 $function$;

CREATE OR REPLACE FUNCTION public.claim_payout(p_event_id uuid, p_organizer_id uuid, p_account_id text, p_gross_cents bigint, p_refunded_cents bigint, p_stripe_fee_cents bigint, p_platform_fee_cents bigint, p_net_cents bigint)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_id uuid;
begin
  insert into public.event_payouts (
    event_id, organizer_id, account_id, gross_cents, refunded_cents,
    stripe_fee_cents, platform_fee_cents, net_cents, status
  ) values (
    p_event_id, p_organizer_id, p_account_id, p_gross_cents, p_refunded_cents,
    p_stripe_fee_cents, p_platform_fee_cents, p_net_cents,
    case when p_net_cents > 0 then 'pending' else 'skipped' end
  )
  -- Déjà réservé par une autre exécution : on ne renvoie rien, l'appelant
  -- passe à l'événement suivant.
  on conflict (event_id) do nothing
  returning id into v_id;

  return v_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.delete_my_account_data()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then
    raise exception 'not_authenticated';
  end if;

  -- Les gardes, dans l'ordre ou l'ecran les annonce.
  if public.deletion_paid_sales(v_user) > 0 then
    raise exception 'has_paid_sales';
  end if;
  if public.deletion_pending_earnings(v_user) > 0 then
    raise exception 'has_pending_earnings';
  end if;
  if public.deletion_paid_tickets(v_user) > 0 then
    raise exception 'has_paid_tickets';
  end if;

  -- 1. Billets VALIDES sur des evenements a venir — forcement gratuits,
  --    grace a la garde ci-dessus : la place retourne au stock, le billet
  --    disparait. Un billet deja annule a deja rendu sa place ; il est
  --    seulement detache a l'etape 2, comme les billets passes.
  update public.ticket_types tt
     set quantity_sold = greatest(coalesce(tt.quantity_sold, 0) - sub.n, 0)
  from (
    select t.ticket_type_id, count(*)::int as n
    from public.tickets t
    join public.events e on e.id = t.event_id
    where t.user_id = v_user
      and t.status = 'valid'
      and coalesce(e.end_date, e.start_date) >= now()
    group by t.ticket_type_id
  ) sub
  where tt.id = sub.ticket_type_id;

  delete from public.tickets t
  using public.events e
  where t.event_id = e.id
    and t.user_id = v_user
    and t.status = 'valid'
    and coalesce(e.end_date, e.start_date) >= now();

  -- 2. Tous les autres billets : ligne conservee, detachee du profil.
  update public.tickets set user_id = null where user_id = v_user;

  -- 2 bis. Trace d'un transfert emis par cet utilisateur.
  update public.tickets
     set transferred_from = null
   where transferred_from = v_user;

  -- 3. Evenements A VENIR avec participants : annulation (trigger = notifs).
  update public.events
     set status = 'cancelled', created_by = null
   where created_by = v_user
     and coalesce(end_date, start_date) >= now()
     and exists (select 1 from public.tickets t where t.event_id = events.id);

  -- 4. Evenements A VENIR sans participant : suppression.
  delete from public.events
   where created_by = v_user
     and coalesce(end_date, start_date) >= now();

  -- 5. Evenements PASSES : anonymisation (« Organisateur supprime »).
  update public.events set created_by = null where created_by = v_user;

  -- 6. Profil. Les conversations, elles, sont traitees par les cles
  --    etrangeres lors de la suppression du compte auth (voir plus haut).
  delete from public.profiles where id = v_user;
end;
$function$;

CREATE OR REPLACE FUNCTION public.deletion_paid_sales(p_user uuid)
 RETURNS bigint
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select count(distinct e.id)
  from public.events e
  join public.ticket_types tt on tt.event_id = e.id
  where e.created_by = p_user
    and coalesce(e.status, 'published') <> 'cancelled'
    and coalesce(e.end_date, e.start_date) >= now()
    and coalesce(tt.price, 0) > 0
    and coalesce(tt.quantity_sold, 0) > 0;
$function$;

CREATE OR REPLACE FUNCTION public.deletion_paid_tickets(p_user uuid)
 RETURNS bigint
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select count(*)
  from public.tickets t
  join public.events e on e.id = t.event_id
  where t.user_id = p_user
    and t.status = 'valid'
    and coalesce(e.end_date, e.start_date) >= now()
    and public.ticket_paid_cents(t.id) > 0;
$function$;

CREATE OR REPLACE FUNCTION public.deletion_pending_earnings(p_user uuid)
 RETURNS bigint
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select count(*)
  from public.events e
  join public.event_ledger() l on l.event_id = e.id
  where e.created_by = p_user
    and coalesce(e.status, 'published') <> 'cancelled'
    and l.gross - l.withheld - l.stripe_fee - l.platform_fee > 0
    and not exists (
      select 1 from public.event_payouts pay
      where pay.event_id = e.id and pay.status = 'paid'
    );
$function$;

CREATE OR REPLACE FUNCTION public.direct_conversation_is_open(p_conversation uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1 from public.direct_conversations c
    where c.id = p_conversation
      and c.member_a is not null
      and c.member_b is not null
  );
$function$;

CREATE OR REPLACE FUNCTION public.event_cancellation_preview(p_event uuid)
 RETURNS TABLE(ticket_count integer, refund_total numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists (
    select 1 from public.events e
    where e.id = p_event and e.created_by = auth.uid()
  ) then
    raise exception 'not_organizer';
  end if;

  return query
  select count(*)::integer,
         coalesce(sum(coalesce(tt.price, 0)), 0)::numeric
  from public.tickets t
  left join public.ticket_types tt on tt.id = t.ticket_type_id
  where t.event_id = p_event
    and t.status = 'valid';
end;
$function$;

CREATE OR REPLACE FUNCTION public.event_has_sales(p_event uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (select 1 from public.tickets where event_id = p_event)
      or exists (select 1 from public.payments where event_id = p_event);
$function$;

CREATE OR REPLACE FUNCTION public.event_is_readable(p_event uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1 from public.events e
    where e.id = p_event
      and (
        coalesce(e.visibility, 'public') = 'public'
        or e.created_by = auth.uid()
        or public.user_holds_ticket_for(e.id)
        or exists (
          select 1 from public.event_unlocks u
          where u.event_id = e.id and u.user_id = auth.uid()
        )
      )
  );
$function$;

CREATE OR REPLACE FUNCTION public.event_ledger()
 RETURNS TABLE(event_id uuid, gross bigint, withheld bigint, stripe_fee bigint, platform_fee bigint)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select
    p.event_id,
    sum(p.gross_cents)::bigint,
    -- Tout ce qui ne reste pas : remboursements, et la totalité d'un paiement
    -- contesté. Regroupés parce qu'ils ont le même effet sur le versement —
    -- l'argent n'est plus là.
    sum(case
          when p.disputed_at is not null then p.gross_cents
          else least(p.refunded_cents, p.gross_cents)
        end)::bigint,
    sum(coalesce(p.stripe_fee_cents, 0))::bigint,
    -- La commission se calcule paiement par paiement, sur ce qui est réellement
    -- conservé AU TITRE DES VENTES, puis s'additionne. L'appliquer au total
    -- ferait payer une commission sur des billets remboursés ; l'appliquer aux
    -- frais retenus, sur des billets annulés.
    sum(round(
      greatest(
        p.gross_cents
          - case when p.disputed_at is not null then p.gross_cents
                 else least(p.refunded_cents, p.gross_cents) end
          - case when p.disputed_at is not null then 0
                 else p.retained_fee_cents end,
        0)::numeric
      * p.platform_fee_bps / 10000))::bigint
  from public.payments p
  group by p.event_id;
$function$;

CREATE OR REPLACE FUNCTION public.event_posts_are_public(p_event uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(
    (select coalesce(e.posts_visibility, 'public') = 'public'
       from public.events e
      where e.id = p_event),
    false
  );
$function$;

CREATE OR REPLACE FUNCTION public.event_tickets_to_refund(p_event uuid)
 RETURNS TABLE(ticket_id uuid, payment_intent_id text, amount numeric)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select t.id,
         t.payment_intent_id,
         public.ticket_paid_cents(t.id)::numeric / 100
  from public.tickets t
  where t.event_id = p_event
    and t.status = 'valid'
  order by t.purchased_at;
$function$;

CREATE OR REPLACE FUNCTION public.events_due_for_payout()
 RETURNS TABLE(event_id uuid, event_title text, organizer_id uuid, account_id text, gross_cents bigint, refunded_cents bigint, stripe_fee_cents bigint, platform_fee_cents bigint, net_cents bigint)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select
    e.id,
    e.title,
    e.created_by,
    a.account_id,
    l.gross,
    l.withheld,
    l.stripe_fee,
    l.platform_fee,
    greatest(l.gross - l.withheld - l.stripe_fee - l.platform_fee, 0)::bigint
  from public.events e
  join public.event_ledger() l on l.event_id = e.id
  join public.stripe_accounts a on a.user_id = e.created_by
  left join public.event_payouts pay on pay.event_id = e.id
  where pay.id is null
    and coalesce(e.status, 'published') <> 'cancelled'
    and e.end_date is not null
    and e.end_date + (public.payout_delay_days() || ' days')::interval < now()
    and a.transfers_enabled
    and a.disabled_reason is null
  order by e.end_date asc;
$function$;

CREATE OR REPLACE FUNCTION public.events_from_connections()
 RETURNS SETOF uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select distinct a.event_id
  from public.event_attendance a
  where a.visible_to_connections
    and a.user_id <> auth.uid()
    and exists (
      select 1 from public.follows f
      where f.follower_id = auth.uid() and f.following_id = a.user_id
    )
    and exists (
      select 1 from public.follows f
      where f.follower_id = a.user_id and f.following_id = auth.uid()
    )
    and not exists (
      select 1 from public.blocked_users b
      where (b.blocker_id = auth.uid() and b.blocked_id = a.user_id)
         or (b.blocker_id = a.user_id  and b.blocked_id = auth.uid())
    );
$function$;

CREATE OR REPLACE FUNCTION public.events_guard_cancellation()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
begin
  if new.status is distinct from old.status
     and (new.status = 'cancelled' or old.status = 'cancelled')
     and current_user in ('authenticated', 'anon') then
    raise exception 'use_cancel_event';
  end if;
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.events_lock_fee()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
begin
  if tg_op = 'INSERT' then
    new.platform_fee_bps := public.platform_fee_bps();
  else
    new.platform_fee_bps := old.platform_fee_bps;
  end if;
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.events_near(p_lat double precision, p_lng double precision, p_radius double precision DEFAULT 20)
 RETURNS TABLE(event_id uuid, distance_km double precision)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  with candidates as (
    select
      a.event_id,
      -- `least(1.0, ...)` : une imprécision de flottant peut donner
      -- 1.0000000002 à acos(), qui renvoie alors NaN pour deux points
      -- identiques — donc une distance nulle deviendrait « inconnue ».
      6371 * acos(
        least(1.0,
          cos(radians(p_lat)) * cos(radians(a.latitude))
          * cos(radians(a.longitude) - radians(p_lng))
          + sin(radians(p_lat)) * sin(radians(a.latitude))
        )
      ) as distance_km
    from public.event_addresses a
    join public.events e on e.id = a.event_id
    where a.latitude is not null
      and a.longitude is not null
      and coalesce(e.visibility, 'public') = 'public'
      and coalesce(e.status, 'published') = 'published'
      and coalesce(e.end_date, e.start_date) > now()
  )
  select event_id, distance_km
  from candidates
  where distance_km <= p_radius
  order by distance_km asc;
$function$;

CREATE OR REPLACE FUNCTION public.generate_username(p_name text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  base text;
  candidate text;
  tries int := 0;
begin
  base := lower(coalesce(p_name, ''));
  base := translate(base,
    'àâäáãåçéèêëíìîïñóòôöõúùûüýÿœæ',
    'aaaaaaceeeeiiiinooooouuuuyyoa');
  base := regexp_replace(base, '[^a-z0-9]+', '', 'g');
  base := left(base, 15);
  if length(base) < 3 or public.is_reserved_username(base) then
    base := 'user';
  end if;

  candidate := base;
  loop
    exit when not exists (
      select 1 from public.profiles where username = candidate
    ) and not public.is_reserved_username(candidate)
      and length(candidate) >= 3;
    tries := tries + 1;
    -- Quatre chiffres au hasard plutot qu'un compteur : un compteur
    -- revelerait combien de « jonathan » sont inscrits.
    candidate := base || lpad((floor(random() * 10000))::int::text, 4, '0');
    if tries > 50 then
      candidate := base || substr(md5(random()::text), 1, 6);
    end if;
  end loop;
  return candidate;
end;
$function$;

CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_dob date;
begin
  begin
    v_dob := nullif(new.raw_user_meta_data->>'date_of_birth', '')::date;
  exception when others then
    v_dob := null;
  end;

  insert into public.profiles (id, email, full_name, date_of_birth)
  values (new.id, new.email, new.raw_user_meta_data->>'full_name', v_dob);

  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.i_am_admin()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(
    (select p.is_admin from public.profiles p where p.id = auth.uid()),
    false
  );
$function$;

CREATE OR REPLACE FUNCTION public.i_meet_age(p_min integer DEFAULT 0)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$ select public.user_meets_age(auth.uid(), p_min) $function$;

CREATE OR REPLACE FUNCTION public.is_reserved_username(p text)
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  select p in (
    'admin', 'administrator', 'happyn', 'happynevents', 'support', 'help',
    'contact', 'moderator', 'moderation', 'mod', 'staff', 'team', 'official',
    'security', 'root', 'system', 'settings', 'me', 'null', 'undefined'
  ) or p like 'happyn%';
$function$;

CREATE OR REPLACE FUNCTION public.is_suspended()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(
    (select p.suspended_at is not null
       from public.profiles p where p.id = auth.uid()),
    false
  );
$function$;

CREATE OR REPLACE FUNCTION public.issue_tickets(p_ticket_type_id uuid, p_quantity integer)
 RETURNS SETOF tickets
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_user      uuid := auth.uid();
  v_event     uuid;
  v_remaining int;
  v_max       int;
  v_end       timestamptz;
  v_status    text;
  v_title     text;
  v_i         int;
  v_token     text;
  v_price     numeric;
  v_min_age   integer;
begin
  if v_user is null then raise exception 'not_authenticated'; end if;
  if p_quantity is null or p_quantity < 1 then
    raise exception 'invalid_quantity';
  end if;

  select event_id, (quantity_total - quantity_sold), coalesce(max_per_order, 10),
         coalesce(price, 0)
    into v_event, v_remaining, v_max, v_price
  from public.ticket_types where id = p_ticket_type_id for update;

  if not found then raise exception 'ticket_type_not_found'; end if;

  -- Cette fonction emet des billets SANS paiement. Elle n'est donc legitime
  -- que pour un palier gratuit ; un palier payant passe par Stripe
  -- (create-payment-intent puis le webhook, issue_tickets_paid). Avant le
  -- 2026-10-08, seule l'app faisait ce tri : un appel direct avec l'id d'un
  -- palier payant rendait des billets valides, gratuitement.
  if v_price > 0 then raise exception 'payment_required'; end if;

  -- Meme regle de visibilite que la fiche : un evenement prive ne s'obtient
  -- qu'apres l'avoir deverrouille avec son code (ou en etant organisateur).
  if not public.event_is_readable(v_event) then
    raise exception 'event_not_available';
  end if;

  select end_date, status, title, coalesce(min_age, 0)
    into v_end, v_status, v_title, v_min_age
  from public.events where id = v_event;

  if v_status <> 'published' then raise exception 'event_not_available'; end if;
  -- Depuis le 2026-10-09, aussi verifie ici et plus seulement dans l'app :
  -- un appel direct a cette fonction contournait l'age minimum d'un
  -- evenement. Sans date de naissance connue, pas de billet non plus.
  if not public.user_meets_age(v_user, v_min_age) then
    raise exception 'age_restricted';
  end if;
  if v_end is not null and v_end < now() then raise exception 'event_ended'; end if;
  if p_quantity > v_max then raise exception 'exceeds_max_per_order'; end if;
  if v_remaining < p_quantity then raise exception 'insufficient_stock'; end if;

  for v_i in 1..p_quantity loop
    v_token := 'HPN-' || replace(gen_random_uuid()::text, '-', '');
    return query
      insert into public.tickets (ticket_type_id, event_id, user_id, qr_token, status)
      values (p_ticket_type_id, v_event, v_user, v_token, 'valid')
      returning *;
  end loop;

  update public.ticket_types
     set quantity_sold = quantity_sold + p_quantity
   where id = p_ticket_type_id;

  insert into public.notifications (user_id, type, title, body, event_id)
  values (
    v_user, 'ticket_confirmed', 'Ticket confirmed',
    p_quantity::text
      || case when p_quantity > 1 then ' tickets for ' else ' ticket for ' end
      || v_title || ' are in "My Tickets".',
    v_event
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.issue_tickets_paid(p_ticket_type_id uuid, p_quantity integer, p_user_id uuid, p_payment_intent_id text)
 RETURNS SETOF tickets
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_event     uuid;
  v_remaining int;
  v_max       int;
  v_title     text;
  v_i         int;
  v_token     text;
  v_existing  int;
begin
  select count(*) into v_existing
  from public.tickets where payment_intent_id = p_payment_intent_id;

  if v_existing > 0 then
    return query select * from public.tickets
      where payment_intent_id = p_payment_intent_id;
    return;
  end if;

  if p_quantity is null or p_quantity < 1 then
    raise exception 'invalid_quantity';
  end if;

  select event_id, (quantity_total - quantity_sold), coalesce(max_per_order, 10)
    into v_event, v_remaining, v_max
  from public.ticket_types where id = p_ticket_type_id for update;

  if not found then raise exception 'ticket_type_not_found'; end if;
  if p_quantity > v_max then raise exception 'exceeds_max_per_order'; end if;
  if v_remaining < p_quantity then raise exception 'insufficient_stock'; end if;

  select title into v_title from public.events where id = v_event;

  for v_i in 1..p_quantity loop
    v_token := 'HPN-' || replace(gen_random_uuid()::text, '-', '');
    return query
      insert into public.tickets
        (ticket_type_id, event_id, user_id, qr_token, status, payment_intent_id)
      values
        (p_ticket_type_id, v_event, p_user_id, v_token, 'valid', p_payment_intent_id)
      returning *;
  end loop;

  update public.ticket_types
     set quantity_sold = quantity_sold + p_quantity
   where id = p_ticket_type_id;

  insert into public.notifications (user_id, type, title, body, event_id)
  values (
    p_user_id, 'ticket_confirmed', 'Ticket confirmed',
    p_quantity::text
      || case when p_quantity > 1 then ' tickets for ' else ' ticket for ' end
      || v_title || ' are in "My Tickets".',
    v_event
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.min_account_age()
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$ select 18 $function$;

CREATE OR REPLACE FUNCTION public.my_attachable_events()
 RETURNS SETOF events
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select e.*
  from public.events e
  where e.created_by = auth.uid()
     or exists (
       select 1 from public.tickets t
       where t.event_id = e.id
         and t.user_id = auth.uid()
     )
  order by e.start_date desc;
$function$;

CREATE OR REPLACE FUNCTION public.my_direct_conversations()
 RETURNS TABLE(conversation_id uuid, other_user_id uuid, other_name text, other_avatar text, other_username text, last_message text, last_message_at timestamp with time zone)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select
    c.id,
    p.id,
    p.full_name,
    p.avatar_url,
    p.username,
    latest.body,
    latest.created_at
  from public.direct_conversations c
  left join public.profiles p
    on p.id = case when c.member_a = auth.uid() then c.member_b else c.member_a end
  cross join lateral (
    select m.body, m.created_at
    from public.direct_messages m
    where m.conversation_id = c.id
    order by m.created_at desc, m.id desc
    limit 1
  ) latest
  where auth.uid() in (c.member_a, c.member_b)
    and public.can_access_direct_conversation(c.id)
  order by latest.created_at desc, c.id;
$function$;

CREATE OR REPLACE FUNCTION public.my_payout_account()
 RETURNS TABLE(has_account boolean, transfers_enabled boolean, payouts_enabled boolean, details_submitted boolean, blocked boolean)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select
    a.user_id is not null,
    coalesce(a.transfers_enabled, false),
    coalesce(a.payouts_enabled, false),
    coalesce(a.details_submitted, false),
    a.disabled_reason is not null
  from (select auth.uid() as uid) me
  left join public.stripe_accounts a on a.user_id = me.uid;
$function$;

CREATE OR REPLACE FUNCTION public.my_payouts()
 RETURNS TABLE(event_id uuid, event_title text, event_end timestamp with time zone, gross_cents bigint, refunded_cents bigint, stripe_fee_cents bigint, platform_fee_cents bigint, net_cents bigint, status text, paid_at timestamp with time zone, eligible_at timestamp with time zone)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select
    e.id,
    e.title,
    e.end_date,
    coalesce(pay.gross_cents,        l.gross)::bigint,
    coalesce(pay.refunded_cents,     l.withheld)::bigint,
    coalesce(pay.stripe_fee_cents,   l.stripe_fee)::bigint,
    coalesce(pay.platform_fee_cents, l.platform_fee)::bigint,
    coalesce(
      pay.net_cents,
      greatest(l.gross - l.withheld - l.stripe_fee - l.platform_fee, 0)
    )::bigint,
    -- Annule sans versement : jamais « a venir ». L'ecran affichait 41,34 $
    -- « Upcoming » pour un evenement annule, qui ne sera jamais verse.
    case
      when pay.status is not null then pay.status
      when coalesce(e.status, 'published') = 'cancelled' then 'cancelled'
      else 'pending'
    end,
    pay.paid_at,
    e.end_date + (public.payout_delay_days() || ' days')::interval
  from public.events e
  -- `join` et non `left join` : un événement qui n'a rien encaissé n'a rien à
  -- montrer ici. L'écran liste des versements, pas des événements.
  join public.event_ledger() l on l.event_id = e.id
  left join public.event_payouts pay on pay.event_id = e.id
  where e.created_by = auth.uid()
  order by e.end_date desc nulls last;
$function$;

CREATE OR REPLACE FUNCTION public.notify_direct_message()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_recipient uuid;
  v_sender    text;
  v_lang      text;
  v_preview   text;
begin
  select case when c.member_a = new.sender_id then c.member_b else c.member_a end
    into v_recipient
  from public.direct_conversations c
  where c.id = new.conversation_id;

  if v_recipient is null then
    return new;
  end if;

  -- Un blocage dans un sens ou dans l'autre coupe la notification. La
  -- politique d'insertion devrait deja l'avoir empeche, mais une notification
  -- poussee est visible sur un ecran verrouille : on verifie deux fois plutot
  -- que de faire apparaitre le nom de quelqu'un qu'on a bloque.
  if exists (
    select 1 from public.blocked_users b
    where (b.blocker_id = v_recipient and b.blocked_id = new.sender_id)
       or (b.blocker_id = new.sender_id and b.blocked_id = v_recipient)
  ) then
    return new;
  end if;

  select coalesce(nullif(trim(p.full_name), ''), p.username, 'HAPPYN')
    into v_sender
  from public.profiles p
  where p.id = new.sender_id;

  select p.language into v_lang from public.profiles p where p.id = v_recipient;

  -- Tronque : une notification est un apercu, pas le message. 2000
  -- caracteres sur un ecran verrouille n'aident personne.
  v_preview := left(trim(new.body), 140);
  if v_preview = '' then
    v_preview := case
      when new.shared_kind = 'post'  and v_lang = 'fr' then 'A partagé une publication'
      when new.shared_kind = 'post'                    then 'Shared a post'
      when new.shared_kind = 'event' and v_lang = 'fr' then 'A partagé un événement'
      when new.shared_kind = 'event'                   then 'Shared an event'
      else v_preview
    end;
  end if;

  delete from public.notifications
  where user_id = v_recipient
    and type = 'direct_message'
    and conversation_id = new.conversation_id
    and read = false;

  insert into public.notifications
    (user_id, type, title, body, conversation_id)
  values (
    v_recipient,
    'direct_message',
    coalesce(v_sender, 'HAPPYN'),
    v_preview,
    new.conversation_id
  );

  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.notify_event_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_type  text;
  v_title text;
  v_body  text;
begin
  if new.status = 'cancelled' and old.status is distinct from 'cancelled' then
    v_type  := 'event_cancelled';
    v_title := 'Event cancelled';
    v_body  := new.title || ' has been cancelled by the organizer.';
  elsif (new.start_date is distinct from old.start_date)
     or (new.end_date   is distinct from old.end_date)
     or (new.location   is distinct from old.location)
     or (new.city       is distinct from old.city) then
    v_type  := 'event_updated';
    v_title := 'Event details changed';
    v_body  := new.title || ' was updated — check the new date or location.';
  else
    return new; -- rien à notifier
  end if;

  -- Une ligne par personne. La phrase sur le remboursement n'est ajoutee qu'a
  -- celles qui ont paye quelque chose : `bool_or(price > 0)` regarde TOUS les
  -- billets d'une meme personne, puisqu'elle peut en avoir plusieurs.
  insert into public.notifications (user_id, type, title, body, event_id)
  select
    t.user_id,
    v_type,
    v_title,
    case
      when v_type = 'event_cancelled'
       and bool_or(coalesce(tt.price, 0) > 0)
      then v_body || ' Your refund is on its way — allow 5 to 10 business '
                  || 'days to see it on your card.'
      else v_body
    end,
    new.id
  from public.tickets t
  left join public.ticket_types tt on tt.id = t.ticket_type_id
  where t.event_id = new.id
  group by t.user_id;

  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.notify_post_comment()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_author  uuid;
  v_name    text;
  v_lang    text;
  v_preview text;
begin
  select p.author_id into v_author from public.posts p where p.id = new.post_id;

  -- Pas de notification pour soi-meme, ni de la part de quelqu'un de bloque.
  if v_author is null
     or v_author = new.author_id
     or public.blocked_either_way(v_author, new.author_id) then
    return new;
  end if;

  select coalesce(nullif(trim(p.full_name), ''), p.username, 'HAPPYN')
    into v_name
  from public.profiles p where p.id = new.author_id;

  select p.language into v_lang from public.profiles p where p.id = v_author;

  v_preview := left(trim(new.body), 120);
  v_preview := case
    when v_lang = 'fr' then 'A commenté : « ' || v_preview || ' »'
    else                    'Commented: “' || v_preview || '”'
  end;

  -- Une ligne par publication, pas une par commentaire : la precedente non
  -- lue est remplacee. Dix reactions a une photo ne font pas dix bulles.
  delete from public.notifications
  where user_id = v_author
    and type = 'post_comment'
    and post_id = new.post_id
    and read = false;

  insert into public.notifications (user_id, type, title, body, post_id)
  values (v_author, 'post_comment', coalesce(v_name, 'HAPPYN'), v_preview,
          new.post_id);

  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.organizer_attendees(p_event uuid)
 RETURNS TABLE(ticket_id uuid, full_name text, avatar_url text, type_name text, status text, purchased_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists (
    select 1 from public.events e
    where e.id = p_event and e.created_by = auth.uid()
  ) then
    raise exception 'not_organizer';
  end if;

  return query
  select
    t.id,
    coalesce(nullif(trim(p.full_name), ''), 'Invite'),
    p.avatar_url,
    tt.name,
    t.status,
    t.purchased_at
  from public.tickets t
  left join public.profiles p on p.id = t.user_id
  left join public.ticket_types tt on tt.id = t.ticket_type_id
  where t.event_id = p_event
    and t.status <> 'cancelled'
  order by (t.status = 'used'), lower(coalesce(p.full_name, '')) asc;
end;
$function$;

CREATE OR REPLACE FUNCTION public.organizer_event_stats(p_event uuid)
 RETURNS TABLE(ticket_type_id uuid, name text, price numeric, quantity_total integer, quantity_sold integer, used_count integer, cancelled_count integer, gross_revenue numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists (
    select 1 from public.events e
    where e.id = p_event and e.created_by = auth.uid()
  ) then
    raise exception 'not_organizer';
  end if;

  return query
  select
    tt.id,
    tt.name,
    tt.price,
    tt.quantity_total,
    tt.quantity_sold,
    (select count(*)::int from public.tickets t
      where t.ticket_type_id = tt.id and t.status = 'used'),
    (select count(*)::int from public.tickets t
      where t.ticket_type_id = tt.id and t.status = 'cancelled'),
    -- Recette BRUTE : ce que les acheteurs ont payé, avant frais Stripe et
    -- avant toute commission. Ne jamais l'appeler « revenu » dans l'interface —
    -- ce n'est pas ce que l'organisateur touchera.
    (tt.price * tt.quantity_sold)
  from public.ticket_types tt
  where tt.event_id = p_event
  order by tt.price asc;
end;
$function$;

CREATE OR REPLACE FUNCTION public.organizer_is_payable(p_organizer uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(
    (select transfers_enabled and disabled_reason is null
       from public.stripe_accounts where user_id = p_organizer),
    false);
$function$;

CREATE OR REPLACE FUNCTION public.payout_delay_days()
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$ select 3 $function$;

CREATE OR REPLACE FUNCTION public.pending_legal_documents(p_locale text DEFAULT NULL::text)
 RETURNS TABLE(slug text, title text, version text, previously_accepted boolean)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select d.slug,
         coalesce(t.title, d.title),
         d.version,
         exists (select 1 from public.user_legal_acceptances a
                 where a.user_id = auth.uid() and a.slug = d.slug)
  from public.legal_documents d
  left join public.legal_document_translations t
         on t.slug = d.slug and t.locale = p_locale and t.version = d.version
  where d.requires_acceptance
    and auth.uid() is not null
    and not exists (
      select 1 from public.user_legal_acceptances a
      where a.user_id = auth.uid()
        and a.slug = d.slug
        and a.version = d.version
    )
  order by d.sort_order;
$function$;

CREATE OR REPLACE FUNCTION public.platform_fee_bps()
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$ select 500 $function$;

CREATE OR REPLACE FUNCTION public.posts_mark_edited()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
begin
  new.author_id  := old.author_id;
  new.created_at := old.created_at;

  if new.caption is distinct from old.caption
     or new.image_url is distinct from old.image_url then
    new.edited_at := now();
  else
    -- Un like ne modifie pas la publication : seul un changement de contenu
    -- doit marquer la ligne.
    new.edited_at := old.edited_at;
  end if;

  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.prevent_delete_with_tickets()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
begin
  if exists (select 1 from public.tickets where event_id = old.id) then
    raise exception 'event_has_tickets';
  end if;
  return old;
end;
$function$;

CREATE OR REPLACE FUNCTION public.prevent_self_admin()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if new.is_admin is distinct from old.is_admin
     and current_setting('role', true) in ('authenticated', 'anon') then
    raise exception 'is_admin ne peut etre accorde que depuis le tableau de bord';
  end if;
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.profile_follows(p_user uuid, p_kind text)
 RETURNS TABLE(id uuid, full_name text, username text, avatar_url text, followed_at timestamp with time zone)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select p.id, p.full_name, p.username, p.avatar_url, f.created_at
  from public.follows f
  join public.profiles p
    on p.id = case when p_kind = 'followers' then f.follower_id
                   else f.following_id end
  where auth.uid() is not null
    and p_kind in ('followers', 'following')
    and (case when p_kind = 'followers' then f.following_id
              else f.follower_id end) = p_user
    and p.suspended_at is null
    and not exists (
      select 1 from public.blocked_users b
      where (b.blocker_id = auth.uid() and b.blocked_id = p.id)
         or (b.blocker_id = p.id and b.blocked_id = auth.uid())
    )
  order by f.created_at desc
  limit 500;
$function$;

CREATE OR REPLACE FUNCTION public.profiles_guard_birth_date()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
begin
  -- Figée une fois connue, sauf pour le serveur (correction d'une erreur
  -- signalée au support). `current_user` et non `auth.role()` : c'est le rôle
  -- réellement en cours, celui qu'on ne peut pas prétendre.
  if tg_op = 'UPDATE'
     and old.date_of_birth is not null
     and new.date_of_birth is distinct from old.date_of_birth
     and current_user in ('authenticated', 'anon') then
    raise exception 'birth_date_locked';
  end if;

  if new.date_of_birth is not null
     and new.date_of_birth > (current_date - make_interval(years => public.min_account_age()))::date then
    raise exception 'under_minimum_age';
  end if;
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.profiles_guard_suspension()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
begin
  if new.suspended_at is distinct from old.suspended_at
     and current_user in ('authenticated', 'anon') then
    raise exception 'suspension_admin_only';
  end if;
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.profiles_username_guard()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
begin
  if new.username is not null then
    new.username := lower(trim(new.username));
  end if;

  if new.username is null or new.username = '' then
    new.username := public.generate_username(new.full_name);
  elsif (tg_op = 'INSERT' or new.username is distinct from old.username)
        and public.is_reserved_username(new.username) then
    raise exception 'username_reserved' using errcode = '23514';
  end if;
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.purge_orphan_conversation()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if new.member_a is null and new.member_b is null then
    delete from public.direct_conversations where id = new.id;
  end if;
  return null;
end;
$function$;

CREATE OR REPLACE FUNCTION private.push_notification()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'private', 'public', 'extensions'
AS $function$
declare
  v_url    text := private.setting('push_hook_url');
  v_secret text := private.setting('push_hook_secret');
begin
  if v_url is null or v_secret is null then
    return new;  -- Base non configuree : on n'envoie pas, on n'echoue pas.
  end if;

  perform net.http_post(
    url     := v_url,
    headers := jsonb_build_object(
                 'Content-Type',    'application/json',
                 'x-happyn-secret', v_secret
               ),
    body    := jsonb_build_object('record', to_jsonb(new))
  );
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.record_dispute(p_payment_intent_id text, p_open boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  update public.payments
     set disputed_at = case when p_open then coalesce(disputed_at, now()) else null end
   where payment_intent_id = p_payment_intent_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.record_payment(p_payment_intent_id text, p_event_id uuid, p_organizer_id uuid, p_buyer_id uuid, p_ticket_type_id uuid, p_quantity integer, p_gross_cents bigint, p_stripe_fee_cents bigint, p_platform_fee_bps integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  insert into public.payments (
    payment_intent_id, event_id, organizer_id, buyer_id, ticket_type_id,
    quantity, gross_cents, stripe_fee_cents, platform_fee_bps
  ) values (
    p_payment_intent_id, p_event_id, p_organizer_id, p_buyer_id, p_ticket_type_id,
    p_quantity, p_gross_cents, p_stripe_fee_cents, p_platform_fee_bps
  )
  on conflict (payment_intent_id) do update
    -- Le montant brut ne se corrige pas : s'il différait, c'est un incident, pas
    -- une mise à jour. Seuls les frais peuvent arriver en retard (la
    -- `balance_transaction` n'est pas toujours disponible au premier webhook).
    set stripe_fee_cents = coalesce(
          excluded.stripe_fee_cents, payments.stripe_fee_cents);
end;
$function$;

CREATE OR REPLACE FUNCTION public.record_refund(p_payment_intent_id text, p_refunded_cents bigint)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  update public.payments
     set refunded_cents = greatest(refunded_cents, p_refunded_cents)
   where payment_intent_id = p_payment_intent_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.record_stripe_fee(p_payment_intent_id text, p_fee_cents bigint)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if p_fee_cents is null or p_fee_cents < 0 then
    return;
  end if;

  update public.payments
     set stripe_fee_cents = p_fee_cents
   where payment_intent_id = p_payment_intent_id
     -- Seulement si le chiffre manque. `charge.updated` est emis a chaque
     -- modification de la charge — un remboursement, par exemple — et il ne
     -- doit jamais ecraser des frais deja etablis.
     and stripe_fee_cents is null;
end;
$function$;

CREATE OR REPLACE FUNCTION public.reports_fill_label()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  new.target_label := case new.target_type
    when 'event' then (select e.title from public.events e where e.id = new.target_id)
    when 'post'  then (select coalesce(nullif(trim(p.caption), ''), '(image)')
                         from public.posts p where p.id = new.target_id)
    when 'user'  then (select pr.full_name from public.profiles pr where pr.id = new.target_id)
    when 'message' then (select left(m.body, 120)
                           from public.direct_messages m where m.id = new.target_id)
    when 'comment' then (select left(c.body, 120)
                           from public.post_comments c where c.id = new.target_id)
  end;
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.restore_cancelled_event(p_event uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_status text;
begin
  select status into v_status
  from public.events
  where id = p_event and created_by = auth.uid();

  if v_status is null then raise exception 'not_organizer'; end if;
  if v_status <> 'cancelled' then raise exception 'not_cancelled'; end if;
  if public.event_has_sales(p_event) then raise exception 'event_had_sales'; end if;

  update public.events set status = 'draft' where id = p_event;
end;
$function$;

CREATE OR REPLACE FUNCTION public.rls_auto_enable()
 RETURNS event_trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog'
AS $function$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
  LOOP
     IF cmd.schema_name IS NOT NULL AND cmd.schema_name IN ('public') AND cmd.schema_name NOT IN ('pg_catalog','information_schema') AND cmd.schema_name NOT LIKE 'pg_toast%' AND cmd.schema_name NOT LIKE 'pg_temp%' THEN
      BEGIN
        EXECUTE format('alter table if exists %s enable row level security', cmd.object_identity);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
     ELSE
        RAISE LOG 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
     END IF;
  END LOOP;
END;
$function$;

CREATE OR REPLACE FUNCTION public.search_profiles(q text)
 RETURNS TABLE(id uuid, full_name text, username text, avatar_url text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  with needle as (
    select ltrim(lower(trim(coalesce(q, ''))), '@') as n
  ),
  esc as (
    select n,
           replace(replace(replace(n, '\', '\\'), '%', '\%'), '_', '\_') as e
    from needle
  )
  select p.id, p.full_name, p.username, p.avatar_url
  from public.profiles p, esc
  where auth.uid() is not null
    and length(esc.n) >= 2
    and p.suspended_at is null
    and (
      p.username like esc.e || '%'
      or lower(coalesce(p.full_name, '')) like '%' || esc.e || '%'
    )
    and not exists (
      select 1 from public.blocked_users b
      where (b.blocker_id = auth.uid() and b.blocked_id = p.id)
         or (b.blocker_id = p.id and b.blocked_id = auth.uid())
    )
  -- Identifiant exact d'abord, puis debut d'identifiant, puis le nom.
  order by (p.username = esc.n) desc,
           (p.username like esc.e || '%') desc,
           p.full_name asc
  limit 20;
$function$;

CREATE OR REPLACE FUNCTION public.set_attendance_visibility(p_event uuid, p_visible boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;

  update public.event_attendance
     set visible_to_connections = p_visible,
         updated_at = now()
   where user_id = auth.uid()
     and event_id = p_event;

  if not found then
    raise exception 'not_attending';
  end if;
end;
$function$;

CREATE OR REPLACE FUNCTION private.setting(p_key text)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'private', 'public'
AS $function$
  select value from private.settings where key = p_key;
$function$;

CREATE OR REPLACE FUNCTION public.settle_payout(p_payout_id uuid, p_transfer_id text, p_failure text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  update public.event_payouts
     set status         = case when p_transfer_id is not null then 'paid' else 'failed' end,
         transfer_id    = p_transfer_id,
         failure_reason = p_failure,
         paid_at        = case when p_transfer_id is not null then now() else null end
   where id = p_payout_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.start_direct_conversation(p_recipient uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_user uuid := auth.uid();
  v_a uuid;
  v_b uuid;
  v_id uuid;
begin
  if v_user is null then
    raise exception 'not_authenticated';
  end if;
  if p_recipient is null or p_recipient = v_user then
    raise exception 'invalid_recipient';
  end if;
  if not exists (
    select 1 from public.follows
    where follower_id = v_user and following_id = p_recipient
  ) then
    raise exception 'must_follow_recipient';
  end if;
  if exists (
    select 1 from public.blocked_users
    where (blocker_id = v_user and blocked_id = p_recipient)
       or (blocker_id = p_recipient and blocked_id = v_user)
  ) then
    raise exception 'messaging_blocked';
  end if;

  v_a := least(v_user, p_recipient);
  v_b := greatest(v_user, p_recipient);

  insert into public.direct_conversations (member_a, member_b)
  values (v_a, v_b)
  on conflict (member_a, member_b) do nothing;

  select id into v_id
  from public.direct_conversations
  where member_a = v_a and member_b = v_b;

  return v_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.sync_event_attendance()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  -- Billet créé ou modifié : garantir la présence du porteur actuel
  if (tg_op = 'INSERT' or tg_op = 'UPDATE') and new.user_id is not null then
    insert into public.event_attendance (user_id, event_id, status)
    values (new.user_id, new.event_id, 'going')
    on conflict (user_id, event_id) do nothing;

    -- Scanné à l'entrée → présence confirmée
    if new.status = 'used' then
      update public.event_attendance
         set status = 'attended', updated_at = now()
       where user_id = new.user_id
         and event_id = new.event_id
         and status <> 'attended';
    end if;
  end if;

  -- Transfert : l'ancien porteur perd sa présence s'il n'a plus aucun billet
  if tg_op = 'UPDATE' and old.user_id is distinct from new.user_id
     and old.user_id is not null then
    delete from public.event_attendance a
     where a.user_id = old.user_id
       and a.event_id = old.event_id
       and not exists (
         select 1 from public.tickets t
         where t.user_id = old.user_id and t.event_id = old.event_id
       );
  end if;

  -- Billet supprimé (annulation, suppression de compte) : même règle
  if tg_op = 'DELETE' and old.user_id is not null then
    delete from public.event_attendance a
     where a.user_id = old.user_id
       and a.event_id = old.event_id
       and not exists (
         select 1 from public.tickets t
         where t.user_id = old.user_id and t.event_id = old.event_id
       );
    return old;
  end if;

  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.ticket_paid_cents(p_ticket uuid)
 RETURNS bigint
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(
    -- Ce qui a vraiment ete encaisse, divise par le nombre de billets de la
    -- meme transaction. Un achat groupe partage son montant.
    (select floor(pay.gross_cents::numeric / greatest(pay.quantity, 1))::bigint
       from public.payments pay
       join public.tickets t2 on t2.payment_intent_id = pay.payment_intent_id
      where t2.id = p_ticket
      limit 1),
    -- Billet d'avant le registre, ou billet gratuit.
    (select round(coalesce(tt.price, 0) * 100)::bigint
       from public.tickets t3
       left join public.ticket_types tt on tt.id = t3.ticket_type_id
      where t3.id = p_ticket),
    0
  );
$function$;

CREATE OR REPLACE FUNCTION public.transfer_ticket_to_user(p_ticket_id uuid, p_recipient uuid)
 RETURNS tickets
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_user      uuid := auth.uid();
  v_owner     uuid;
  v_event     uuid;
  v_status    text;
  v_ended     boolean;
  v_ev_status text;
  v_min_age   integer;
  v_dob       date;
  v_new_token text;
  v_ticket    public.tickets;
begin
  if v_user is null then
    raise exception 'not_authenticated';
  end if;

  -- Verrou de ligne : deux transferts simultanes du meme billet ne doivent
  -- pas pouvoir partir chacun vers quelqu'un. Variables scalaires : un
  -- SELECT ... INTO rowtype mapperait par position.
  select user_id, event_id, status
    into v_owner, v_event, v_status
  from public.tickets
  where id = p_ticket_id
  for update;

  if not found then
    raise exception 'ticket_not_found';
  end if;
  if v_owner is distinct from v_user then
    raise exception 'not_ticket_owner';
  end if;
  if coalesce(v_status, 'valid') <> 'valid' then
    raise exception 'ticket_not_transferable'; -- deja scanne / annule
  end if;

  select (end_date < now()), coalesce(status, 'published'), coalesce(min_age, 0)
    into v_ended, v_ev_status, v_min_age
  from public.events
  where id = v_event;

  if v_ev_status = 'cancelled' then
    raise exception 'event_cancelled';
  end if;
  if coalesce(v_ended, false) then
    raise exception 'event_ended';
  end if;

  if p_recipient is null or p_recipient = v_user then
    raise exception 'cannot_transfer_self';
  end if;

  -- Seulement a quelqu'un qu'on suit : c'est la meme porte que pour lui
  -- ecrire (`start_direct_conversation`).
  if not exists (
    select 1 from public.follows
    where follower_id = v_user and following_id = p_recipient
  ) then
    raise exception 'not_following_recipient';
  end if;

  -- Un blocage, dans un sens ou dans l'autre, ferme aussi cette porte. Le
  -- message est le meme dans les deux cas : dire « il t'a bloque » serait une
  -- information que l'autre n'a pas choisi de donner.
  if exists (
    select 1 from public.blocked_users
    where (blocker_id = v_user and blocked_id = p_recipient)
       or (blocker_id = p_recipient and blocked_id = v_user)
  ) then
    raise exception 'transfer_not_allowed';
  end if;

  -- L'age : la regle qui s'applique a l'achat s'applique au transfert, sinon
  -- le transfert devient le moyen de la contourner. Un age inconnu ne passe
  -- pas un evenement avec age minimum. Une seule erreur pour « trop jeune »
  -- et « inconnu » : on ne revele pas l'age de quelqu'un a un tiers.
  if v_min_age > 0 then
    select date_of_birth into v_dob from public.profiles where id = p_recipient;
    if v_dob is null
       or extract(year from age(current_date, v_dob)) < v_min_age then
      raise exception 'recipient_age_requirement';
    end if;
  end if;

  -- Nouveau jeton : l'ancien QR (capture d'ecran comprise) ne vaut plus rien.
  v_new_token := 'HPN-' || replace(gen_random_uuid()::text, '-', '');

  update public.tickets
     set user_id          = p_recipient,
         qr_token         = v_new_token,
         transferred_from = v_user,
         transferred_at   = now()
   where id = p_ticket_id
  returning * into v_ticket;

  -- Meme texte qu'avant, mot pour mot : `translate_notification` le reconnait
  -- par son type et l'ecrit en francais pour un destinataire francophone.
  insert into public.notifications (user_id, type, title, body, event_id)
  select p_recipient,
         'ticket_received',
         'Ticket received 🎟️',
         'You received a ticket for ' || e.title || '. Find it in “My Tickets”.',
         v_event
  from public.events e
  where e.id = v_event;

  return v_ticket;
end;
$function$;

CREATE OR REPLACE FUNCTION public.translate_notification()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_lang  text;
  v_event text;
  v_qty   integer;
  -- Les variables PL/pgSQL ne sont pas annulees par une exception : sans ces
  -- copies, une erreur entre le titre et le texte enverrait un titre francais
  -- sur un texte anglais.
  v_title text := new.title;
  v_body  text := new.body;
begin
  select p.language into v_lang from public.profiles p where p.id = new.user_id;
  if v_lang is distinct from 'fr' then
    return new;
  end if;

  if new.event_id is not null then
    select e.title into v_event from public.events e where e.id = new.event_id;
  end if;
  -- Sans titre (evenement supprime entre-temps), on garde l'anglais plutot
  -- que d'envoyer une phrase francaise trouee.
  if v_event is null and new.type <> 'direct_message' then
    return new;
  end if;

  -- Le titre est toujours introduit par « L'evenement » : il peut etre
  -- feminin (« Soiree... »), et accorder le participe sur lui serait faux une
  -- fois sur deux.
  --
  -- La version francaise dit exactement ce que dit l'anglaise : la quantite
  -- et la mention du remboursement sont lues dans le texte d'origine, pas
  -- recalculees. Deux calculs finiraient par se contredire.
  case new.type
    when 'ticket_confirmed' then
      v_qty := nullif(substring(new.body from '^\d+'), '')::integer;
      new.title := 'Billet confirmé';
      new.body := case
        when v_qty is null then 'Tes billets pour ' || v_event || ' sont dans « Mes billets ».'
        when v_qty = 1     then '1 billet pour ' || v_event || ' est dans « Mes billets ».'
        else v_qty::text || ' billets pour ' || v_event || ' sont dans « Mes billets ».'
      end;

    when 'event_cancelled' then
      new.title := 'Événement annulé';
      new.body := 'L''événement « ' || v_event || ' » a été annulé par l''organisateur.'
        || case when new.body like '%Your refund is on its way%'
                then ' Ton remboursement est en route — compte 5 à 10 jours '
                     || 'ouvrables pour le voir sur ta carte.'
                else '' end;

    when 'event_updated' then
      new.title := 'Événement modifié';
      new.body := 'L''événement « ' || v_event || ' » a été modifié — vérifie la nouvelle date ou le nouveau lieu.';

    when 'ticket_received' then
      new.title := 'Billet reçu 🎟️';
      new.body := 'Tu as reçu un billet pour ' || v_event || '. Retrouve-le dans « Mes billets ».';

    when 'ticket_cancelled' then
      new.title := 'Billet annulé';
      new.body := 'Ton billet pour ' || v_event || ' a été annulé.';

    else
      -- `direct_message` : le titre est le nom de l'expediteur et le texte est
      -- ce qu'il a ecrit. Rien a traduire. Un type inconnu reste tel quel.
      null;
  end case;

  return new;
exception when others then
  -- Jamais d'achat annule pour une phrase : on garde l'anglais.
  new.title := v_title;
  new.body  := v_body;
  raise warning 'translate_notification: % (%), notification laissee en anglais',
    sqlerrm, new.type;
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.unlock_private_event(p_code text)
 RETURNS SETOF events
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_code  text := upper(trim(p_code));
  v_event uuid;
begin
  select id into v_event
  from public.events
  where visibility = 'private'
    and upper(access_code) = v_code
  limit 1;

  if v_event is null then
    return;
  end if;

  if auth.uid() is not null then
    insert into public.event_unlocks (user_id, event_id)
    values (auth.uid(), v_event)
    on conflict do nothing;
  end if;

  -- L'adresse précise n'est PAS ici : elle est dans `event_addresses`, dont la
  -- policy exige un billet. Déverrouiller donne accès à l'événement, pas à son
  -- emplacement exact.
  return query select * from public.events where id = v_event;
end;
$function$;

CREATE OR REPLACE FUNCTION public.user_holds_ticket_for(p_event uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1
    from public.tickets
    where event_id = p_event
      and user_id = auth.uid()
  );
$function$;

CREATE OR REPLACE FUNCTION public.user_meets_age(p_user uuid, p_min integer DEFAULT 0)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce((
    select p.date_of_birth
             <= (current_date - make_interval(
                   years => greatest(coalesce(p_min, 0), public.min_account_age())))::date
    from public.profiles p where p.id = p_user
  ), false)
$function$;

CREATE OR REPLACE FUNCTION public.username_status(p text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  u text := lower(trim(coalesce(p, '')));
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;
  if u !~ '^[a-z0-9._]{3,20}$' or u ~ '^\.|\.$|\.\.' then
    return 'invalid';
  end if;
  if public.is_reserved_username(u) then
    return 'reserved';
  end if;
  if exists (
    select 1 from public.profiles where username = u and id <> auth.uid()
  ) then
    return 'taken';
  end if;
  return 'ok';
end;
$function$;

CREATE OR REPLACE FUNCTION public.who_is_going(p_event uuid)
 RETURNS TABLE(id uuid, full_name text, avatar_url text, status text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select p.id, p.full_name, p.avatar_url, a.status
  from public.event_attendance a
  join public.profiles p on p.id = a.user_id
  where a.event_id = p_event
    and a.visible_to_connections
    and a.user_id <> auth.uid()
    -- suivi réciproque, dans les deux sens
    and exists (
      select 1 from public.follows f
      where f.follower_id = auth.uid() and f.following_id = a.user_id
    )
    and exists (
      select 1 from public.follows f
      where f.follower_id = a.user_id and f.following_id = auth.uid()
    )
    -- ni bloqué, ni bloquant
    and not exists (
      select 1 from public.blocked_users b
      where (b.blocker_id = auth.uid() and b.blocked_id = a.user_id)
         or (b.blocker_id = a.user_id  and b.blocked_id = auth.uid())
    )
  order by a.created_at desc;
$function$;

alter table public."admin_actions" alter column "id" set default gen_random_uuid();

alter table public."admin_actions" alter column "created_at" set default now();

alter table public."blocked_users" alter column "created_at" set default now();

alter table public."categories" alter column "id" set default gen_random_uuid();

alter table public."categories" alter column "created_at" set default now();

alter table public."categories" alter column "sort_order" set default 0;

alter table public."categories" alter column "is_active" set default true;

alter table public."cities" alter column "country" set default 'Canada'::text;

alter table public."cities" alter column "radius_km" set default 20;

alter table public."cities" alter column "sort_order" set default 100;

alter table public."device_tokens" alter column "created_at" set default now();

alter table public."device_tokens" alter column "updated_at" set default now();

alter table public."direct_conversations" alter column "id" set default gen_random_uuid();

alter table public."direct_conversations" alter column "created_at" set default now();

alter table public."direct_messages" alter column "id" set default gen_random_uuid();

alter table public."direct_messages" alter column "created_at" set default now();

alter table public."event_addresses" alter column "created_at" set default now();

alter table public."event_addresses" alter column "updated_at" set default now();

alter table public."event_attendance" alter column "status" set default 'going'::text;

alter table public."event_attendance" alter column "visible_to_connections" set default false;

alter table public."event_attendance" alter column "created_at" set default now();

alter table public."event_attendance" alter column "updated_at" set default now();

alter table public."event_payouts" alter column "id" set default gen_random_uuid();

alter table public."event_payouts" alter column "status" set default 'pending'::text;

alter table public."event_payouts" alter column "created_at" set default now();

alter table public."event_unlocks" alter column "created_at" set default now();

alter table public."events" alter column "id" set default gen_random_uuid();

alter table public."events" alter column "price" set default 0;

alter table public."events" alter column "created_at" set default now();

alter table public."events" alter column "status" set default 'published'::text;

alter table public."events" alter column "visibility" set default 'public'::text;

alter table public."events" alter column "min_age" set default 0;

alter table public."events" alter column "posts_visibility" set default 'invitees'::text;

alter table public."events" alter column "cancellation_hours" set default 24;

alter table public."events" alter column "country" set default 'Canada'::text;

alter table public."events" alter column "platform_fee_bps" set default platform_fee_bps();

alter table public."favorites" alter column "id" set default gen_random_uuid();

alter table public."favorites" alter column "created_at" set default now();

alter table public."follows" alter column "created_at" set default now();

alter table public."legal_document_translations" alter column "updated_at" set default now();

alter table public."legal_documents" alter column "effective_date" set default CURRENT_DATE;

alter table public."legal_documents" alter column "requires_acceptance" set default false;

alter table public."legal_documents" alter column "sort_order" set default 0;

alter table public."legal_documents" alter column "updated_at" set default now();

alter table public."notifications" alter column "id" set default gen_random_uuid();

alter table public."notifications" alter column "read" set default false;

alter table public."notifications" alter column "created_at" set default now();

alter table public."payments" alter column "refunded_cents" set default 0;

alter table public."payments" alter column "created_at" set default now();

alter table public."payments" alter column "retained_fee_cents" set default 0;

alter table public."post_comments" alter column "id" set default gen_random_uuid();

alter table public."post_comments" alter column "created_at" set default now();

alter table public."post_likes" alter column "created_at" set default now();

alter table public."posts" alter column "id" set default gen_random_uuid();

alter table public."posts" alter column "created_at" set default now();

alter table public."posts" alter column "comments_disabled" set default false;

alter table public."profiles" alter column "created_at" set default now();

alter table public."profiles" alter column "interests" set default '{}'::text[];

alter table public."profiles" alter column "onboarded" set default false;

alter table public."profiles" alter column "is_admin" set default false;

alter table public."reports" alter column "id" set default gen_random_uuid();

alter table public."reports" alter column "status" set default 'pending'::text;

alter table public."reports" alter column "created_at" set default now();

alter table public."stripe_accounts" alter column "transfers_enabled" set default false;

alter table public."stripe_accounts" alter column "payouts_enabled" set default false;

alter table public."stripe_accounts" alter column "details_submitted" set default false;

alter table public."stripe_accounts" alter column "created_at" set default now();

alter table public."stripe_accounts" alter column "updated_at" set default now();

alter table public."ticket_types" alter column "id" set default gen_random_uuid();

alter table public."ticket_types" alter column "price" set default 0;

alter table public."ticket_types" alter column "quantity_total" set default 100;

alter table public."ticket_types" alter column "quantity_sold" set default 0;

alter table public."ticket_types" alter column "created_at" set default now();

alter table public."ticket_types" alter column "max_per_order" set default 10;

alter table public."tickets" alter column "id" set default gen_random_uuid();

alter table public."tickets" alter column "status" set default 'valid'::text;

alter table public."tickets" alter column "purchased_at" set default now();

alter table public."user_legal_acceptances" alter column "id" set default gen_random_uuid();

alter table public."user_legal_acceptances" alter column "accepted_at" set default now();

alter table public."event_attendance" add constraint "event_attendance_pkey" PRIMARY KEY (user_id, event_id);

alter table public."profiles" add constraint "profiles_pkey" PRIMARY KEY (id);

alter table public."notifications" add constraint "notifications_pkey" PRIMARY KEY (id);

alter table public."event_addresses" add constraint "event_addresses_pkey" PRIMARY KEY (event_id);

alter table public."post_likes" add constraint "post_likes_pkey" PRIMARY KEY (post_id, user_id);

alter table public."stripe_accounts" add constraint "stripe_accounts_pkey" PRIMARY KEY (user_id);

alter table public."reports" add constraint "reports_pkey" PRIMARY KEY (id);

alter table public."legal_document_translations" add constraint "legal_document_translations_pkey" PRIMARY KEY (slug, locale);

alter table public."event_payouts" add constraint "event_payouts_pkey" PRIMARY KEY (id);

alter table public."blocked_users" add constraint "blocked_users_pkey" PRIMARY KEY (blocker_id, blocked_id);

alter table public."events" add constraint "events_pkey" PRIMARY KEY (id);

alter table public."legal_documents" add constraint "legal_documents_pkey" PRIMARY KEY (slug);

alter table public."user_legal_acceptances" add constraint "user_legal_acceptances_pkey" PRIMARY KEY (id);

alter table public."admin_actions" add constraint "admin_actions_pkey" PRIMARY KEY (id);

alter table public."device_tokens" add constraint "device_tokens_pkey" PRIMARY KEY (token);

alter table public."follows" add constraint "follows_pkey" PRIMARY KEY (follower_id, following_id);

alter table public."event_unlocks" add constraint "event_unlocks_pkey" PRIMARY KEY (user_id, event_id);

alter table public."cities" add constraint "cities_pkey" PRIMARY KEY (slug);

alter table private."settings" add constraint "settings_pkey" PRIMARY KEY (key);

alter table public."posts" add constraint "posts_pkey" PRIMARY KEY (id);

alter table public."favorites" add constraint "favorites_pkey" PRIMARY KEY (id);

alter table public."ticket_types" add constraint "ticket_types_pkey" PRIMARY KEY (id);

alter table public."payments" add constraint "payments_pkey" PRIMARY KEY (payment_intent_id);

alter table public."tickets" add constraint "tickets_pkey" PRIMARY KEY (id);

alter table public."post_comments" add constraint "post_comments_pkey" PRIMARY KEY (id);

alter table public."direct_conversations" add constraint "direct_conversations_pkey" PRIMARY KEY (id);

alter table public."direct_messages" add constraint "direct_messages_pkey" PRIMARY KEY (id);

alter table public."categories" add constraint "categories_pkey" PRIMARY KEY (id);

alter table public."stripe_accounts" add constraint "stripe_accounts_account_id_key" UNIQUE (account_id);

alter table public."profiles" add constraint "profiles_username_key" UNIQUE (username);

alter table public."event_payouts" add constraint "event_payouts_event_id_key" UNIQUE (event_id);

alter table public."tickets" add constraint "tickets_qr_token_key" UNIQUE (qr_token);

alter table public."user_legal_acceptances" add constraint "user_legal_acceptances_user_id_slug_version_key" UNIQUE (user_id, slug, version);

alter table public."event_payouts" add constraint "event_payouts_transfer_id_key" UNIQUE (transfer_id);

alter table public."favorites" add constraint "favorites_user_id_event_id_key" UNIQUE (user_id, event_id);

alter table public."direct_conversations" add constraint "direct_conversations_member_a_member_b_key" UNIQUE (member_a, member_b);

alter table public."profiles" add constraint "profiles_email_key" UNIQUE (email);

alter table public."categories" add constraint "categories_name_key" UNIQUE (name);

alter table public."reports" add constraint "reports_status_check" CHECK ((status = ANY (ARRAY['pending'::text, 'reviewed'::text, 'actioned'::text, 'dismissed'::text])));

alter table public."profiles" add constraint "profiles_language_check" CHECK ((language = ANY (ARRAY['en'::text, 'fr'::text])));

alter table public."profiles" add constraint "username_format" CHECK (((username IS NULL) OR ((username = lower(username)) AND (username ~ '^[a-z0-9._]{3,20}$'::text) AND (username !~ '^\.|\.$|\.\.'::text))));

alter table public."events" add constraint "event_ends_after_start" CHECK (((end_date IS NULL) OR (end_date >= start_date))) NOT VALID;

alter table public."events" add constraint "events_cancellation_hours_check" CHECK (((cancellation_hours >= 0) AND (cancellation_hours <= 720)));

alter table public."events" add constraint "events_min_age_check" CHECK ((min_age = ANY (ARRAY[0, 18, 21])));

alter table public."events" add constraint "events_posts_visibility_check" CHECK ((posts_visibility = ANY (ARRAY['invitees'::text, 'public'::text])));

alter table public."events" add constraint "events_status_check" CHECK ((status = ANY (ARRAY['published'::text, 'draft'::text, 'cancelled'::text])));

alter table public."tickets" add constraint "tickets_status_check" CHECK ((status = ANY (ARRAY['valid'::text, 'used'::text, 'expired'::text, 'refunded'::text])));

alter table public."reports" add constraint "reports_target_type_check" CHECK ((target_type = ANY (ARRAY['event'::text, 'user'::text, 'post'::text, 'message'::text, 'comment'::text])));

alter table public."blocked_users" add constraint "no_self_block" CHECK ((blocker_id <> blocked_id));

alter table public."follows" add constraint "no_self_follow" CHECK ((follower_id <> following_id));

alter table public."posts" add constraint "post_not_empty" CHECK (((COALESCE(TRIM(BOTH FROM caption), ''::text) <> ''::text) OR (COALESCE(image_url, ''::text) <> ''::text)));

alter table public."posts" add constraint "posts_image_aspect_range" CHECK (((image_aspect IS NULL) OR ((image_aspect >= (0.2)::double precision) AND (image_aspect <= (5)::double precision))));

alter table public."event_attendance" add constraint "event_attendance_status_check" CHECK ((status = ANY (ARRAY['going'::text, 'attended'::text])));

alter table public."device_tokens" add constraint "device_tokens_platform_check" CHECK ((platform = ANY (ARRAY['android'::text, 'ios'::text])));

alter table public."event_payouts" add constraint "event_payouts_status_check" CHECK ((status = ANY (ARRAY['pending'::text, 'paid'::text, 'failed'::text, 'skipped'::text])));

alter table public."direct_messages" add constraint "direct_message_body_length" CHECK (((char_length(body) <= 2000) AND ((char_length(TRIM(BOTH FROM body)) >= 1) OR (shared_kind IS NOT NULL))));

alter table public."direct_messages" add constraint "direct_message_shared_kind" CHECK (
CASE shared_kind
    WHEN 'post'::text THEN (event_id IS NULL)
    WHEN 'event'::text THEN (post_id IS NULL)
    ELSE ((shared_kind IS NULL) AND (post_id IS NULL) AND (event_id IS NULL))
END);

alter table public."direct_conversations" add constraint "direct_conversation_members_ordered" CHECK ((member_a < member_b));

alter table public."post_comments" add constraint "post_comment_body_length" CHECK (((char_length(TRIM(BOTH FROM body)) >= 1) AND (char_length(TRIM(BOTH FROM body)) <= 500)));

alter table public."legal_document_translations" add constraint "legal_document_translations_locale_check" CHECK ((locale = 'fr'::text));

alter table public."stripe_accounts" add constraint "stripe_accounts_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

alter table public."notifications" add constraint "notifications_conversation_id_fkey" FOREIGN KEY (conversation_id) REFERENCES direct_conversations(id) ON DELETE CASCADE;

alter table public."notifications" add constraint "notifications_event_id_fkey" FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE SET NULL;

alter table public."event_addresses" add constraint "event_addresses_event_id_fkey" FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE;

alter table public."notifications" add constraint "notifications_post_id_fkey" FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE;

alter table public."notifications" add constraint "notifications_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

alter table public."event_attendance" add constraint "event_attendance_event_id_fkey" FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE;

alter table public."follows" add constraint "follows_following_id_fkey" FOREIGN KEY (following_id) REFERENCES auth.users(id) ON DELETE CASCADE;

alter table public."ticket_types" add constraint "ticket_types_event_id_fkey" FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE;

alter table public."event_attendance" add constraint "event_attendance_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

alter table public."follows" add constraint "follows_follower_id_fkey" FOREIGN KEY (follower_id) REFERENCES auth.users(id) ON DELETE CASCADE;

alter table public."profiles" add constraint "profiles_id_fkey" FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;

alter table public."device_tokens" add constraint "device_tokens_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

alter table public."admin_actions" add constraint "admin_actions_admin_id_fkey" FOREIGN KEY (admin_id) REFERENCES auth.users(id) ON DELETE SET NULL;

alter table public."user_legal_acceptances" add constraint "user_legal_acceptances_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

alter table public."admin_actions" add constraint "admin_actions_report_id_fkey" FOREIGN KEY (report_id) REFERENCES reports(id) ON DELETE SET NULL;

alter table public."blocked_users" add constraint "blocked_users_blocker_id_fkey" FOREIGN KEY (blocker_id) REFERENCES auth.users(id) ON DELETE CASCADE;

alter table public."event_payouts" add constraint "event_payouts_organizer_id_fkey" FOREIGN KEY (organizer_id) REFERENCES auth.users(id) ON DELETE SET NULL;

alter table public."blocked_users" add constraint "blocked_users_blocked_id_fkey" FOREIGN KEY (blocked_id) REFERENCES auth.users(id) ON DELETE CASCADE;

alter table public."post_comments" add constraint "post_comments_author_id_fkey" FOREIGN KEY (author_id) REFERENCES auth.users(id) ON DELETE CASCADE;

alter table public."reports" add constraint "reports_reporter_id_fkey" FOREIGN KEY (reporter_id) REFERENCES auth.users(id) ON DELETE SET NULL;

alter table public."events" add constraint "events_created_by_fkey" FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;

alter table public."post_comments" add constraint "post_comments_post_id_fkey" FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE;

alter table public."direct_messages" add constraint "direct_messages_conversation_id_fkey" FOREIGN KEY (conversation_id) REFERENCES direct_conversations(id) ON DELETE CASCADE;

alter table public."direct_messages" add constraint "direct_messages_event_id_fkey" FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE SET NULL;

alter table public."tickets" add constraint "tickets_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;

alter table public."direct_messages" add constraint "direct_messages_post_id_fkey" FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE SET NULL;

alter table public."direct_messages" add constraint "direct_messages_sender_id_fkey" FOREIGN KEY (sender_id) REFERENCES auth.users(id) ON DELETE SET NULL;

alter table public."legal_document_translations" add constraint "legal_document_translations_slug_fkey" FOREIGN KEY (slug) REFERENCES legal_documents(slug) ON DELETE CASCADE;

alter table public."direct_conversations" add constraint "direct_conversations_member_a_fkey" FOREIGN KEY (member_a) REFERENCES auth.users(id) ON DELETE SET NULL;

alter table public."tickets" add constraint "tickets_transferred_from_fkey" FOREIGN KEY (transferred_from) REFERENCES auth.users(id) ON DELETE SET NULL;

alter table public."direct_conversations" add constraint "direct_conversations_member_b_fkey" FOREIGN KEY (member_b) REFERENCES auth.users(id) ON DELETE SET NULL;

alter table public."tickets" add constraint "tickets_ticket_type_id_fkey" FOREIGN KEY (ticket_type_id) REFERENCES ticket_types(id);

alter table public."payments" add constraint "payments_buyer_id_fkey" FOREIGN KEY (buyer_id) REFERENCES auth.users(id) ON DELETE SET NULL;

alter table public."payments" add constraint "payments_organizer_id_fkey" FOREIGN KEY (organizer_id) REFERENCES auth.users(id) ON DELETE SET NULL;

alter table public."tickets" add constraint "tickets_event_id_fkey" FOREIGN KEY (event_id) REFERENCES events(id);

alter table public."favorites" add constraint "favorites_event_id_fkey" FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE;

alter table public."favorites" add constraint "favorites_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

alter table public."posts" add constraint "posts_event_id_fkey" FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE;

alter table public."event_unlocks" add constraint "event_unlocks_event_id_fkey" FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE;

alter table public."posts" add constraint "posts_author_id_fkey" FOREIGN KEY (author_id) REFERENCES auth.users(id) ON DELETE CASCADE;

alter table public."event_unlocks" add constraint "event_unlocks_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

alter table public."post_likes" add constraint "post_likes_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

alter table public."post_likes" add constraint "post_likes_post_id_fkey" FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE;

create or replace view public."public_profiles" as  SELECT id,
    full_name,
    avatar_url,
    bio,
    city,
    username
   FROM profiles p;

create or replace view public."feed_posts" as  SELECT p.id,
    p.author_id,
    p.caption,
    p.image_url,
    p.event_id,
    p.created_at,
    pr.full_name AS author_name,
    pr.avatar_url AS author_avatar,
    e.title AS event_title,
    e.start_date AS event_start_date,
    e.image_url AS event_image,
    COALESCE(e.visibility, 'public'::text) AS event_visibility,
    (e.created_by = p.author_id) AS author_is_organizer,
    ( SELECT count(*) AS count
           FROM post_likes l
          WHERE (l.post_id = p.id)) AS like_count,
    (EXISTS ( SELECT 1
           FROM post_likes l
          WHERE ((l.post_id = p.id) AND (l.user_id = auth.uid())))) AS liked_by_me,
    p.edited_at,
    ( SELECT count(*) AS count
           FROM post_comments c
          WHERE (c.post_id = p.id)) AS comment_count,
    p.comments_disabled,
    p.image_aspect,
    e.city AS event_city
   FROM ((posts p
     JOIN events e ON ((e.id = p.event_id)))
     LEFT JOIN profiles pr ON ((pr.id = p.author_id)))
  WHERE ((COALESCE(e.posts_visibility, 'public'::text) = 'public'::text) OR can_attach_event(p.event_id));

CREATE UNIQUE INDEX categories_name_unique ON public.categories USING btree (name);

CREATE INDEX payments_event_idx ON public.payments USING btree (event_id);

CREATE INDEX device_tokens_user_idx ON public.device_tokens USING btree (user_id);

CREATE INDEX follows_following_idx ON public.follows USING btree (following_id);

CREATE INDEX posts_recent_idx ON public.posts USING btree (created_at DESC);

CREATE INDEX post_comments_post_created_idx ON public.post_comments USING btree (post_id, created_at, id);

CREATE INDEX reports_target_idx ON public.reports USING btree (target_type, target_id, status);

CREATE INDEX notifications_user_idx ON public.notifications USING btree (user_id, created_at DESC);

CREATE INDEX event_attendance_event_idx ON public.event_attendance USING btree (event_id) WHERE visible_to_connections;

CREATE INDEX admin_actions_created_idx ON public.admin_actions USING btree (created_at DESC);

CREATE INDEX event_addresses_coords_idx ON public.event_addresses USING btree (latitude, longitude);

CREATE INDEX direct_messages_conversation_created_idx ON public.direct_messages USING btree (conversation_id, created_at, id);

CREATE INDEX posts_author_idx ON public.posts USING btree (author_id, created_at DESC);

CREATE INDEX event_payouts_organizer_idx ON public.event_payouts USING btree (organizer_id);

CREATE INDEX favorites_user_idx ON public.favorites USING btree (user_id);

CREATE INDEX payments_organizer_idx ON public.payments USING btree (organizer_id);

CREATE UNIQUE INDEX events_access_code_key ON public.events USING btree (access_code) WHERE (access_code IS NOT NULL);

CREATE INDEX tickets_payment_intent_idx ON public.tickets USING btree (payment_intent_id);

CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION handle_new_user();

CREATE TRIGGER trg_prevent_event_delete BEFORE DELETE ON public.events FOR EACH ROW EXECUTE FUNCTION prevent_delete_with_tickets();

CREATE TRIGGER trg_notify_event_change AFTER UPDATE ON public.events FOR EACH ROW EXECUTE FUNCTION notify_event_change();

CREATE TRIGGER trg_sync_event_attendance AFTER INSERT OR DELETE OR UPDATE ON public.tickets FOR EACH ROW EXECUTE FUNCTION sync_event_attendance();

CREATE TRIGGER profiles_prevent_self_admin BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION prevent_self_admin();

CREATE TRIGGER notify_report_on_insert AFTER INSERT ON public.reports FOR EACH ROW EXECUTE FUNCTION supabase_functions.http_request('https://jvjvuozvlzqqmcjanvnh.supabase.co/functions/v1/notify-report', 'POST', '{"x-happyn-secret":"IWa4KT3aB-Q0sL8F8PkaB6qyyhjznWZ3-I12rbsEXC8"}', '{}', '5000');

CREATE TRIGGER send_push_on_notification AFTER INSERT ON public.notifications FOR EACH ROW EXECUTE FUNCTION supabase_functions.http_request('https://jvjvuozvlzqqmcjanvnh.supabase.co/functions/v1/send-push', 'POST', '{"Content-Type":"application/json","x-happyn-secret":"WdIV1_-lLLlZWZ1eXcOZZeP_WMV9fnOiFcZZ--AFrUw"}', '{}', '5000');

CREATE TRIGGER profiles_username_guard BEFORE INSERT OR UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION profiles_username_guard();

CREATE TRIGGER posts_mark_edited BEFORE UPDATE ON public.posts FOR EACH ROW EXECUTE FUNCTION posts_mark_edited();

CREATE TRIGGER reports_fill_label BEFORE INSERT ON public.reports FOR EACH ROW EXECUTE FUNCTION reports_fill_label();

CREATE TRIGGER events_lock_fee BEFORE INSERT OR UPDATE ON public.events FOR EACH ROW EXECUTE FUNCTION events_lock_fee();

CREATE TRIGGER notify_on_direct_message AFTER INSERT ON public.direct_messages FOR EACH ROW EXECUTE FUNCTION notify_direct_message();

CREATE TRIGGER purge_orphan_conversation AFTER UPDATE OF member_a, member_b ON public.direct_conversations FOR EACH ROW EXECUTE FUNCTION purge_orphan_conversation();

CREATE TRIGGER translate_notification BEFORE INSERT ON public.notifications FOR EACH ROW EXECUTE FUNCTION translate_notification();

CREATE TRIGGER notify_on_post_comment AFTER INSERT ON public.post_comments FOR EACH ROW EXECUTE FUNCTION notify_post_comment();

CREATE TRIGGER events_guard_cancellation BEFORE UPDATE OF status ON public.events FOR EACH ROW EXECUTE FUNCTION events_guard_cancellation();

CREATE TRIGGER profiles_guard_suspension BEFORE UPDATE OF suspended_at ON public.profiles FOR EACH ROW EXECUTE FUNCTION profiles_guard_suspension();

CREATE TRIGGER profiles_guard_birth_date BEFORE INSERT OR UPDATE OF date_of_birth ON public.profiles FOR EACH ROW EXECUTE FUNCTION profiles_guard_birth_date();

alter table public."profiles" enable row level security;

alter table public."events" enable row level security;

alter table public."ticket_types" enable row level security;

alter table public."tickets" enable row level security;

alter table public."categories" enable row level security;

alter table public."reports" enable row level security;

alter table public."blocked_users" enable row level security;

alter table public."legal_documents" enable row level security;

alter table public."user_legal_acceptances" enable row level security;

alter table public."follows" enable row level security;

alter table public."event_addresses" enable row level security;

alter table public."post_likes" enable row level security;

alter table public."posts" enable row level security;

alter table public."favorites" enable row level security;

alter table public."cities" enable row level security;

alter table public."event_unlocks" enable row level security;

alter table public."stripe_accounts" enable row level security;

alter table public."notifications" enable row level security;

alter table public."event_attendance" enable row level security;

alter table public."device_tokens" enable row level security;

alter table public."admin_actions" enable row level security;

alter table public."event_payouts" enable row level security;

alter table public."direct_messages" enable row level security;

alter table public."direct_conversations" enable row level security;

alter table public."payments" enable row level security;

alter table public."post_comments" enable row level security;

alter table public."legal_document_translations" enable row level security;

create policy "Users can view own profile" on public."profiles" as permissive for select to public using ((auth.uid() = id));

create policy "Users can insert own profile" on public."profiles" as permissive for insert to public with check ((auth.uid() = id));

create policy "Users can update own profile" on public."profiles" as permissive for update to public using ((auth.uid() = id));

create policy "Public can read categories" on public."categories" as permissive for select to public using (true);

create policy "own acceptances select" on public."user_legal_acceptances" as permissive for select to authenticated using ((auth.uid() = user_id));

create policy "own likes insert" on public."post_likes" as permissive for insert to authenticated with check ((auth.uid() = user_id));

create policy "categories are public" on public."categories" as permissive for select to public using (true);

create policy "own favorites select" on public."favorites" as permissive for select to authenticated using ((auth.uid() = user_id));

create policy "own favorites insert" on public."favorites" as permissive for insert to authenticated with check ((auth.uid() = user_id));

create policy "own favorites delete" on public."favorites" as permissive for delete to authenticated using ((auth.uid() = user_id));

create policy "own notifs select" on public."notifications" as permissive for select to authenticated using ((auth.uid() = user_id));

create policy "own notifs update" on public."notifications" as permissive for update to authenticated using ((auth.uid() = user_id));

create policy "own profile select" on public."profiles" as permissive for select to authenticated using ((auth.uid() = id));

create policy "own profile insert" on public."profiles" as permissive for insert to authenticated with check ((auth.uid() = id));

create policy "own profile update" on public."profiles" as permissive for update to authenticated using ((auth.uid() = id));

create policy "legal readable by all" on public."legal_documents" as permissive for select to authenticated, anon using (true);

create policy "addresses readable when allowed" on public."event_addresses" as permissive for select to authenticated, anon using (can_see_exact_address(event_id));

create policy "own reports insert" on public."reports" as permissive for insert to authenticated with check ((auth.uid() = reporter_id));

create policy "own reports select" on public."reports" as permissive for select to authenticated using ((auth.uid() = reporter_id));

create policy "own blocks select" on public."blocked_users" as permissive for select to authenticated using ((auth.uid() = blocker_id));

create policy "own blocks insert" on public."blocked_users" as permissive for insert to authenticated with check ((auth.uid() = blocker_id));

create policy "own blocks delete" on public."blocked_users" as permissive for delete to authenticated using ((auth.uid() = blocker_id));

create policy "follows readable" on public."follows" as permissive for select to authenticated, anon using (true);

create policy "own follows insert" on public."follows" as permissive for insert to authenticated with check ((auth.uid() = follower_id));

create policy "own follows delete" on public."follows" as permissive for delete to authenticated using ((auth.uid() = follower_id));

create policy "own posts delete" on public."posts" as permissive for delete to authenticated using ((auth.uid() = author_id));

create policy "own likes delete" on public."post_likes" as permissive for delete to authenticated using ((auth.uid() = user_id));

create policy "own attendance select" on public."event_attendance" as permissive for select to authenticated using ((auth.uid() = user_id));

create policy "own tokens upsert" on public."device_tokens" as permissive for insert to authenticated with check ((auth.uid() = user_id));

create policy "own tokens update" on public."device_tokens" as permissive for update to authenticated using ((auth.uid() = user_id));

create policy "delete by exact token" on public."device_tokens" as permissive for delete to authenticated using (true);

create policy "Users can update own events" on public."events" as permissive for update to authenticated using ((auth.uid() = created_by));

create policy "Users can delete own events" on public."events" as permissive for delete to authenticated using ((auth.uid() = created_by));

create policy "Users see their own tickets" on public."tickets" as permissive for select to authenticated using ((auth.uid() = user_id));

create policy "Organizers can manage ticket types" on public."ticket_types" as permissive for all to authenticated using ((auth.uid() = ( SELECT e.created_by
   FROM events e
  WHERE (e.id = ticket_types.event_id))));

create policy "own unlocks readable" on public."event_unlocks" as permissive for select to authenticated using ((auth.uid() = user_id));

create policy "Anyone can view ticket types" on public."ticket_types" as permissive for select to authenticated, anon using (event_is_readable(event_id));

create policy "own posts insert" on public."posts" as permissive for insert to authenticated with check (((auth.uid() = author_id) AND can_attach_event(event_id) AND (NOT is_suspended())));

create policy "own tokens select" on public."device_tokens" as permissive for select to authenticated using ((auth.uid() = user_id));

create policy "organizer writes address" on public."event_addresses" as permissive for all to authenticated using ((auth.uid() = ( SELECT e.created_by
   FROM events e
  WHERE (e.id = event_addresses.event_id))));

create policy "cities readable" on public."cities" as permissive for select to authenticated, anon using (true);

create policy "own posts update" on public."posts" as permissive for update to authenticated using (((auth.uid() = author_id) AND (NOT is_suspended()))) with check (((auth.uid() = author_id) AND (NOT is_suspended())));

create policy "own stripe account read" on public."stripe_accounts" as permissive for select to authenticated using ((auth.uid() = user_id));

create policy "own payouts read" on public."event_payouts" as permissive for select to authenticated using ((auth.uid() = organizer_id));

create policy "conversation participants can read" on public."direct_conversations" as permissive for select to authenticated using (can_access_direct_conversation(id));

create policy "conversation participants can read messages" on public."direct_messages" as permissive for select to authenticated using (can_access_direct_conversation(conversation_id));

create policy "conversation participants can send messages" on public."direct_messages" as permissive for insert to authenticated with check (((sender_id = auth.uid()) AND can_access_direct_conversation(conversation_id) AND direct_conversation_is_open(conversation_id)));

create policy "comments readable" on public."post_comments" as permissive for select to authenticated using (((EXISTS ( SELECT 1
   FROM posts p
  WHERE ((p.id = post_comments.post_id) AND (event_posts_are_public(p.event_id) OR can_attach_event(p.event_id))))) AND (NOT blocked_either_way(auth.uid(), author_id))));

create policy "own comments insert" on public."post_comments" as permissive for insert to authenticated with check (((author_id = auth.uid()) AND (NOT is_suspended()) AND (EXISTS ( SELECT 1
   FROM posts p
  WHERE ((p.id = post_comments.post_id) AND (NOT p.comments_disabled) AND (event_posts_are_public(p.event_id) OR can_attach_event(p.event_id)) AND (NOT blocked_either_way(auth.uid(), p.author_id)))))));

create policy "own or post author comments delete" on public."post_comments" as permissive for delete to authenticated using (((author_id = auth.uid()) OR (EXISTS ( SELECT 1
   FROM posts p
  WHERE ((p.id = post_comments.post_id) AND (p.author_id = auth.uid()))))));

create policy "events readable" on public."events" as permissive for select to authenticated, anon using ((((COALESCE(visibility, 'public'::text) = 'public'::text) AND (COALESCE(status, 'published'::text) <> 'draft'::text)) OR (created_by = auth.uid()) OR user_holds_ticket_for(id)));

create policy "posts readable" on public."posts" as permissive for select to authenticated using ((event_posts_are_public(event_id) OR can_attach_event(event_id)));

create policy "likes readable" on public."post_likes" as permissive for select to authenticated using ((EXISTS ( SELECT 1
   FROM posts p
  WHERE ((p.id = post_likes.post_id) AND (event_posts_are_public(p.event_id) OR can_attach_event(p.event_id))))));

create policy "Authenticated users can create events" on public."events" as permissive for insert to authenticated with check (((auth.uid() = created_by) AND (NOT is_suspended()) AND i_meet_age(18)));

create policy "legal translations readable by all" on public."legal_document_translations" as permissive for select to authenticated, anon using (true);

-- Droits : on part de zero, puis on rejoue exactement ceux de la production.

revoke all on private."settings" from public, anon, authenticated, service_role;

revoke all on public."admin_actions" from public, anon, authenticated, service_role;

revoke all on public."blocked_users" from public, anon, authenticated, service_role;

revoke all on public."categories" from public, anon, authenticated, service_role;

revoke all on public."cities" from public, anon, authenticated, service_role;

revoke all on public."device_tokens" from public, anon, authenticated, service_role;

revoke all on public."direct_conversations" from public, anon, authenticated, service_role;

revoke all on public."direct_messages" from public, anon, authenticated, service_role;

revoke all on public."event_addresses" from public, anon, authenticated, service_role;

revoke all on public."event_attendance" from public, anon, authenticated, service_role;

revoke all on public."event_payouts" from public, anon, authenticated, service_role;

revoke all on public."event_unlocks" from public, anon, authenticated, service_role;

revoke all on public."events" from public, anon, authenticated, service_role;

revoke all on public."favorites" from public, anon, authenticated, service_role;

revoke all on public."follows" from public, anon, authenticated, service_role;

revoke all on public."legal_document_translations" from public, anon, authenticated, service_role;

revoke all on public."legal_documents" from public, anon, authenticated, service_role;

revoke all on public."notifications" from public, anon, authenticated, service_role;

revoke all on public."payments" from public, anon, authenticated, service_role;

revoke all on public."post_comments" from public, anon, authenticated, service_role;

revoke all on public."post_likes" from public, anon, authenticated, service_role;

revoke all on public."posts" from public, anon, authenticated, service_role;

revoke all on public."profiles" from public, anon, authenticated, service_role;

revoke all on public."reports" from public, anon, authenticated, service_role;

revoke all on public."stripe_accounts" from public, anon, authenticated, service_role;

revoke all on public."ticket_types" from public, anon, authenticated, service_role;

revoke all on public."tickets" from public, anon, authenticated, service_role;

revoke all on public."user_legal_acceptances" from public, anon, authenticated, service_role;

revoke all on public."public_profiles" from public, anon, authenticated, service_role;

revoke all on public."feed_posts" from public, anon, authenticated, service_role;

grant REFERENCES, TRUNCATE, DELETE, UPDATE, SELECT, INSERT, TRIGGER on public."admin_actions" to anon;

grant UPDATE, INSERT, DELETE, TRUNCATE, REFERENCES, TRIGGER, SELECT on public."admin_actions" to authenticated;

grant TRUNCATE, DELETE, REFERENCES, TRIGGER, UPDATE, SELECT, INSERT on public."admin_actions" to service_role;

grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER on public."blocked_users" to anon;

grant TRUNCATE, TRIGGER, REFERENCES, DELETE, UPDATE, SELECT, INSERT on public."blocked_users" to authenticated;

grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER on public."blocked_users" to service_role;

grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER on public."categories" to anon;

grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER on public."categories" to authenticated;

grant UPDATE, SELECT, INSERT, REFERENCES, TRUNCATE, TRIGGER, DELETE on public."categories" to service_role;

grant SELECT, REFERENCES, TRUNCATE, DELETE, UPDATE, INSERT, TRIGGER on public."cities" to anon;

grant REFERENCES, DELETE, UPDATE, SELECT, INSERT, TRUNCATE, TRIGGER on public."cities" to authenticated;

grant REFERENCES, TRUNCATE, DELETE, UPDATE, INSERT, SELECT, TRIGGER on public."cities" to service_role;

grant REFERENCES, TRUNCATE, DELETE, UPDATE, SELECT, INSERT, TRIGGER on public."device_tokens" to anon;

grant SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER on public."device_tokens" to authenticated;

grant TRIGGER, REFERENCES, TRUNCATE, DELETE, UPDATE, INSERT, SELECT on public."device_tokens" to service_role;

grant SELECT on public."direct_conversations" to authenticated;

grant UPDATE, INSERT, SELECT, DELETE, TRUNCATE, REFERENCES, TRIGGER on public."direct_conversations" to service_role;

grant SELECT, INSERT on public."direct_messages" to authenticated;

grant TRIGGER, INSERT, SELECT, UPDATE, TRUNCATE, DELETE, REFERENCES on public."direct_messages" to service_role;

grant DELETE, SELECT, UPDATE, INSERT, TRUNCATE, REFERENCES, TRIGGER on public."event_addresses" to anon;

grant DELETE, TRUNCATE, REFERENCES, TRIGGER, UPDATE, SELECT, INSERT on public."event_addresses" to authenticated;

grant DELETE, TRUNCATE, REFERENCES, TRIGGER, INSERT, SELECT, UPDATE on public."event_addresses" to service_role;

grant DELETE, UPDATE, SELECT, INSERT, TRIGGER, REFERENCES, TRUNCATE on public."event_attendance" to anon;

grant DELETE, TRIGGER, REFERENCES, TRUNCATE, UPDATE, SELECT, INSERT on public."event_attendance" to authenticated;

grant REFERENCES, UPDATE, DELETE, TRUNCATE, INSERT, SELECT, TRIGGER on public."event_attendance" to service_role;

grant TRIGGER, REFERENCES, TRUNCATE, SELECT on public."event_payouts" to anon;

grant TRIGGER, SELECT, TRUNCATE, REFERENCES on public."event_payouts" to authenticated;

grant DELETE, UPDATE, SELECT, INSERT, TRIGGER, REFERENCES, TRUNCATE on public."event_payouts" to service_role;

grant TRUNCATE, INSERT, SELECT, UPDATE, DELETE, REFERENCES, TRIGGER on public."event_unlocks" to anon;

grant SELECT, TRIGGER, REFERENCES, TRUNCATE, DELETE, UPDATE, INSERT on public."event_unlocks" to authenticated;

grant TRIGGER, INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES on public."event_unlocks" to service_role;

grant TRIGGER, SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES on public."events" to anon;

grant TRUNCATE, TRIGGER, REFERENCES, DELETE, UPDATE, SELECT, INSERT on public."events" to authenticated;

grant TRUNCATE, INSERT, SELECT, UPDATE, DELETE, TRIGGER, REFERENCES on public."events" to service_role;

grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER on public."favorites" to anon;

grant SELECT, TRIGGER, REFERENCES, TRUNCATE, DELETE, UPDATE, INSERT on public."favorites" to authenticated;

grant REFERENCES, INSERT, TRIGGER, TRUNCATE, DELETE, UPDATE, SELECT on public."favorites" to service_role;

grant DELETE, UPDATE, INSERT, REFERENCES, TRUNCATE, TRIGGER on public."feed_posts" to anon;

grant DELETE, TRUNCATE, REFERENCES, SELECT, UPDATE, TRIGGER, INSERT on public."feed_posts" to authenticated;

grant REFERENCES, DELETE, UPDATE, SELECT, INSERT, TRIGGER, TRUNCATE on public."feed_posts" to service_role;

grant REFERENCES, TRIGGER, INSERT, SELECT, UPDATE, DELETE, TRUNCATE on public."follows" to anon;

grant REFERENCES, UPDATE, INSERT, SELECT, DELETE, TRIGGER, TRUNCATE on public."follows" to authenticated;

grant UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, INSERT, SELECT on public."follows" to service_role;

grant SELECT on public."legal_document_translations" to anon;

grant SELECT on public."legal_document_translations" to authenticated;

grant TRIGGER, UPDATE, SELECT, INSERT, TRUNCATE, DELETE, REFERENCES on public."legal_document_translations" to service_role;

grant DELETE, TRUNCATE, REFERENCES, TRIGGER, INSERT, SELECT, UPDATE on public."legal_documents" to anon;

grant REFERENCES, UPDATE, SELECT, INSERT, DELETE, TRUNCATE, TRIGGER on public."legal_documents" to authenticated;

grant SELECT, TRIGGER, REFERENCES, TRUNCATE, DELETE, UPDATE, INSERT on public."legal_documents" to service_role;

grant TRIGGER, REFERENCES, TRUNCATE, DELETE, UPDATE, SELECT, INSERT on public."notifications" to anon;

grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER on public."notifications" to authenticated;

grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER on public."notifications" to service_role;

grant DELETE, UPDATE, SELECT, INSERT, TRIGGER, REFERENCES, TRUNCATE on public."payments" to service_role;

grant INSERT, SELECT, DELETE on public."post_comments" to authenticated;

grant DELETE, TRUNCATE, REFERENCES, TRIGGER, INSERT, SELECT, UPDATE on public."post_comments" to service_role;

grant DELETE, TRUNCATE, REFERENCES, TRIGGER, INSERT, SELECT, UPDATE on public."post_likes" to anon;

grant TRIGGER, REFERENCES, TRUNCATE, DELETE, UPDATE, SELECT, INSERT on public."post_likes" to authenticated;

grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER on public."post_likes" to service_role;

grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER on public."posts" to anon;

grant INSERT, TRIGGER, REFERENCES, TRUNCATE, DELETE, UPDATE, SELECT on public."posts" to authenticated;

grant INSERT, TRIGGER, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES on public."posts" to service_role;

grant REFERENCES, TRIGGER, INSERT, SELECT, UPDATE, DELETE, TRUNCATE on public."profiles" to anon;

grant SELECT, INSERT, TRIGGER, REFERENCES, TRUNCATE, DELETE, UPDATE on public."profiles" to authenticated;

grant TRIGGER, UPDATE, DELETE, TRUNCATE, REFERENCES, INSERT, SELECT on public."profiles" to service_role;

grant UPDATE, INSERT, TRIGGER, REFERENCES, TRUNCATE, DELETE on public."public_profiles" to anon;

grant UPDATE, SELECT, INSERT, TRIGGER, REFERENCES, TRUNCATE, DELETE on public."public_profiles" to authenticated;

grant UPDATE, TRIGGER, REFERENCES, TRUNCATE, DELETE, SELECT, INSERT on public."public_profiles" to service_role;

grant TRUNCATE, INSERT, SELECT, UPDATE, DELETE, TRIGGER, REFERENCES on public."reports" to anon;

grant TRUNCATE, DELETE, UPDATE, SELECT, INSERT, TRIGGER, REFERENCES on public."reports" to authenticated;

grant REFERENCES, DELETE, UPDATE, SELECT, INSERT, TRIGGER, TRUNCATE on public."reports" to service_role;

grant TRUNCATE, TRIGGER, REFERENCES, SELECT on public."stripe_accounts" to anon;

grant TRIGGER, SELECT, TRUNCATE, REFERENCES on public."stripe_accounts" to authenticated;

grant REFERENCES, TRIGGER, INSERT, SELECT, UPDATE, DELETE, TRUNCATE on public."stripe_accounts" to service_role;

grant UPDATE, INSERT, SELECT, DELETE, TRIGGER, REFERENCES, TRUNCATE on public."ticket_types" to anon;

grant TRUNCATE, UPDATE, SELECT, INSERT, TRIGGER, REFERENCES, DELETE on public."ticket_types" to authenticated;

grant DELETE, UPDATE, SELECT, INSERT, TRIGGER, REFERENCES, TRUNCATE on public."ticket_types" to service_role;

grant TRUNCATE, TRIGGER, REFERENCES, DELETE, UPDATE, SELECT, INSERT on public."tickets" to anon;

grant DELETE, INSERT, SELECT, UPDATE, TRIGGER, REFERENCES, TRUNCATE on public."tickets" to authenticated;

grant DELETE, UPDATE, SELECT, INSERT, TRUNCATE, REFERENCES, TRIGGER on public."tickets" to service_role;

grant SELECT, REFERENCES, TRIGGER on public."user_legal_acceptances" to authenticated;

grant TRUNCATE, TRIGGER, SELECT, INSERT, UPDATE, DELETE, REFERENCES on public."user_legal_acceptances" to service_role;

revoke all on function events_lock_fee() from public, anon, authenticated, service_role;

grant execute on function events_lock_fee() to anon;

grant execute on function events_lock_fee() to authenticated;

grant execute on function events_lock_fee() to service_role;

revoke all on function payout_delay_days() from public, anon, authenticated, service_role;

grant execute on function payout_delay_days() to anon;

grant execute on function payout_delay_days() to authenticated;

grant execute on function payout_delay_days() to service_role;

revoke all on function settle_payout(uuid,text,text) from public, anon, authenticated, service_role;

grant execute on function settle_payout(uuid,text,text) to service_role;

revoke all on function start_direct_conversation(uuid) from public, anon, authenticated, service_role;

grant execute on function start_direct_conversation(uuid) to authenticated;

grant execute on function start_direct_conversation(uuid) to service_role;

revoke all on function organizer_is_payable(uuid) from public, anon, authenticated, service_role;

grant execute on function organizer_is_payable(uuid) to authenticated;

grant execute on function organizer_is_payable(uuid) to service_role;

revoke all on function ticket_paid_cents(uuid) from public, anon, authenticated, service_role;

grant execute on function ticket_paid_cents(uuid) to authenticated;

grant execute on function ticket_paid_cents(uuid) to service_role;

revoke all on function record_stripe_fee(text,bigint) from public, anon, authenticated, service_role;

grant execute on function record_stripe_fee(text,bigint) to service_role;

revoke all on function can_access_direct_conversation(uuid) from public, anon, authenticated, service_role;

grant execute on function can_access_direct_conversation(uuid) to authenticated;

grant execute on function can_access_direct_conversation(uuid) to service_role;

revoke all on function my_attachable_events() from public, anon, authenticated, service_role;

grant execute on function my_attachable_events() to authenticated;

grant execute on function my_attachable_events() to service_role;

revoke all on function can_attach_event(uuid) from public, anon, authenticated, service_role;

grant execute on function can_attach_event(uuid) to anon;

grant execute on function can_attach_event(uuid) to authenticated;

grant execute on function can_attach_event(uuid) to service_role;

revoke all on function purge_orphan_conversation() from public, anon, authenticated, service_role;

grant execute on function purge_orphan_conversation() to service_role;

revoke all on function direct_conversation_is_open(uuid) from public, anon, authenticated, service_role;

grant execute on function direct_conversation_is_open(uuid) to authenticated;

grant execute on function direct_conversation_is_open(uuid) to service_role;

revoke all on function my_direct_conversations() from public, anon, authenticated, service_role;

grant execute on function my_direct_conversations() to authenticated;

grant execute on function my_direct_conversations() to service_role;

revoke all on function handle_new_user() from public, anon, authenticated, service_role;

grant execute on function handle_new_user() to anon;

grant execute on function handle_new_user() to authenticated;

grant execute on function handle_new_user() to service_role;

revoke all on function rls_auto_enable() from public, anon, authenticated, service_role;

grant execute on function rls_auto_enable() to anon;

grant execute on function rls_auto_enable() to authenticated;

grant execute on function rls_auto_enable() to service_role;

revoke all on function deletion_paid_sales(uuid) from public, anon, authenticated, service_role;

grant execute on function deletion_paid_sales(uuid) to service_role;

revoke all on function deletion_pending_earnings(uuid) from public, anon, authenticated, service_role;

grant execute on function deletion_pending_earnings(uuid) to service_role;

revoke all on function deletion_paid_tickets(uuid) from public, anon, authenticated, service_role;

grant execute on function deletion_paid_tickets(uuid) to service_role;

revoke all on function account_deletion_preview() from public, anon, authenticated, service_role;

grant execute on function account_deletion_preview() to authenticated;

grant execute on function account_deletion_preview() to service_role;

revoke all on function issue_tickets_paid(uuid,integer,uuid,text) from public, anon, authenticated, service_role;

grant execute on function issue_tickets_paid(uuid,integer,uuid,text) to service_role;

revoke all on function prevent_delete_with_tickets() from public, anon, authenticated, service_role;

grant execute on function prevent_delete_with_tickets() to anon;

grant execute on function prevent_delete_with_tickets() to authenticated;

grant execute on function prevent_delete_with_tickets() to service_role;

revoke all on function notify_event_change() from public, anon, authenticated, service_role;

grant execute on function notify_event_change() to anon;

grant execute on function notify_event_change() to authenticated;

grant execute on function notify_event_change() to service_role;

revoke all on function unlock_private_event(text) from public, anon, authenticated, service_role;

grant execute on function unlock_private_event(text) to authenticated;

grant execute on function unlock_private_event(text) to service_role;

revoke all on function cancel_ticket_for_event(uuid,text) from public, anon, authenticated, service_role;

grant execute on function cancel_ticket_for_event(uuid,text) to service_role;

revoke all on function event_tickets_to_refund(uuid) from public, anon, authenticated, service_role;

grant execute on function event_tickets_to_refund(uuid) to service_role;

revoke all on function restore_cancelled_event(uuid) from public, anon, authenticated, service_role;

grant execute on function restore_cancelled_event(uuid) to authenticated;

grant execute on function restore_cancelled_event(uuid) to service_role;

revoke all on function cancellation_fee_terms() from public, anon, authenticated, service_role;

grant execute on function cancellation_fee_terms() to authenticated;

grant execute on function cancellation_fee_terms() to service_role;

revoke all on function user_holds_ticket_for(uuid) from public, anon, authenticated, service_role;

grant execute on function user_holds_ticket_for(uuid) to anon;

grant execute on function user_holds_ticket_for(uuid) to authenticated;

grant execute on function user_holds_ticket_for(uuid) to service_role;

revoke all on function blocked_users_details() from public, anon, authenticated, service_role;

grant execute on function blocked_users_details() to authenticated;

grant execute on function blocked_users_details() to service_role;

revoke all on function sync_event_attendance() from public, anon, authenticated, service_role;

grant execute on function sync_event_attendance() to anon;

grant execute on function sync_event_attendance() to authenticated;

grant execute on function sync_event_attendance() to service_role;

revoke all on function set_attendance_visibility(uuid,boolean) from public, anon, authenticated, service_role;

grant execute on function set_attendance_visibility(uuid,boolean) to authenticated;

grant execute on function set_attendance_visibility(uuid,boolean) to service_role;

revoke all on function who_is_going(uuid) from public, anon, authenticated, service_role;

grant execute on function who_is_going(uuid) to authenticated;

grant execute on function who_is_going(uuid) to service_role;

revoke all on function event_posts_are_public(uuid) from public, anon, authenticated, service_role;

grant execute on function event_posts_are_public(uuid) to anon;

grant execute on function event_posts_are_public(uuid) to authenticated;

grant execute on function event_posts_are_public(uuid) to service_role;

revoke all on function event_is_readable(uuid) from public, anon, authenticated, service_role;

grant execute on function event_is_readable(uuid) to anon;

grant execute on function event_is_readable(uuid) to authenticated;

grant execute on function event_is_readable(uuid) to service_role;

revoke all on function events_from_connections() from public, anon, authenticated, service_role;

grant execute on function events_from_connections() to authenticated;

grant execute on function events_from_connections() to service_role;

revoke all on function prevent_self_admin() from public, anon, authenticated, service_role;

grant execute on function prevent_self_admin() to anon;

grant execute on function prevent_self_admin() to authenticated;

grant execute on function prevent_self_admin() to service_role;

revoke all on function i_am_admin() from public, anon, authenticated, service_role;

grant execute on function i_am_admin() to authenticated;

grant execute on function i_am_admin() to service_role;

revoke all on function is_suspended() from public, anon, authenticated, service_role;

grant execute on function is_suspended() to authenticated;

grant execute on function is_suspended() to service_role;

revoke all on function admin_resolve_report(uuid,text,text) from public, anon, authenticated, service_role;

grant execute on function admin_resolve_report(uuid,text,text) to authenticated;

grant execute on function admin_resolve_report(uuid,text,text) to service_role;

revoke all on function admin_remove_content(text,uuid,uuid,text) from public, anon, authenticated, service_role;

grant execute on function admin_remove_content(text,uuid,uuid,text) to authenticated;

grant execute on function admin_remove_content(text,uuid,uuid,text) to service_role;

revoke all on function admin_set_suspended(uuid,boolean,uuid,text) from public, anon, authenticated, service_role;

grant execute on function admin_set_suspended(uuid,boolean,uuid,text) to authenticated;

grant execute on function admin_set_suspended(uuid,boolean,uuid,text) to service_role;

revoke all on function cancellation_fee_cents(bigint) from public, anon, authenticated, service_role;

grant execute on function cancellation_fee_cents(bigint) to authenticated;

grant execute on function cancellation_fee_cents(bigint) to service_role;

revoke all on function user_meets_age(uuid,integer) from public, anon, authenticated, service_role;

grant execute on function user_meets_age(uuid,integer) to service_role;

revoke all on function can_see_exact_address(uuid) from public, anon, authenticated, service_role;

grant execute on function can_see_exact_address(uuid) to anon;

grant execute on function can_see_exact_address(uuid) to authenticated;

grant execute on function can_see_exact_address(uuid) to service_role;

revoke all on function events_near(double precision,double precision,double precision) from public, anon, authenticated, service_role;

grant execute on function events_near(double precision,double precision,double precision) to anon;

grant execute on function events_near(double precision,double precision,double precision) to authenticated;

grant execute on function events_near(double precision,double precision,double precision) to service_role;

revoke all on function organizer_event_stats(uuid) from public, anon, authenticated, service_role;

grant execute on function organizer_event_stats(uuid) to authenticated;

grant execute on function organizer_event_stats(uuid) to service_role;

revoke all on function is_reserved_username(text) from public, anon, authenticated, service_role;

grant execute on function is_reserved_username(text) to anon;

grant execute on function is_reserved_username(text) to authenticated;

grant execute on function is_reserved_username(text) to service_role;

revoke all on function generate_username(text) from public, anon, authenticated, service_role;

grant execute on function generate_username(text) to authenticated;

grant execute on function generate_username(text) to service_role;

revoke all on function profiles_username_guard() from public, anon, authenticated, service_role;

grant execute on function profiles_username_guard() to anon;

grant execute on function profiles_username_guard() to authenticated;

grant execute on function profiles_username_guard() to service_role;

revoke all on function username_status(text) from public, anon, authenticated, service_role;

grant execute on function username_status(text) to authenticated;

grant execute on function username_status(text) to service_role;

revoke all on function search_profiles(text) from public, anon, authenticated, service_role;

grant execute on function search_profiles(text) to authenticated;

grant execute on function search_profiles(text) to service_role;

revoke all on function profile_follows(uuid,text) from public, anon, authenticated, service_role;

grant execute on function profile_follows(uuid,text) to authenticated;

grant execute on function profile_follows(uuid,text) to service_role;

revoke all on function reports_fill_label() from public, anon, authenticated, service_role;

grant execute on function reports_fill_label() to anon;

grant execute on function reports_fill_label() to authenticated;

grant execute on function reports_fill_label() to service_role;

revoke all on function platform_fee_bps() from public, anon, authenticated, service_role;

grant execute on function platform_fee_bps() to anon;

grant execute on function platform_fee_bps() to authenticated;

grant execute on function platform_fee_bps() to service_role;

revoke all on function record_payment(text,uuid,uuid,uuid,uuid,integer,bigint,bigint,integer) from public, anon, authenticated, service_role;

grant execute on function record_payment(text,uuid,uuid,uuid,uuid,integer,bigint,bigint,integer) to service_role;

revoke all on function record_refund(text,bigint) from public, anon, authenticated, service_role;

grant execute on function record_refund(text,bigint) to service_role;

revoke all on function record_dispute(text,boolean) from public, anon, authenticated, service_role;

grant execute on function record_dispute(text,boolean) to service_role;

revoke all on function my_payout_account() from public, anon, authenticated, service_role;

grant execute on function my_payout_account() to authenticated;

grant execute on function my_payout_account() to service_role;

revoke all on function claim_payout(uuid,uuid,text,bigint,bigint,bigint,bigint,bigint) from public, anon, authenticated, service_role;

grant execute on function claim_payout(uuid,uuid,text,bigint,bigint,bigint,bigint,bigint) to service_role;

revoke all on function event_ledger() from public, anon, authenticated, service_role;

grant execute on function event_ledger() to service_role;

revoke all on function event_cancellation_preview(uuid) from public, anon, authenticated, service_role;

grant execute on function event_cancellation_preview(uuid) to authenticated;

grant execute on function event_cancellation_preview(uuid) to service_role;

revoke all on function event_has_sales(uuid) from public, anon, authenticated, service_role;

grant execute on function event_has_sales(uuid) to authenticated;

grant execute on function event_has_sales(uuid) to service_role;

revoke all on function organizer_attendees(uuid) from public, anon, authenticated, service_role;

grant execute on function organizer_attendees(uuid) to authenticated;

grant execute on function organizer_attendees(uuid) to service_role;

revoke all on function cancel_event(uuid,uuid) from public, anon, authenticated, service_role;

grant execute on function cancel_event(uuid,uuid) to service_role;

revoke all on function events_due_for_payout() from public, anon, authenticated, service_role;

grant execute on function events_due_for_payout() to service_role;

revoke all on function private.setting(text) from public, anon, authenticated, service_role;

revoke all on function private.push_notification() from public, anon, authenticated, service_role;

revoke all on function profiles_guard_birth_date() from public, anon, authenticated, service_role;

grant execute on function profiles_guard_birth_date() to anon;

grant execute on function profiles_guard_birth_date() to authenticated;

grant execute on function profiles_guard_birth_date() to service_role;

revoke all on function delete_my_account_data() from public, anon, authenticated, service_role;

grant execute on function delete_my_account_data() to authenticated;

grant execute on function delete_my_account_data() to service_role;

revoke all on function translate_notification() from public, anon, authenticated, service_role;

grant execute on function translate_notification() to service_role;

revoke all on function notify_direct_message() from public, anon, authenticated, service_role;

grant execute on function notify_direct_message() to service_role;

revoke all on function transfer_ticket_to_user(uuid,uuid) from public, anon, authenticated, service_role;

grant execute on function transfer_ticket_to_user(uuid,uuid) to authenticated;

grant execute on function transfer_ticket_to_user(uuid,uuid) to service_role;

revoke all on function blocked_either_way(uuid,uuid) from public, anon, authenticated, service_role;

grant execute on function blocked_either_way(uuid,uuid) to authenticated;

grant execute on function blocked_either_way(uuid,uuid) to service_role;

revoke all on function notify_post_comment() from public, anon, authenticated, service_role;

grant execute on function notify_post_comment() to service_role;

revoke all on function pending_legal_documents(text) from public, anon, authenticated, service_role;

grant execute on function pending_legal_documents(text) to authenticated;

grant execute on function pending_legal_documents(text) to service_role;

revoke all on function admin_report_target(uuid) from public, anon, authenticated, service_role;

grant execute on function admin_report_target(uuid) to authenticated;

grant execute on function admin_report_target(uuid) to service_role;

revoke all on function admin_reports(text) from public, anon, authenticated, service_role;

grant execute on function admin_reports(text) to authenticated;

grant execute on function admin_reports(text) to service_role;

revoke all on function events_guard_cancellation() from public, anon, authenticated, service_role;

grant execute on function events_guard_cancellation() to service_role;

revoke all on function my_payouts() from public, anon, authenticated, service_role;

grant execute on function my_payouts() to authenticated;

grant execute on function my_payouts() to service_role;

revoke all on function posts_mark_edited() from public, anon, authenticated, service_role;

grant execute on function posts_mark_edited() to anon;

grant execute on function posts_mark_edited() to authenticated;

grant execute on function posts_mark_edited() to service_role;

revoke all on function profiles_guard_suspension() from public, anon, authenticated, service_role;

grant execute on function profiles_guard_suspension() to service_role;

revoke all on function can_cancel_ticket(uuid) from public, anon, authenticated, service_role;

grant execute on function can_cancel_ticket(uuid) to authenticated;

grant execute on function can_cancel_ticket(uuid) to service_role;

revoke all on function cancel_ticket(uuid,uuid,text,bigint) from public, anon, authenticated, service_role;

grant execute on function cancel_ticket(uuid,uuid,text,bigint) to service_role;

revoke all on function min_account_age() from public, anon, authenticated, service_role;

grant execute on function min_account_age() to authenticated;

grant execute on function min_account_age() to service_role;

revoke all on function i_meet_age(integer) from public, anon, authenticated, service_role;

grant execute on function i_meet_age(integer) to authenticated;

grant execute on function i_meet_age(integer) to service_role;

revoke all on function issue_tickets(uuid,integer) from public, anon, authenticated, service_role;

grant execute on function issue_tickets(uuid,integer) to authenticated;

grant execute on function issue_tickets(uuid,integer) to service_role;

revoke all on function accept_legal_documents(jsonb,text) from public, anon, authenticated, service_role;

grant execute on function accept_legal_documents(jsonb,text) to authenticated;

grant execute on function accept_legal_documents(jsonb,text) to service_role;

grant usage on schema public to anon, authenticated, service_role;
