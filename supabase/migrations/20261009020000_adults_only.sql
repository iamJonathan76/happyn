-- HAPPYN réservé aux 18 ans et plus — décidé le 2026-10-09.
--
-- Jusqu'ici : un compte dès 14 ans, 18 ans pour organiser. HAPPYN est aussi
-- un réseau social avec messagerie privée, et accueille tout type d'événement
-- (soirées, alcool) : des mineurs et des adultes inconnus qui peuvent
-- s'écrire, c'est le risque que surveillent les magasins d'applications et
-- les parents. Un mineur peut aussi faire annuler un achat après coup, et la
-- clause « un parent autorise » n'était vérifiée par rien. Eventbrite exige
-- l'âge de la majorité au Canada. Le faire maintenant ne coûte rien : aucun
-- compte de moins de 18 ans en production (vérifié le 2026-10-09). Pour un
-- événement familial, un parent achète le billet.
--
-- En même temps, les règles d'âge passent du côté du serveur. L'app les
-- vérifiait seule : un appel direct à l'API les contournait toutes — l'âge
-- minimum d'un événement à l'achat, les 18 ans pour organiser. Et la date de
-- naissance, sur laquelle tout repose, était modifiable à volonté.

-- ═══════════════════════════════════════════════════════════════════════════
-- La règle, à un seul endroit
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.min_account_age()
returns integer language sql immutable
set search_path = public
as $$ select 18 $$;

-- Le compte a-t-il l'âge requis — celui du compte, ou celui de l'événement
-- s'il est plus élevé ? Faux si la date de naissance est inconnue : une règle
-- d'âge qui laisse passer l'inconnu n'en est pas une.
--
-- Réservée au serveur : ouverte à tous, elle dirait l'âge de n'importe qui à
-- coups de questions « a-t-il 21 ans ? ».
create or replace function public.user_meets_age(p_user uuid, p_min integer default 0)
returns boolean language sql stable security definer
set search_path = public
as $$
  select coalesce((
    select p.date_of_birth
             <= (current_date - make_interval(
                   years => greatest(coalesce(p_min, 0), public.min_account_age())))::date
    from public.profiles p where p.id = p_user
  ), false)
$$;

-- La même, pour soi seulement : c'est elle que les règles d'accès appellent.
create or replace function public.i_meet_age(p_min integer default 0)
returns boolean language sql stable security definer
set search_path = public
as $$ select public.user_meets_age(auth.uid(), p_min) $$;

revoke all on function public.min_account_age()                from public, anon;
revoke all on function public.user_meets_age(uuid, integer)    from public, anon, authenticated;
revoke all on function public.i_meet_age(integer)              from public, anon;
grant execute on function public.min_account_age()             to authenticated, service_role;
grant execute on function public.user_meets_age(uuid, integer) to service_role;
grant execute on function public.i_meet_age(integer)           to authenticated, service_role;

-- ═══════════════════════════════════════════════════════════════════════════
-- La date de naissance : donnée une fois, puis figée
-- ═══════════════════════════════════════════════════════════════════════════

-- SANS `security definer` : dans une fonction definer, `current_user` vaut
-- son propriétaire, et le verrou ne reconnaîtrait jamais l'utilisateur. Le
-- test « la date de naissance est figée » l'a attrapé.
create or replace function public.profiles_guard_birth_date()
returns trigger language plpgsql security invoker
set search_path = public
as $$
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
$$;

drop trigger if exists profiles_guard_birth_date on public.profiles;
create trigger profiles_guard_birth_date
  before insert or update of date_of_birth on public.profiles
  for each row execute function public.profiles_guard_birth_date();

-- À l'inscription par e-mail, la date était saisie dans le formulaire mais
-- restait dans les métadonnées du compte : le profil ne la recevait qu'à
-- l'écran « Complète ton profil ». La recopier dès la création applique la
-- règle des 18 ans dès le premier instant — un compte créé directement par
-- l'API avec une date trop récente échoue ici. Une date illisible est ignorée
-- plutôt que d'empêcher l'inscription : l'app la redemandera.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer
set search_path = public
as $$
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
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- Organiser : 18 ans, vérifié par la base
-- ═══════════════════════════════════════════════════════════════════════════

drop policy if exists "Authenticated users can create events" on public.events;
create policy "Authenticated users can create events" on public.events
  as permissive for insert to authenticated
  with check (auth.uid() = created_by and not public.is_suspended() and public.i_meet_age(18));

-- 14+ et 16+ n'ont plus de sens : personne de moins de 18 ans n'a de compte.
-- Aucun événement ne les utilisait (vérifié le 2026-10-09).
alter table public.events drop constraint if exists events_min_age_check;
alter table public.events
  add constraint events_min_age_check check (min_age in (0, 18, 21));

-- ═══════════════════════════════════════════════════════════════════════════
-- Billets gratuits : l'âge de l'événement, vérifié par la base
-- ═══════════════════════════════════════════════════════════════════════════
-- Les billets payants le sont dans `create-payment-intent`, avant le paiement.

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

revoke all on function public.issue_tickets(uuid, integer) from public, anon;
grant execute on function public.issue_tickets(uuid, integer) to authenticated, service_role;
