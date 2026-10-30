-- Outils de modération : depuis une fiche de signalement, l'administrateur doit
-- pouvoir (1) ouvrir la vraie page de l'événement signalé pour l'analyser, même
-- s'il est privé, brouillon ou annulé, et (2) écrire à l'auteur (organisateur
-- ou membre), sans avoir à le suivre d'abord.

-- (1) L'événement complet pour un administrateur, quel que soit son état. La
-- RLS normale cacherait un événement privé ou brouillon dont l'admin n'est ni
-- l'auteur ni un détenteur de billet ; ici on contourne pour la modération, et
-- seulement pour un admin. Renvoie null (pas une erreur) à un non-admin.
create or replace function public.admin_event(p_event uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select case
    when public.i_am_admin()
      then (select to_jsonb(e) from public.events e where e.id = p_event)
    else null
  end;
$$;
revoke all on function public.admin_event(uuid) from public, anon;
grant execute on function public.admin_event(uuid) to authenticated;

-- (2) Écrire à quelqu'un sans le suivre, SI on est administrateur. La règle
-- « il faut suivre pour écrire » reste pour tout le monde ; l'admin en est
-- dispensé, parce que contacter l'auteur d'un signalement est une action de
-- modération légitime. Le blocage, lui, continue de s'appliquer (on ne force
-- pas une conversation que la personne a explicitement refusée).
create or replace function public.start_direct_conversation(p_recipient uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_a uuid;
  v_b uuid;
  v_id uuid;
begin
  if v_user is null then
    raise exception 'not_authenticated';
  end if;
  if p_recipient is null or p_recipient = v_user then
    raise exception 'invalid_recipient';
  end if;
  if not public.i_am_admin() and not exists (
    select 1 from public.follows
    where follower_id = v_user and following_id = p_recipient
  ) then
    raise exception 'must_follow_recipient';
  end if;
  if exists (
    select 1 from public.blocked_users
    where (blocker_id = v_user and blocked_id = p_recipient)
       or (blocker_id = p_recipient and blocked_id = v_user)
  ) then
    raise exception 'messaging_blocked';
  end if;

  v_a := least(v_user, p_recipient);
  v_b := greatest(v_user, p_recipient);

  insert into public.direct_conversations (member_a, member_b)
  values (v_a, v_b)
  on conflict (member_a, member_b) do nothing;

  select id into v_id
  from public.direct_conversations
  where member_a = v_a and member_b = v_b;

  return v_id;
end;
$$;
revoke all on function public.start_direct_conversation(uuid) from public, anon;
grant execute on function public.start_direct_conversation(uuid) to authenticated;
