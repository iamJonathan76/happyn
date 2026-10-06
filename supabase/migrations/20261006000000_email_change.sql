-- Changer d'adresse e-mail, sans que `profiles.email` reste en arriere.
--
-- L'app peut desormais demander un changement d'adresse. Supabase gere la
-- partie delicate : l'adresse de `auth.users` ne bouge qu'une fois les liens
-- de confirmation cliques (les deux, quand `secure_email_change` est actif).
-- Rien a ecrire ici pour ca.
--
-- Le probleme est ailleurs. `public.profiles` porte sa propre colonne
-- `email`, recopiee depuis `auth.users` a l'inscription et a chaque
-- enregistrement du profil. Tant que l'adresse ne changeait pas, les deux
-- restaient d'accord. Elles ne le resteront plus.
--
-- Et cette colonne n'est pas decorative : `transfer_ticket()` resout le
-- destinataire avec
--
--     select id from public.profiles where lower(email) = <adresse> limit 1
--
-- Si Alice passe de `alice@a.com` a `alice@b.com` et que `profiles` garde
-- l'ancienne, deux choses arrivent, toutes les deux silencieuses : un billet
-- envoye a `alice@b.com` est refuse (`recipient_not_found`) alors que c'est
-- bien son adresse, et un billet envoye a `alice@a.com` lui arrive encore
-- alors que cette adresse peut avoir ete reprise par quelqu'un d'autre. Le
-- second cas donne un billet a un inconnu — sans erreur, sans trace.
--
-- On raccroche donc `profiles.email` a sa source. Pas depuis l'app : le
-- client ne sait pas quand la confirmation aboutit (elle se termine dans un
-- navigateur, peut-etre sur un autre appareil, peut-etre des jours plus
-- tard), et une app qui ne se rouvre jamais ne synchroniserait jamais. La
-- base, elle, voit le moment exact.

-- ── La synchronisation ──────────────────────────────────────────────────────
-- `auth.users.email` ne change qu'a la confirmation : ce declencheur se
-- reveille donc pile au bon moment, et jamais sur une adresse en attente.
create or replace function public.sync_profile_email()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.profiles
     set email = new.email
   where id = new.id;
  return new;
exception
  -- Ne jamais faire echouer l'operation d'authentification. Une erreur ici
  -- (profil absent, contrainte inattendue) doit laisser le changement
  -- d'adresse aboutir : l'utilisateur a clique ses deux liens, lui refuser
  -- le changement parce que notre copie resiste serait absurde. On trace et
  -- on laisse passer ; la prochaine sauvegarde du profil recopiera l'adresse.
  when others then
    raise warning 'sync_profile_email(%): %', new.id, sqlerrm;
    return new;
end;
$$;

revoke all on function public.sync_profile_email() from public, anon, authenticated;

drop trigger if exists sync_profile_email on auth.users;
create trigger sync_profile_email
  after update of email on auth.users
  for each row
  -- `new.email is not null` : on ne recopie jamais un vide par-dessus une
  -- adresse valide. `profiles.email` date d'avant les migrations et peut
  -- porter un `not null` ; une copie a vide echouerait, ou effacerait la seule
  -- adresse que `transfer_ticket()` sait lire.
  when (new.email is distinct from old.email and new.email is not null)
  execute function public.sync_profile_email();

-- ── Rattrapage ──────────────────────────────────────────────────────────────
-- Les adresses deja desaccordees avant ce declencheur. Normalement aucune —
-- l'app ne permettait pas d'en changer — mais une modification depuis le
-- tableau de bord Supabase a le meme effet, et une ligne fausse ici suffit a
-- egarer un billet. Idempotent : ne touche que ce qui differe.
update public.profiles p
   set email = u.email
  from auth.users u
 where u.id = p.id
   and u.email is not null
   and p.email is distinct from u.email;
