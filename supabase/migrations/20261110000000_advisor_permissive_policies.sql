-- Advisor « Multiple Permissive Policies » : sur `categories` et `profiles`, des
-- policies permissives faisaient double emploi pour un même couple (rôle,
-- commande). Postgres évalue TOUTES les policies permissives d'un couple (un OR
-- logique) : les doublons ne changent pas l'accès, mais l'advisor les signale
-- (coût d'évaluation), six fois sur categories, trois sur profiles.
--
-- On garde une seule policy par couple. L'accès reste identique :
--   • anon et comptes lisent toujours les catégories ;
--   • un compte ne lit/écrit toujours que SON profil.
--
-- Rien n'est recréé : on retire simplement les doublons. Les policies
-- conservées sont déjà optimisées InitPlan (migration 20261107000000).

begin;

-- ── categories ──────────────────────────────────────────────────────────────
-- « Public can read categories » et « categories are public » sont deux fois la
-- même chose : SELECT, to public, using (true). On en garde une.
drop policy if exists "categories are public" on public.categories;

-- ── profiles ────────────────────────────────────────────────────────────────
-- Les policies « to public » doublonnent les « to authenticated » de même
-- condition : `public` englobe `authenticated`, et un visiteur anonyme est de
-- toute façon exclu par `auth.uid() = id` (uid nul). On garde les versions
-- câblées sur `authenticated` — l'intention réelle, et c'est là que la
-- condition peut matcher.
drop policy if exists "Users can view own profile"   on public.profiles;
drop policy if exists "Users can insert own profile" on public.profiles;
drop policy if exists "Users can update own profile" on public.profiles;

commit;
