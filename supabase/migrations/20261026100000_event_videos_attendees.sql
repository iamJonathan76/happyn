-- Un moment vidéo se partage comme une photo : par toute personne qui peut
-- rattacher à l'événement — l'organisateur OU un détenteur de billet — et pas
-- seulement l'organisateur, comme le faisait la première version du bucket.
-- On aligne la policy d'upload d'event-videos sur can_attach_event, exactement
-- la règle des photos (table posts). Le dossier reste au nom de l'uploadeur.
drop policy if exists "organizers upload event videos" on storage.objects;
drop policy if exists "attendees upload event videos" on storage.objects;
create policy "attendees upload event videos"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'event-videos'
    and (storage.foldername(name))[2] = auth.uid()::text
    and exists (
      select 1
      from public.events e
      where e.id::text = (storage.foldername(name))[1]
        and public.can_attach_event(e.id)
    )
  );
