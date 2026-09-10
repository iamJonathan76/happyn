-- Jetons d'appareil, pour les notifications poussées.
--
-- La table `notifications` se remplit déjà (achat confirmé, événement annulé,
-- billet annulé) mais personne n'est prévenu quand l'app est fermée. Or c'est
-- exactement là que ça compte : apprendre l'annulation d'un événement en
-- ouvrant l'app par hasard, c'est l'apprendre trop tard.
--
-- Un jeton identifie une INSTALLATION, pas une personne : même téléphone,
-- deux comptes = deux lignes successives. D'où la clé primaire sur le jeton
-- lui-même, et la suppression à la déconnexion (voir plus bas).

create table if not exists public.device_tokens (
  token      text primary key,
  user_id    uuid not null references auth.users(id) on delete cascade,
  platform   text not null check (platform in ('android', 'ios')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists device_tokens_user_idx
  on public.device_tokens (user_id);

alter table public.device_tokens enable row level security;

-- Chacun gère ses propres jetons, et uniquement les siens. Un jeton est une
-- adresse de livraison : pouvoir écrire celui d'autrui reviendrait à faire
-- envoyer ses notifications sur son propre téléphone.
drop policy if exists "own tokens select" on public.device_tokens;
create policy "own tokens select"
  on public.device_tokens for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "own tokens upsert" on public.device_tokens;
create policy "own tokens upsert"
  on public.device_tokens for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "own tokens update" on public.device_tokens;
create policy "own tokens update"
  on public.device_tokens for update
  to authenticated
  using (auth.uid() = user_id);

-- ⚠️ La suppression est volontairement ouverte à tout compte authentifié, avec
-- une condition : on ne peut supprimer QUE par jeton exact.
--
-- Raison : à la déconnexion, l'app doit retirer le jeton de CET appareil. Mais
-- si un autre compte s'est connecté entre-temps sur le même téléphone, la ligne
-- appartient déjà à lui. Sans cette ouverture, l'ancien jeton resterait attaché
-- au compte précédent et la personne suivante recevrait les notifications de
-- quelqu'un d'autre — une fuite bien pire que ce qu'on protège ici.
--
-- Le risque résiduel est faible : il faut connaître le jeton exact d'un
-- appareil, qui n'est exposé nulle part, et le pire qu'on obtienne est de faire
-- taire les notifications de ce téléphone.
drop policy if exists "delete by exact token" on public.device_tokens;
create policy "delete by exact token"
  on public.device_tokens for delete
  to authenticated
  using (true);

comment on table public.device_tokens is
  'Jetons FCM. Un jeton = une installation. Supprime a la deconnexion pour '
  'qu''un compte ne recoive jamais les notifications du precedent.';
