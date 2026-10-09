-- Le consentement aux conditions, enregistré pour de vrai.
--
-- Les conditions disent « en créant un compte, vous acceptez… », et la table
-- `user_legal_acceptances` existait — mais l'app n'y écrivait jamais. Aucune
-- preuve de qui avait accepté quoi, ni de quelle version ; et la promesse de
-- re-présenter une nouvelle version restait sans moyen.
--
-- ── Ce qui change ───────────────────────────────────────────────────────────
--
--   1. Trois documents exigent une acceptation explicite : les conditions
--      d'utilisation, la politique de confidentialité, les règles de la
--      communauté — ceux que les conditions déclarent acceptés ensemble.
--
--   2. Une acceptation ne s'écrit plus directement. La règle d'insertion
--      laissait l'app enregistrer N'IMPORTE QUELLE version, y compris une qui
--      n'existe pas, et `accepted_at` pouvait être fourni par le client. Une
--      preuve que l'intéressé peut fabriquer ne prouve rien. Désormais seule
--      `accept_legal_documents()` écrit, avec l'heure du serveur.
--
--   3. On n'accepte que ce qu'on a vu. L'app transmet les versions qu'elle a
--      affichées ; si un document a changé entre l'affichage et le clic, le
--      serveur refuse (`version_changed`) et l'app re-présente. Sans ça, un
--      clic sur la version 1.1 enregistrerait l'acceptation d'une 2.0 jamais lue.

update public.legal_documents
set requires_acceptance = true
where slug in ('terms', 'privacy', 'community');

-- ═══════════════════════════════════════════════════════════════════════════
-- Ce qui reste à accepter
-- ═══════════════════════════════════════════════════════════════════════════

-- `previously_accepted` : la personne avait accepté une version antérieure.
-- L'écran dit alors « nos conditions ont changé », et non « bienvenue ».
create or replace function public.pending_legal_documents()
returns table(slug text, title text, version text, previously_accepted boolean)
language sql stable security definer
set search_path = public
as $$
  select d.slug, d.title, d.version,
         exists (select 1 from public.user_legal_acceptances a
                 where a.user_id = auth.uid() and a.slug = d.slug)
  from public.legal_documents d
  where d.requires_acceptance
    and auth.uid() is not null
    and not exists (
      select 1 from public.user_legal_acceptances a
      where a.user_id = auth.uid()
        and a.slug = d.slug
        and a.version = d.version
    )
  order by d.sort_order;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- Accepter
-- ═══════════════════════════════════════════════════════════════════════════

-- `p_versions` : {"terms": "Version 1.1", …} — ce que l'écran a montré.
-- Tout ou rien : si un seul document a changé, rien n'est enregistré, pour ne
-- pas laisser une acceptation à moitié faite.
create or replace function public.accept_legal_documents(p_versions jsonb)
returns void
language plpgsql security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  d      record;
begin
  if v_user is null then
    raise exception 'not_authenticated';
  end if;

  for d in
    select l.slug, l.version from public.legal_documents l
    where l.requires_acceptance
  loop
    -- Un document exigé mais absent de la demande : l'écran ne l'a pas montré.
    if not (p_versions ? d.slug) then
      raise exception 'version_changed';
    end if;
    if p_versions ->> d.slug is distinct from d.version then
      raise exception 'version_changed';
    end if;
  end loop;

  insert into public.user_legal_acceptances (user_id, slug, version, accepted_at)
  select v_user, l.slug, l.version, now()
  from public.legal_documents l
  where l.requires_acceptance
  on conflict (user_id, slug, version) do nothing;
end;
$$;

revoke all on function public.pending_legal_documents()      from public, anon;
revoke all on function public.accept_legal_documents(jsonb)  from public, anon;
grant execute on function public.pending_legal_documents()     to authenticated, service_role;
grant execute on function public.accept_legal_documents(jsonb) to authenticated, service_role;

-- ═══════════════════════════════════════════════════════════════════════════
-- Plus d'écriture directe
-- ═══════════════════════════════════════════════════════════════════════════

drop policy if exists "own acceptances insert" on public.user_legal_acceptances;
revoke insert, update, delete, truncate on public.user_legal_acceptances
  from anon, authenticated;
-- Lire ses propres acceptations reste permis (règle « own acceptances select »).
revoke all on public.user_legal_acceptances from anon;
