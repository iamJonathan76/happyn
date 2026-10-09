-- Les textes légaux en français.
--
-- Pourquoi une table à part plutôt qu'une colonne `locale` dans
-- `legal_documents` : le site en ligne lit TOUTES les lignes de
-- `legal_documents` sans regarder la langue, et il ne peut pas être redéployé
-- avant le 20 octobre (crédits Netlify épuisés). Deux lignes par document
-- l'auraient fait tout afficher en double. Ici, la table d'origine ne change
-- pas ; le site lira les traductions une fois redéployé.
--
-- ── La règle ───────────────────────────────────────────────────────────────
-- `legal_documents` reste la référence, en anglais, et seule à porter le
-- numéro de version. Une traduction ne s'affiche que si elle porte le MÊME
-- numéro : sinon, l'app et le site retombent sur l'anglais. Publier une
-- nouvelle version anglaise sans sa traduction ne montre donc jamais un texte
-- français périmé — il disparaît jusqu'à ce qu'on le mette à jour.
--
-- L'acceptation enregistre désormais la langue lue : un consentement se
-- prouve sur le texte exact, et il y en a maintenant deux.

create table if not exists public.legal_document_translations (
  slug       text not null references public.legal_documents(slug) on delete cascade,
  locale     text not null check (locale in ('fr')),
  title      text not null,
  content    text not null,
  version    text not null,
  updated_at timestamptz not null default now(),
  primary key (slug, locale)
);

alter table public.legal_document_translations enable row level security;

drop policy if exists "legal translations readable by all" on public.legal_document_translations;
create policy "legal translations readable by all" on public.legal_document_translations
  as permissive for select to anon, authenticated using (true);

revoke all on public.legal_document_translations from public, anon, authenticated;
grant select on public.legal_document_translations to anon, authenticated;

alter table public.user_legal_acceptances
  add column if not exists locale text;
-- Les acceptations déjà données l'ont été sur le seul texte qui existait.
update public.user_legal_acceptances set locale = 'en' where locale is null;

-- ═══════════════════════════════════════════════════════════════════════════
-- Ce qui reste à accepter, dans la langue demandée
-- ═══════════════════════════════════════════════════════════════════════════
-- Les signatures changent (un paramètre de langue, facultatif) : on retire les
-- anciennes pour qu'un appel sans argument n'en trouve qu'une.

drop function if exists public.pending_legal_documents();
drop function if exists public.accept_legal_documents(jsonb);

create or replace function public.pending_legal_documents(p_locale text default null)
returns table(slug text, title text, version text, previously_accepted boolean)
language sql stable security definer
set search_path = public
as $$
  select d.slug,
         coalesce(t.title, d.title),
         d.version,
         exists (select 1 from public.user_legal_acceptances a
                 where a.user_id = auth.uid() and a.slug = d.slug)
  from public.legal_documents d
  left join public.legal_document_translations t
         on t.slug = d.slug and t.locale = p_locale and t.version = d.version
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

-- `p_locale` : la langue de l'écran. Elle n'est enregistrée que si une
-- traduction de CETTE version existe — sinon la personne a lu l'anglais.
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

  for d in
    select l.slug, l.version from public.legal_documents l
    where l.requires_acceptance
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
  on conflict (user_id, slug, version) do nothing;
end;
$$;

revoke all on function public.pending_legal_documents(text)       from public, anon;
revoke all on function public.accept_legal_documents(jsonb, text) from public, anon;
grant execute on function public.pending_legal_documents(text)      to authenticated, service_role;
grant execute on function public.accept_legal_documents(jsonb, text) to authenticated, service_role;
