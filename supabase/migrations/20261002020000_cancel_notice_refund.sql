-- La notification d'annulation parle de l'argent.
--
-- Elle disait « <titre> has been cancelled by the organizer. » et s'arretait
-- la. Du point de vue de l'acheteur, son evenement disparait et personne ne
-- lui dit si son argent revient — c'est pourtant sa premiere question.
--
-- Le remboursement part desormais automatiquement (`cancel-event`), donc on
-- peut l'annoncer. On ne l'annonce QUE pour les billets payants : ecrire
-- « ton remboursement arrive » a quelqu'un qui n'a rien paye le ferait
-- attendre un virement qui ne viendra jamais.
--
-- Le delai est dit, parce qu'il est reel : Stripe rend l'argent tout de
-- suite, la banque met 5 a 10 jours ouvrables a l'afficher. Sans cette
-- phrase, le silence passe pour une arnaque.
--
-- DETTE CONNUE : ces textes sont en anglais, en dur, pour tout le monde. Les
-- notifications ne sont pas traduites — ni celle-ci, ni les autres. A
-- reprendre en stockant une cle et ses parametres plutot qu'une phrase.

create or replace function public.notify_event_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
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
$$;
