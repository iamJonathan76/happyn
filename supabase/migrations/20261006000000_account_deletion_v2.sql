-- Suppression de compte, deuxieme version : l'argent, les photos, les messages.
--
-- La premiere version (20260726) date d'avant les remboursements et les
-- versements. Ecrite quand tout etait gratuit, elle ne savait pas qu'un billet
-- pouvait avoir coute quelque chose, ni qu'un organisateur pouvait attendre de
-- l'argent. Relue le 2026-10-06 avant d'ecrire la page publique exigee par
-- Google Play — qui aurait sinon promis des choses fausses.
--
-- ── Ce qui change ───────────────────────────────────────────────────────────
--
--   1. Un acheteur ne perd plus son argent. Ses billets a venir etaient
--      SUPPRIMES, payants compris, sans remboursement. On refuse maintenant la
--      suppression tant qu'il detient un billet paye pour un evenement a venir
--      (`has_paid_tickets`) : il l'annule (ce qui le rembourse) ou le
--      transfere d'abord. On ne rembourse pas a sa place : l'annulation a ses
--      propres regles (delai, montant), et les contourner ici en ferait une
--      deuxieme porte de remboursement, sans ces regles.
--
--   2. Un organisateur ne perd plus ses gains. La garde ne regardait que les
--      ventes d'evenements A VENIR. Un evenement termine pendant les trois
--      jours de retenue laissait supprimer le compte ; le lien Stripe partait
--      en cascade, et le versement ne pouvait plus jamais avoir lieu.
--      Nouvelle garde : `has_pending_earnings`.
--
--   3. Une place n'est plus rendue deux fois. Le retour au stock comptait
--      TOUS les billets a venir, y compris ceux deja annules — qui avaient
--      deja rendu leur place en s'annulant.
--
--   4. Les conversations privees ne disparaissent plus chez l'autre. Avant,
--      supprimer son compte effacait la conversation entiere, des deux cotes,
--      y compris un message que l'autre avait signale a la moderation : un
--      moyen simple de detruire des preuves. Desormais, comme une lettre
--      envoyee, le message reste chez qui l'a recu ; seule l'identite de
--      l'auteur disparait (« Compte supprime »). Quand les deux membres sont
--      partis, la conversation est effacee pour de bon.
--
-- (La purge des photos de publications est dans la fonction Edge
--  `delete-account` : le stockage ne se vide pas depuis SQL.)

-- ═══════════════════════════════════════════════════════════════════════════
-- Messagerie : d'un seul cote
-- ═══════════════════════════════════════════════════════════════════════════

-- Les noms de contraintes sont ceux que Postgres a generes ; on les retrouve
-- plutot que de les supposer, pour que la migration tienne sur une base ou
-- ils differeraient.
do $$
declare
  r record;
begin
  for r in
    select c.conname, c.conrelid::regclass as tbl, a.attname as col
    from pg_constraint c
    join pg_attribute a
      on a.attrelid = c.conrelid and a.attnum = c.conkey[1]
    where c.contype = 'f'
      and c.confrelid = 'auth.users'::regclass
      and c.conrelid in ('public.direct_conversations'::regclass,
                         'public.direct_messages'::regclass)
      and a.attname in ('member_a', 'member_b', 'sender_id')
  loop
    execute format('alter table %s drop constraint %I', r.tbl, r.conname);
  end loop;
end;
$$;

alter table public.direct_conversations
  alter column member_a drop not null,
  alter column member_b drop not null,
  add constraint direct_conversations_member_a_fkey
    foreign key (member_a) references auth.users(id) on delete set null,
  add constraint direct_conversations_member_b_fkey
    foreign key (member_b) references auth.users(id) on delete set null;

alter table public.direct_messages
  alter column sender_id drop not null,
  add constraint direct_messages_sender_id_fkey
    foreign key (sender_id) references auth.users(id) on delete set null;

-- La contrainte `member_a < member_b` reste vraie : avec un membre nul elle
-- vaut NULL, ce que Postgres accepte. L'unicite aussi : deux NULL ne sont
-- jamais egaux, et personne ne peut plus ouvrir de conversation avec un compte
-- qui n'existe plus.

-- ── Quand les deux sont partis : effacer ────────────────────────────────────
--
-- Personne ne garde une conversation « au cas ou ». Le SET NULL de la cle
-- etrangere est un UPDATE, donc il declenche ce trigger.

create or replace function public.purge_orphan_conversation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.member_a is null and new.member_b is null then
    delete from public.direct_conversations where id = new.id;
  end if;
  return null;
end;
$$;

revoke all on function public.purge_orphan_conversation()
  from public, anon, authenticated;

drop trigger if exists purge_orphan_conversation on public.direct_conversations;
create trigger purge_orphan_conversation
  after update of member_a, member_b on public.direct_conversations
  for each row execute function public.purge_orphan_conversation();

-- ── On lit encore, on n'ecrit plus ──────────────────────────────────────────
--
-- `can_access_direct_conversation` laisse lire la personne restante (elle est
-- toujours l'un des deux membres). Ecrire a quelqu'un qui n'existe plus n'a
-- pas de sens : la politique d'envoi exige maintenant les deux membres.

create or replace function public.direct_conversation_is_open(p_conversation uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.direct_conversations c
    where c.id = p_conversation
      and c.member_a is not null
      and c.member_b is not null
  );
$$;

revoke all on function public.direct_conversation_is_open(uuid) from public, anon;
grant execute on function public.direct_conversation_is_open(uuid) to authenticated;

drop policy if exists "conversation participants can send messages" on public.direct_messages;
create policy "conversation participants can send messages"
  on public.direct_messages for insert
  to authenticated
  with check (
    sender_id = auth.uid()
    and public.can_access_direct_conversation(conversation_id)
    and public.direct_conversation_is_open(conversation_id)
  );

-- ── La liste des conversations ──────────────────────────────────────────────
--
-- Une jointure interne sur `profiles` faisait disparaitre la conversation de
-- la liste des que l'autre n'avait plus de profil : le message restait en
-- base, mais introuvable. Jointure externe : `other_user_id` nul signifie
-- « Compte supprime », a l'app de l'afficher.

create or replace function public.my_direct_conversations()
returns table (
  conversation_id uuid,
  other_user_id uuid,
  other_name text,
  other_avatar text,
  other_username text,
  last_message text,
  last_message_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    c.id,
    p.id,
    p.full_name,
    p.avatar_url,
    p.username,
    latest.body,
    latest.created_at
  from public.direct_conversations c
  left join public.profiles p
    on p.id = case when c.member_a = auth.uid() then c.member_b else c.member_a end
  cross join lateral (
    select m.body, m.created_at
    from public.direct_messages m
    where m.conversation_id = c.id
    order by m.created_at desc, m.id desc
    limit 1
  ) latest
  where auth.uid() in (c.member_a, c.member_b)
    and public.can_access_direct_conversation(c.id)
  order by latest.created_at desc, c.id;
$$;

revoke all on function public.my_direct_conversations() from public, anon;
grant execute on function public.my_direct_conversations() to authenticated;

-- ── Le contexte d'un message signale ────────────────────────────────────────
--
-- Reprise a l'identique de 20261003000000, une seule ligne change : `=`
-- devient `is not distinct from`. Avec un auteur supprime, `NULL = NULL` vaut
-- NULL, et le moderateur ne voyait plus qui avait ecrit quoi autour du
-- message signale.

create or replace function public.admin_report_target(p_report uuid)
returns jsonb
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  r      public.reports;
  result jsonb;
begin
  if not public.i_am_admin() then
    raise exception 'not_admin';
  end if;

  select * into r from public.reports where id = p_report;
  if not found then
    return null;
  end if;

  if r.target_type = 'event' then
    select jsonb_build_object(
      'type',        'event',
      'title',       e.title,
      'description', e.description,
      'image_url',   e.image_url,
      'start_date',  e.start_date,
      'end_date',    e.end_date,
      'city',        e.city,
      'location',    e.location,
      'category',    e.category,
      'price',       e.price,
      'status',      e.status,
      'visibility',  coalesce(e.visibility, 'public'),
      'author_id',   e.created_by,
      'author_name', (select pr.full_name from public.profiles pr where pr.id = e.created_by),
      'tickets_sold', (
        select count(*) from public.tickets t
        where t.event_id = e.id
          and coalesce(t.status, '') <> 'cancelled'
      )
    )
    into result
    from public.events e
    where e.id = r.target_id;

  elsif r.target_type = 'post' then
    select jsonb_build_object(
      'type',        'post',
      'caption',     p.caption,
      'image_url',   p.image_url,
      'created_at',  p.created_at,
      'edited_at',   p.edited_at,
      'author_id',   p.author_id,
      'author_name', (select pr.full_name from public.profiles pr where pr.id = p.author_id),
      'event_title', (select e.title from public.events e where e.id = p.event_id),
      'like_count',  (select count(*) from public.post_likes l where l.post_id = p.id)
    )
    into result
    from public.posts p
    where p.id = r.target_id;

  elsif r.target_type = 'user' then
    select jsonb_build_object(
      'type',         'user',
      'full_name',    pr.full_name,
      'username',     pr.username,
      'avatar_url',   pr.avatar_url,
      'is_suspended', pr.is_suspended,
      'author_id',    pr.id,
      'post_count',   (select count(*) from public.posts p where p.author_id = pr.id),
      'event_count',  (select count(*) from public.events e where e.created_by = pr.id)
    )
    into result
    from public.profiles pr
    where pr.id = r.target_id;

  elsif r.target_type = 'message' then
    select jsonb_build_object(
      'type',        'message',
      'body',        m.body,
      'created_at',  m.created_at,
      'author_id',   m.sender_id,
      'author_name', (select pr.full_name from public.profiles pr
                       where pr.id = m.sender_id),
      'context', (
        select coalesce(jsonb_agg(x order by x_created), '[]'::jsonb)
        from (
          select jsonb_build_object(
                   'body', prev.body,
                   'mine', prev.sender_id is not distinct from m.sender_id,
                   'created_at', prev.created_at
                 ) as x,
                 prev.created_at as x_created
          from public.direct_messages prev
          where prev.conversation_id = m.conversation_id
            and prev.created_at < m.created_at
          order by prev.created_at desc
          limit 3
        ) q
      )
    )
    into result
    from public.direct_messages m
    where m.id = r.target_id;
  end if;

  return result;
end;
$$;

revoke all on function public.admin_report_target(uuid) from public, anon;
grant execute on function public.admin_report_target(uuid) to authenticated;

-- ═══════════════════════════════════════════════════════════════════════════
-- L'argent : ce qui empeche de supprimer son compte
-- ═══════════════════════════════════════════════════════════════════════════
--
-- Les trois gardes vivent dans des fonctions a part, appelees a la fois par
-- l'apercu (ce que l'ecran annonce) et par la suppression (ce qui est
-- applique). Une seule definition : l'ecran ne peut pas promettre une
-- suppression que le serveur refusera ensuite.

-- Organisateur : billets payants vendus sur un evenement a venir.
-- (Inchange depuis 20260726.)
create or replace function public.deletion_paid_sales(p_user uuid)
returns bigint
language sql
stable
security definer
set search_path = public
as $$
  select count(distinct e.id)
  from public.events e
  join public.ticket_types tt on tt.event_id = e.id
  where e.created_by = p_user
    and coalesce(e.status, 'published') <> 'cancelled'
    and coalesce(e.end_date, e.start_date) >= now()
    and coalesce(tt.price, 0) > 0
    and coalesce(tt.quantity_sold, 0) > 0;
$$;

-- Organisateur : de l'argent gagne qui ne lui a pas encore ete verse.
--
-- `pending` ne compte pas comme verse : la ligne est posee AVANT l'appel a
-- Stripe, le virement peut encore echouer. `failed` non plus : rien n'est
-- parti. Seul `paid` solde l'evenement.
create or replace function public.deletion_pending_earnings(p_user uuid)
returns bigint
language sql
stable
security definer
set search_path = public
as $$
  select count(*)
  from public.events e
  join public.event_ledger() l on l.event_id = e.id
  where e.created_by = p_user
    and coalesce(e.status, 'published') <> 'cancelled'
    and l.gross - l.withheld - l.stripe_fee - l.platform_fee > 0
    and not exists (
      select 1 from public.event_payouts pay
      where pay.event_id = e.id and pay.status = 'paid'
    );
$$;

-- Acheteur : billet paye, encore valide, pour un evenement pas encore passe.
--
-- On ne filtre PAS sur le statut de l'evenement : un evenement annule dont le
-- remboursement a echoue garde des billets `valid`, et supprimer le compte a
-- ce moment-la ferait perdre a la personne de quoi reclamer son argent.
create or replace function public.deletion_paid_tickets(p_user uuid)
returns bigint
language sql
stable
security definer
set search_path = public
as $$
  select count(*)
  from public.tickets t
  join public.events e on e.id = t.event_id
  where t.user_id = p_user
    and t.status = 'valid'
    and coalesce(e.end_date, e.start_date) >= now()
    and public.ticket_paid_cents(t.id) > 0;
$$;

revoke all on function public.deletion_paid_sales(uuid)       from public, anon, authenticated;
revoke all on function public.deletion_pending_earnings(uuid) from public, anon, authenticated;
revoke all on function public.deletion_paid_tickets(uuid)     from public, anon, authenticated;

-- ── L'apercu ────────────────────────────────────────────────────────────────
--
-- Memes cles qu'avant, plus deux nouvelles. `upcoming_tickets` ne compte plus
-- que les billets valides : les annules ne sont plus « annules a nouveau ».

create or replace function public.account_deletion_preview()
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then
    raise exception 'not_authenticated';
  end if;

  return json_build_object(
    'upcoming_tickets', (
      select count(*) from public.tickets t
      join public.events e on e.id = t.event_id
      where t.user_id = v_user
        and t.status = 'valid'
        and coalesce(e.end_date, e.start_date) >= now()
    ),
    'events_to_cancel', (
      select count(*) from public.events e
      where e.created_by = v_user
        and coalesce(e.end_date, e.start_date) >= now()
        and exists (select 1 from public.tickets t where t.event_id = e.id)
    ),
    'events_to_delete', (
      select count(*) from public.events e
      where e.created_by = v_user
        and coalesce(e.end_date, e.start_date) >= now()
        and not exists (select 1 from public.tickets t where t.event_id = e.id)
    ),
    'blocked_paid_sales',       public.deletion_paid_sales(v_user),
    'blocked_pending_earnings', public.deletion_pending_earnings(v_user),
    'blocked_paid_tickets',     public.deletion_paid_tickets(v_user)
  );
end;
$$;

revoke all on function public.account_deletion_preview() from public, anon;
grant execute on function public.account_deletion_preview() to authenticated;

-- ── La suppression ──────────────────────────────────────────────────────────

create or replace function public.delete_my_account_data()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then
    raise exception 'not_authenticated';
  end if;

  -- Les gardes, dans l'ordre ou l'ecran les annonce.
  if public.deletion_paid_sales(v_user) > 0 then
    raise exception 'has_paid_sales';
  end if;
  if public.deletion_pending_earnings(v_user) > 0 then
    raise exception 'has_pending_earnings';
  end if;
  if public.deletion_paid_tickets(v_user) > 0 then
    raise exception 'has_paid_tickets';
  end if;

  -- 1. Billets VALIDES sur des evenements a venir — forcement gratuits,
  --    grace a la garde ci-dessus : la place retourne au stock, le billet
  --    disparait. Un billet deja annule a deja rendu sa place ; il est
  --    seulement detache a l'etape 2, comme les billets passes.
  update public.ticket_types tt
     set quantity_sold = greatest(coalesce(tt.quantity_sold, 0) - sub.n, 0)
  from (
    select t.ticket_type_id, count(*)::int as n
    from public.tickets t
    join public.events e on e.id = t.event_id
    where t.user_id = v_user
      and t.status = 'valid'
      and coalesce(e.end_date, e.start_date) >= now()
    group by t.ticket_type_id
  ) sub
  where tt.id = sub.ticket_type_id;

  delete from public.tickets t
  using public.events e
  where t.event_id = e.id
    and t.user_id = v_user
    and t.status = 'valid'
    and coalesce(e.end_date, e.start_date) >= now();

  -- 2. Tous les autres billets : ligne conservee, detachee du profil.
  update public.tickets set user_id = null where user_id = v_user;

  -- 2 bis. Trace d'un transfert emis par cet utilisateur.
  update public.tickets
     set transferred_from = null
   where transferred_from = v_user;

  -- 3. Evenements A VENIR avec participants : annulation (trigger = notifs).
  update public.events
     set status = 'cancelled', created_by = null
   where created_by = v_user
     and coalesce(end_date, start_date) >= now()
     and exists (select 1 from public.tickets t where t.event_id = events.id);

  -- 4. Evenements A VENIR sans participant : suppression.
  delete from public.events
   where created_by = v_user
     and coalesce(end_date, start_date) >= now();

  -- 5. Evenements PASSES : anonymisation (« Organisateur supprime »).
  update public.events set created_by = null where created_by = v_user;

  -- 6. Profil. Les conversations, elles, sont traitees par les cles
  --    etrangeres lors de la suppression du compte auth (voir plus haut).
  delete from public.profiles where id = v_user;
end;
$$;

revoke all on function public.delete_my_account_data() from public, anon;
grant execute on function public.delete_my_account_data() to authenticated;
