-- Notifier l'auteur d'un moment quand on l'aime.
--
-- Les commentaires prévenaient déjà l'auteur ; les likes, non — alors que
-- c'est le signal social le plus fréquent. Même forme que notify_post_comment :
-- pas de notif pour soi-même ni d'un compte bloqué, et une seule ligne non lue
-- par moment (dix likes ne font pas dix bulles ; la dernière remplace la
-- précédente).
create or replace function public.notify_post_like()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_author uuid;
  v_name   text;
  v_lang   text;
begin
  select p.author_id into v_author from public.posts p where p.id = new.post_id;

  if v_author is null
     or v_author = new.user_id
     or public.blocked_either_way(v_author, new.user_id) then
    return new;
  end if;

  select coalesce(nullif(trim(p.full_name), ''), p.username, 'HAPPYN')
    into v_name
  from public.profiles p where p.id = new.user_id;

  select p.language into v_lang from public.profiles p where p.id = v_author;

  delete from public.notifications
  where user_id = v_author
    and type = 'post_like'
    and post_id = new.post_id
    and read = false;

  insert into public.notifications (user_id, type, title, body, post_id)
  values (
    v_author,
    'post_like',
    coalesce(v_name, 'HAPPYN'),
    case when v_lang = 'fr' then 'A aimé ton moment' else 'Liked your moment' end,
    new.post_id
  );

  return new;
end;
$$;

revoke all on function public.notify_post_like() from public, anon, authenticated;

drop trigger if exists notify_on_post_like on public.post_likes;
create trigger notify_on_post_like
  after insert on public.post_likes
  for each row execute function public.notify_post_like();
