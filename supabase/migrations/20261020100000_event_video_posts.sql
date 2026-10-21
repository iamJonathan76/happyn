-- Allow video-only feed posts and keep the video URL in the feed projection.
alter table public.posts
  add column if not exists video_url text;

alter table public.posts
  drop constraint if exists post_not_empty;
alter table public.posts
  add constraint post_not_empty check (
    coalesce(trim(caption), '') <> ''
    or coalesce(image_url, '') <> ''
    or coalesce(video_url, '') <> ''
  );

insert into storage.buckets (id, name, public)
values ('event-videos', 'event-videos', false)
on conflict (id) do update set public = false;

drop policy if exists "event videos readable by attendees" on storage.objects;
create policy "event videos readable by attendees"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'event-videos'
    and exists (
      select 1
      from public.events e
      where e.id::text = (storage.foldername(name))[1]
        and (
          (
            coalesce(e.status, 'published') <> 'draft'
            and public.event_posts_are_public(e.id)
          )
          or public.can_attach_event(e.id)
        )
    )
  );

drop policy if exists "organizers upload event videos" on storage.objects;
create policy "organizers upload event videos"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'event-videos'
    and (storage.foldername(name))[2] = auth.uid()::text
    and exists (
      select 1
      from public.events e
      where e.id::text = (storage.foldername(name))[1]
        and e.created_by = auth.uid()
    )
  );

drop policy if exists "owners delete event videos" on storage.objects;
create policy "owners delete event videos"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'event-videos'
    and (storage.foldername(name))[2] = auth.uid()::text
  );

-- Add the new media column at the end so the existing view's column order is
-- preserved. Draft-event videos stay visible only to people allowed to attach
-- to the event, and appear publicly when the event is published.
create or replace view public.feed_posts as
select
  p.id,
  p.author_id,
  p.caption,
  p.image_url,
  p.event_id,
  p.created_at,
  pr.full_name  as author_name,
  pr.avatar_url as author_avatar,
  e.title       as event_title,
  e.start_date  as event_start_date,
  e.image_url   as event_image,
  coalesce(e.visibility, 'public') as event_visibility,
  (e.created_by = p.author_id) as author_is_organizer,
  (select count(*) from public.post_likes l where l.post_id = p.id)
    as like_count,
  exists (
    select 1 from public.post_likes l
    where l.post_id = p.id and l.user_id = auth.uid()
  ) as liked_by_me,
  p.edited_at,
  (select count(*) from public.post_comments c where c.post_id = p.id)
    as comment_count,
  p.comments_disabled,
  p.image_aspect,
  e.city as event_city,
  p.video_url
from public.posts p
join public.events e on e.id = p.event_id
left join public.profiles pr on pr.id = p.author_id
where
  (
    coalesce(e.status, 'published') <> 'draft'
    or public.can_attach_event(p.event_id)
  )
  and (
    coalesce(e.posts_visibility, 'public') = 'public'
    or public.can_attach_event(p.event_id)
  );
