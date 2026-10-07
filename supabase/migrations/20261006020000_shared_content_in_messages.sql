-- Partager une publication ou un evenement dans une conversation privee.
--
-- C'est la moitie « dans HAPPYN » de la feuille d'envoi : on choisit des gens
-- qu'on suit, et la publication ou l'evenement leur arrive en message, sous
-- forme de carte. L'autre moitie (WhatsApp, menu de partage du telephone) ne
-- touche pas la base.
--
-- ── Ce que le message porte, et ce qu'il ne porte pas ───────────────────────
--
-- Une REFERENCE (`post_id` ou `event_id`), jamais une copie du contenu. La
-- carte est construite a l'affichage, avec les droits du DESTINATAIRE : une
-- publication reservee aux participants, ou un evenement prive, s'affiche
-- « contenu non disponible » chez qui n'y a pas acces. Copier le titre ou
-- l'image dans le message contournerait exactement ces regles.
--
-- Pour la meme raison, si le contenu disparait (publication supprimee,
-- evenement supprime), la reference passe a NULL et le message reste — avec
-- le mot qui l'accompagnait, s'il y en avait un. `shared_kind`, lui, ne
-- s'efface pas : c'est lui qui rend un partage sans mot valide. Fonder la
-- contrainte sur la reference faisait echouer la suppression de la
-- publication partagee — et, par cascade, celle du compte de son auteur
-- (trouve en executant cette migration avant de la livrer).
--
-- On ne construit pas une app de messagerie : pas de piece jointe libre, pas
-- de liste de contenus. Deux colonnes, et c'est tout.

alter table public.direct_messages
  add column if not exists shared_kind text,
  add column if not exists post_id uuid
    references public.posts(id) on delete set null,
  add column if not exists event_id uuid
    references public.events(id) on delete set null;

-- Une reference va avec son genre, et un message ne partage qu'une chose.
--
-- Ecrit en CASE, et pas en suite de OR : avec `shared_kind` NULL, une
-- comparaison vaut NULL, et une contrainte qui vaut NULL LAISSE PASSER. La
-- premiere ecriture acceptait ainsi une publication sans genre (vu en
-- executant la migration). Chaque branche ci-dessous rend vrai ou faux.
alter table public.direct_messages
  drop constraint if exists direct_message_shared_kind;
alter table public.direct_messages
  add constraint direct_message_shared_kind check (
    case shared_kind
      when 'post'  then event_id is null
      when 'event' then post_id  is null
      else shared_kind is null and post_id is null and event_id is null
    end
  );

-- Un partage peut partir sans mot : « regarde ca » est implicite. Le texte
-- reste obligatoire pour un message ordinaire, et plafonne dans tous les cas.
alter table public.direct_messages
  drop constraint if exists direct_message_body_length;
alter table public.direct_messages
  add constraint direct_message_body_length check (
    char_length(body) <= 2000
    and (char_length(trim(body)) >= 1 or shared_kind is not null)
  );

-- ── La notification d'un partage sans mot ───────────────────────────────────
--
-- Reprise de 20261005000000 ; seul l'apercu change. Un partage sans texte
-- donnait une notification vide sous le nom de l'expediteur. Il dit
-- maintenant ce qui a ete partage, dans la langue du destinataire — ce
-- declencheur ecrit lui-meme sa phrase, `translate_notification` ne touche
-- pas aux messages prives.

create or replace function public.notify_direct_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_recipient uuid;
  v_sender    text;
  v_lang      text;
  v_preview   text;
begin
  select case when c.member_a = new.sender_id then c.member_b else c.member_a end
    into v_recipient
  from public.direct_conversations c
  where c.id = new.conversation_id;

  if v_recipient is null then
    return new;
  end if;

  -- Un blocage dans un sens ou dans l'autre coupe la notification. La
  -- politique d'insertion devrait deja l'avoir empeche, mais une notification
  -- poussee est visible sur un ecran verrouille : on verifie deux fois plutot
  -- que de faire apparaitre le nom de quelqu'un qu'on a bloque.
  if exists (
    select 1 from public.blocked_users b
    where (b.blocker_id = v_recipient and b.blocked_id = new.sender_id)
       or (b.blocker_id = new.sender_id and b.blocked_id = v_recipient)
  ) then
    return new;
  end if;

  select coalesce(nullif(trim(p.full_name), ''), p.username, 'HAPPYN')
    into v_sender
  from public.profiles p
  where p.id = new.sender_id;

  select p.language into v_lang from public.profiles p where p.id = v_recipient;

  -- Tronque : une notification est un apercu, pas le message. 2000
  -- caracteres sur un ecran verrouille n'aident personne.
  v_preview := left(trim(new.body), 140);
  if v_preview = '' then
    v_preview := case
      when new.shared_kind = 'post'  and v_lang = 'fr' then 'A partagé une publication'
      when new.shared_kind = 'post'                    then 'Shared a post'
      when new.shared_kind = 'event' and v_lang = 'fr' then 'A partagé un événement'
      when new.shared_kind = 'event'                   then 'Shared an event'
      else v_preview
    end;
  end if;

  delete from public.notifications
  where user_id = v_recipient
    and type = 'direct_message'
    and conversation_id = new.conversation_id
    and read = false;

  insert into public.notifications
    (user_id, type, title, body, conversation_id)
  values (
    v_recipient,
    'direct_message',
    coalesce(v_sender, 'HAPPYN'),
    v_preview,
    new.conversation_id
  );

  return new;
end;
$$;

revoke all on function public.notify_direct_message() from public, anon, authenticated;
