-- Politique de confidentialité : déclarer la liste d'attente du site.
--
-- Le site recueille désormais des adresses courriel (« Être prévenu »). Le
-- lien sous le formulaire mène à cette politique : elle doit dire ce qu'on
-- collecte, pourquoi, combien de temps, et où c'est stocké — avant la première
-- inscription, pas après.
--
-- Ce n'est PAS le texte juridique complet (docs/LEGAL-DRAFT.md), qui attend
-- la relecture d'un avocat. C'est un ajout ciblé à la version en ligne, pour
-- que ce qu'elle dit reste vrai.
--
-- Rejouable sans risque : la section n'est ajoutée que si elle n'y est pas
-- déjà. Le contenu est du markdown léger rendu par textContent — pas de
-- **gras** : les astérisques s'afficheraient tels quels.
--
-- Passer en 1.2 ne redemande rien aux utilisateurs : l'app ne relit pas
-- `user_legal_acceptances` à l'ouverture.

begin;

update public.legal_documents
set
  content = content || E'\n\n' ||
$policy$## Website launch list

If you join the launch list on happynevents.com, we collect your email address, the language you used, and the exact consent statement you agreed to, along with the date. We keep the consent statement as proof that you asked to hear from us, as Canada's anti-spam law requires.

We use your email only to tell you about HAPPYN's launch and related news. We do not sell it or share it with anyone to market to you.

These submissions are stored by our website host, Netlify, in the United States. They may be subject to the laws of that country, including lawful access by its authorities.

We keep your email until you unsubscribe or ask us to delete it. You can unsubscribe at any time with the link included in every email we send, or by writing to contact@happynevents.com.$policy$,
  version = 'Version 1.2',
  effective_date = current_date,
  updated_at = now()
where slug = 'privacy'
  and position('## Website launch list' in content) = 0;

commit;

-- Vérification : doit renvoyer une ligne, en Version 1.2, avec la section.
select slug, version, effective_date,
       position('## Website launch list' in content) > 0 as has_launch_list
from public.legal_documents
where slug = 'privacy';
