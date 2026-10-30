-- Les regles d'acces de HAPPYN, verifiees contre le schema de production.
--
-- Chaque test dit une regle en une phrase. Il passe si la base l'applique —
-- pas l'app : la cle de l'app est publique, et tout ce qui suit est appele
-- comme le ferait quelqu'un qui ecrit lui-meme ses requetes.
--
-- Personnages :
--   Alice  (…0a) organisatrice, adulte
--   Bruno  (…0b) participant, adulte, suit Alice ; Alice le suit aussi
--   Chloe  (…0c) 19 ans : majeure, mais sous les 21 ans d'une soiree 21+
--   Eve    (…0e) bloquee par Alice
--   Sam    (…05) compte suspendu
--   Modo   (…ad) moderateur

\set ON_ERROR_STOP 1

-- ═══ Donnees de depart (en superutilisateur : la RLS ne s'applique pas) ═══

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-00000000000a', 'alice@test.local', '{"full_name":"Alice"}'),
  ('00000000-0000-0000-0000-00000000000b', 'bruno@test.local', '{"full_name":"Bruno"}'),
  ('00000000-0000-0000-0000-00000000000c', 'chloe@test.local', '{"full_name":"Chloe"}'),
  ('00000000-0000-0000-0000-00000000000e', 'eve@test.local',   '{"full_name":"Eve"}'),
  ('00000000-0000-0000-0000-000000000005', 'sam@test.local',   '{"full_name":"Sam"}'),
  ('00000000-0000-0000-0000-0000000000ad', 'modo@test.local',  '{"full_name":"Modo"}');

update profiles set date_of_birth = date '1990-01-01';
update profiles set date_of_birth = (current_date - interval '19 years')::date
 where id = '00000000-0000-0000-0000-00000000000c';
update profiles set suspended_at = now()
 where id = '00000000-0000-0000-0000-000000000005';
update profiles set is_admin = true
 where id = '00000000-0000-0000-0000-0000000000ad';

insert into follows (follower_id, following_id) values
  ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-00000000000a'),
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000b');
insert into blocked_users (blocker_id, blocked_id) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000e');

insert into events (id, title, created_by, status, visibility, start_date, end_date, posts_visibility, access_code, min_age) values
  ('00000000-0000-0000-0000-0000000000e1', 'Public',    '00000000-0000-0000-0000-00000000000a', 'published', 'public',  now() + interval '10 days', now() + interval '11 days', 'public',   null, 0),
  ('00000000-0000-0000-0000-0000000000e2', 'Prive',     '00000000-0000-0000-0000-00000000000a', 'published', 'private', now() + interval '10 days', now() + interval '11 days', 'invitees', 'CODE-SECRET-42', 0),
  ('00000000-0000-0000-0000-0000000000e3', 'Brouillon', '00000000-0000-0000-0000-00000000000a', 'draft',     'public',  now() + interval '10 days', now() + interval '11 days', 'public',   null, 0),
  ('00000000-0000-0000-0000-0000000000e4', 'Soiree 21+','00000000-0000-0000-0000-00000000000a', 'published', 'public',  now() + interval '10 days', now() + interval '11 days', 'public',   null, 21);

insert into event_addresses (event_id, address_line) values
  ('00000000-0000-0000-0000-0000000000e2', '12 rue Secrete');

insert into ticket_types (id, event_id, name, price, quantity_total, quantity_sold, max_per_order) values
  ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000e1', 'Gratuit', 0,  100, 0, 10),
  ('00000000-0000-0000-0000-0000000000f2', '00000000-0000-0000-0000-0000000000e1', 'VIP',     25, 100, 1, 10),
  ('00000000-0000-0000-0000-0000000000f3', '00000000-0000-0000-0000-0000000000e2', 'Invite',  0,  100, 0, 10),
  ('00000000-0000-0000-0000-0000000000f5', '00000000-0000-0000-0000-0000000000e4', 'Entree',  0,  100, 0, 10);

-- Bruno a paye un billet VIP.
insert into tickets (id, ticket_type_id, event_id, user_id, qr_token, status, payment_intent_id) values
  ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000f2', '00000000-0000-0000-0000-0000000000e1',
   '00000000-0000-0000-0000-00000000000b', 'HPN-bruno', 'valid', 'pi_bruno');
insert into payments (payment_intent_id, event_id, ticket_type_id, organizer_id, buyer_id, quantity, gross_cents, platform_fee_bps) values
  ('pi_bruno', '00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000f2',
   '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000b', 1, 2500, 500);
insert into stripe_accounts (user_id, account_id) values ('00000000-0000-0000-0000-00000000000a', 'acct_alice');
insert into device_tokens (token, user_id, platform) values
  ('jeton-alice', '00000000-0000-0000-0000-00000000000a', 'android'),
  ('jeton-bruno', '00000000-0000-0000-0000-00000000000b', 'ios');
insert into favorites (user_id, event_id) values
  ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000000e1');
insert into private.settings (key, value) values ('push_hook_secret', 'secret-de-test');

insert into posts (id, author_id, event_id, caption) values
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000e1', 'photo publique'),
  ('00000000-0000-0000-0000-0000000000a2', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000e2', 'photo entre invites'),
  ('00000000-0000-0000-0000-0000000000a3', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000e3', 'photo sur un brouillon');
insert into post_comments (post_id, author_id, body) values
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-00000000000e', 'commentaire d''Eve');

-- Deux vidéos dans le bucket event-videos. Chemin réel : <event>/<auteur>/fichier.
-- v-pub est sur l'événement public e1 ; v-brouillon sur le brouillon e3.
-- Le bucket est semé ici : le snapshot de prod n'emporte que la structure, pas
-- les lignes de storage.buckets, et sans lui la fixture casse pour toute
-- migration autre que celle qui crée justement le bucket.
insert into storage.buckets (id, name, public) values ('event-videos', 'event-videos', true)
on conflict (id) do nothing;
insert into storage.objects (bucket_id, name, owner) values
  ('event-videos', '00000000-0000-0000-0000-0000000000e1/00000000-0000-0000-0000-00000000000a/clip-public.mp4',    '00000000-0000-0000-0000-00000000000a'),
  ('event-videos', '00000000-0000-0000-0000-0000000000e3/00000000-0000-0000-0000-00000000000a/clip-brouillon.mp4', '00000000-0000-0000-0000-00000000000a');

insert into direct_conversations (id, member_a, member_b) values
  ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000b'),
  -- Ouverte entre Alice et Eve AVANT qu'Alice ne bloque Eve : le cas d'une
  -- personne harcelee, qui bloque au milieu d'un echange deja commence.
  ('00000000-0000-0000-0000-0000000000c2', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000e');
insert into direct_messages (conversation_id, sender_id, body) values
  ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-00000000000a', 'message prive'),
  ('00000000-0000-0000-0000-0000000000c2', '00000000-0000-0000-0000-00000000000e', 'message d''avant le blocage');

insert into reports (reporter_id, target_type, target_id, reason) values
  ('00000000-0000-0000-0000-00000000000b', 'user', '00000000-0000-0000-0000-00000000000e', 'harassment');

-- ═══ Visiteur sans compte ═══════════════════════════════════════════════════

select t.as_anon();
select t.sees_nothing('select email from profiles', 'Visiteur : ne lit aucun courriel de membre');
select t.sees_nothing('select * from public_profiles', 'Visiteur : ne lit pas l''annuaire des membres');
select t.sees_nothing('select * from feed_posts', 'Visiteur : ne lit pas le fil');
select t.sees_nothing('select * from posts', 'Visiteur : ne lit aucune publication');
select t.sees_nothing('select * from post_likes', 'Visiteur : ne lit aucun « j''aime »');
select t.sees_nothing('select * from post_comments', 'Visiteur : ne lit aucun commentaire');
select t.sees_nothing('select * from tickets', 'Visiteur : ne lit aucun billet');
select t.sees_nothing('select * from payments', 'Visiteur : ne lit aucun paiement');
select t.sees_nothing('select * from direct_messages', 'Visiteur : ne lit aucun message prive');
select t.sees_nothing('select * from event_addresses', 'Visiteur : ne lit aucune adresse exacte');
select t.sees_nothing('select * from notifications', 'Visiteur : ne lit aucune notification');
select t.sees_nothing($$select * from events where visibility = 'private'$$, 'Visiteur : ne voit pas les evenements prives');
select t.sees_nothing('select access_code from events where access_code is not null', 'Visiteur : ne lit aucun code d''invitation');
select t.sees_nothing($$select * from events where status = 'draft'$$, 'Visiteur : ne voit pas les brouillons');
select t.fails_with($$select public.unlock_private_event('CODE-SECRET-42')$$, 'permission', 'Visiteur : ne peut pas essayer de code d''invitation');
select t.fails_with($$select public.issue_tickets('00000000-0000-0000-0000-0000000000f1', 1)$$, 'permission', 'Visiteur : ne peut pas prendre de billet');
reset role;

-- ═══ Bruno, compte ordinaire ════════════════════════════════════════════════

select t.as_user('00000000-0000-0000-0000-00000000000b');

-- Ce qui appartient aux autres
select t.sees_nothing($$select email from profiles where id <> auth.uid()$$, 'Compte : ne lit pas le courriel des autres');
select t.sees_nothing($$select * from tickets where user_id <> auth.uid()$$, 'Compte : ne lit pas les billets des autres');
select t.sees_nothing($$select * from notifications where user_id <> auth.uid()$$, 'Compte : ne lit pas les notifications des autres');
select t.sees_nothing($$select * from device_tokens where user_id <> auth.uid()$$, 'Compte : ne lit pas les jetons push des autres');
select t.sees_nothing('select * from payments', 'Compte : ne lit pas le registre des paiements');
select t.sees_nothing('select * from stripe_accounts', 'Compte : ne lit pas les comptes de versement');
select t.sees_nothing('select * from event_payouts', 'Compte : ne lit pas les versements');
select t.sees_nothing('select * from private.settings', 'Compte : ne lit pas les secrets serveur');
select t.sees_nothing($$select * from reports where reporter_id <> auth.uid()$$, 'Compte : ne lit pas les signalements des autres');
select t.sees_nothing('select * from admin_actions', 'Compte : ne lit pas le journal de moderation');
select t.cannot_write($$update profiles set full_name = 'pirate' where id = '00000000-0000-0000-0000-00000000000a'$$, 'Compte : ne modifie pas le profil d''un autre');
select t.cannot_write($$update events set title = 'pirate' where id = '00000000-0000-0000-0000-0000000000e1'$$, 'Compte : ne modifie pas l''evenement d''un autre');
select t.cannot_write($$delete from events where id = '00000000-0000-0000-0000-0000000000e1'$$, 'Compte : ne supprime pas l''evenement d''un autre');
select t.cannot_write($$update ticket_types set price = 0 where id = '00000000-0000-0000-0000-0000000000f2'$$, 'Compte : ne change pas le prix d''un palier d''un autre');
select t.cannot_write($$delete from device_tokens where user_id <> auth.uid()$$, 'Compte : ne supprime pas les jetons push des autres');

-- Les billets
select t.cannot_write($$insert into tickets (ticket_type_id, event_id, user_id, qr_token, status) values ('00000000-0000-0000-0000-0000000000f2', '00000000-0000-0000-0000-0000000000e1', auth.uid(), 'HPN-faux', 'valid')$$, 'Billets : ne se fabriquent pas a la main');
select t.cannot_write($$update tickets set status = 'valid', user_id = auth.uid() where id = '00000000-0000-0000-0000-0000000000b1'$$, 'Billets : ne se modifient pas a la main');
select t.fails_with($$select public.issue_tickets('00000000-0000-0000-0000-0000000000f2', 2)$$, 'payment_required', 'Billets : un palier payant ne s''obtient pas sans payer');
select t.can_write($$select public.issue_tickets('00000000-0000-0000-0000-0000000000f1', 1)$$, 'Billets : un palier gratuit s''obtient');
select t.fails_with($$select public.issue_tickets('00000000-0000-0000-0000-0000000000f3', 1)$$, 'event_not_available', 'Billets : un evenement prive exige son code');

-- Les evenements prives
select t.sees_nothing($$select * from events where id = '00000000-0000-0000-0000-0000000000e2'$$, 'Prive : invisible sans le code');
select t.sees_nothing($$select * from ticket_types where event_id = '00000000-0000-0000-0000-0000000000e2'$$, 'Prive : ses paliers sont invisibles sans le code');
select t.sees_nothing($$select * from event_addresses where event_id = '00000000-0000-0000-0000-0000000000e2'$$, 'Prive : son adresse est invisible sans billet');
-- Un mauvais code ne leve pas d'erreur : il ne rend rien, ce qui ne dit rien.
select t.sees_nothing($$select * from public.unlock_private_event('MAUVAIS-CODE')$$, 'Prive : un mauvais code ne revele rien');
select t.sees($$select * from public.unlock_private_event('CODE-SECRET-42')$$, 1, 'Prive : le bon code ouvre l''evenement');
select t.sees_nothing($$select * from events where status = 'draft' and created_by <> auth.uid()$$, 'Brouillons : invisibles pour les autres');

-- L'annulation
reset role;
select t.as_user('00000000-0000-0000-0000-00000000000a');
select t.fails_with($$update events set status = 'cancelled' where id = '00000000-0000-0000-0000-0000000000e1'$$, 'use_cancel_event', 'Annulation : pas en ecrivant directement (cela contournerait les remboursements)');
select t.fails_with($$select public.cancel_event('00000000-0000-0000-0000-0000000000e1', auth.uid())$$, 'permission', 'Annulation : la fonction serveur n''est pas appelable depuis l''app');
select t.can_write($$update events set status = 'draft' where id = '00000000-0000-0000-0000-0000000000e1'$$, 'Organisateur : peut depublier son evenement');
select t.sees($$select * from events where id = '00000000-0000-0000-0000-0000000000e3'$$, 1, 'Organisateur : voit ses propres brouillons');
select t.cannot_write($$update events set platform_fee_bps = 0 where id = '00000000-0000-0000-0000-0000000000e1' and platform_fee_bps = 0$$, 'Organisateur : ne change pas la commission de son evenement');

-- Les fonctions reservees au serveur
reset role;
select t.as_user('00000000-0000-0000-0000-00000000000b');
select t.fails_with($$select * from public.events_due_for_payout()$$, 'permission', 'Serveur seulement : liste des versements dus');
select t.fails_with($$select * from public.event_tickets_to_refund('00000000-0000-0000-0000-0000000000e1')$$, 'permission', 'Serveur seulement : billets a rembourser');
select t.fails_with($$select * from public.issue_tickets_paid('00000000-0000-0000-0000-0000000000f2', 1, auth.uid(), 'pi_faux')$$, 'permission', 'Serveur seulement : emission de billets payes');
select t.fails_with($$select public.record_refund('pi_bruno', 2500)$$, 'permission', 'Serveur seulement : enregistrer un remboursement');
select t.fails_with($$select * from public.event_ledger()$$, 'permission', 'Serveur seulement : registre des gains');

-- Le profil et ses droits
select t.fails_with($$update profiles set is_admin = true where id = auth.uid()$$, 'is_admin', 'Profil : on ne se nomme pas moderateur');
select t.fails_with($$select * from public.admin_reports('pending')$$, 'not_admin', 'Moderation : file reservee aux moderateurs');
select t.fails_with($$select public.admin_set_suspended('00000000-0000-0000-0000-00000000000e', true, null, null)$$, 'not_admin', 'Moderation : on ne suspend personne sans etre moderateur');
reset role;
select t.as_user('00000000-0000-0000-0000-000000000005');
select t.cannot_write($$update profiles set suspended_at = null where id = auth.uid()$$, 'Suspension : un compte suspendu ne se retablit pas lui-meme');
select t.cannot_write($$insert into posts (author_id, event_id, caption) values (auth.uid(), '00000000-0000-0000-0000-0000000000e1', 'je reviens')$$, 'Suspension : un compte suspendu ne publie pas');
reset role;
select t.as_user('00000000-0000-0000-0000-0000000000ad');
select t.can_write($$select public.admin_set_suspended('00000000-0000-0000-0000-000000000005', false, null, 'test')$$, 'Suspension : un moderateur peut retablir un compte');

-- La messagerie
reset role;
select t.as_user('00000000-0000-0000-0000-00000000000e');
select t.sees_nothing('select * from direct_messages', 'Messages : on ne lit pas les conversations des autres');
select t.cannot_write($$insert into direct_messages (conversation_id, sender_id, body) values ('00000000-0000-0000-0000-0000000000c1', auth.uid(), 'intrusion')$$, 'Messages : on n''ecrit pas dans la conversation des autres');
select t.fails_with($$select public.start_direct_conversation('00000000-0000-0000-0000-00000000000a')$$, 'must_follow', 'Messages : on n''ecrit qu''a quelqu''un qu''on suit');
select t.cannot_write($$insert into direct_messages (conversation_id, sender_id, body) values ('00000000-0000-0000-0000-0000000000c2', auth.uid(), 'encore moi')$$, 'Blocage : la personne bloquee n''ecrit plus dans une conversation deja ouverte');
select t.sees_nothing($$select * from direct_messages where conversation_id = '00000000-0000-0000-0000-0000000000c2'$$, 'Blocage : la personne bloquee ne relit plus la conversation');
reset role;
select t.as_user('00000000-0000-0000-0000-00000000000a');
select t.cannot_write($$insert into direct_messages (conversation_id, sender_id, body) values ('00000000-0000-0000-0000-0000000000c2', auth.uid(), 'reponse')$$, 'Blocage : celle qui bloque n''ecrit plus non plus dans la conversation');
select t.sees_nothing($$select * from direct_messages where conversation_id = '00000000-0000-0000-0000-0000000000c2'$$, 'Blocage : les messages de la personne bloquee disparaissent pour celle qui bloque');
reset role;
select t.as_user('00000000-0000-0000-0000-00000000000e');
reset role;
select t.as_user('00000000-0000-0000-0000-00000000000b');
select t.cannot_write($$insert into direct_messages (conversation_id, sender_id, body) values ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-00000000000a', 'usurpe')$$, 'Messages : on n''ecrit pas au nom d''un autre');
select t.sees('select * from direct_messages', 1, 'Messages : on lit sa propre conversation');
select t.sees($$select * from posts where id = '00000000-0000-0000-0000-0000000000a1'$$, 1, 'Publications : un compte lit celles des evenements publics');

-- Les commentaires et le blocage
reset role;
select t.as_user('00000000-0000-0000-0000-00000000000a');
select t.sees_nothing($$select * from post_comments where author_id = '00000000-0000-0000-0000-00000000000e'$$, 'Blocage : Alice ne voit plus les commentaires d''Eve');
reset role;
select t.as_user('00000000-0000-0000-0000-00000000000e');
select t.cannot_write($$insert into post_comments (post_id, author_id, body) values ('00000000-0000-0000-0000-0000000000a1', auth.uid(), 'encore moi')$$, 'Blocage : Eve ne commente plus chez Alice');
select t.sees_nothing($$select * from post_comments where post_id = '00000000-0000-0000-0000-0000000000a2'$$, 'Publications entre invites : invisibles sans billet');

-- Le transfert de billet
reset role;
select t.as_user('00000000-0000-0000-0000-00000000000b');
select t.fails_with($$select public.transfer_ticket_to_user('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-00000000000c')$$, 'not_following', 'Transfert : seulement a quelqu''un qu''on suit');
reset role;

-- Les frais d'annulation (acheteur qui annule : remboursé moins les frais de
-- Stripe, annoncés avant l'achat)
reset role;
select t.record(
  public.cancellation_fee_cents(2000) = 88
  and public.cancellation_fee_cents(1000) = 59
  and public.cancellation_fee_cents(0) = 0
  and public.cancellation_fee_cents(20) = 20,
  'Frais d''annulation : 2,9 % + 0,30 $, plafonnes au prix du billet');
select t.as_anon();
select t.fails_with('select public.cancellation_fee_cents(2000)', 'permission denied', 'Frais d''annulation : un visiteur ne les calcule pas');
reset role;
select t.as_user('00000000-0000-0000-0000-00000000000b');
select t.record(
  (select fee from public.can_cancel_ticket('00000000-0000-0000-0000-0000000000b1')) = 1.03,
  'Frais d''annulation : annonces a l''acheteur sur son billet (25 $ -> 1,03 $)');
select t.fails_with($$select public.cancel_ticket('00000000-0000-0000-0000-0000000000b1', auth.uid(), null, 0)$$, 'permission denied', 'Annulation : seul le serveur annule, apres avoir rembourse');
reset role;
-- Un billet de 20 $ annule par l'acheteur : 19,12 $ rendus, 0,88 $ retenus,
-- autant que les frais de Stripe. L'organisateur n'y perd rien et ne paie pas
-- de commission sur une vente qui n'a pas eu lieu.
insert into payments (payment_intent_id, event_id, ticket_type_id, organizer_id, buyer_id, quantity,
                      gross_cents, stripe_fee_cents, platform_fee_bps, refunded_cents, retained_fee_cents) values
  ('pi_annule', '00000000-0000-0000-0000-0000000000e4', '00000000-0000-0000-0000-0000000000f5',
   '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000c', 1, 2000, 88, 500, 1912, 88);
select t.record(
  (select platform_fee = 0 and gross - withheld - stripe_fee - platform_fee = 0
     from public.event_ledger() where event_id = '00000000-0000-0000-0000-0000000000e4'),
  'Versement : un billet annule par l''acheteur ne coute rien a l''organisateur');

-- Le consentement aux conditions : enregistre par le serveur, pour la version
-- montree, et re-demande quand elle change
reset role;
insert into legal_documents (slug, title, content, version, effective_date, requires_acceptance, sort_order, updated_at) values
  ('terms',     'Terms',     '...', 'Version 1.1', current_date, true,  1, now()),
  ('privacy',   'Privacy',   '...', 'Version 1.2', current_date, true,  2, now()),
  ('community', 'Community', '...', 'Version 1.1', current_date, true,  3, now()),
  ('cookie',    'Cookies',   '...', 'Version 1.1', current_date, false, 4, now())
-- Les vrais textes peuvent deja etre la (schema regenere depuis la production,
-- ou migration en attente) : on impose les versions dont les tests dependent.
on conflict (slug) do update set version = excluded.version,
  requires_acceptance = excluded.requires_acceptance;
select t.as_anon();
select t.fails_with('select * from public.pending_legal_documents()', 'permission denied', 'Consentement : un visiteur n''a rien a accepter');
reset role;
select t.as_user('00000000-0000-0000-0000-00000000000c');
select t.sees('select * from public.pending_legal_documents()', 3, 'Consentement : un nouveau compte a trois documents a accepter');
select t.cannot_write($$insert into user_legal_acceptances (user_id, slug, version, accepted_at) values (auth.uid(), 'terms', 'Version 9.9', now() - interval '1 year')$$, 'Consentement : une acceptation ne s''ecrit pas a la main (version ou date inventees)');
select t.fails_with($$select public.accept_legal_documents('{"terms":"Version 1.0","privacy":"Version 1.2","community":"Version 1.1"}')$$, 'version_changed', 'Consentement : on n''accepte pas une version qu''on n''a pas vue');
select t.fails_with($$select public.accept_legal_documents('{"terms":"Version 1.1"}')$$, 'version_changed', 'Consentement : tout ou rien, un document manquant refuse l''ensemble');
select public.accept_legal_documents('{"terms":"Version 1.1","privacy":"Version 1.2","community":"Version 1.1"}');
select t.sees('select * from public.pending_legal_documents()', 0, 'Consentement : une fois accepte, plus rien a accepter');
select t.sees('select * from user_legal_acceptances', 3, 'Consentement : chacun relit ses propres acceptations');
reset role;
update legal_documents set version = 'Version 2.0' where slug = 'terms';
select t.as_user('00000000-0000-0000-0000-00000000000c');
select t.sees('select * from public.pending_legal_documents() where previously_accepted', 1, 'Consentement : une nouvelle version est re-presentee, comme une mise a jour');
-- Le bug du 2026-10-09 : l'ecran de mise a jour n'envoie que le document qui
-- a change ; l'exiger avec les autres bloquait « J'accepte » en boucle.
select t.can_write($$select public.accept_legal_documents('{"terms":"Version 2.0"}')$$, 'Consentement : une mise a jour s''accepte sans renvoyer les documents inchanges');
select t.fails_with($$select public.accept_legal_documents('{"privacy":"Version 1.2"}')$$, 'version_changed', 'Consentement : mais un document en attente ne peut pas manquer');
reset role;
select t.as_user('00000000-0000-0000-0000-00000000000b');
select t.sees_nothing($$select * from user_legal_acceptances where user_id = '00000000-0000-0000-0000-00000000000c'$$, 'Consentement : on ne lit pas les acceptations des autres');
reset role;

-- HAPPYN reserve aux 18 ans et plus, et les regles d'age tenues par la base
reset role;
-- Zoe : compte cree sans date de naissance (inscription Google, avant l'ecran
-- qui la demande). Yann : inscription par e-mail, date dans les metadonnees.
insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000f0', 'zoe@test.local',  '{"full_name":"Zoe"}'),
  ('00000000-0000-0000-0000-0000000000f9', 'yann@test.local', '{"full_name":"Yann","date_of_birth":"1995-05-05"}');
select t.record(
  (select date_of_birth = date '1995-05-05' from profiles where id = '00000000-0000-0000-0000-0000000000f9'),
  'Age : la date saisie a l''inscription arrive dans le profil des la creation');
select t.fails_with($$insert into auth.users (id, email, raw_user_meta_data) values (gen_random_uuid(), 'ado@test.local', jsonb_build_object('full_name','Ado','date_of_birth', (current_date - interval '16 years')::date::text))$$,
  'under_minimum_age', 'Age : un compte de moins de 18 ans ne peut pas etre cree, meme par l''API');

select t.as_user('00000000-0000-0000-0000-00000000000a');
select t.fails_with($$update profiles set date_of_birth = date '1980-01-01' where id = auth.uid()$$, 'birth_date_locked', 'Age : la date de naissance est figee une fois donnee');
select t.cannot_write($$insert into events (title, created_by, status, start_date, end_date, min_age) values ('Ados', auth.uid(), 'draft', now() + interval '5 days', now() + interval '6 days', 16)$$, 'Age : plus d''evenement 14+ ou 16+');
select t.can_write($$select public.issue_tickets('00000000-0000-0000-0000-0000000000f5', 1)$$, 'Age : un compte de 36 ans entre a une soiree 21+');
reset role;
select t.as_user('00000000-0000-0000-0000-0000000000f0');
select t.can_write($$update profiles set date_of_birth = date '2000-02-02' where id = auth.uid()$$, 'Age : une date manquante peut etre donnee une premiere fois');
select t.fails_with($$update profiles set date_of_birth = (current_date - interval '15 years')::date where id = auth.uid()$$, 'under_minimum_age', 'Age : une date de moins de 18 ans est refusee par la base');
select t.fails_with($$select public.issue_tickets('00000000-0000-0000-0000-0000000000f1', 1)$$, 'age_restricted', 'Age : sans date de naissance connue, pas de billet');
select t.cannot_write($$insert into events (title, created_by, status, start_date, end_date) values ('Sans age', auth.uid(), 'draft', now() + interval '5 days', now() + interval '6 days')$$, 'Age : sans date de naissance connue, pas d''evenement');
select t.fails_with('select public.user_meets_age(''00000000-0000-0000-0000-00000000000a'', 21)', 'permission denied', 'Age : on ne sonde pas l''age des autres');
reset role;
select t.as_user('00000000-0000-0000-0000-00000000000c');
select t.fails_with($$select public.issue_tickets('00000000-0000-0000-0000-0000000000f5', 1)$$, 'age_restricted', 'Age : a 19 ans, pas de billet pour une soiree 21+, meme par l''API');
select t.can_write($$insert into events (title, created_by, status, start_date, end_date) values ('Majeure', auth.uid(), 'draft', now() + interval '5 days', now() + interval '6 days')$$, 'Age : a 19 ans, on peut organiser');
reset role;
select t.as_server();
select t.can_write($$update profiles set date_of_birth = date '1991-01-01' where id = '00000000-0000-0000-0000-00000000000e'$$, 'Age : le serveur peut corriger une date (demande au support)');
reset role;

-- Les textes en francais : une traduction ne compte que si elle porte la
-- version de l'original, et l'acceptation enregistre la langue lue
reset role;
update legal_documents set version = 'Version 2.0' where slug = 'terms';
insert into legal_document_translations (slug, locale, title, content, version) values
  ('terms',   'fr', 'Conditions d''utilisation',   '...', 'Version 2.0'),
  ('privacy', 'fr', 'Politique de confidentialite', '...', 'Version 0.9')
on conflict (slug, locale) do update set version = excluded.version, title = excluded.title;
select t.as_user('00000000-0000-0000-0000-0000000000f9');
select t.sees($$select * from public.pending_legal_documents('fr') where slug = 'terms' and title = 'Conditions d''utilisation'$$, 1, 'Traduction : affichee quand elle porte la version de l''original');
select t.sees($$select * from public.pending_legal_documents('fr') where slug = 'privacy' and title = 'Privacy'$$, 1, 'Traduction : perimee, on retombe sur l''anglais');
select public.accept_legal_documents('{"terms":"Version 2.0","privacy":"Version 1.2","community":"Version 1.1"}', 'fr');
select t.sees($$select * from user_legal_acceptances where slug = 'terms' and locale = 'fr'$$, 1, 'Traduction : l''acceptation note la langue lue');
select t.sees($$select * from user_legal_acceptances where slug = 'privacy' and locale = 'en'$$, 1, 'Traduction : une traduction perimee n''a pas ete lue, c''est l''anglais qui est note');
select t.cannot_write($$update legal_document_translations set content = 'pirate' where slug = 'terms'$$, 'Traduction : personne ne la modifie depuis l''app');
reset role;
select t.as_anon();
select t.sees('select * from legal_document_translations', 2, 'Traduction : lisible sans compte, comme les originaux (site Web)');
reset role;

-- Supprimer ses notifications, et seulement les siennes
reset role;
insert into notifications (id, user_id, type, title) values
  ('00000000-0000-0000-0000-00000000aa01', '00000000-0000-0000-0000-00000000000a', 'test', 'pour Alice'),
  ('00000000-0000-0000-0000-00000000aa02', '00000000-0000-0000-0000-00000000000b', 'test', 'pour Bruno');
select t.as_user('00000000-0000-0000-0000-00000000000a');
select t.can_write($$delete from notifications where id = '00000000-0000-0000-0000-00000000aa01'$$, 'Notifications : on supprime les siennes');
select t.cannot_write($$delete from notifications where id = '00000000-0000-0000-0000-00000000aa02'$$, 'Notifications : on ne supprime pas celles des autres');
reset role;

-- Le billet transfere arrive dans la conversation, avec un mot ; seul le
-- serveur cree ces messages
reset role;
select t.as_user('00000000-0000-0000-0000-00000000000b');
select t.cannot_write($$insert into direct_messages (conversation_id, sender_id, body, shared_kind, event_id, ticket_id) values ('00000000-0000-0000-0000-0000000000c1', auth.uid(), '', 'ticket', '00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000b1')$$, 'Transfert : l''app ne fabrique pas un faux message de billet');
select t.fails_with($$select public.transfer_ticket_to_user('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-00000000000a', repeat('x', 501))$$, 'note_too_long', 'Transfert : un mot, pas une lettre (500 caracteres)');
select public.transfer_ticket_to_user('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-00000000000a', '  Bonne soiree !  ');
select t.sees($$select * from direct_messages where shared_kind = 'ticket' and body = 'Bonne soiree !'$$, 1, 'Transfert : l''expediteur voit le message, avec son mot');
reset role;
select t.as_user('00000000-0000-0000-0000-00000000000a');
select t.sees($$select * from direct_messages where shared_kind = 'ticket' and ticket_id = '00000000-0000-0000-0000-0000000000b1'$$, 1, 'Transfert : le destinataire le recoit dans la conversation');
select t.sees($$select * from notifications where type = 'direct_message'$$, 0, 'Transfert : pas de deuxieme notification pour le message du billet');
select t.sees($$select * from notifications where type = 'ticket_received'$$, 1, 'Transfert : la notification du billet, elle, part');
reset role;

-- Maintenance et version minimale : lues par tous, écrites par un admin seul
reset role;
-- Le schéma régénéré ne porte pas les données : la ligne unique est recréée ici.
insert into app_status (id) values (true) on conflict (id) do nothing;
select t.as_anon();
select t.sees('select * from app_status', 1, 'Maintenance : l''etat se lit sans compte (ecran avant connexion)');
select t.cannot_write($$update app_status set maintenance = true$$, 'Maintenance : un visiteur ne l''active pas');
select t.fails_with($$select public.admin_set_app_status(true)$$, 'permission', 'Maintenance : un visiteur n''appelle pas la fonction admin');
reset role;
select t.as_user('00000000-0000-0000-0000-00000000000a');
select t.cannot_write($$update app_status set maintenance = true$$, 'Maintenance : un compte ne l''ecrit pas directement');
select t.cannot_write($$delete from app_status$$, 'Maintenance : personne ne supprime la ligne');
select t.cannot_write($$insert into app_status (id) values (false)$$, 'Maintenance : personne n''ajoute de deuxieme ligne');
select t.fails_with($$select public.admin_set_app_status(true, 'pirate')$$, 'not_admin', 'Maintenance : un compte ordinaire ne l''active pas');
reset role;
select t.as_user('00000000-0000-0000-0000-0000000000ad');
select public.admin_set_app_status(true, '  Retour a 22 h  ', null, '1.2.0');
select t.sees($$select * from app_status where maintenance and message_fr = 'Retour a 22 h' and message_en is null and min_version = '1.2.0' and updated_by = auth.uid()$$, 1, 'Maintenance : un admin l''active, et c''est trace');
select t.fails_with($$select public.admin_set_app_status(false, null, null, 'v2')$$, 'check', 'Maintenance : une version minimale mal formee est refusee');
select public.admin_set_app_status(false);
select t.sees($$select * from app_status where not maintenance and min_version is null$$, 1, 'Maintenance : un admin la leve');
reset role;

-- Paiement : un webhook rejoué n'émet pas les billets deux fois
reset role;
select t.as_server();
select count(*) from public.issue_tickets_paid('00000000-0000-0000-0000-0000000000f2', 2, '00000000-0000-0000-0000-00000000000a', 'pi_test_rejeu');
select count(*) from public.issue_tickets_paid('00000000-0000-0000-0000-0000000000f2', 2, '00000000-0000-0000-0000-00000000000a', 'pi_test_rejeu');
select t.sees($$select * from tickets where payment_intent_id = 'pi_test_rejeu'$$, 2, 'Paiement : rejoue, le webhook renvoie les memes billets au lieu d''en creer');
reset role;
select t.as_user('00000000-0000-0000-0000-00000000000b');
select t.fails_with($$select public.issue_tickets_paid('00000000-0000-0000-0000-0000000000f2', 1, auth.uid(), 'pi_pirate')$$, 'permission', 'Paiement : un compte n''emet pas de billet paye lui-meme');
reset role;

-- La limite de l'organisateur est par personne, pas par commande
reset role;
insert into ticket_types (id, event_id, name, price, quantity_total, quantity_sold, max_per_order) values
  ('00000000-0000-0000-0000-0000000000f6', '00000000-0000-0000-0000-0000000000e1', 'Gratuit limite', 0, 100, 0, 2)
on conflict (id) do nothing;
select t.as_user('00000000-0000-0000-0000-00000000000b');
select t.can_write($$select public.issue_tickets('00000000-0000-0000-0000-0000000000f6', 2)$$, 'Limite : jusqu''a la limite, ca passe');
-- can_write annule ce qu'il essaie : la commande est rejouee pour de bon.
select count(*) from public.issue_tickets('00000000-0000-0000-0000-0000000000f6', 2);
select t.fails_with($$select public.issue_tickets('00000000-0000-0000-0000-0000000000f6', 1)$$, 'exceeds_per_person', 'Limite : une deuxieme commande ne la depasse pas');
select t.sees($$select * from tickets where ticket_type_id = '00000000-0000-0000-0000-0000000000f6' and user_id = auth.uid()$$, 2, 'Limite : la personne garde ses 2 billets, pas un de plus');
reset role;
-- Un billet annule ne compte plus : on peut en reprendre un
update tickets set status = 'refunded'
 where id = (select id from tickets where ticket_type_id = '00000000-0000-0000-0000-0000000000f6' limit 1);
select t.as_user('00000000-0000-0000-0000-00000000000b');
select t.can_write($$select public.issue_tickets('00000000-0000-0000-0000-0000000000f6', 1)$$, 'Limite : un billet annule libere sa place dans la limite');
reset role;

-- Versements : personne ne déclenche la tâche depuis l'app
reset role;
select t.as_anon();
select t.fails_with($$select private.run_payouts_tick()$$, 'permission', 'Versements : un visiteur ne declenche pas la tache');
reset role;
select t.as_user('00000000-0000-0000-0000-0000000000ad');
select t.fails_with($$select private.run_payouts_tick()$$, 'permission', 'Versements : meme un admin ne la declenche pas depuis l''app');
reset role;

-- Notes d'événement : seuls les présents notent, dans la fenêtre, avec les bons tags
reset role;
insert into events (id, title, created_by, status, visibility, start_date, end_date, posts_visibility, access_code, min_age, category) values
  ('00000000-0000-0000-0000-0000000000e9', 'Soiree tech', '00000000-0000-0000-0000-00000000000a', 'published', 'public', now() - interval '30 hours', now() - interval '26 hours', 'public', null, 0, 'Technology'),
  ('00000000-0000-0000-0000-0000000000e8', 'Vieux concert', '00000000-0000-0000-0000-00000000000a', 'published', 'public', now() - interval '11 days', now() - interval '10 days', 'public', null, 0, 'Music');
insert into ticket_types (id, event_id, name, price, quantity_total, quantity_sold, max_per_order) values
  ('00000000-0000-0000-0000-0000000000f9', '00000000-0000-0000-0000-0000000000e9', 'Entree', 25, 100, 2, 10),
  ('00000000-0000-0000-0000-0000000000f8', '00000000-0000-0000-0000-0000000000e8', 'Entree', 0, 100, 1, 10);
insert into tickets (ticket_type_id, event_id, user_id, qr_token, status) values
  ('00000000-0000-0000-0000-0000000000f9', '00000000-0000-0000-0000-0000000000e9', '00000000-0000-0000-0000-00000000000b', 'HPN-note-1', 'used'),
  ('00000000-0000-0000-0000-0000000000f9', '00000000-0000-0000-0000-0000000000e9', '00000000-0000-0000-0000-00000000000c', 'HPN-note-2', 'valid'),
  ('00000000-0000-0000-0000-0000000000f8', '00000000-0000-0000-0000-0000000000e8', '00000000-0000-0000-0000-00000000000b', 'HPN-note-3', 'used');

-- La demande part une fois, aux seuls presents, et pas pour un evenement clos
select private.send_rating_requests();
select t.sees($$select * from notifications where type = 'rate_event' and event_id = '00000000-0000-0000-0000-0000000000e9' and user_id = '00000000-0000-0000-0000-00000000000b'$$, 1, 'Notes : la demande part a celui dont le billet a ete scanne');
select t.sees($$select * from notifications where type = 'rate_event' and user_id = '00000000-0000-0000-0000-00000000000c'$$, 0, 'Notes : pas de demande a un billet jamais scanne');
select t.sees($$select * from notifications where type = 'rate_event' and event_id = '00000000-0000-0000-0000-0000000000e8'$$, 0, 'Notes : pas de demande quand la fenetre est fermee');
select private.send_rating_requests();
select t.sees($$select * from notifications where type = 'rate_event'$$, 1, 'Notes : la demande ne part qu''une fois');

select t.as_user('00000000-0000-0000-0000-00000000000b');
select t.sees($$select * from unnest(public.rating_tags_for('00000000-0000-0000-0000-0000000000e9')) t where t in ('speakers', 'value')$$, 2, 'Notes : une soiree tech payante propose intervenants et qualite-prix');
select t.sees($$select * from unnest(public.rating_tags_for('00000000-0000-0000-0000-0000000000e9')) t where t = 'music'$$, 0, 'Notes : une soiree tech ne demande pas la musique');
select t.fails_with($$select public.rate_event('00000000-0000-0000-0000-0000000000e9', 5, array['music'])$$, 'invalid_tag', 'Notes : un tag hors de la categorie est refuse');
select t.fails_with($$select public.rate_event('00000000-0000-0000-0000-0000000000e9', 6)$$, 'invalid_stars', 'Notes : pas plus de 5 etoiles');
select t.fails_with($$select public.rate_event('00000000-0000-0000-0000-0000000000e8', 4)$$, 'rating_closed', 'Notes : fermees au meme delai que le versement');
select public.rate_event('00000000-0000-0000-0000-0000000000e9', 4, array['content', 'ambiance', 'content'], '  Super intervenants  ');
select public.rate_event('00000000-0000-0000-0000-0000000000e9', 5, array['speakers']);
select t.sees($$select * from public.my_event_rating('00000000-0000-0000-0000-0000000000e9') where stars = 5 and tags = array['speakers'] and comment is null$$, 1, 'Notes : on corrige sa note, sans en creer une seconde');
select t.fails_with($$select * from event_ratings$$, 'permission', 'Notes : la table ne se lit pas directement');
select t.fails_with($$select public.event_rating_summary('00000000-0000-0000-0000-0000000000e9')$$, 'not_organizer', 'Notes : le detail est reserve a l''organisateur');
reset role;
select t.as_user('00000000-0000-0000-0000-00000000000c');
select t.fails_with($$select public.rate_event('00000000-0000-0000-0000-0000000000e9', 1)$$, 'not_attended', 'Notes : un billet non scanne ne note pas');
reset role;
select t.as_user('00000000-0000-0000-0000-00000000000a');
select t.fails_with($$select public.rate_event('00000000-0000-0000-0000-0000000000e9', 5)$$, 'organizer_cannot_rate', 'Notes : l''organisateur ne note pas sa soiree');
select t.sees($$select 1 from (select public.event_rating_summary('00000000-0000-0000-0000-0000000000e9') s) x where (s->>'count')::int = 1 and s::text not like '%00000000-0000-0000-0000-00000000000b%'$$, 1, 'Notes : l''organisateur voit le detail, sans savoir qui a note');
reset role;
select t.as_anon();
select t.sees($$select * from public.organizer_public_rating('00000000-0000-0000-0000-00000000000a')$$, 0, 'Notes : pas de moyenne publique sous 5 notes');
reset role;

-- Versements : 7 jours, retenues automatiques, decision de l'administrateur
reset role;
update stripe_accounts set transfers_enabled = true, disabled_reason = null where user_id = '00000000-0000-0000-0000-00000000000a';
insert into events (id, title, created_by, status, visibility, start_date, end_date, posts_visibility, access_code, min_age) values
  ('00000000-0000-0000-0000-0000000000e7', 'Personne a la porte', '00000000-0000-0000-0000-00000000000a', 'published', 'public', now() - interval '11 days', now() - interval '10 days', 'public', null, 0),
  ('00000000-0000-0000-0000-0000000000e6', 'Vraie soiree', '00000000-0000-0000-0000-00000000000a', 'published', 'public', now() - interval '11 days', now() - interval '10 days', 'public', null, 0),
  ('00000000-0000-0000-0000-0000000000e5', 'Il y a 5 jours', '00000000-0000-0000-0000-00000000000a', 'published', 'public', now() - interval '6 days', now() - interval '5 days', 'public', null, 0);
insert into ticket_types (id, event_id, name, price, quantity_total, quantity_sold, max_per_order) values
  ('00000000-0000-0000-0000-0000000000fa', '00000000-0000-0000-0000-0000000000e7', 'Entree', 20, 100, 1, 10),
  ('00000000-0000-0000-0000-0000000000fb', '00000000-0000-0000-0000-0000000000e6', 'Entree', 20, 100, 1, 10),
  ('00000000-0000-0000-0000-0000000000fc', '00000000-0000-0000-0000-0000000000e5', 'Entree', 20, 100, 1, 10);
insert into tickets (ticket_type_id, event_id, user_id, qr_token, status, payment_intent_id) values
  ('00000000-0000-0000-0000-0000000000fa', '00000000-0000-0000-0000-0000000000e7', '00000000-0000-0000-0000-00000000000b', 'HPN-pay-1', 'valid', 'pi_porte_vide'),
  ('00000000-0000-0000-0000-0000000000fb', '00000000-0000-0000-0000-0000000000e6', '00000000-0000-0000-0000-00000000000b', 'HPN-pay-2', 'used', 'pi_vraie'),
  ('00000000-0000-0000-0000-0000000000fc', '00000000-0000-0000-0000-0000000000e5', '00000000-0000-0000-0000-00000000000b', 'HPN-pay-3', 'used', 'pi_recent');
insert into payments (payment_intent_id, event_id, ticket_type_id, organizer_id, buyer_id, quantity, gross_cents, platform_fee_bps) values
  ('pi_porte_vide', '00000000-0000-0000-0000-0000000000e7', '00000000-0000-0000-0000-0000000000fa', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000b', 1, 2000, 500),
  ('pi_vraie',      '00000000-0000-0000-0000-0000000000e6', '00000000-0000-0000-0000-0000000000fb', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000b', 1, 2000, 500),
  ('pi_recent',     '00000000-0000-0000-0000-0000000000e5', '00000000-0000-0000-0000-0000000000fc', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000b', 1, 2000, 500);

select t.sees($$select * from public.events_due_for_payout() where event_id = '00000000-0000-0000-0000-0000000000e5'$$, 0, 'Versement : pas avant 7 jours apres la fin');
select t.sees($$select * from public.events_due_for_payout() where event_id = '00000000-0000-0000-0000-0000000000e7'$$, 0, 'Versement : retenu si aucun billet n''a ete scanne');
select t.sees($$select * from public.events_due_for_payout() where event_id = '00000000-0000-0000-0000-0000000000e6'$$, 0, 'Versement : retenu pour le premier evenement paye d''un organisateur');

select private.alert_payout_holds();
select t.sees($$select * from notifications where type = 'payout_review' and user_id = '00000000-0000-0000-0000-0000000000ad'$$, 2, 'Versement : l''administrateur est prevenu des deux retenues');
select t.sees($$select * from notifications where type = 'payout_review' and user_id <> '00000000-0000-0000-0000-0000000000ad'$$, 0, 'Versement : seuls les administrateurs sont prevenus');
select private.alert_payout_holds();
select t.sees($$select * from notifications where type = 'payout_review'$$, 2, 'Versement : une seule alerte par evenement');

-- L'organisateur est prevenu de ses deux retenues, dans sa langue, et une seule
-- fois chacune (meme deduplication que l'admin).
select t.sees($$select * from notifications where type = 'payout_held' and user_id = '00000000-0000-0000-0000-00000000000a'$$, 2, 'Versement : l''organisateur est prevenu de ses retenues');
select t.sees($$select * from notifications where type = 'payout_held' and user_id <> '00000000-0000-0000-0000-00000000000a'$$, 0, 'Versement : la retenue ne previent que l''organisateur concerne');
select t.sees($$select * from notifications where type = 'payout_held' and event_id = '00000000-0000-0000-0000-0000000000e7' and body ilike '%scann%'$$, 1, 'Versement : la retenue sans scan le dit a l''organisateur');

select t.as_user('00000000-0000-0000-0000-00000000000a');
select t.fails_with($$select * from public.admin_payout_queue()$$, 'not_admin', 'Versement : l''organisateur ne voit pas la file admin');
select t.fails_with($$select public.admin_set_payout_review('00000000-0000-0000-0000-0000000000e6', 'released')$$, 'not_admin', 'Versement : l''organisateur ne libere pas son propre versement');
reset role;
select t.as_user('00000000-0000-0000-0000-0000000000ad');
select t.sees($$select * from public.admin_payout_queue() where state = 'held' and hold_reason in ('no_scans', 'first_event')$$, 2, 'Versement : l''administrateur voit les retenues et leur raison');
select t.sees($$select * from public.admin_payout_queue() where event_id = '00000000-0000-0000-0000-0000000000e5' and state = 'waiting'$$, 1, 'Versement : et ceux dont le delai court encore');
select public.admin_set_payout_review('00000000-0000-0000-0000-0000000000e6', 'released', 'Verifie : vraie soiree');
reset role;
select t.sees($$select * from public.events_due_for_payout() where event_id = '00000000-0000-0000-0000-0000000000e6'$$, 1, 'Versement : libere par l''administrateur, il part');
select t.sees($$select * from public.events_due_for_payout() where event_id = '00000000-0000-0000-0000-0000000000e7'$$, 0, 'Versement : l''autre reste retenu');
select t.as_user('00000000-0000-0000-0000-0000000000ad');
select public.admin_set_payout_review('00000000-0000-0000-0000-0000000000e6', 'held', 'Plainte recue');
reset role;
select t.sees($$select * from public.events_due_for_payout() where event_id = '00000000-0000-0000-0000-0000000000e6'$$, 0, 'Versement : bloque par l''administrateur, il ne part plus');
select t.sees($$select * from payout_reviews where event_id = '00000000-0000-0000-0000-0000000000e6' and decided_by = '00000000-0000-0000-0000-0000000000ad' and reason = 'Plainte recue'$$, 1, 'Versement : la decision garde qui et pourquoi');
select t.as_user('00000000-0000-0000-0000-00000000000a');
select t.fails_with($$select * from payout_reviews$$, 'permission', 'Versement : les decisions ne se lisent pas depuis l''app');
reset role;

-- Versement versé : quand le virement part, l'organisateur est prevenu une
-- fois, et repasser la ligne a 'paid' ne renotifie pas.
insert into event_payouts (id, event_id, organizer_id, account_id, gross_cents, refunded_cents, stripe_fee_cents, platform_fee_cents, net_cents, status, transfer_id, created_at, paid_at)
values (gen_random_uuid(), '00000000-0000-0000-0000-0000000000e6', '00000000-0000-0000-0000-00000000000a', 'acct_test', 130000, 0, 4000, 2000, 124000, 'paid', 'tr_test', now(), now());
select t.sees($$select * from notifications where type = 'payout_paid' and user_id = '00000000-0000-0000-0000-00000000000a'$$, 1, 'Versement verse : l''organisateur est prevenu');
update event_payouts set status = 'paid' where event_id = '00000000-0000-0000-0000-0000000000e6';
select t.sees($$select * from notifications where type = 'payout_paid' and user_id = '00000000-0000-0000-0000-00000000000a'$$, 1, 'Versement verse : pas de doublon si la ligne repasse a paid');
reset role;

-- ═══ device_tokens : la suppression ne vaut que pour ses propres lignes ═════
-- Piege subtil. Le test « ne supprime pas les jetons des autres » (section
-- Bruno) passe parce que son WHERE lit une colonne (user_id) : Postgres
-- applique alors la policy SELECT (propres lignes), et Bruno ne « voit » que la
-- sienne. Mais un DELETE SANS WHERE ne lit aucune colonne — la policy SELECT ne
-- joue pas, et un using(true) sur le DELETE laisse un seul compte vider toute la
-- table, coupant les notifications push de tout le monde. C'est le trou reel.
reset role;
delete from device_tokens;
insert into device_tokens (token, user_id, platform) values
  ('sonde-alice', '00000000-0000-0000-0000-00000000000a', 'android'),
  ('sonde-bruno', '00000000-0000-0000-0000-00000000000b', 'ios');
select t.as_user('00000000-0000-0000-0000-00000000000b');
delete from device_tokens;                 -- l'attaque : aucun WHERE
reset role;
select t.sees($$select 1 from device_tokens where token = 'sonde-alice'$$, 1,
  'device_tokens : un compte ne supprime pas le jeton d''un autre (DELETE sans WHERE)');

-- La reattribution d'appareil reste possible, mais par le serveur seul :
-- register_device_token retire la ligne de l'ancien proprietaire puis pose la
-- sienne. Le client n'ecrase plus la ligne d'autrui lui-meme.
select t.as_user('00000000-0000-0000-0000-00000000000b');
select public.register_device_token('sonde-alice', 'ios');   -- Bruno reprend l'appareil d'Alice
reset role;
select t.sees($$select 1 from device_tokens where token = 'sonde-alice' and user_id = '00000000-0000-0000-0000-00000000000b'$$, 1,
  'device_tokens : la reattribution passe par le serveur (register_device_token)');
select t.sees($$select 1 from device_tokens where token = 'sonde-alice' and user_id = '00000000-0000-0000-0000-00000000000a'$$, 0,
  'device_tokens : l''ancien proprietaire ne garde pas la ligne reattribuee');
reset role;


-- ═══ Publications d'un brouillon ════════════════════════════════════════════
-- Un brouillon n'est pas publié. Ses publications — y compris la vidéo posée à
-- la création de l'événement — ne doivent pas se lire depuis la table posts par
-- quelqu'un qui n'y est pour rien, même si posts_visibility vaut 'public'.
-- L'organisateur, lui, les voit (can_attach_event).

select t.as_user('00000000-0000-0000-0000-00000000000b');  -- Bruno, étranger au brouillon
select t.sees_nothing($$select 1 from posts where event_id = '00000000-0000-0000-0000-0000000000e3'$$,
  'Brouillon : un compte ne lit pas les publications d''un brouillon');
select t.sees($$select 1 from feed_posts where event_id = '00000000-0000-0000-0000-0000000000e3'$$, 0,
  'Brouillon : les publications d''un brouillon n''apparaissent pas dans le fil');
reset role;

select t.as_user('00000000-0000-0000-0000-00000000000a');  -- Alice, organisatrice
select t.sees($$select 1 from posts where event_id = '00000000-0000-0000-0000-0000000000e3'$$, 1,
  'Brouillon : l''organisateur lit les publications de son brouillon');
reset role;

-- ═══ Vidéos d'événement (bucket event-videos) ═══════════════════════════════
-- Même logique que les publications : la vidéo d'un événement public se lit,
-- celle d'un brouillon reste à l'organisateur et aux présents. Le téléversement
-- n'appartient qu'à l'organisateur, et dans SON dossier ; la suppression, au
-- seul propriétaire du fichier.

\set V_PUB '00000000-0000-0000-0000-0000000000e1/00000000-0000-0000-0000-00000000000a/clip-public.mp4'
\set V_DRAFT '00000000-0000-0000-0000-0000000000e3/00000000-0000-0000-0000-00000000000a/clip-brouillon.mp4'

select t.as_anon();
select t.sees_nothing($$select 1 from storage.objects where bucket_id = 'event-videos'$$,
  'Vidéo : un visiteur sans compte ne lit aucune vidéo');
reset role;

select t.as_user('00000000-0000-0000-0000-00000000000b');  -- Bruno, détenteur d'un billet pour e1
select t.sees($$select 1 from storage.objects where name = '00000000-0000-0000-0000-0000000000e1/00000000-0000-0000-0000-00000000000a/clip-public.mp4'$$, 1,
  'Vidéo : un compte lit la vidéo d''un événement public');
select t.sees($$select 1 from storage.objects where name = '00000000-0000-0000-0000-0000000000e3/00000000-0000-0000-0000-00000000000a/clip-brouillon.mp4'$$, 0,
  'Vidéo : un compte ne lit pas la vidéo d''un brouillon');
-- Bruno a un billet pour e1 : comme pour les photos, il peut y poster un
-- moment vidéo, dans son propre dossier.
select t.can_write($$insert into storage.objects (bucket_id, name) values ('event-videos', '00000000-0000-0000-0000-0000000000e1/00000000-0000-0000-0000-00000000000b/mon-moment.mp4')$$,
  'Vidéo : un détenteur de billet poste un moment sur l''événement');
-- Mais pas sous le dossier de quelqu'un d'autre.
select t.cannot_write($$insert into storage.objects (bucket_id, name) values ('event-videos', '00000000-0000-0000-0000-0000000000e1/00000000-0000-0000-0000-00000000000a/usurpation.mp4')$$,
  'Vidéo : on ne poste pas sous le dossier d''un autre');
-- Bruno supprime le fichier d'Alice (dossier à son nom à elle) : refusé.
select t.cannot_write($$delete from storage.objects where name = '00000000-0000-0000-0000-0000000000e1/00000000-0000-0000-0000-00000000000a/clip-public.mp4'$$,
  'Vidéo : on ne supprime pas le fichier d''un autre');
reset role;

select t.as_user('00000000-0000-0000-0000-00000000000c');  -- Chloe, ni billet ni événement
select t.cannot_write($$insert into storage.objects (bucket_id, name) values ('event-videos', '00000000-0000-0000-0000-0000000000e1/00000000-0000-0000-0000-00000000000c/sans-billet.mp4')$$,
  'Vidéo : sans billet ni événement organisé, pas de téléversement');
reset role;

select t.as_user('00000000-0000-0000-0000-00000000000a');  -- Alice, organisatrice
select t.sees($$select 1 from storage.objects where name = '00000000-0000-0000-0000-0000000000e3/00000000-0000-0000-0000-00000000000a/clip-brouillon.mp4'$$, 1,
  'Vidéo : l''organisateur lit la vidéo de son brouillon');
select t.can_write($$insert into storage.objects (bucket_id, name) values ('event-videos', '00000000-0000-0000-0000-0000000000e1/00000000-0000-0000-0000-00000000000a/nouvelle.mp4')$$,
  'Vidéo : l''organisateur téléverse sur son événement, dans son dossier');
-- Alice téléverse sur son événement mais sous le dossier de Bruno : refusé,
-- le deuxième segment du chemin doit être l'identifiant de l'uploadeur.
select t.cannot_write($$insert into storage.objects (bucket_id, name) values ('event-videos', '00000000-0000-0000-0000-0000000000e1/00000000-0000-0000-0000-00000000000b/usurpation.mp4')$$,
  'Vidéo : le téléversement se fait sous son propre dossier, pas celui d''un autre');
-- Alice supprime bien sa propre vidéo.
select t.can_write($$delete from storage.objects where name = '00000000-0000-0000-0000-0000000000e1/00000000-0000-0000-0000-00000000000a/clip-public.mp4'$$,
  'Vidéo : le propriétaire supprime son propre fichier');
reset role;

-- ═══ Tableau de bord organisateur (organizer_dashboard) ═════════════════════
-- Chacun ne voit QUE ses propres événements et leur argent. Alice organise
-- e1..e4 ; Bruno n'organise rien (il a juste un billet).

select t.as_user('00000000-0000-0000-0000-00000000000a');  -- Alice, organisatrice
select t.sees($$select 1 from organizer_dashboard() where event_id = '00000000-0000-0000-0000-0000000000e1'$$, 1,
  'Dashboard : l''organisateur voit son propre événement');
select t.sees($$select 1 from organizer_dashboard() where event_id = '00000000-0000-0000-0000-0000000000e1' and net_cents = 2375$$, 1,
  'Dashboard : le net est calculé (2500 − 5 % = 2375)');
reset role;

select t.as_user('00000000-0000-0000-0000-00000000000b');  -- Bruno, détenteur de billet, pas organisateur
select t.sees_nothing($$select 1 from organizer_dashboard()$$,
  'Dashboard : un non-organisateur ne voit aucun revenu');
select t.sees_nothing($$select 1 from organizer_dashboard() where event_id = '00000000-0000-0000-0000-0000000000e1'$$,
  'Dashboard : on ne voit pas le revenu de l''événement d''un autre');
reset role;

select t.as_anon();
select t.fails_with($$select * from organizer_dashboard()$$, 'permission',
  'Dashboard : un visiteur sans compte ne peut pas l''appeler');
reset role;

-- ═══ Outils de modération (admin_event + message admin) ═════════════════════
-- Depuis une fiche de signalement, l'admin ouvre l'event même brouillon/privé,
-- et écrit à l'auteur sans le suivre. Un membre normal n'a ni l'un ni l'autre.

select t.as_user('00000000-0000-0000-0000-0000000000ad');  -- Modo, admin
select t.sees($$select 1 where public.admin_event('00000000-0000-0000-0000-0000000000e3') is not null$$, 1,
  'Modération : l''admin ouvre un event brouillon signalé');
select t.sees($$select 1 where public.start_direct_conversation('00000000-0000-0000-0000-00000000000b') is not null$$, 1,
  'Modération : l''admin écrit à un membre sans le suivre');
reset role;

select t.as_user('00000000-0000-0000-0000-00000000000b');  -- Bruno, membre
select t.sees($$select 1 where public.admin_event('00000000-0000-0000-0000-0000000000e3') is not null$$, 0,
  'Modération : un non-admin n''ouvre pas d''event via admin_event');
reset role;

select t.as_user('00000000-0000-0000-0000-00000000000c');  -- Chloe, ne suit pas Bruno
select t.fails_with($$select public.start_direct_conversation('00000000-0000-0000-0000-00000000000b')$$, 'must_follow',
  'Message : un membre doit suivre la personne pour lui écrire');
reset role;
