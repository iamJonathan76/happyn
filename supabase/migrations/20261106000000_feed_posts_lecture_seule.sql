-- feed_posts : vue de LECTURE seule, retirer les droits d'ecriture inertes.
--
-- Prevention, pas colmatage : contrairement a public_profiles, feed_posts
-- joint posts/events/profiles et porte des agregats, donc Postgres la refuse en
-- ecriture (non auto-modifiable). Les droits INSERT/UPDATE/DELETE/TRUNCATE que
-- Supabase y attache par defaut pour anon et authenticated sont donc inoperants
-- AUJOURD'HUI.
--
-- Mais c'est un piege latent : si quelqu'un simplifie un jour la vue en une
-- seule table, ces droits redeviendraient actifs et ecriraient dans la base en
-- contournant la RLS (le scenario public_profiles). On ferme la surface tant
-- qu'on y pense. La vue ne doit qu'etre lue ; seul authenticated garde SELECT
-- (anon l'avait deja perdu au durcissement precedent).

revoke insert, update, delete, truncate, references, trigger
  on public.feed_posts from anon;
revoke insert, update, delete, truncate, references, trigger
  on public.feed_posts from authenticated;
revoke all on public.feed_posts from public, service_role;

grant select on public.feed_posts to authenticated;
