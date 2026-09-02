-- Annulation d'un billet par son détenteur, et remboursement.
--
-- Il manquait le geste le plus banal d'une billetterie : « je ne peux plus y
-- aller ». L'acheteur n'avait aucun bouton, l'organisateur aucun outil, et la
-- place restait bloquée pour toujours — comptée comme vendue alors que
-- personne ne viendrait.
--
-- Trois pièges traités ici :
--
--   1. `tickets` n'a AUCUNE policy d'écriture, et c'est délibéré : c'est ce qui
--      empêche un client de se fabriquer un billet. L'annulation passe donc par
--      une fonction SECURITY DEFINER, pas par un update depuis l'app.
--
--   2. La place doit être RENDUE. `quantity_sold` est ce qui limite les ventes ;
--      annuler sans le décrémenter retire une place du marché définitivement.
--
--   3. Un `payment_intent_id` couvre souvent PLUSIEURS billets (achat groupé).
--      Rembourser l'intention entière rendrait l'argent des billets qu'on garde.
--      La fonction renvoie donc le montant du seul billet annulé, et la fonction
--      Edge demande à Stripe un remboursement PARTIEL de ce montant.

-- ── Fenêtre d'annulation, choisie par l'organisateur ────────────────────────
-- Le recueil légal dit que les conditions de remboursement appartiennent à
-- l'organisateur. Sans ce réglage, cette phrase serait fausse.
--
-- 24 h par défaut : assez pour couvrir un imprévu, assez tôt pour que
-- l'organisateur puisse revendre la place. `0` désactive l'annulation.

alter table public.events
  add column if not exists cancellation_hours integer not null default 24;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'events_cancellation_hours_check'
  ) then
    alter table public.events
      add constraint events_cancellation_hours_check
      check (cancellation_hours between 0 and 720);
  end if;
end $$;

comment on column public.events.cancellation_hours is
  'Combien d''heures avant le début un acheteur peut annuler lui-même. '
  '0 = annulation impossible. Maximum 720 (30 jours).';

-- ── Traçabilité sur le billet ───────────────────────────────────────────────
-- On garde la ligne plutôt que de la supprimer : l'acheteur doit conserver la
-- trace de ce qu'il a payé et de son remboursement, et l'organisateur celle de
-- ce qui s'est passé sur son événement.

alter table public.tickets
  add column if not exists cancelled_at timestamptz,
  add column if not exists refunded_at  timestamptz,
  add column if not exists refund_id    text;

-- ── Puis-je annuler ce billet, et jusqu'à quand ? ───────────────────────────
-- Sert à l'affichage : montrer un bouton qui échouera est pire que ne rien
-- montrer. La vraie décision reste prise à l'annulation, côté serveur.

create or replace function public.can_cancel_ticket(p_ticket uuid)
returns table (
  allowed   boolean,
  reason    text,
  deadline  timestamptz,
  amount    numeric
)
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  v_user     uuid;
  v_status   text;
  v_start    timestamptz;
  v_evstatus text;
  v_hours    integer;
  v_price    numeric;
begin
  select t.user_id, t.status, e.start_date, e.status,
         coalesce(e.cancellation_hours, 24), coalesce(tt.price, 0)
    into v_user, v_status, v_start, v_evstatus, v_hours, v_price
  from public.tickets t
  join public.events e on e.id = t.event_id
  left join public.ticket_types tt on tt.id = t.ticket_type_id
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
    -- Déjà utilisé, déjà annulé, ou transféré : il n'y a plus rien à annuler.
    return query select false, 'ticket_not_valid'::text, null::timestamptz, v_price;
    return;
  end if;

  -- Événement annulé par l'organisateur : ce n'est pas à l'acheteur d'annuler,
  -- c'est un remboursement qui lui est dû. Traité séparément.
  if v_evstatus = 'cancelled' then
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

revoke all on function public.can_cancel_ticket(uuid) from public, anon;
grant execute on function public.can_cancel_ticket(uuid) to authenticated;

-- ── L'annulation elle-même ──────────────────────────────────────────────────
-- Appelée par la fonction Edge `cancel-ticket` (service_role) APRÈS que Stripe
-- a confirmé le remboursement, ou immédiatement pour un billet gratuit.
--
-- `p_actor` est passé explicitement : sous service_role, `auth.uid()` est nul,
-- et on veut quand même vérifier que la personne qui demande est bien celle qui
-- détient le billet.

create or replace function public.cancel_ticket(
  p_ticket    uuid,
  p_actor     uuid,
  p_refund_id text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user   uuid;
  v_status text;
  v_type   uuid;
begin
  select user_id, status, ticket_type_id
    into v_user, v_status, v_type
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
$$;

-- Personne ne peut l'appeler directement : uniquement la fonction Edge, qui
-- s'exécute en service_role et a d'abord identifié l'appelant. Laisser
-- `authenticated` l'appeler permettrait d'annuler sans passer par Stripe, donc
-- de rendre une place sans jamais rembourser.
revoke all on function public.cancel_ticket(uuid, uuid, text)
  from public, anon, authenticated;
