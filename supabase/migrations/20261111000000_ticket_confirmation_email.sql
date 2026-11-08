-- Courriel de confirmation à l'émission d'un billet — GRATUIT comme PAYANT.
--
-- On se branche sur la notification `ticket_confirmed`, déjà créée une seule
-- fois par achat dans `issue_tickets` et `issue_tickets_paid` (migration
-- 20260706040000). Plutôt que de recréer ces grosses fonctions SECURITY
-- DEFINER — chaque recréation est une occasion d'en perdre un bout — un simple
-- déclencheur sur cette notif suffit, et il couvre les deux chemins d'émission
-- au même endroit. Zéro risque sur l'émission elle-même.
--
-- Même mécanisme que le push : l'URL et le secret vivent dans `private.settings`
-- (jamais dans Git). Sans eux, on n'envoie rien et on n'échoue pas. Le secret
-- (`x-happyn-secret`) protège la fonction Edge `send-ticket-confirmation`,
-- comparé en temps constant côté fonction.
--
-- Le courriel est best-effort : le trigger met l'appel HTTP en file (net.http_post
-- est asynchrone) et rend la main ; une panne d'envoi ne casse jamais l'achat.

create or replace function private.email_ticket_confirmation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_url    text := private.setting('ticket_hook_url');
  v_secret text := private.setting('ticket_hook_secret');
  v_qty    int;
begin
  if v_url is null or v_secret is null then
    return new;  -- Base non configurée : on n'envoie pas, on n'échoue pas.
  end if;

  -- Le corps de la notif commence par le nombre de billets (« 3 tickets for … »
  -- / « 1 ticket for … »). On en tire la quantité pour le courriel.
  v_qty := coalesce((regexp_match(new.body, '^(\d+)'))[1]::int, 1);

  perform net.http_post(
    url     := v_url,
    headers := jsonb_build_object(
                 'Content-Type',    'application/json',
                 'x-happyn-secret', v_secret
               ),
    body    := jsonb_build_object(
                 'user_id',  new.user_id,
                 'event_id', new.event_id,
                 'quantity', v_qty
               )
  );
  return new;
end $$;

-- Un trigger, pas une fonction d'API : personne ne doit pouvoir l'appeler.
revoke all on function private.email_ticket_confirmation()
  from public, anon, authenticated;

drop trigger if exists ticket_confirmed_email on public.notifications;
create trigger ticket_confirmed_email
  after insert on public.notifications
  for each row
  when (new.type = 'ticket_confirmed')
  execute function private.email_ticket_confirmation();
