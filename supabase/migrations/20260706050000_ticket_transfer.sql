-- =============================================================================
-- HAPPYN — Transfert de billet (v1 : « chacun son billet »)
-- =============================================================================
-- Un porteur de billet peut le transférer à un autre utilisateur HAPPYN par
-- son email. Règles :
--   * Seul le propriétaire du billet peut le transférer (auth.uid()).
--   * Le billet doit être encore `valid` (pas scanné/utilisé).
--   * L'event ne doit être ni passé ni annulé.
--   * Le destinataire doit exister (avoir un compte HAPPYN) — on le retrouve
--     par email dans `profiles`.
--   * On régénère le `qr_token` : tout QR déjà affiché côté expéditeur devient
--     caduc côté serveur (le token de référence change).
--   * On trace l'origine (transferred_from / transferred_at).
--   * Le destinataire reçoit une notif in-app `ticket_received`.
-- Fonction SECURITY DEFINER : le client n'a toujours pas le droit d'UPDATE
-- direct sur `tickets` (voir plus bas), seul ce chemin réassigne un billet.
-- À exécuter dans le SQL Editor du dashboard Supabase.
-- =============================================================================

-- Traçabilité du transfert
alter table public.tickets
  add column if not exists transferred_from uuid references auth.users(id),
  add column if not exists transferred_at   timestamptz;

create or replace function public.transfer_ticket(
  p_ticket_id       uuid,
  p_recipient_email text
)
returns public.tickets
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user      uuid := auth.uid();
  v_recipient uuid;
  v_event     uuid;
  v_owner     uuid;
  v_status    text;
  v_ended     boolean;
  v_ev_status text;
  v_new_token text;
  v_ticket    public.tickets;
  v_email     text := lower(trim(p_recipient_email));
begin
  if v_user is null then
    raise exception 'not_authenticated';
  end if;

  -- Verrou de ligne sur le billet + contrôle de propriété
  -- (variables scalaires : un SELECT ... INTO rowtype mapperait par position)
  select user_id, event_id, status
    into v_owner, v_event, v_status
  from public.tickets
  where id = p_ticket_id
  for update;

  if not found then
    raise exception 'ticket_not_found';
  end if;

  if v_owner <> v_user then
    raise exception 'not_ticket_owner';
  end if;

  if coalesce(v_status, 'valid') <> 'valid' then
    raise exception 'ticket_not_transferable'; -- déjà scanné / annulé
  end if;

  -- L'event ne doit être ni annulé ni terminé
  select (end_date < now()), coalesce(status, 'published')
    into v_ended, v_ev_status
  from public.events
  where id = v_event;

  if v_ev_status = 'cancelled' then
    raise exception 'event_cancelled';
  end if;
  if coalesce(v_ended, false) then
    raise exception 'event_ended';
  end if;

  -- Résolution du destinataire par email
  select id into v_recipient
  from public.profiles
  where lower(email) = v_email
  limit 1;

  if v_recipient is null then
    raise exception 'recipient_not_found';
  end if;
  if v_recipient = v_user then
    raise exception 'cannot_transfer_self';
  end if;

  -- Régénère le token de référence (invalide le QR précédent côté serveur)
  v_new_token := 'HPN-' || replace(gen_random_uuid()::text, '-', '');

  update public.tickets
     set user_id          = v_recipient,
         qr_token         = v_new_token,
         transferred_from = v_user,
         transferred_at   = now()
   where id = p_ticket_id
  returning * into v_ticket;

  -- Notifie le destinataire
  insert into public.notifications (user_id, type, title, body, event_id)
  select v_recipient,
         'ticket_received',
         'Ticket received 🎟️',
         'You received a ticket for ' || e.title || '. Find it in “My Tickets”.',
         v_event
  from public.events e
  where e.id = v_event;

  return v_ticket;
end;
$$;

revoke all on function public.transfer_ticket(uuid, text) from public, anon;
grant execute on function public.transfer_ticket(uuid, text) to authenticated;
