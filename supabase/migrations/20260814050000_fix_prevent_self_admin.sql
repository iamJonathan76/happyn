-- Correctif : le garde-fou de `is_admin` bloquait aussi l'administrateur.
--
-- La version précédente n'autorisait que le rôle `service_role`. Or l'éditeur
-- SQL du tableau de bord s'exécute en `postgres` : accorder le premier droit de
-- modération devenait donc impossible, et personne ne pouvait plus rien
-- accorder du tout.
--
-- On renverse la règle : au lieu d'autoriser un rôle précis, on REFUSE les
-- rôles par lesquels passe un client (`authenticated`, `anon`). C'est plus sûr
-- dans le bon sens — un nouveau rôle d'administration créé demain passera, un
-- client ne passera jamais, et c'est bien le client qui est la menace ici.
--
-- Rappel de ce que ça protège : la policy d'UPDATE de `profiles` laisse chacun
-- modifier sa propre ligne. Sans ce trigger, n'importe qui se nommerait
-- administrateur en une requête.

create or replace function public.prevent_self_admin()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.is_admin is distinct from old.is_admin
     and current_setting('role', true) in ('authenticated', 'anon') then
    raise exception 'is_admin ne peut etre accorde que depuis le tableau de bord';
  end if;
  return new;
end;
$$;
