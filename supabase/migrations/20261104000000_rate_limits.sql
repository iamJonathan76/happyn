-- Limitation de debit : un compteur par (action, compte, fenetre).
--
-- Rien ne bridait le RYTHME des actions sensibles. Un seul compte pouvait
-- marteler le code d'invitation (brute-force), noyer la file de signalements
-- (et vider le quota d'e-mails Resend au passage), ou ouvrir des conversations
-- en masse. La limite par personne existait pour les billets, mais par palier,
-- pas dans le temps.
--
-- Le mecanisme est volontairement simple : une fenetre FIXE (date_bin), un
-- compteur incremente a chaque action, une erreur 'rate_limited' au-dela. Il
-- s'appuie sur auth.uid() : il protege contre un COMPTE abusif. L'abus anonyme
-- par IP (pilonnage de lectures publiques, creation de comptes en masse) se
-- traite au bord (Cloudflare, reglages Auth), pas ici.

create table if not exists private.rate_limits (
  action       text        not null,
  subject      text        not null,
  window_start timestamptz not null,
  hits         integer     not null default 0,
  primary key (action, subject, window_start)
);

-- rl_hit : incremente le compteur de la fenetre courante et leve 'rate_limited'
-- au-dela de la limite. SECURITY DEFINER, appelee UNIQUEMENT depuis d'autres
-- fonctions/triggers definer (jamais accordee a un client : sinon n'importe qui
-- pourrait gonfler le compteur d'un autre pour le verrouiller).
create or replace function private.rl_hit(
  p_action text, p_subject text, p_limit integer, p_window interval
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_window timestamptz := date_bin(p_window, now(), timestamptz 'epoch');
  v_hits   integer;
begin
  insert into private.rate_limits (action, subject, window_start, hits)
  values (p_action, p_subject, v_window, 1)
  on conflict (action, subject, window_start)
  do update set hits = private.rate_limits.hits + 1
  returning hits into v_hits;

  if v_hits > p_limit then
    raise exception 'rate_limited';
  end if;
end $$;

revoke all on function private.rl_hit(text, text, integer, interval) from public;

-- ── Deverrouillage de code prive : 10 essais / heure ────────────────────────
-- Doit etre DANS la fonction : un mauvais code n'insere rien, donc un trigger
-- ne verrait jamais les essais rates — justement ceux du brute-force. Corps
-- repris a l'identique de la production, avec la seule ligne rl_hit ajoutee.
create or replace function public.unlock_private_event(p_code text)
returns setof public.events
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code  text := upper(trim(p_code));
  v_event uuid;
begin
  if auth.uid() is not null then
    perform private.rl_hit('unlock', auth.uid()::text, 10, interval '1 hour');
  end if;

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

  -- L'adresse precise n'est PAS ici : elle est dans event_addresses, dont la
  -- policy exige un billet. Deverrouiller donne acces a l'evenement, pas a son
  -- emplacement exact.
  return query select * from public.events where id = v_event;
end;
$$;

-- ── Signalements : 5 / heure ────────────────────────────────────────────────
-- Chaque insert declenche un e-mail (notify-report). Sans frein, un compte
-- vide le quota d'e-mails et noie les vraies alertes.
create or replace function private.rl_reports() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null then
    perform private.rl_hit('report', auth.uid()::text, 5, interval '1 hour');
  end if;
  return new;
end $$;
drop trigger if exists rl_reports_before on public.reports;
create trigger rl_reports_before before insert on public.reports
  for each row execute function private.rl_reports();

-- ── Nouvelles conversations : 20 / heure ────────────────────────────────────
-- Cap le nombre de NOUVELLES personnes a qui l'on ecrit par heure (le vecteur
-- « spammer plein de gens »). Les inserts du serveur hors session utilisateur
-- (auth.uid() nul) ne comptent pas.
create or replace function private.rl_new_conversation() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null then
    perform private.rl_hit('new_conversation', auth.uid()::text, 20, interval '1 hour');
  end if;
  return new;
end $$;
drop trigger if exists rl_new_conversation_before on public.direct_conversations;
create trigger rl_new_conversation_before before insert on public.direct_conversations
  for each row execute function private.rl_new_conversation();

-- ── Billets gratuits : 30 / heure ───────────────────────────────────────────
-- Les billets payants (payment_intent_id non nul) passent par Stripe : payer
-- est deja un frein, on ne les limite pas. Seule l'emission GRATUITE, qui ne
-- coute rien a l'attaquant, est bridee.
create or replace function private.rl_free_tickets() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.payment_intent_id is null and auth.uid() is not null then
    perform private.rl_hit('free_tickets', auth.uid()::text, 30, interval '1 hour');
  end if;
  return new;
end $$;
drop trigger if exists rl_free_tickets_before on public.tickets;
create trigger rl_free_tickets_before before insert on public.tickets
  for each row execute function private.rl_free_tickets();
