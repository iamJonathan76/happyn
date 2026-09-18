-- Identifiant unique, recherche de personnes, listes d'abonnes.
--
-- Trois manques qui n'en font qu'un. On avait construit un social complet —
-- suivre, suivi mutuel, filtre « mes connexions », presence visible entre
-- connexions — et aucun moyen de trouver quelqu'un. Le « @handle » affiche
-- n'existait pas en base : sur son propre profil il etait tire de l'e-mail,
-- chez les autres du nom colle en minuscules. On ne se voyait donc pas comme
-- les autres nous voyaient, et deux « Jonathan K. » etaient indiscernables.

-- ── La colonne ──────────────────────────────────────────────────────────────
-- Stocke en minuscules : « Jonathan » et « jonathan » sont le meme
-- identifiant. 3 a 20 caracteres, lettres, chiffres, point et tiret bas ; pas
-- de point en bord ni de double point, qui servent a imiter un autre compte
-- (« jon.athan » contre « jonathan »).
alter table public.profiles add column if not exists username text;

alter table public.profiles drop constraint if exists username_format;
alter table public.profiles add constraint username_format check (
  username is null or (
    username = lower(username)
    and username ~ '^[a-z0-9._]{3,20}$'
    and username !~ '^\.|\.$|\.\.'
  )
);

create unique index if not exists profiles_username_key
  on public.profiles (username);

-- ── Noms reserves ───────────────────────────────────────────────────────────
-- Ce qu'un compte ordinaire ne doit pas pouvoir porter, parce qu'on le
-- prendrait pour HAPPYN lui-meme.
create or replace function public.is_reserved_username(p text)
returns boolean
language sql
immutable
as $$
  select p in (
    'admin', 'administrator', 'happyn', 'happynevents', 'support', 'help',
    'contact', 'moderator', 'moderation', 'mod', 'staff', 'team', 'official',
    'security', 'root', 'system', 'settings', 'me', 'null', 'undefined'
  ) or p like 'happyn%';
$$;

-- ── Generation ──────────────────────────────────────────────────────────────
-- Chaque profil a un identifiant, toujours : ceux qui existent deja, ceux qui
-- passent l'onboarding sans le remplir. On le tire du NOM, jamais de
-- l'e-mail — le nom est public, l'e-mail ne l'est pas, et un identifiant
-- tire de l'adresse la publierait a moitie.
--
-- SECURITY DEFINER, et ce n'est pas un detail : la RLS de `profiles` ne laisse
-- lire que sa propre ligne. Executee avec les droits de l'utilisateur, la
-- verification d'unicite ne verrait AUCUN autre identifiant, et attribuerait
-- un nom deja pris — l'insertion echouerait alors sur l'index unique.
create or replace function public.generate_username(p_name text)
returns text
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  base text;
  candidate text;
  tries int := 0;
begin
  base := lower(coalesce(p_name, ''));
  base := translate(base,
    'àâäáãåçéèêëíìîïñóòôöõúùûüýÿœæ',
    'aaaaaaceeeeiiiinooooouuuuyyoa');
  base := regexp_replace(base, '[^a-z0-9]+', '', 'g');
  base := left(base, 15);
  if length(base) < 3 or public.is_reserved_username(base) then
    base := 'user';
  end if;

  candidate := base;
  loop
    exit when not exists (
      select 1 from public.profiles where username = candidate
    ) and not public.is_reserved_username(candidate)
      and length(candidate) >= 3;
    tries := tries + 1;
    -- Quatre chiffres au hasard plutot qu'un compteur : un compteur
    -- revelerait combien de « jonathan » sont inscrits.
    candidate := base || lpad((floor(random() * 10000))::int::text, 4, '0');
    if tries > 50 then
      candidate := base || substr(md5(random()::text), 1, 6);
    end if;
  end loop;
  return candidate;
end;
$$;

revoke all on function public.generate_username(text) from public, anon;
grant execute on function public.generate_username(text) to authenticated;

-- ── Garde-fou a l'ecriture ──────────────────────────────────────────────────
-- La base complete un identifiant manquant et refuse un nom reserve. Ce n'est
-- pas l'app qui decide : elle pourrait etre contournee avec la cle anon.
create or replace function public.profiles_username_guard()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.username is not null then
    new.username := lower(trim(new.username));
  end if;

  if new.username is null or new.username = '' then
    new.username := public.generate_username(new.full_name);
  elsif (tg_op = 'INSERT' or new.username is distinct from old.username)
        and public.is_reserved_username(new.username) then
    raise exception 'username_reserved' using errcode = '23514';
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_username_guard on public.profiles;
create trigger profiles_username_guard
  before insert or update on public.profiles
  for each row execute function public.profiles_username_guard();

-- Profils existants : un par un, pour que chaque generation voie les
-- identifiants deja attribues. Une seule instruction UPDATE ne les verrait
-- pas, et deux « jonathan » recevraient le meme.
do $$
declare r record;
begin
  for r in select id, full_name from public.profiles where username is null
  loop
    update public.profiles
      set username = public.generate_username(r.full_name)
      where id = r.id;
  end loop;
end;
$$;

-- ── Disponibilite, pendant la saisie ────────────────────────────────────────
-- Un statut plutot qu'un booleen : « deja pris » et « format invalide » ne se
-- corrigent pas de la meme facon, et l'ecran doit pouvoir le dire.
-- Son propre identifiant actuel est « ok » : sinon ouvrir l'ecran d'edition
-- afficherait « deja pris » sur ce qu'on possede deja.
create or replace function public.username_status(p text)
returns text
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  u text := lower(trim(coalesce(p, '')));
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;
  if u !~ '^[a-z0-9._]{3,20}$' or u ~ '^\.|\.$|\.\.' then
    return 'invalid';
  end if;
  if public.is_reserved_username(u) then
    return 'reserved';
  end if;
  if exists (
    select 1 from public.profiles where username = u and id <> auth.uid()
  ) then
    return 'taken';
  end if;
  return 'ok';
end;
$$;

revoke all on function public.username_status(text) from public, anon;
grant execute on function public.username_status(text) to authenticated;

-- ── Profils publics ─────────────────────────────────────────────────────────
-- L'identifiant rejoint les champs publics. Ajoute en fin de liste :
-- `create or replace view` refuse de reordonner les colonnes existantes.
create or replace view public.public_profiles as
select
  p.id,
  p.full_name,
  p.avatar_url,
  p.bio,
  p.city,
  p.username
from public.profiles p;

grant select on public.public_profiles to anon, authenticated;

-- ── Recherche ───────────────────────────────────────────────────────────────
-- Par debut d'identifiant, ou par morceau de nom. Ce qu'elle ne renvoie
-- jamais : l'e-mail, les comptes suspendus, et les comptes bloques — dans
-- les DEUX sens. Quelqu'un qu'on a bloque ne doit pas pouvoir nous retrouver
-- en tapant notre nom ; c'est tout l'objet du blocage.
--
-- Les jokers LIKE saisis par l'utilisateur sont neutralises : taper « % »
-- ne doit pas lister toute la base.
create or replace function public.search_profiles(q text)
returns table (
  id         uuid,
  full_name  text,
  username   text,
  avatar_url text
)
language sql
stable
security definer
set search_path = public
as $$
  with needle as (
    select ltrim(lower(trim(coalesce(q, ''))), '@') as n
  ),
  esc as (
    select n,
           replace(replace(replace(n, '\', '\\'), '%', '\%'), '_', '\_') as e
    from needle
  )
  select p.id, p.full_name, p.username, p.avatar_url
  from public.profiles p, esc
  where auth.uid() is not null
    and length(esc.n) >= 2
    and p.suspended_at is null
    and (
      p.username like esc.e || '%'
      or lower(coalesce(p.full_name, '')) like '%' || esc.e || '%'
    )
    and not exists (
      select 1 from public.blocked_users b
      where (b.blocker_id = auth.uid() and b.blocked_id = p.id)
         or (b.blocker_id = p.id and b.blocked_id = auth.uid())
    )
  -- Identifiant exact d'abord, puis debut d'identifiant, puis le nom.
  order by (p.username = esc.n) desc,
           (p.username like esc.e || '%') desc,
           p.full_name asc
  limit 20;
$$;

revoke all on function public.search_profiles(text) from public, anon;
grant execute on function public.search_profiles(text) to authenticated;

-- ── Abonnes et abonnements ──────────────────────────────────────────────────
-- `follows` est deja lisible par tous (les compteurs en ont besoin) : cette
-- fonction ne revele rien de neuf. Elle existe pour joindre les profils en
-- une requete, et pour appliquer les memes exclusions que la recherche.
--
-- Consequence assumee : la liste peut compter moins de lignes que le
-- compteur, qui lui inclut les comptes bloques et suspendus. Mieux vaut un
-- ecart de un que montrer quelqu'un qu'on a bloque.
create or replace function public.profile_follows(p_user uuid, p_kind text)
returns table (
  id          uuid,
  full_name   text,
  username    text,
  avatar_url  text,
  followed_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select p.id, p.full_name, p.username, p.avatar_url, f.created_at
  from public.follows f
  join public.profiles p
    on p.id = case when p_kind = 'followers' then f.follower_id
                   else f.following_id end
  where auth.uid() is not null
    and p_kind in ('followers', 'following')
    and (case when p_kind = 'followers' then f.following_id
              else f.follower_id end) = p_user
    and p.suspended_at is null
    and not exists (
      select 1 from public.blocked_users b
      where (b.blocker_id = auth.uid() and b.blocked_id = p.id)
         or (b.blocker_id = p.id and b.blocked_id = auth.uid())
    )
  order by f.created_at desc
  limit 500;
$$;

revoke all on function public.profile_follows(uuid, text) from public, anon;
grant execute on function public.profile_follows(uuid, text) to authenticated;
