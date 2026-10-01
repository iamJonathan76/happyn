-- Signaler un message prive, et pouvoir le retirer.
--
-- La messagerie a ouvert une nouvelle surface de contenu entre utilisateurs,
-- sans aucun moyen de la signaler. C'est precisement ce que regarde la regle
-- 1.2 d'Apple — celle pour laquelle toute la file de moderation a ete
-- construite — et c'est aussi le minimum decent : quelqu'un qui recoit des
-- insultes en prive doit pouvoir faire autre chose que bloquer en silence.
--
-- Le blocage existe et reste la premiere reponse : immediat, sans attendre
-- personne. Le signalement s'y ajoute pour les cas ou l'auteur doit etre
-- arrete, pas seulement eloigne d'une personne.

alter table public.reports
  drop constraint if exists reports_target_type_check;

alter table public.reports
  add constraint reports_target_type_check
  check (target_type in ('event', 'user', 'post', 'message'));

-- ── L'etiquette figee au moment du signalement ──────────────────────────────
-- Un message peut etre supprime ensuite ; l'etiquette garde la trace de ce qui
-- a ete signale.

create or replace function public.reports_fill_label()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  new.target_label := case new.target_type
    when 'event' then (select e.title from public.events e where e.id = new.target_id)
    when 'post'  then (select coalesce(nullif(trim(p.caption), ''), '(image)')
                         from public.posts p where p.id = new.target_id)
    when 'user'  then (select pr.full_name from public.profiles pr where pr.id = new.target_id)
    when 'message' then (select left(m.body, 120)
                           from public.direct_messages m where m.id = new.target_id)
  end;
  return new;
end;
$$;

-- ── De quoi juger ───────────────────────────────────────────────────────────
--
-- Un message isole est souvent illisible : « ferme-la » apres une menace et
-- « ferme-la » sans raison ne se jugent pas pareil. On joint donc les trois
-- messages qui precedent.
--
-- C'est une intrusion dans une conversation privee, et elle est volontairement
-- BORNEE : trois messages, dans la seule conversation concernee, et seulement
-- pour un moderateur saisi d'un signalement. Pas de lecture libre des
-- conversations. A decrire dans la politique de confidentialite.

create or replace function public.admin_report_target(p_report uuid)
returns jsonb
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  r      public.reports;
  result jsonb;
begin
  if not public.i_am_admin() then
    raise exception 'not_admin';
  end if;

  select * into r from public.reports where id = p_report;
  if not found then
    return null;
  end if;

  if r.target_type = 'event' then
    select jsonb_build_object(
      'type',        'event',
      'title',       e.title,
      'description', e.description,
      'image_url',   e.image_url,
      'start_date',  e.start_date,
      'end_date',    e.end_date,
      'city',        e.city,
      'location',    e.location,
      'category',    e.category,
      'price',       e.price,
      'status',      e.status,
      'visibility',  coalesce(e.visibility, 'public'),
      'author_id',   e.created_by,
      'author_name', (select pr.full_name from public.profiles pr where pr.id = e.created_by),
      'tickets_sold', (
        select count(*) from public.tickets t
        where t.event_id = e.id
          and coalesce(t.status, '') <> 'cancelled'
      )
    )
    into result
    from public.events e
    where e.id = r.target_id;

  elsif r.target_type = 'post' then
    select jsonb_build_object(
      'type',        'post',
      'caption',     p.caption,
      'image_url',   p.image_url,
      'created_at',  p.created_at,
      'edited_at',   p.edited_at,
      'author_id',   p.author_id,
      'author_name', (select pr.full_name from public.profiles pr where pr.id = p.author_id),
      'event_title', (select e.title from public.events e where e.id = p.event_id),
      'like_count',  (select count(*) from public.post_likes l where l.post_id = p.id)
    )
    into result
    from public.posts p
    where p.id = r.target_id;

  elsif r.target_type = 'user' then
    select jsonb_build_object(
      'type',         'user',
      'full_name',    pr.full_name,
      'username',     pr.username,
      'avatar_url',   pr.avatar_url,
      'is_suspended', pr.is_suspended,
      'author_id',    pr.id,
      'post_count',   (select count(*) from public.posts p where p.author_id = pr.id),
      'event_count',  (select count(*) from public.events e where e.created_by = pr.id)
    )
    into result
    from public.profiles pr
    where pr.id = r.target_id;

  elsif r.target_type = 'message' then
    select jsonb_build_object(
      'type',        'message',
      'body',        m.body,
      'created_at',  m.created_at,
      'author_id',   m.sender_id,
      'author_name', (select pr.full_name from public.profiles pr
                       where pr.id = m.sender_id),
      'context', (
        select coalesce(jsonb_agg(x order by x_created), '[]'::jsonb)
        from (
          select jsonb_build_object(
                   'body', prev.body,
                   'mine', prev.sender_id = m.sender_id,
                   'created_at', prev.created_at
                 ) as x,
                 prev.created_at as x_created
          from public.direct_messages prev
          where prev.conversation_id = m.conversation_id
            and prev.created_at < m.created_at
          order by prev.created_at desc
          limit 3
        ) q
      )
    )
    into result
    from public.direct_messages m
    where m.id = r.target_id;
  end if;

  return result;
end;
$$;

revoke all on function public.admin_report_target(uuid) from public, anon;
grant execute on function public.admin_report_target(uuid) to authenticated;

-- ── Retirer un message ──────────────────────────────────────────────────────
-- Supprime, comme une publication. L'etiquette du signalement garde la trace
-- de ce qui a ete retire : le moderateur ne detruit pas sa propre preuve.

create or replace function public.admin_remove_content(
  p_type   text,
  p_id     uuid,
  p_report uuid default null,
  p_note   text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.i_am_admin() then
    raise exception 'not_admin';
  end if;

  if p_type = 'post' then
    delete from public.posts where id = p_id;
  elsif p_type = 'event' then
    update public.events set status = 'draft' where id = p_id;
  elsif p_type = 'message' then
    delete from public.direct_messages where id = p_id;
  else
    raise exception 'invalid_type';
  end if;

  insert into public.admin_actions (admin_id, action, target_type, target_id,
                                    report_id, note)
  values (auth.uid(), 'remove_content', p_type, p_id, p_report, p_note);
end;
$$;

revoke all on function public.admin_remove_content(text, uuid, uuid, text)
  from public, anon;
grant execute on function public.admin_remove_content(text, uuid, uuid, text)
  to authenticated;

-- ── Un compte suspendu n'ecrit plus ─────────────────────────────────────────
-- `is_suspended()` bloque deja la publication d'un post et la creation d'un
-- evenement. La messagerie l'ignorait : suspendre quelqu'un le faisait taire
-- en public et le laissait continuer en prive, ce qui est exactement
-- l'inverse de ce qu'on veut quand on suspend pour harcelement.
--
-- En LECTURE rien ne change : il voit toujours ses conversations. Une
-- suspension n'est pas une confiscation.

drop policy if exists "conversation participants can send messages"
  on public.direct_messages;

create policy "conversation participants can send messages"
  on public.direct_messages for insert
  to authenticated
  with check (
    sender_id = auth.uid()
    and public.can_access_direct_conversation(conversation_id)
    and not public.is_suspended()
  );
