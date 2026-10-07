-- Transferer un billet a quelqu'un qu'on suit, et plus a une adresse courriel.
--
-- ── Ce que l'ancien transfert laissait passer ───────────────────────────────
--
-- `transfer_ticket(uuid, text)` resolvait le destinataire par son courriel.
-- Relu le 2026-10-07, il avait trois trous :
--
--   1. AUCUN controle d'age. Un billet 18+ partait vers un compte de 14 ans,
--      alors que ce meme compte ne pouvait pas l'acheter.
--   2. AUCUN controle de blocage. On pouvait envoyer un billet — et la
--      notification qui va avec — a quelqu'un qui nous avait bloque.
--   3. Il disait qui est inscrit. « recipient_not_found » pour une adresse
--      inconnue, un transfert pour une adresse connue : en essayant des
--      courriels, on dressait la liste des comptes HAPPYN. L'ecran de
--      connexion, lui, a ete ecrit expres pour ne jamais le reveler.
--
-- Decide le 2026-10-07 : on transfere seulement a quelqu'un QU'ON SUIT, choisi
-- dans une liste, et le transfert par courriel disparait. Choisir parmi ses
-- abonnements ne revele rien : on les connait deja.
--
-- ── Et le remboursement ─────────────────────────────────────────────────────
--
-- Avant : le nouveau detenteur d'un billet paye pouvait l'annuler, et Stripe
-- remboursait la carte de l'ACHETEUR — la seule qu'il sache rembourser. Le
-- nouveau detenteur perdait son billet sans rien recuperer ; si l'acheteur
-- avait ete paye de la main a la main, il touchait deux fois.
--
-- Decide le 2026-10-07 : un billet paye transfere n'est plus remboursable a
-- la demande. Le transfert vaut revente, comme dans la plupart des
-- billetteries ; l'ecran de confirmation le dit avant d'envoyer.
--
-- Seule exception, impossible a eviter : si l'ORGANISATEUR annule
-- l'evenement, `cancel-event` rembourse quand meme — vers la carte de
-- l'acheteur d'origine. Un billet gratuit transfere, lui, reste annulable :
-- il n'y a rien a rembourser, seulement une place a rendre.

create or replace function public.transfer_ticket_to_user(
  p_ticket_id uuid,
  p_recipient uuid
)
returns public.tickets
language plpgsql
security definer
set search_path = public
as $$
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
$$;

revoke all on function public.transfer_ticket_to_user(uuid, uuid) from public, anon;
grant execute on function public.transfer_ticket_to_user(uuid, uuid) to authenticated;

-- L'ancien transfert disparait plutot que de rester appelable : laisse en
-- place, il resterait un annuaire des comptes accessible a n'importe quelle
-- session, meme sans ecran pour l'appeler.
drop function if exists public.transfer_ticket(uuid, text);

-- ── L'annulation ────────────────────────────────────────────────────────────
--
-- Reprise de 20261002030000 ; une seule garde ajoutee, `transferred`, juste
-- apres le controle du statut.

create or replace function public.can_cancel_ticket(p_ticket uuid)
returns table (
  allowed  boolean,
  reason   text,
  deadline timestamptz,
  amount   numeric
)
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  v_user        uuid;
  v_status      text;
  v_start       timestamptz;
  v_ev          text;
  v_hours       integer;
  v_price       numeric;
  v_transferred boolean;
begin
  select t.user_id, t.status, e.start_date, e.status,
         coalesce(e.cancellation_hours, 24),
         public.ticket_paid_cents(t.id)::numeric / 100,
         t.transferred_from is not null
    into v_user, v_status, v_start, v_ev, v_hours, v_price, v_transferred
  from public.tickets t
  join public.events e on e.id = t.event_id
  where t.id = p_ticket;

  if v_user is null then
    return query select false, 'not_found'::text, null::timestamptz, 0::numeric;
    return;
  end if;
  if v_user <> auth.uid() then
    return query select false, 'not_owner'::text, null::timestamptz, 0::numeric;
    return;
  end if;
  if v_status <> 'valid' then
    return query select false, 'ticket_not_valid'::text, null::timestamptz, v_price;
    return;
  end if;

  -- Paye puis transfere : plus remboursable a la demande. Stripe ne saurait
  -- rembourser que la carte de l'acheteur, pas la personne qui annule.
  if v_transferred and v_price > 0 then
    return query select false, 'transferred'::text, null::timestamptz, v_price;
    return;
  end if;

  -- Evenement annule par l'organisateur : le remboursement part tout seul
  -- (`cancel-event`). Ce n'est pas a l'acheteur de le demander.
  if v_ev = 'cancelled' then
    return query select false, 'event_cancelled'::text, null::timestamptz, v_price;
    return;
  end if;

  if v_hours = 0 then
    return query select false, 'not_allowed_by_organizer'::text,
                        null::timestamptz, v_price;
    return;
  end if;

  return query
  select now() < (v_start - make_interval(hours => v_hours)),
         case when now() < (v_start - make_interval(hours => v_hours))
              then 'ok' else 'deadline_passed' end,
         v_start - make_interval(hours => v_hours),
         v_price;
end;
$$;
