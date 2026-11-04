-- Menage advisor : droit d'execution inutile + index redondant.

-- ── 1. register_device_token : reserve aux comptes connectes ────────────────
-- La fonction rejette deja anon (auth.uid() is null -> not_authenticated), donc
-- aucun risque reel ; mais anon n'a aucune raison de l'appeler. On retire le
-- droit, l'advisor cesse de la signaler, et l'intention devient explicite.
revoke execute on function public.register_device_token(text, text) from public, anon;

-- ── 2. categories : supprimer l'index unique redondant ──────────────────────
-- Deux index uniques couvrent categories(name) : categories_name_key (cree par
-- la contrainte UNIQUE) et categories_name_unique (index autonome). Ils font le
-- meme travail ; le second est du poids mort (ecritures ralenties, espace). On
-- garde celui de la contrainte et on jette l'autre ; l'unicite reste garantie.
drop index if exists public.categories_name_unique;
