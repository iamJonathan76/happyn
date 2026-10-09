-- Supprimer ses propres notifications.
--
-- Aucune règle ne le permettait : la table n'avait que lecture et mise à jour
-- (marquer comme lu). Une liste qu'on ne peut que voir grossir finit ignorée
-- en entier — y compris la notification qui compte.
--
-- Seulement les siennes : `auth.uid() = user_id`. Une notification d'un autre
-- reste hors d'atteinte, comme en lecture.

drop policy if exists "own notifs delete" on public.notifications;
create policy "own notifs delete" on public.notifications
  as permissive for delete to authenticated
  using (auth.uid() = user_id);
