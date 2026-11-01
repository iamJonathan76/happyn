-- Perf RLS (auth_rls_initplan) : evaluer auth.*()/current_setting() UNE
-- fois par requete, pas par ligne. On wrappe chaque appel direct dans un
-- (select ...) : Postgres le calcule une seule fois (InitPlan) au lieu de
-- le rejouer pour chaque ligne. Comportement identique, seul le plan
-- change. Genere depuis le catalogue prod ; ALTER POLICY ne modifie que
-- l'expression, jamais les roles ni la commande.

begin;

alter policy "own blocks delete" on public."blocked_users"
  using (((select auth.uid()) = blocker_id));
alter policy "own blocks insert" on public."blocked_users"
  with check (((select auth.uid()) = blocker_id));
alter policy "own blocks select" on public."blocked_users"
  using (((select auth.uid()) = blocker_id));
alter policy "own tokens delete" on public."device_tokens"
  using (((select auth.uid()) = user_id));
alter policy "own tokens select" on public."device_tokens"
  using (((select auth.uid()) = user_id));
alter policy "own tokens update" on public."device_tokens"
  using (((select auth.uid()) = user_id));
alter policy "own tokens upsert" on public."device_tokens"
  with check (((select auth.uid()) = user_id));
alter policy "conversation participants can send messages" on public."direct_messages"
  with check (((sender_id = (select auth.uid())) AND can_access_direct_conversation(conversation_id) AND direct_conversation_is_open(conversation_id) AND (shared_kind IS DISTINCT FROM 'ticket'::text)));
alter policy "organizer writes address" on public."event_addresses"
  using (((select auth.uid()) = ( SELECT e.created_by
   FROM events e
  WHERE (e.id = event_addresses.event_id))));
alter policy "own attendance select" on public."event_attendance"
  using (((select auth.uid()) = user_id));
alter policy "own payouts read" on public."event_payouts"
  using (((select auth.uid()) = organizer_id));
alter policy "own unlocks readable" on public."event_unlocks"
  using (((select auth.uid()) = user_id));
alter policy "Authenticated users can create events" on public."events"
  with check ((((select auth.uid()) = created_by) AND (NOT is_suspended()) AND i_meet_age(18)));
alter policy "Users can delete own events" on public."events"
  using (((select auth.uid()) = created_by));
alter policy "Users can update own events" on public."events"
  using (((select auth.uid()) = created_by));
alter policy "events readable" on public."events"
  using ((((COALESCE(visibility, 'public'::text) = 'public'::text) AND (COALESCE(status, 'published'::text) <> 'draft'::text)) OR (created_by = (select auth.uid())) OR user_holds_ticket_for(id)));
alter policy "own favorites delete" on public."favorites"
  using (((select auth.uid()) = user_id));
alter policy "own favorites insert" on public."favorites"
  with check (((select auth.uid()) = user_id));
alter policy "own favorites select" on public."favorites"
  using (((select auth.uid()) = user_id));
alter policy "own follows delete" on public."follows"
  using (((select auth.uid()) = follower_id));
alter policy "own follows insert" on public."follows"
  with check (((select auth.uid()) = follower_id));
alter policy "own notifs delete" on public."notifications"
  using (((select auth.uid()) = user_id));
alter policy "own notifs select" on public."notifications"
  using (((select auth.uid()) = user_id));
alter policy "own notifs update" on public."notifications"
  using (((select auth.uid()) = user_id));
alter policy "comments readable" on public."post_comments"
  using (((EXISTS ( SELECT 1
   FROM posts p
  WHERE ((p.id = post_comments.post_id) AND (event_posts_are_public(p.event_id) OR can_attach_event(p.event_id))))) AND (NOT blocked_either_way((select auth.uid()), author_id))));
alter policy "own comments insert" on public."post_comments"
  with check (((author_id = (select auth.uid())) AND (NOT is_suspended()) AND (EXISTS ( SELECT 1
   FROM posts p
  WHERE ((p.id = post_comments.post_id) AND (NOT p.comments_disabled) AND (event_posts_are_public(p.event_id) OR can_attach_event(p.event_id)) AND (NOT blocked_either_way((select auth.uid()), p.author_id)))))));
alter policy "own or post author comments delete" on public."post_comments"
  using (((author_id = (select auth.uid())) OR (EXISTS ( SELECT 1
   FROM posts p
  WHERE ((p.id = post_comments.post_id) AND (p.author_id = (select auth.uid())))))));
alter policy "own likes delete" on public."post_likes"
  using (((select auth.uid()) = user_id));
alter policy "own likes insert" on public."post_likes"
  with check (((select auth.uid()) = user_id));
alter policy "own posts delete" on public."posts"
  using (((select auth.uid()) = author_id));
alter policy "own posts insert" on public."posts"
  with check ((((select auth.uid()) = author_id) AND can_attach_event(event_id) AND (NOT is_suspended())));
alter policy "own posts update" on public."posts"
  using ((((select auth.uid()) = author_id) AND (NOT is_suspended())))
  with check ((((select auth.uid()) = author_id) AND (NOT is_suspended())));
alter policy "Users can insert own profile" on public."profiles"
  with check (((select auth.uid()) = id));
alter policy "Users can update own profile" on public."profiles"
  using (((select auth.uid()) = id));
alter policy "Users can view own profile" on public."profiles"
  using (((select auth.uid()) = id));
alter policy "own profile insert" on public."profiles"
  with check (((select auth.uid()) = id));
alter policy "own profile select" on public."profiles"
  using (((select auth.uid()) = id));
alter policy "own profile update" on public."profiles"
  using (((select auth.uid()) = id));
alter policy "own reports insert" on public."reports"
  with check (((select auth.uid()) = reporter_id));
alter policy "own reports select" on public."reports"
  using (((select auth.uid()) = reporter_id));
alter policy "own stripe account read" on public."stripe_accounts"
  using (((select auth.uid()) = user_id));
alter policy "Organizers can manage ticket types" on public."ticket_types"
  using (((select auth.uid()) = ( SELECT e.created_by
   FROM events e
  WHERE (e.id = ticket_types.event_id))));
alter policy "Users see their own tickets" on public."tickets"
  using (((select auth.uid()) = user_id));
alter policy "own acceptances select" on public."user_legal_acceptances"
  using (((select auth.uid()) = user_id));
alter policy "attendees upload event videos" on storage."objects"
  with check (((bucket_id = 'event-videos'::text) AND ((storage.foldername(name))[2] = ((select auth.uid()))::text) AND (EXISTS ( SELECT 1
   FROM events e
  WHERE (((e.id)::text = (storage.foldername(objects.name))[1]) AND can_attach_event(e.id))))));
alter policy "owners delete event videos" on storage."objects"
  using (((bucket_id = 'event-videos'::text) AND ((storage.foldername(name))[2] = ((select auth.uid()))::text)));
alter policy "users delete own avatar" on storage."objects"
  using (((bucket_id = 'avatars'::text) AND ((storage.foldername(name))[1] = ((select auth.uid()))::text)));
alter policy "users delete own event images" on storage."objects"
  using (((bucket_id = 'events'::text) AND ((storage.foldername(name))[1] = ((select auth.uid()))::text)));
alter policy "users delete own post images" on storage."objects"
  using (((bucket_id = 'posts'::text) AND ((storage.foldername(name))[1] = ((select auth.uid()))::text)));
alter policy "users update own avatar" on storage."objects"
  using (((bucket_id = 'avatars'::text) AND ((storage.foldername(name))[1] = ((select auth.uid()))::text)));
alter policy "users update own event images" on storage."objects"
  using (((bucket_id = 'events'::text) AND ((storage.foldername(name))[1] = ((select auth.uid()))::text)));
alter policy "users upload own avatar" on storage."objects"
  with check (((bucket_id = 'avatars'::text) AND ((storage.foldername(name))[1] = ((select auth.uid()))::text)));
alter policy "users upload own event images" on storage."objects"
  with check (((bucket_id = 'events'::text) AND ((storage.foldername(name))[1] = ((select auth.uid()))::text)));
alter policy "users upload own post images" on storage."objects"
  with check (((bucket_id = 'posts'::text) AND ((storage.foldername(name))[1] = ((select auth.uid()))::text)));

commit;
