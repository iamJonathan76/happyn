-- One-to-one text conversations between people on Happyn.
--
-- A user may start a conversation only with someone they follow. Once a
-- conversation exists, either participant may reply, even if the follow is
-- removed. Blocking either participant stops access and sending immediately.

create table if not exists public.direct_conversations (
  id         uuid primary key default gen_random_uuid(),
  member_a   uuid not null references auth.users(id) on delete cascade,
  member_b   uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint direct_conversation_members_ordered check (member_a < member_b),
  unique (member_a, member_b)
);

create table if not exists public.direct_messages (
  id              uuid primary key default gen_random_uuid(),
  conversation_id uuid not null
    references public.direct_conversations(id) on delete cascade,
  sender_id       uuid not null references auth.users(id) on delete cascade,
  body            text not null,
  created_at      timestamptz not null default now(),
  constraint direct_message_body_length check (
    char_length(trim(body)) between 1 and 2000
  )
);

create index if not exists direct_messages_conversation_created_idx
  on public.direct_messages (conversation_id, created_at, id);

alter table public.direct_conversations enable row level security;
alter table public.direct_messages enable row level security;

create or replace function public.can_access_direct_conversation(p_conversation uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.direct_conversations c
    where c.id = p_conversation
      and auth.uid() in (c.member_a, c.member_b)
      and not exists (
        select 1
        from public.blocked_users b
        where (b.blocker_id = c.member_a and b.blocked_id = c.member_b)
           or (b.blocker_id = c.member_b and b.blocked_id = c.member_a)
      )
  );
$$;

revoke all on function public.can_access_direct_conversation(uuid)
  from public, anon;
grant execute on function public.can_access_direct_conversation(uuid)
  to authenticated;

drop policy if exists "conversation participants can read" on public.direct_conversations;
create policy "conversation participants can read"
  on public.direct_conversations for select
  to authenticated
  using (public.can_access_direct_conversation(id));

drop policy if exists "conversation participants can read messages" on public.direct_messages;
create policy "conversation participants can read messages"
  on public.direct_messages for select
  to authenticated
  using (public.can_access_direct_conversation(conversation_id));

drop policy if exists "conversation participants can send messages" on public.direct_messages;
create policy "conversation participants can send messages"
  on public.direct_messages for insert
  to authenticated
  with check (
    sender_id = auth.uid()
    and public.can_access_direct_conversation(conversation_id)
  );

revoke all on public.direct_conversations from anon, authenticated;
grant select on public.direct_conversations to authenticated;
revoke all on public.direct_messages from anon, authenticated;
grant select, insert on public.direct_messages to authenticated;

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
  if not exists (
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

create or replace function public.my_direct_conversations()
returns table (
  conversation_id uuid,
  other_user_id uuid,
  other_name text,
  other_avatar text,
  other_username text,
  last_message text,
  last_message_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    c.id,
    p.id,
    p.full_name,
    p.avatar_url,
    p.username,
    latest.body,
    latest.created_at
  from public.direct_conversations c
  join public.profiles p
    on p.id = case when c.member_a = auth.uid() then c.member_b else c.member_a end
  cross join lateral (
    select m.body, m.created_at
    from public.direct_messages m
    where m.conversation_id = c.id
    order by m.created_at desc, m.id desc
    limit 1
  ) latest
  where auth.uid() in (c.member_a, c.member_b)
    and public.can_access_direct_conversation(c.id)
  order by latest.created_at desc, c.id;
$$;

revoke all on function public.my_direct_conversations() from public, anon;
grant execute on function public.my_direct_conversations() to authenticated;

alter publication supabase_realtime add table public.direct_messages;
