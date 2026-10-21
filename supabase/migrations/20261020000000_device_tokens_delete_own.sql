-- device_tokens : fermer la suppression de masse.
--
-- La policy de DELETE etait `using (true)`, ouverte a tout compte authentifie.
-- Le commentaire de `20260902010000_device_tokens` assurait qu'« on ne peut
-- supprimer QUE par jeton exact » — mais rien dans la base ne l'imposait. Le
-- client ecrit lui-meme son WHERE : `delete from device_tokens` sans aucun
-- filtre ne lit aucune colonne, la policy SELECT ne s'applique donc pas, et
-- using(true) laissait un seul compte vider toute la table. Les notifications
-- push coupees pour tout le monde en une requete, via la cle anon publique.
--
-- La suppression redevient strictement personnelle. Le cas legitime que
-- l'ouverture servait — un appareil qui passe d'un compte a un autre et dont la
-- ligne appartient encore au precedent — est repris par une fonction serveur
-- (`register_device_token`), seule habilitee a retirer la ligne d'autrui, et
-- seulement en la remplacant par celle de l'appelant. Le client ne touche plus
-- jamais la ligne d'un autre.

drop policy if exists "delete by exact token" on public.device_tokens;

create policy "own tokens delete"
  on public.device_tokens for delete
  to authenticated
  using (auth.uid() = user_id);

-- Reattribution d'un appareil, cote serveur. Retire la ligne attachee a ce
-- jeton (quel qu'en soit le proprietaire) puis la recree pour l'appelant, de
-- facon atomique. C'est le seul chemin par lequel la ligne d'un autre compte
-- disparait, et elle ne disparait que remplacee — jamais effacee en masse.
create or replace function public.register_device_token(
  p_token text, p_platform text
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if p_token is null or length(p_token) = 0 then
    raise exception 'invalid_token';
  end if;
  if p_platform not in ('android', 'ios') then
    raise exception 'invalid_platform';
  end if;

  delete from public.device_tokens where token = p_token;
  insert into public.device_tokens (token, user_id, platform, created_at, updated_at)
  values (p_token, auth.uid(), p_platform, now(), now());
end $$;

revoke all on function public.register_device_token(text, text) from public;
grant execute on function public.register_device_token(text, text) to authenticated;
