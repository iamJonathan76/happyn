-- Un billet transféré arrive aussi dans la conversation, avec un mot.
--
-- Avant, le transfert ne laissait qu'une notification et le billet dans
-- « Billets » : rien dans la conversation ne disait qui l'avait envoyé. Le
-- transfert y dépose maintenant un message (« … t'a transféré un billet »),
-- avec le mot facultatif de l'expéditeur.
--
-- ── Seul le serveur crée ces messages ──────────────────────────────────────
-- La règle d'envoi laissait l'app insérer tout message à son nom. Un type
-- « billet » ouvert à tous aurait permis de fabriquer un faux « je t'ai
-- transféré un billet ». La règle refuse désormais ce type ; seule
-- `transfer_ticket_to_user`, qui fait le vrai transfert, l'écrit.

alter table public.direct_messages
  add column if not exists ticket_id uuid references public.tickets(id) on delete set null;

alter table public.direct_messages drop constraint if exists direct_message_shared_kind;
alter table public.direct_messages add constraint direct_message_shared_kind check (
  case shared_kind
    when 'post'   then event_id is null and ticket_id is null
    when 'event'  then post_id is null and ticket_id is null
    when 'ticket' then post_id is null
    else shared_kind is null and post_id is null and event_id is null and ticket_id is null
  end);

drop policy if exists "conversation participants can send messages" on public.direct_messages;
create policy "conversation participants can send messages" on public.direct_messages
  as permissive for insert to authenticated
  with check (
    sender_id = auth.uid()
    and public.can_access_direct_conversation(conversation_id)
    and public.direct_conversation_is_open(conversation_id)
    and shared_kind is distinct from 'ticket'
  );

-- Nouvelle signature (un mot facultatif) : on retire l'ancienne pour qu'un
-- appel ne trouve qu'une fonction.
drop function if exists public.transfer_ticket_to_user(uuid, uuid);

CREATE OR REPLACE FUNCTION public.transfer_ticket_to_user(p_ticket_id uuid, p_recipient uuid, p_note text DEFAULT NULL::text)
 RETURNS tickets
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
  v_note      text := nullif(trim(coalesce(p_note, '')), '');
  v_conv      uuid;
begin
  if v_user is null then
    raise exception 'not_authenticated';
  end if;
  -- Un mot, pas une lettre : le message part avec le billet.
  if char_length(coalesce(v_note, '')) > 500 then
    raise exception 'note_too_long';
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

  -- Le transfert arrive aussi dans la conversation, avec le mot s'il y en a
  -- un : ouvrir la conversation dit qui a envoye quoi, sans aller fouiller
  -- dans Billets. Toujours possible : on vient de verifier le suivi et
  -- l'absence de blocage, la porte meme de la messagerie.
  insert into public.direct_conversations (member_a, member_b)
  values (least(v_user, p_recipient), greatest(v_user, p_recipient))
  on conflict (member_a, member_b) do nothing;

  select id into v_conv
  from public.direct_conversations
  where member_a = least(v_user, p_recipient)
    and member_b = greatest(v_user, p_recipient);

  insert into public.direct_messages
    (conversation_id, sender_id, body, shared_kind, event_id, ticket_id)
  values (v_conv, v_user, coalesce(v_note, ''), 'ticket', v_event, p_ticket_id);

  return v_ticket;
end;
$function$;

revoke all on function public.transfer_ticket_to_user(uuid, uuid, text) from public, anon;
grant execute on function public.transfer_ticket_to_user(uuid, uuid, text) to authenticated, service_role;

CREATE OR REPLACE FUNCTION public.notify_direct_message()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
  -- Un billet transfere a deja sa notification (`ticket_received`) : une
  -- deuxieme, pour le message qui l'accompagne, ferait vibrer deux fois le
  -- telephone pour un seul geste.
  if new.shared_kind = 'ticket' then
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
$function$;
