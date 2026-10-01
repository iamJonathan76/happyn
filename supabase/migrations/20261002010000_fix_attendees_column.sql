-- Corriger `organizer_attendees` : la colonne s'appelle `purchased_at`.
--
-- Ecrite le 2026-09-16 avec `t.created_at`, qui n'existe pas : la table
-- `tickets` n'a pas ete creee par une migration de ce depot, et porte
-- `purchased_at`.
--
-- Pourquoi personne ne l'a vu pendant deux semaines : une fonction PL/pgSQL
-- n'est PAS verifiee a sa creation, seulement a son execution. La migration
-- est donc passee sans broncher, et la liste des participants n'a jamais ete
-- ouverte sur un evenement qui en avait. Le meme defaut dans une fonction
-- `language sql` aurait echoue immediatement — c'est d'ailleurs comme ca
-- qu'on l'a trouve, en ecrivant `event_tickets_to_refund`.
--
-- Seule la ligne de la date change ; le reste est identique, y compris le
-- choix de ne PAS exposer l'adresse courriel.

create or replace function public.organizer_attendees(p_event uuid)
returns table (
  ticket_id    uuid,
  full_name    text,
  avatar_url   text,
  type_name    text,
  status       text,
  purchased_at timestamptz
)
language plpgsql
security definer
stable
set search_path = public
as $$
begin
  if not exists (
    select 1 from public.events e
    where e.id = p_event and e.created_by = auth.uid()
  ) then
    raise exception 'not_organizer';
  end if;

  return query
  select
    t.id,
    coalesce(nullif(trim(p.full_name), ''), 'Invite'),
    p.avatar_url,
    tt.name,
    t.status,
    t.purchased_at
  from public.tickets t
  left join public.profiles p on p.id = t.user_id
  left join public.ticket_types tt on tt.id = t.ticket_type_id
  where t.event_id = p_event
    and t.status <> 'cancelled'
  order by (t.status = 'used'), lower(coalesce(p.full_name, '')) asc;
end;
$$;

revoke all on function public.organizer_attendees(uuid) from public, anon;
grant execute on function public.organizer_attendees(uuid) to authenticated;
