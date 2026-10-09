-- Accepter une MISE À JOUR des documents légaux.
--
-- Bug trouvé le 2026-10-09 sur un vrai compte : après une nouvelle version
-- des conditions et de la confidentialité, l'écran ne présentait — à juste
-- titre — que ces deux documents, et n'envoyait donc que ces deux versions.
-- Mais `accept_legal_documents` exigeait TOUS les documents à accepter,
-- règles de la communauté comprises, déjà acceptées et inchangées. Elle
-- répondait `version_changed`, l'écran se rechargeait à l'identique : « J'accepte »
-- ne menait nulle part. La règle « tout ou rien » avait été écrite pour une
-- première acceptation, sans penser aux mises à jour.
--
-- Désormais seuls les documents ENCORE À ACCEPTER (version en vigueur jamais
-- acceptée) doivent figurer dans la demande, à la bonne version. Le reste de
-- la règle ne change pas : un document en attente absent, ou une version qui
-- ne correspond plus, refuse l'ensemble — on n'accepte que ce qu'on a vu.

create or replace function public.accept_legal_documents(p_versions jsonb, p_locale text default null)
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

  -- Les documents en attente pour CE compte : exigés, à la bonne version.
  for d in
    select l.slug, l.version from public.legal_documents l
    where l.requires_acceptance
      and not exists (
        select 1 from public.user_legal_acceptances a
        where a.user_id = v_user and a.slug = l.slug and a.version = l.version)
  loop
    if not (p_versions ? d.slug) then
      raise exception 'version_changed';
    end if;
    if p_versions ->> d.slug is distinct from d.version then
      raise exception 'version_changed';
    end if;
  end loop;

  insert into public.user_legal_acceptances (user_id, slug, version, accepted_at, locale)
  select v_user, l.slug, l.version, now(),
         case when exists (
                select 1 from public.legal_document_translations t
                where t.slug = l.slug and t.locale = p_locale and t.version = l.version)
              then p_locale else 'en' end
  from public.legal_documents l
  where l.requires_acceptance
    and p_versions ->> l.slug = l.version
  on conflict (user_id, slug, version) do nothing;
end;
$$;

revoke all on function public.accept_legal_documents(jsonb, text) from public, anon;
grant execute on function public.accept_legal_documents(jsonb, text) to authenticated, service_role;
