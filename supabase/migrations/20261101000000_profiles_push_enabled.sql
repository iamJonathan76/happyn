-- Préférence de notifications poussées, par personne.
--
-- Jusqu'ici, couper les notifications n'était possible que dans les Réglages
-- du téléphone. On veut le proposer DANS l'app, et que le choix suive la
-- personne d'un appareil à l'autre — donc en base, pas en local.
--
-- Côté envoi, `send-push` lit ce drapeau et n'envoie rien si la personne a
-- coupé. Le jeton de l'appareil reste enregistré : on ne le supprime pas, on
-- respecte juste la préférence. Rallumer, c'est remettre le drapeau à vrai.
--
-- Pas de nouvelle politique : la règle « update own profile » laisse déjà
-- chacun modifier sa propre ligne, et les gardes existants ne visent que
-- is_admin, suspended_at, date_of_birth et username.
alter table public.profiles
  add column if not exists push_enabled boolean not null default true;
