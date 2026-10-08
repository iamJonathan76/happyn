-- Durcissement de securite, suite a l'audit du 2026-10-08.
--
-- Audit : advisors Supabase (securite + performance) passes sur la base de
-- production, puis chaque alerte verifiee a la main. Le detail est dans
-- docs/AUDIT-2026-10-08.md. Ici, seulement ce qui se corrige en base.
--
-- ── 1. CRITIQUE — des billets payants gratuitement ──────────────────────────
--
-- `issue_tickets` emet des billets sans paiement, pour les evenements
-- gratuits. Elle ne verifiait jamais le prix : le tri gratuit/payant n'etait
-- fait que par l'app. N'importe quel compte pouvait l'appeler directement
-- (`/rest/v1/rpc/issue_tickets`) avec l'id d'un palier payant et recevoir des
-- billets valides — QR signe compris. Exactement l'erreur que ce projet
-- s'interdit : une regle dans l'app n'est qu'un confort d'affichage.
--
-- Elle ne verifiait pas non plus la visibilite : un evenement prive
-- s'obtenait avec le seul id de son palier, sans le code d'acces.
--
-- Reprise de la definition de production, deux gardes ajoutees.

CREATE OR REPLACE FUNCTION public.issue_tickets(p_ticket_type_id uuid, p_quantity integer)
 RETURNS SETOF tickets
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $$
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

  select end_date, status, title into v_end, v_status, v_title
  from public.events where id = v_event;

  if v_status <> 'published' then raise exception 'event_not_available'; end if;
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
$$;

-- ── 2. Le code d'invitation ne s'essaie plus sans compte ────────────────────
--
-- `unlock_private_event` etait executable par `anon` : on pouvait essayer des
-- codes en boucle sans meme s'inscrire. Un compte n'arrete pas un acharne,
-- mais il donne au moins quelqu'un a suspendre. (La limitation de debit reste
-- a faire — voir l'audit.)

-- Retirer le droit a `anon` seul ne suffit pas : une fonction est executable
-- par PUBLIC par defaut, et `anon` en herite (vu en executant la migration).
revoke execute on function public.unlock_private_event(text) from public, anon;
grant  execute on function public.unlock_private_event(text) to authenticated;

-- ── 3. search_path fige partout ─────────────────────────────────────────────
--
-- Sept fonctions n'avaient pas de search_path fige, dont une SECURITY DEFINER
-- (`handle_new_user`, appelee a chaque inscription). C'est le vecteur classique
-- d'elevation de privilege sur Postgres : une fonction qui s'execute avec les
-- droits du proprietaire resout ses noms dans un chemin que l'appelant peut
-- influencer. Le risque est faible sur Supabase (personne ne peut creer
-- d'objets via l'API), mais la regle du projet est « zero exception ».

alter function public.handle_new_user()             set search_path = public;
alter function public.prevent_delete_with_tickets() set search_path = public;
alter function public.is_reserved_username(text)    set search_path = public;
alter function public.posts_mark_edited()           set search_path = public;
alter function public.platform_fee_bps()            set search_path = public;
alter function public.events_lock_fee()             set search_path = public;
alter function public.payout_delay_days()           set search_path = public;

-- ── 4. Les vues publiques ne sont plus lisibles sans compte ─────────────────
--
-- `public_profiles` (nom, photo, ville, bio, identifiant de TOUS les comptes)
-- et `feed_posts` etaient lisibles par `anon` : de quoi aspirer l'annuaire
-- des membres sans s'inscrire. Ni l'app avant connexion ni le site ne les
-- lisent. Ce sont des vues SECURITY DEFINER par conception — elles ne
-- montrent que des colonnes publiques d'une table dont la RLS ne laisse lire
-- que sa propre ligne — mais rien ne justifie de les ouvrir aux anonymes.

revoke select on public.public_profiles from anon;
revoke select on public.feed_posts      from anon;
