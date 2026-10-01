-- Un evenement ne peut pas finir avant d'avoir commence.
--
-- Rien ne l'interdisait, ni l'app ni la base. Les consequences depassaient
-- l'affichage :
--
--   * `isEventPast()` regarde la date de FIN : l'evenement disparaissait des
--     fils des sa creation ;
--   * `create-payment-intent` refuse un evenement termine, donc aucun billet
--     ne pouvait se vendre ;
--   * et surtout `events_due_for_payout()` compte trois jours apres la FIN :
--     l'organisateur devenait payable AVANT que son evenement ait lieu. Ce
--     delai existe pour laisser le temps aux remboursements ; une fin
--     anterieure au debut le supprimait purement et simplement.
--
-- `not valid` : la contrainte s'applique aux ecritures a venir sans rejeter
-- l'existant. Une ligne deja incoherente doit etre corrigee a la main, pas
-- effacee par une migration. Pour les trouver :
--
--   select id, title, start_date, end_date
--     from public.events
--    where end_date is not null and end_date < start_date;
--
-- Une fois corrigees, on peut durcir :
--
--   alter table public.events validate constraint event_ends_after_start;

alter table public.events
  drop constraint if exists event_ends_after_start;

alter table public.events
  add constraint event_ends_after_start
  check (end_date is null or end_date >= start_date)
  not valid;

comment on constraint event_ends_after_start on public.events is
  'La date de fin sert au calcul du versement : une fin anterieure au debut '
  'rendait l''organisateur payable avant son evenement.';
