-- Advisor « Public Bucket Allows Listing ».
--
-- avatars, events et posts sont des buckets PUBLICS : leurs images se servent
-- par URL publique (getPublicUrl → /object/public/...), un chemin qui ne passe
-- PAS par la RLS. Mais leurs policies de lecture laissaient aussi n'importe qui,
-- non connecté, ENUMÉRER tout le contenu — lister les URLs de tous les avatars,
-- de toutes les images d'événements et de publications.
--
-- L'app ne liste jamais ces buckets (elle connaît l'URL de chaque image, posée
-- en base) et exige une connexion pour tout. On restreint donc la lecture — qui
-- est ce qui autorise la LISTE — aux comptes connectés. L'URL publique continue
-- de servir chaque image à tout le monde (comportement des buckets publics,
-- indépendant de la RLS) ; seule l'énumération anonyme disparaît.

alter policy "avatars are public"       on storage.objects to authenticated;
alter policy "events images are public" on storage.objects to authenticated;
alter policy "post images are public"   on storage.objects to authenticated;
