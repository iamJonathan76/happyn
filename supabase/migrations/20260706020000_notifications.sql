-- =============================================================================
-- HAPPYN — Notifications in-app (V1 : annulation + changement de détails)
-- =============================================================================
-- Table `notifications` (chacun voit les siennes). Génération AUTOMATIQUE via
-- trigger sur events : quand un event passe à `cancelled` OU que sa date/lieu
-- change, une notif est créée pour chaque participant ayant un billet.
-- Les clients ne peuvent pas insérer (seul le trigger SECURITY DEFINER le fait).
-- À exécuter dans le SQL Editor.
-- =============================================================================

create table if not exists public.notifications (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  type       text not null,
  title      text not null,
  body       text,
  event_id   uuid references public.events(id) on delete set null,
  read       boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists notifications_user_idx
  on public.notifications (user_id, created_at desc);

alter table public.notifications enable row level security;

drop policy if exists "own notifs select" on public.notifications;
create policy "own notifs select"
  on public.notifications for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "own notifs update" on public.notifications;
create policy "own notifs update"
  on public.notifications for update
  to authenticated
  using (auth.uid() = user_id);

-- (Pas de policy INSERT : seul le trigger, en SECURITY DEFINER, crée les notifs.)

-- ── Trigger : génère les notifs pour les participants ───────────────────────
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

  insert into public.notifications (user_id, type, title, body, event_id)
  select distinct t.user_id, v_type, v_title, v_body, new.id
  from public.tickets t
  where t.event_id = new.id;

  return new;
end;
$$;

drop trigger if exists trg_notify_event_change on public.events;
create trigger trg_notify_event_change
  after update on public.events
  for each row
  execute function public.notify_event_change();
