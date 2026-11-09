-- Rappel push « ton événement approche », ~24 h avant le début.
--
-- Gratuit : on insère une notification `event_reminder` par détenteur de billet,
-- et le webhook `send_push_on_notification` déjà en place la pousse. Aucun
-- courriel (le quota Resend est précieux ; un rappel est récurrent).
--
-- La langue : `event_reminder` est un type INCONNU de `translate_notification`
-- (son `else` ne touche à rien), donc on écrit directement le texte dans la
-- langue de chaque personne, lue sur son profil.
--
-- Idempotence : une seule notif par (personne, événement), garantie par le
-- `not exists`. Deux billets pour le même événement = un seul rappel. Un cron
-- qui repasse ne double rien.

create or replace function private.send_event_reminders()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.notifications (user_id, type, title, body, event_id)
  select distinct
    t.user_id,
    'event_reminder',
    case when p.language = 'fr' then 'Rappel' else 'Event reminder' end,
    case when p.language = 'fr'
         then '« ' || e.title || ' » approche. Ton billet est dans l''app.'
         else e.title || ' is coming up. Your ticket is in the app.'
    end,
    e.id
  from public.tickets t
  join public.events e   on e.id = t.event_id
  join public.profiles p on p.id = t.user_id
  where t.status = 'valid'
    and e.status = 'published'
    -- Dans les 24 h à venir : un cron horaire attrape chaque événement au
    -- premier passage où il entre dans la fenêtre (≈ 24 h avant), une fois.
    and e.start_date > now()
    and e.start_date <= now() + interval '24 hours'
    and not exists (
      select 1 from public.notifications n
      where n.user_id = t.user_id
        and n.event_id = e.id
        and n.type = 'event_reminder'
    );
end $$;

-- Tâche serveur : jamais appelable depuis l'app.
revoke all on function private.send_event_reminders() from public, anon, authenticated;
