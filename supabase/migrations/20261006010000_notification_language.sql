-- Les notifications dans la langue de la personne.
--
-- Toutes etaient redigees en anglais, en dur, par la base. Un utilisateur
-- francophone recevait « Your refund is on its way » dans une app entierement
-- traduite — sur l'ecran verrouille comme dans la liste.
--
-- ── Version simple, retenue le 2026-10-06 ───────────────────────────────────
--
-- La notification est ecrite UNE FOIS, dans la langue du profil au moment de
-- l'envoi. Changer de langue ensuite ne traduit pas les anciennes. La version
-- complete (stocker le type et ses valeurs, et reconstruire la phrase a
-- l'affichage) est reportee : voir docs/LANCEMENT.md, § 7.
--
-- ── Pourquoi un declencheur, et pas cinq fonctions modifiees ────────────────
--
-- Les textes sont ecrits dans cinq fonctions, dont `issue_tickets_paid`, que
-- le webhook Stripe appelle pour emettre des billets payes. Retoucher une
-- fonction d'argent pour changer une phrase, c'est risquer l'emission pour un
-- gain cosmetique. Un seul declencheur, AVANT l'insertion, traduit ce que ces
-- fonctions ont ecrit : elles restent intactes, et la traduction vit a un seul
-- endroit.
--
-- Il passe avant `send_push_on_notification` (AFTER INSERT) : la bulle sur le
-- telephone part donc deja traduite.
--
-- ── Ce que le declencheur ne doit JAMAIS faire ──────────────────────────────
--
-- Faire echouer l'insertion. Il s'execute dans la transaction qui emet le
-- billet : une erreur ici annulerait l'achat. Toute erreur est donc rattrapee
-- et la notification part en anglais, telle qu'elle a ete ecrite.

alter table public.profiles
  add column if not exists language text
    check (language in ('en', 'fr'));

comment on column public.profiles.language is
  'Langue des notifications, ecrite par l''app a chaque changement. NULL = anglais.';

create or replace function public.translate_notification()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_lang  text;
  v_event text;
  v_qty   integer;
  -- Les variables PL/pgSQL ne sont pas annulees par une exception : sans ces
  -- copies, une erreur entre le titre et le texte enverrait un titre francais
  -- sur un texte anglais.
  v_title text := new.title;
  v_body  text := new.body;
begin
  select p.language into v_lang from public.profiles p where p.id = new.user_id;
  if v_lang is distinct from 'fr' then
    return new;
  end if;

  if new.event_id is not null then
    select e.title into v_event from public.events e where e.id = new.event_id;
  end if;
  -- Sans titre (evenement supprime entre-temps), on garde l'anglais plutot
  -- que d'envoyer une phrase francaise trouee.
  if v_event is null and new.type <> 'direct_message' then
    return new;
  end if;

  -- Le titre est toujours introduit par « L'evenement » : il peut etre
  -- feminin (« Soiree... »), et accorder le participe sur lui serait faux une
  -- fois sur deux.
  --
  -- La version francaise dit exactement ce que dit l'anglaise : la quantite
  -- et la mention du remboursement sont lues dans le texte d'origine, pas
  -- recalculees. Deux calculs finiraient par se contredire.
  case new.type
    when 'ticket_confirmed' then
      v_qty := nullif(substring(new.body from '^\d+'), '')::integer;
      new.title := 'Billet confirmé';
      new.body := case
        when v_qty is null then 'Tes billets pour ' || v_event || ' sont dans « Mes billets ».'
        when v_qty = 1     then '1 billet pour ' || v_event || ' est dans « Mes billets ».'
        else v_qty::text || ' billets pour ' || v_event || ' sont dans « Mes billets ».'
      end;

    when 'event_cancelled' then
      new.title := 'Événement annulé';
      new.body := 'L''événement « ' || v_event || ' » a été annulé par l''organisateur.'
        || case when new.body like '%Your refund is on its way%'
                then ' Ton remboursement est en route — compte 5 à 10 jours '
                     || 'ouvrables pour le voir sur ta carte.'
                else '' end;

    when 'event_updated' then
      new.title := 'Événement modifié';
      new.body := 'L''événement « ' || v_event || ' » a été modifié — vérifie la nouvelle date ou le nouveau lieu.';

    when 'ticket_received' then
      new.title := 'Billet reçu 🎟️';
      new.body := 'Tu as reçu un billet pour ' || v_event || '. Retrouve-le dans « Mes billets ».';

    when 'ticket_cancelled' then
      new.title := 'Billet annulé';
      new.body := 'Ton billet pour ' || v_event || ' a été annulé.';

    else
      -- `direct_message` : le titre est le nom de l'expediteur et le texte est
      -- ce qu'il a ecrit. Rien a traduire. Un type inconnu reste tel quel.
      null;
  end case;

  return new;
exception when others then
  -- Jamais d'achat annule pour une phrase : on garde l'anglais.
  new.title := v_title;
  new.body  := v_body;
  raise warning 'translate_notification: % (%), notification laissee en anglais',
    sqlerrm, new.type;
  return new;
end;
$$;

revoke all on function public.translate_notification()
  from public, anon, authenticated;

drop trigger if exists translate_notification on public.notifications;
create trigger translate_notification
  before insert on public.notifications
  for each row execute function public.translate_notification();
