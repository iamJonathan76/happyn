-- =============================================================================
-- HAPPYN — Autoriser le signalement des publications
-- =============================================================================
-- La table `reports` a été créée avant le social : sa contrainte n'acceptait
-- que 'event' et 'user'. Signaler une publication du fil aurait échoué sur une
-- violation de contrainte.
-- À exécuter dans le SQL Editor du dashboard Supabase.
-- =============================================================================

do $$
declare
  v_name text;
begin
  select conname into v_name
  from pg_constraint
  where conrelid = 'public.reports'::regclass
    and contype = 'c'
    and pg_get_constraintdef(oid) ilike '%target_type%';

  if v_name is not null then
    execute format('alter table public.reports drop constraint %I', v_name);
  end if;

  alter table public.reports
    add constraint reports_target_type_check
    check (target_type in ('event', 'user', 'post'));
end $$;
