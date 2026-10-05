-- Rapatrier l'envoi des notifications dans le depot, et notifier les messages.
--
-- ── Pourquoi cette migration existe ─────────────────────────────────────────
--
-- `send-push` est appelee par un declencheur qui n'existe QUE dans le tableau
-- de bord Supabase, cree a la main. Il fonctionne en production — verifie le
-- 2026-10-04, reponse 200 et notification recue — mais il n'est nulle part
-- dans le code. Une base recreee, ou l'environnement d'un autre developpeur,
-- n'a aucune notification, et rien n'explique pourquoi.
--
-- C'est la troisieme fois dans ce projet qu'un comportement vivant en
-- production est invisible dans le depot. On le corrige ici.
--
-- ── Le probleme du secret ───────────────────────────────────────────────────
--
-- Le declencheur doit presenter `PUSH_HOOK_SECRET` a `send-push`. Ce secret ne
-- peut pas etre ecrit ici : une migration est versionnee, et un secret dans
-- Git est un secret brule. Il ne peut pas non plus venir des secrets Supabase,
-- qui sont visibles des fonctions Edge, pas de Postgres.
--
-- On le range donc dans une table que SEUL `service_role` peut lire, remplie
-- une fois a la main. La migration cree le contenant, jamais le contenu.
--
-- Et si la table est vide, le declencheur ne fait RIEN, en silence. Une base
-- de developpement sans notifications poussees est normale ; une base qui
-- refuse d'enregistrer une notification parce qu'elle ne peut pas la pousser
-- serait une panne.

create schema if not exists private;

create table if not exists private.settings (
  key   text primary key,
  value text not null
);

-- Personne d'autre que `service_role`. Pas de RLS ici : RLS protege les lignes
-- d'une table exposee, et cette table ne doit pas etre exposee du tout.
revoke all on schema private from public, anon, authenticated;
revoke all on private.settings from public, anon, authenticated;

create or replace function private.setting(p_key text)
returns text
language sql
stable
security definer
set search_path = private, public
as $$
  select value from private.settings where key = p_key;
$$;

revoke all on function private.setting(text) from public, anon, authenticated;

-- ── Le declencheur d'envoi ──────────────────────────────────────────────────
--
-- `net.http_post` est asynchrone : il met l'appel en file et rend la main. La
-- transaction qui insere la notification n'attend donc pas Firebase, et un
-- Firebase lent ou injoignable ne ralentit jamais un achat de billet.
--
-- La reponse part dans `net._http_response`, qui est la seule trace quand une
-- notification n'arrive pas. C'est par la qu'on a diagnostique le 2026-10-04.

create extension if not exists pg_net with schema extensions;

create or replace function private.push_notification()
returns trigger
language plpgsql
security definer
set search_path = private, public, extensions
as $$
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
$$;

revoke all on function private.push_notification() from public, anon, authenticated;

-- On ne recree PAS le declencheur s'il existe deja : celui du tableau de bord
-- fonctionne, et en poser un second ferait partir deux notifications pour
-- chaque evenement. Sur une base neuve, celui-ci prend le relais.
do $$
begin
  if not exists (
    select 1 from pg_trigger
    where tgrelid = 'public.notifications'::regclass
      and not tgisinternal
  ) then
    create trigger send_push_on_notification
      after insert on public.notifications
      for each row execute function private.push_notification();
  end if;
end;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- Notifier les messages prives
-- ═══════════════════════════════════════════════════════════════════════════
--
-- Le trou le plus visible de l'app : quelqu'un ecrit, le destinataire ne
-- l'apprend qu'en ouvrant l'app. Pour une app sociale, c'est la notification
-- qui compte le plus.

alter table public.notifications
  add column if not exists conversation_id uuid
    references public.direct_conversations(id) on delete cascade;

-- ── Regroupement ────────────────────────────────────────────────────────────
--
-- Dix messages d'affilee ne doivent pas faire dix notifications. On supprime
-- la precedente NON LUE de la meme conversation avant d'inserer : la liste
-- montre une ligne par conversation, pas une par message.
--
-- Non lue seulement : une notification deja lue appartient a l'historique de
-- la personne, et l'effacer serait reecrire ce qu'elle a vu.
--
-- Cote telephone, le regroupement est assure par `collapse_key` dans
-- `send-push` : Android remplace la bulle precedente de la meme conversation
-- au lieu d'empiler.
--
-- ── Et quand la conversation est deja ouverte a l'ecran ? ───────────────────
--
-- Rien a faire : Android ne montre pas de notification quand l'app est au
-- premier plan (le message part dans `onMessage`, pas dans la barre). La base
-- ne sait pas ce qui est affiche, et ce n'est pas a elle de le savoir.

create or replace function public.notify_direct_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_recipient uuid;
  v_sender    text;
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
    -- Tronque : une notification est un apercu, pas le message. 2000
    -- caracteres sur un ecran verrouille n'aident personne.
    left(trim(new.body), 140),
    new.conversation_id
  );

  return new;
end;
$$;

revoke all on function public.notify_direct_message() from public, anon, authenticated;

drop trigger if exists notify_on_direct_message on public.direct_messages;
create trigger notify_on_direct_message
  after insert on public.direct_messages
  for each row execute function public.notify_direct_message();
