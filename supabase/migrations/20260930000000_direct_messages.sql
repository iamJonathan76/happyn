create table if not exists public.direct_conversations (
  id uuid primary key default gen_random_uuid(),
  user_a uuid not null references auth.users(id) on delete cascade,
  user_b uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  last_message_at timestamptz not null default now(),
  constraint direct_conversation_pair_order check (user_a < user_b),
  constraint direct_conversation_pair_unique unique (user_a, user_b)
);

create table if not exists public.direct_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null
    references public.direct_conversations(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  body text not null check (char_length(trim(body)) between 1 and 2000),
  created_at timestamptz not null default now()
);

create index if not exists direct_messages_conversation_created_idx
  on public.direct_messages (conversation_id, created_at desc);

alter table public.direct_conversations enable row level security;
alter table public.direct_messages enable row level security;

grant select on public.direct_conversations to authenticated;
grant select, insert on public.direct_messages to authenticated;

drop policy if exists "conversation participants can read"
  on public.direct_conversations;
create policy "conversation participants can read"
  on public.direct_conversations for select
  to authenticated
  using (auth.uid() in (user_a, user_b));

drop policy if exists "conversation participants can read messages"
  on public.direct_messages;
create policy "conversation participants can read messages"
  on public.direct_messages for select
  to authenticated
  using (
    exists (
      select 1 from public.direct_conversations c
      where c.id = conversation_id
        and auth.uid() in (c.user_a, c.user_b)
    )
  );

create or replace function public.direct_message_is_allowed(
  p_conversation_id uuid,
  p_sender_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.direct_conversations c
    where c.id = p_conversation_id
      and p_sender_id = auth.uid()
      and p_sender_id in (c.user_a, c.user_b)
      and not exists (
        select 1 from public.blocked_users b
        where (b.blocker_id = c.user_a and b.blocked_id = c.user_b)
           or (b.blocker_id = c.user_b and b.blocked_id = c.user_a)
      )
  );
$$;

revoke all on function public.direct_message_is_allowed(uuid, uuid) from public;
grant execute on function public.direct_message_is_allowed(uuid, uuid)
  to authenticated;

drop policy if exists "participants can send messages"
  on public.direct_messages;
create policy "participants can send messages"
  on public.direct_messages for insert
  to authenticated
  with check (public.direct_message_is_allowed(conversation_id, sender_id));

create or replace function public.start_direct_conversation(p_user_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_user_a uuid;
  v_user_b uuid;
  v_conversation_id uuid;
begin
  if v_user_id is null or p_user_id is null or v_user_id = p_user_id then
    raise exception 'Invalid conversation participant';
  end if;

  if not exists (
    select 1 from public.follows
    where follower_id = v_user_id and following_id = p_user_id
  ) then
    raise exception 'You must follow this person to start a conversation';
  end if;

  if exists (
    select 1 from public.blocked_users
    where (blocker_id = v_user_id and blocked_id = p_user_id)
       or (blocker_id = p_user_id and blocked_id = v_user_id)
  ) then
    raise exception 'Conversation unavailable';
  end if;

  v_user_a := least(v_user_id, p_user_id);
  v_user_b := greatest(v_user_id, p_user_id);

  insert into public.direct_conversations (user_a, user_b)
  values (v_user_a, v_user_b)
  on conflict (user_a, user_b) do nothing;

  select id into v_conversation_id
  from public.direct_conversations
  where user_a = v_user_a and user_b = v_user_b;

  return v_conversation_id;
end;
$$;

revoke all on function public.start_direct_conversation(uuid) from public;
grant execute on function public.start_direct_conversation(uuid)
  to authenticated;

create or replace function public.update_direct_conversation_timestamp()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  update public.direct_conversations
  set last_message_at = new.created_at
  where id = new.conversation_id;
  return new;
end;
$$;

drop trigger if exists direct_messages_update_conversation_timestamp
  on public.direct_messages;
create trigger direct_messages_update_conversation_timestamp
  after insert on public.direct_messages
  for each row execute function public.update_direct_conversation_timestamp();

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'direct_messages'
    ) then
      alter publication supabase_realtime add table public.direct_messages;
    end if;
  end if;
end;
$$;