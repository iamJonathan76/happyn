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
  ('00000000-0000-0000-0000-0000000000a2', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000e2', 'photo entre invites');
insert into post_comments (post_id, author_id, body) values
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-00000000000e', 'commentaire d''Eve');

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
