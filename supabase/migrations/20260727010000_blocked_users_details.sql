-- =============================================================================
-- HAPPYN — Afficher QUI on a bloqué, sans ouvrir les profils
-- =============================================================================
-- L'écran « Utilisateurs bloqués » n'affichait qu'un identifiant, parce que la
-- RLS de `profiles` ne laisse lire que son propre profil.
--
-- Pourquoi on ne se contente PAS d'ajouter une policy « je peux lire le profil
-- des comptes que j'ai bloqués » : la RLS de Postgres agit au niveau de la
-- LIGNE, pas de la colonne. Autoriser le SELECT exposerait donc aussi l'email,
-- la date de naissance, la bio et la ville du compte bloqué — une fuite de
-- données personnelles pour rien.
--
-- On passe donc par une fonction SECURITY DEFINER qui ne renvoie QUE les
-- champs nécessaires à l'affichage (nom + avatar), et uniquement pour les
-- comptes que l'appelant a lui-même bloqués.
-- À exécuter dans le SQL Editor du dashboard Supabase.
-- =============================================================================

create or replace function public.blocked_users_details()
returns table (
  id         uuid,
  full_name  text,
  avatar_url text
)
language sql
security definer
stable
set search_path = public
as $$
  select p.id, p.full_name, p.avatar_url
  from public.blocked_users b
  join public.profiles p on p.id = b.blocked_id
  where b.blocker_id = auth.uid()
  order by b.created_at desc;
$$;

revoke all on function public.blocked_users_details() from public, anon;
grant execute on function public.blocked_users_details() to authenticated;
