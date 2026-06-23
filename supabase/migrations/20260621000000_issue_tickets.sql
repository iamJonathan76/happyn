-- =============================================================================
-- HAPPYN — Step 1 sécurité billetterie : émission de tickets côté serveur
-- =============================================================================
-- Objectif :
--   1. Générer le qr_token côté serveur avec un identifiant ALÉATOIRE non
--      devinable (UUID, ~122 bits d'entropie) au lieu de l'ancien format
--      prévisible 'HPN-{timestamp}-{userId8}'.
--   2. Rendre l'achat ATOMIQUE : verrou de ligne sur le ticket_type, contrôle
--      du stock, insertion des N tickets et décompte du stock dans une seule
--      transaction (corrige le bug "1 QR pour N places" + les achats
--      concurrents qui dépassaient quantity_total).
--   3. Empêcher la forge : on retire le droit d'INSERT direct sur `tickets`.
--      Seule cette fonction (SECURITY DEFINER) peut créer des tickets.
--
-- À exécuter dans le SQL Editor du dashboard Supabase (ou via la CLI plus tard).
-- =============================================================================

create or replace function public.issue_tickets(
  p_ticket_type_id uuid,
  p_quantity int
)
returns setof public.tickets
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user      uuid := auth.uid();
  v_event     uuid;
  v_remaining int;
  v_i         int;
  v_token     text;
begin
  -- L'appelant doit être authentifié
  if v_user is null then
    raise exception 'not_authenticated';
  end if;

  -- Garde-fou sur la quantité (aligné avec le stepper UI : 1..10)
  if p_quantity is null or p_quantity < 1 or p_quantity > 10 then
    raise exception 'invalid_quantity';
  end if;

  -- Verrou de ligne : empêche deux achats concurrents de dépasser le stock
  select event_id, (quantity_total - quantity_sold)
    into v_event, v_remaining
  from public.ticket_types
  where id = p_ticket_type_id
  for update;

  if not found then
    raise exception 'ticket_type_not_found';
  end if;

  if v_remaining < p_quantity then
    raise exception 'insufficient_stock';
  end if;

  -- Insertion d'un ticket par unité achetée, chacun avec un token aléatoire
  for v_i in 1..p_quantity loop
    v_token := 'HPN-' || replace(gen_random_uuid()::text, '-', '');
    return query
      insert into public.tickets (ticket_type_id, event_id, user_id, qr_token, status)
      values (p_ticket_type_id, v_event, v_user, v_token, 'valid')
      returning *;
  end loop;

  -- Décompte du stock (dans la même transaction, ligne déjà verrouillée)
  update public.ticket_types
     set quantity_sold = quantity_sold + p_quantity
   where id = p_ticket_type_id;
end;
$$;

-- Seuls les utilisateurs authentifiés peuvent appeler la fonction
revoke all on function public.issue_tickets(uuid, int) from public, anon;
grant execute on function public.issue_tickets(uuid, int) to authenticated;

-- -----------------------------------------------------------------------------
-- Anti-forge : retirer l'INSERT direct sur `tickets`.
-- La fonction ci-dessus tourne en SECURITY DEFINER et bypass donc la RLS,
-- mais le client, lui, ne peut plus insérer de ticket arbitraire.
-- (Le SELECT reste : l'utilisateur voit toujours ses propres tickets.)
-- -----------------------------------------------------------------------------
drop policy if exists "Users can buy tickets" on public.tickets;
