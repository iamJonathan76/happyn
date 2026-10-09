-- Les textes légaux en français, et deux corrections de la version anglaise.
--
-- Anglais, conditions et confidentialité en 1.2 :
--   * les conditions ne disent plus « en cochant une case » — l'écran de
--     consentement va changer de forme — mais « en confirmant », et précisent
--     que la langue lue est enregistrée ;
--   * la confidentialité ne dit plus « nous ne montrons pas de publicité »
--     mais « pas de publicité de tiers, pas de pistage ». Toujours vrai
--     aujourd'hui, et ça laisse la place aux événements sponsorisés
--     d'organisateurs sans obliger chacun à ré-accepter le jour où ils
--     arrivent. Une régie publicitaire, elle, demanderait une nouvelle version.
--
-- Français : les 13 documents, traduits de la version anglaise en vigueur,
-- avec le même numéro de version — sans quoi l'app et le site ne les
-- afficheraient pas (voir 20261009040000). Vouvoiement, l'usage pour un texte
-- contractuel ; vocabulaire juridique canadien et québécois (LPRPDE,
-- Commissariat à la protection de la vie privée, témoins).
--
-- PAS ENCORE RELUS PAR UN AVOCAT, ni en anglais ni en français.
--
-- Après application :
--   node web/tools/sync-legal-fallback.mjs

-- ═══════════════════════════════════════════════════════════════════════════
-- Anglais : conditions et confidentialité en 1.2
-- ═══════════════════════════════════════════════════════════════════════════

update public.legal_documents
set content = replace(content,
      $t$Before using HAPPYN, you are asked to read and explicitly accept these Terms, the Privacy Policy and the Community Guidelines, by ticking a box and confirming. We record which version of each document you accepted, and when.$t$,
      $t$Before using HAPPYN, you are asked to read and explicitly accept these Terms, the Privacy Policy and the Community Guidelines. We record which version of each document you accepted, in which language, and when.$t$),
    version = 'Version 1.2', effective_date = date '2026-10-09', updated_at = now()
where slug = 'terms';

update public.legal_documents
set content = replace(replace(content,
      $t$- We don't sell your information, show ads, or track you across other apps or websites.$t$,
      $t$- We don't sell your information. There are no third-party ads in HAPPYN, and we don't track you across other apps or websites.$t$),
      $t$- No advertising or tracking. There is no advertising network in HAPPYN, we don't build an advertising profile of you, and we don't sell personal information — to anyone.$t$,
      $t$- No third-party advertising or tracking. There is no advertising network in HAPPYN, we don't build an advertising profile of you, and we don't sell personal information — to anyone.$t$),
    version = 'Version 1.2', effective_date = date '2026-10-09', updated_at = now()
where slug = 'privacy';

do $$
begin
  if exists (select 1 from public.legal_documents
             where (slug = 'terms'   and position('in which language' in content) = 0)
                or (slug = 'privacy' and (position('no third-party ads' in content) = 0
                                          or position('No third-party advertising' in content) = 0))) then
    raise exception 'textes 1.2 : un passage attendu est introuvable, rien n''est publie';
  end if;
end $$;

-- ═══════════════════════════════════════════════════════════════════════════
-- Français
-- ═══════════════════════════════════════════════════════════════════════════

insert into public.legal_document_translations (slug, locale, title, content, version, updated_at)
values

-- ─────────────────────────────────────────────────────────────────────────────
('terms', 'fr', 'Conditions d''utilisation', $fr$
## En bref
- HAPPYN est une application et un site Web pour découvrir des événements, acheter des billets et partager ce qui s'y est passé.
- Il vous faut un compte, et vous devez avoir 18 ans ou plus.
- Ce sont les organisateurs qui tiennent leurs événements, pas HAPPYN. Quand vous achetez un billet, votre contrat pour l'événement est conclu avec l'organisateur ; HAPPYN s'occupe du paiement et du billet.
- Si un organisateur annule, vous êtes remboursé en entier, automatiquement. Vous pouvez aussi annuler vous-même un billet jusqu'à la date limite fixée par l'organisateur, moins de petits frais de service non remboursables.
- Votre billet porte un code QR qui change toutes les quelques minutes et ne sert qu'une fois. Une capture d'écran ne fait entrer personne.
- Ce que vous publiez vous appartient. Vous nous permettez de l'afficher dans HAPPYN, et cette permission prend fin quand vous le supprimez.
- Si vous enfreignez les règles, nous pouvons retirer du contenu ou suspendre votre compte. Vous conservez les billets que vous avez payés.

## 1. Qui nous sommes
HAPPYN (« HAPPYN », « nous ») exploite l'application mobile HAPPYN et le site Web happynevents.com. Les présentes conditions forment un contrat qui vous lie à HAPPYN.
Avant d'utiliser HAPPYN, vous êtes invité à lire et à accepter expressément les présentes conditions, la politique de confidentialité et les règles de la communauté. Nous enregistrons la version de chaque document que vous avez acceptée, dans quelle langue, et à quel moment.
Les autres politiques publiées avec ces conditions en font partie lorsqu'elles s'appliquent à ce que vous faites — par exemple, les normes pour les organisateurs quand vous créez un événement.

## 2. Âge minimum
Vous devez avoir au moins 18 ans — l'âge de la majorité en Ontario et au Québec — pour créer un compte et utiliser HAPPYN.
HAPPYN demande une date de naissance à chaque nouveau compte, quel que soit le mode de connexion, et elle ne peut plus être modifiée ensuite. Si la date indique que vous avez moins de 18 ans, le compte est supprimé immédiatement, avec les renseignements reçus lors de l'inscription.

## 3. Les mineurs aux événements
Une personne de moins de 18 ans ne peut pas avoir de compte HAPPYN. Pour un événement ouvert à tous les âges, un parent ou un tuteur légal peut acheter le billet avec son propre compte et accompagner la personne mineure ; il demeure responsable de ce billet.

## 4. Âge minimum d'un événement
Un organisateur peut fixer un âge minimum pour son événement : 18+ ou 21+, ou aucun (tous les âges). HAPPYN utilise votre date de naissance pour vous empêcher d'acheter un billet pour un événement auquel vous êtes trop jeune pour assister, et pour empêcher le transfert d'un billet à une personne trop jeune.
HAPPYN ne vérifie ni l'identité ni la date de naissance déclarée. C'est à l'organisateur de vérifier l'âge à l'entrée.

## 5. Votre compte
Vous pouvez créer un compte avec une adresse courriel et un mot de passe, ou avec votre compte Google.
- Gardez votre mot de passe pour vous. Vous êtes responsable de ce qui est fait au moyen de votre compte.
- Prévenez-nous immédiatement à contact@happynevents.com si vous pensez que quelqu'un d'autre y a accès.
- Une personne, un compte. Un compte ne peut être ni vendu, ni loué, ni partagé, ni cédé.
- Les renseignements que vous fournissez doivent être exacts — en particulier votre date de naissance.
- Votre nom d'utilisateur est public et unique. Si vous n'en choisissez pas, HAPPYN en crée un à partir de votre nom.

## 6. Ce qu'est HAPPYN — et ce qu'il n'est pas
HAPPYN est une plateforme. Les événements sont créés, décrits, tarifés et tenus par leurs organisateurs — pas par nous. Nous n'accueillons pas d'événements, nous ne vérifions pas l'exactitude de leur description et nous ne garantissons pas qu'ils auront lieu comme annoncé.
Quand vous achetez un billet, vous concluez un contrat avec l'organisateur pour l'événement. HAPPYN perçoit le paiement, émet le billet et remet l'argent à l'organisateur, moins nos frais (voir la politique de paiement).

## 7. Les billets
Les billets sont créés par nos serveurs, et seulement une fois le paiement confirmé (ou immédiatement, pour un événement gratuit). Aucune application ni aucune personne ne peut créer un billet autrement.
Chaque billet affiche un code QR signé cryptographiquement qui change toutes les cinq minutes. Une capture d'écran montre un code qui expire : il ne fera entrer personne. Un billet ne peut être lu qu'une fois ; une deuxième lecture est refusée. Seul l'organisateur de l'événement peut lire ses billets.

## 8. Transférer un billet
Vous pouvez donner un billet à un autre utilisateur de HAPPYN depuis l'application, si toutes ces conditions sont réunies :
- vous suivez la personne à qui vous le donnez ;
- le billet n'a été ni lu ni annulé ;
- l'événement n'a été ni annulé ni terminé ;
- la personne qui le reçoit a l'âge minimum de l'événement.

## 9. Après un transfert
Le transfert émet un nouveau code QR pour la personne qui reçoit le billet ; le vôtre cesse immédiatement de fonctionner. Elle en est avisée.
Un billet reçu par transfert ne peut pas être remboursé à son nouveau détenteur — un remboursement ne peut revenir qu'à la carte qui a payé.
HAPPYN ne prend pas en charge la revente, ne participe à aucun échange d'argent entre particuliers pour un billet et ne peut pas intervenir si un tel échange tourne mal.

## 10. Comportements interdits
Les règles de la communauté décrivent ces règles plus en détail. Il est interdit :
- de créer des événements frauduleux, trompeurs ou inexistants, ou de vendre des billets pour un événement que vous n'avez pas le droit de vendre ;
- de harceler, de menacer, de diffamer qui que ce soit ou de vous faire passer pour quelqu'un d'autre ;
- de publier du contenu que vous n'avez pas le droit de publier ;
- d'utiliser HAPPYN à des fins illégales, y compris pour vendre des produits réglementés ou interdits ;
- de tenter de falsifier, de copier ou de réutiliser des billets ou des codes QR ;
- d'extraire massivement le contenu de HAPPYN, d'en sonder les failles ou de chercher à contourner ses contrôles d'accès ;
- de créer des comptes ou d'interagir de façon automatisée (robots, scripts) ;
- d'utiliser la messagerie privée pour envoyer des pourriels ou des sollicitations non désirées.

## 11. Le contenu que vous publiez
« Contenu » désigne tout ce que vous mettez sur HAPPYN : publications et leurs photos, légendes, commentaires, messages, descriptions et images d'événements, et votre profil.
Votre contenu vous appartient. Vous accordez à HAPPYN une licence non exclusive, mondiale et gratuite pour l'héberger, le conserver, l'afficher et le diffuser dans HAPPYN, uniquement pour faire fonctionner le service et seulement tant qu'il reste publié. Cette licence prend fin quand vous supprimez le contenu ou votre compte, sauf lorsque nous devons le conserver (voir la politique de conservation des données et la politique de modération des contenus).

## 12. Qui voit une publication
Une publication doit être liée à un événement que vous organisez ou pour lequel vous détenez un billet. Nos serveurs l'imposent.
Les publications ne sont visibles que par les personnes connectées à HAPPYN — jamais par des visiteurs sans compte.
- Les publications sur un événement public sont visibles par tous les membres.
- Pour un événement privé, l'organisateur choisit si les publications sont visibles par tous ou seulement par l'organisateur et les détenteurs de billets. Si elles sont publiques, le nom et la date de l'événement deviennent visibles avec elles.
- Les membres qui voient une publication peuvent la commenter. L'auteur d'une publication peut désactiver les commentaires.

## 13. Modération et sanctions
Nous pouvons retirer du contenu et suspendre des comptes qui enfreignent les présentes conditions ou les règles de la communauté. La politique de modération des contenus explique comment les signalements sont traités et comment contester une décision.
Un compte suspendu conserve les billets qu'il a payés, mais ne peut plus publier, commenter ni créer d'événement.

## 14. Paiements, remboursements et annulations
Voir la politique de paiement et la politique de remboursement et d'annulation. En bref : vos données de carte vont à Stripe et ne nous parviennent jamais ; un événement annulé est remboursé en entier, automatiquement ; vous pouvez annuler vous-même un billet jusqu'à la date limite de l'organisateur, moins de petits frais de service non remboursables affichés avant le paiement.

## 15. Disponibilité
HAPPYN est fourni « tel quel ». Nous ne garantissons pas qu'il sera toujours disponible ni exempt d'erreurs, et nous pouvons modifier ou arrêter des fonctionnalités. Nous donnerons un préavis raisonnable avant d'arrêter tout ce pour quoi vous avez payé.

## 16. Limitation de responsabilité
Rien dans les présentes conditions ne limite une responsabilité que la loi ne permet pas de limiter, notamment en vertu de la Loi de 2002 sur la protection du consommateur de l'Ontario et, pour les consommateurs qui résident au Québec, de la Loi sur la protection du consommateur du Québec. Dans la mesure permise par la loi, HAPPYN n'est pas responsable :
- de ce qui se passe lors d'un événement, notamment les blessures, pertes ou dommages ;
- du fait qu'un organisateur ne tienne pas ou ne mène pas un événement (les remboursements des événements annulés suivent la politique de remboursement et d'annulation) ;
- du contenu publié par d'autres utilisateurs ;
- des pertes causées par un manque de protection de votre compte de votre part.

## 17. Droit applicable
Les présentes conditions sont régies par les lois de la province de l'Ontario et les lois fédérales du Canada qui s'y appliquent. Cela ne vous retire aucun droit dont vous disposez, en tant que consommateur, en vertu de la loi de la province où vous résidez.

## 18. Modifications des présentes conditions
Nous pouvons mettre à jour ces conditions. Pour une modification importante, nous vous en avisons dans l'application au moins 30 jours avant son entrée en vigueur. Quand la nouvelle version entre en vigueur, l'application vous demande de la lire et de l'accepter avant de continuer. Les petites corrections qui ne changent rien au fond entrent en vigueur dès leur publication, sans nouvelle acceptation.

## 19. Nous joindre
contact@happynevents.com
$fr$, 'Version 1.2', now()),

-- ─────────────────────────────────────────────────────────────────────────────
('privacy', 'fr', 'Politique de confidentialité', $fr$
## En bref
- Nous recueillons ce qu'il faut pour faire fonctionner HAPPYN : les renseignements de votre compte, ce que vous publiez, vos billets et votre utilisation des fonctions sociales.
- Nous ne vendons pas vos renseignements. Il n'y a pas de publicité de tiers dans HAPPYN, et nous ne vous suivons pas dans d'autres applications ou sites Web.
- Votre adresse courriel et votre date de naissance ne sont jamais montrées à personne. Votre nom, nom d'utilisateur, photo, bio et ville sont visibles par les autres membres.
- Votre position n'est utilisée que si vous activez « Autour de moi », pour trouver des événements près de vous. Elle n'est jamais montrée à personne.
- Personne ne peut voir à quels événements vous allez, sauf si vous vous suivez mutuellement et que vous choisissez de le montrer.
- Notre base de données est à Montréal, au Canada. Certains de nos fournisseurs (paiements, courriels, rapports de plantage, notifications) sont aux États-Unis.
- Vous pouvez consulter, corriger, obtenir une copie et supprimer vos renseignements. La suppression de votre compte se fait dans les Réglages.

## 1. Qui est responsable
HAPPYN est responsable des renseignements personnels décrits dans la présente politique. Notre responsable de la protection des renseignements personnels répond de leur traitement et traite vos questions et demandes à contact@happynevents.com.

## 2. Quelle loi s'applique
HAPPYN est établi à Ottawa, en Ontario : c'est donc la Loi sur la protection des renseignements personnels et les documents électroniques (LPRPDE), loi fédérale, qui encadre notre traitement des renseignements personnels. Comme beaucoup de nos membres vivent au Québec, nous appliquons aussi à tous les exigences de la Loi sur la protection des renseignements personnels dans le secteur privé du Québec (Loi 25), plutôt que de traiter les gens différemment selon la rive où ils habitent.

## 3. Ce que vous nous fournissez à la création de votre compte
- Adresse courriel — obligatoire. Votre identité, la connexion et les courriels liés à votre compte (réinitialisation du mot de passe, reçus). Vue par vous seul.
- Mot de passe — obligatoire pour l'inscription par courriel. Conservé sous forme chiffrée irréversible par notre fournisseur d'authentification ; personne chez HAPPYN ne peut le lire.
- Nom complet — obligatoire. Affiché sur votre profil, vos publications, vos commentaires et vos messages.
- Date de naissance — obligatoire, et non modifiable ensuite. Sert à appliquer l'âge minimum de 18 ans et l'âge minimum des événements. Vue par vous seul.
- Nom d'utilisateur — obligatoire (créé automatiquement si vous n'en choisissez pas). Permet aux autres de vous trouver et de vous mentionner. Visible par les membres.
- Photo de profil, bio et ville — facultatives. Affichées sur votre profil. Votre ville est un texte que vous saisissez, pas une position.
- Centres d'intérêt — facultatifs. Conservés dans votre profil ; non montrés aux autres.
- Langue de l'application — automatique. Sert à afficher l'application et à envoyer les notifications dans votre langue.

## 4. Si vous vous connectez avec Google
Google nous transmet votre adresse courriel, votre nom et votre photo de profil. Nous ne recevons rien d'autre de Google — ni vos contacts, ni votre activité Google — et nous ne transmettons à Google rien de ce que vous faites sur HAPPYN. HAPPYN vous demande ensuite votre date de naissance, que Google ne fournit pas.

## 5. Ce qui est créé quand vous utilisez HAPPYN
- Les billets que vous détenez et leur état (valide, utilisé, transféré, annulé) — pour vous faire entrer aux événements et traiter les remboursements. Vus par vous et par l'organisateur de l'événement.
- Les relevés d'achat : montant, date et référence de paiement Stripe — pour la comptabilité, les remboursements et les contestations.
- Les événements que vous créez, y compris leur adresse — pour les publier (voir la section 11 pour les événements privés).
- Les publications, photos, légendes et commentaires — pour les publier (voir les conditions d'utilisation).
- Les messages privés, et les événements ou publications que vous y partagez — pour les acheminer (voir la section 6).
- Vos abonnements, vos « j'aime » et vos événements sauvegardés. Les abonnements et les « j'aime » sont visibles par les membres ; les événements sauvegardés, par vous seul.
- Votre présence aux événements, créée quand vous obtenez un billet — montrée à vos proches seulement si vous le permettez (voir la section 10).
- Les comptes que vous bloquez — vous seul les voyez.
- Les signalements que vous faites, ou qui concernent votre contenu — traités par nos modérateurs.
- Les notifications que nous vous envoyons, et l'identifiant de notification de votre appareil — pour vous envoyer des notifications.

## 6. Les messages privés
Vous pouvez envoyer un message privé à une personne que vous suivez, sauf si l'un de vous a bloqué l'autre. Un message peut contenir du texte ainsi que des événements ou des publications partagés.
- Les messages sont conservés sur nos serveurs pour être acheminés et rester dans l'historique de la conversation. Ils ne sont pas chiffrés de bout en bout.
- L'équipe de HAPPYN ne lit pas les messages, sauf un message qui nous a été signalé, qu'un modérateur examine pour traiter le signalement.
- Vous ne pouvez pas supprimer un message une fois envoyé ; il reste dans l'historique de l'autre personne, comme une lettre. Si vous supprimez votre compte, vos messages restent chez leurs destinataires, affichés comme venant d'un « Compte supprimé ».
- Si l'un de vous bloque l'autre, aucun des deux ne peut plus écrire à l'autre, et la conversation disparaît pour les deux tant que le blocage dure.

## 7. Votre position — seulement si vous activez « Autour de moi »
« Autour de moi » affiche les événements situés à la distance que vous choisissez. Vous choisissez une ville dans une liste, ou vous permettez à HAPPYN d'utiliser la position de votre téléphone. Si vous le permettez :
- HAPPYN demande une position approximative, jamais précise, et seulement quand l'application est ouverte — jamais en arrière-plan ;
- la position est envoyée à notre serveur à chaque recherche d'événements proches, pour calculer les distances, et n'y est pas conservée ;
- la position est enregistrée sur votre téléphone pour accélérer la recherche suivante. Vous pouvez revenir à une ville, ou désactiver la localisation dans les réglages de votre téléphone, à tout moment ;
- personne d'autre ne voit jamais votre position, et HAPPYN ne s'en sert que pour trouver des événements près de vous.

## 8. Si vous organisez des événements payants
Pour recevoir l'argent de vos ventes de billets, vous ouvrez un compte de versement auprès de Stripe, notre fournisseur de paiement. C'est Stripe — et non HAPPYN — qui recueille vos renseignements d'identité et vos coordonnées bancaires, comme l'exige la réglementation financière. HAPPYN ne conserve que l'identifiant de votre compte Stripe et le fait qu'il peut recevoir des versements.

## 9. Ce que nous ne recueillons délibérément pas
- Pas de publicité de tiers ni de pistage. Il n'y a pas de régie publicitaire dans HAPPYN, nous ne dressons pas de profil publicitaire à votre sujet et nous ne vendons pas de renseignements personnels — à qui que ce soit.
- Pas de suivi dans d'autres applications ou sites Web.
- Pas de données de carte. Votre numéro de carte va directement à Stripe.
- Pas de contacts. HAPPYN ne lit jamais le carnet d'adresses de votre téléphone.
- Pas de localisation en arrière-plan.

## 10. Ce que voient les autres membres
Visible par les membres : votre nom, votre nom d'utilisateur, votre photo de profil, votre bio, votre ville, vos publications et commentaires, les personnes que vous suivez et celles qui vous suivent.
Jamais visible par les autres membres : votre adresse courriel, votre date de naissance, vos centres d'intérêt, vos événements sauvegardés, les comptes que vous bloquez, votre position. C'est notre base de données qui l'impose, pas seulement les écrans de l'application.
Obtenir un billet crée une mention de présence que, par défaut, personne ne peut voir. Quelqu'un ne peut voir que vous allez à un événement que si vous vous suivez mutuellement et que vous avez choisi de montrer cette présence-là. Les comptes bloqués ne la voient jamais.

## 11. Ce que voient les organisateurs
Quand vous détenez un billet pour un événement, son organisateur peut voir, dans sa liste de participants, votre nom, votre photo de profil, votre type de billet, son état et la date à laquelle vous l'avez obtenu. Les organisateurs ne voient jamais votre adresse courriel ni votre date de naissance.
Pour un événement privé, l'adresse exacte n'est visible que par l'organisateur et les détenteurs de billets ; les autres membres ne voient que la ville.

## 12. Nos fournisseurs
Nous faisons appel à des fournisseurs pour faire fonctionner HAPPYN. Chacun ne reçoit que ce dont il a besoin pour sa tâche.
- Supabase — base de données, comptes, courriels liés aux comptes, stockage de fichiers et fonctions serveur. Détient les données décrites dans la présente politique. Montréal, Canada.
- Stripe — paiements, remboursements et versements aux organisateurs. Données de paiement ; identité et coordonnées bancaires des organisateurs. Canada et États-Unis.
- Google Firebase Cloud Messaging — envoi des notifications. L'identifiant de notification de votre appareil et le texte de la notification. États-Unis.
- Google Sign-In — si vous le choisissez (voir la section 4). États-Unis.
- Resend — envoi de certains courriels, comme les alertes de signalement à nos modérateurs. Le destinataire et le contenu du courriel. États-Unis.
- Netlify — hébergement du site Web. Données techniques de votre visite (adresse IP, navigateur). Réseau mondial.
- Sentry — rapports de plantage et d'erreur, et mesures de performance de l'application. Détails techniques d'une erreur ou d'un écran lent ; ni nom, ni adresse courriel, ni adresse IP, ni capture d'écran. États-Unis.

## 13. Renseignements traités hors du Canada
Certains de ces fournisseurs traitent des renseignements aux États-Unis, où ils peuvent être accessibles aux autorités en vertu des lois de ce pays. Nous les protégeons par contrat avec chaque fournisseur, et nous en demeurons responsables.

## 14. Quand la loi l'exige
Nous pouvons communiquer des renseignements lorsque la loi l'exige (par exemple, une ordonnance d'un tribunal), ou lorsque c'est nécessaire pour protéger la vie ou la sécurité d'une personne. Si HAPPYN était vendu ou fusionné, vos renseignements passeraient au nouveau propriétaire, qui resterait lié par la présente politique ; nous vous en aviserions au préalable.

## 15. Décisions automatisées
HAPPYN ne prend aucune décision automatisée ayant des effets juridiques ou des effets importants similaires à votre égard. Le contenu est retiré et les comptes sont suspendus par une personne, et chaque action est consignée. Les règles automatiques qui existent — refuser le transfert d'un billet à une personne trop jeune, refuser une deuxième lecture d'un billet — appliquent les règles décrites dans nos politiques ; vous pouvez toujours nous écrire à leur sujet.

## 16. Photos et fichiers
Les photos (photos de profil, images d'événements, photos de publications) sont conservées dans un stockage infonuagique à Montréal. Quiconque obtient l'adresse Web d'une photo peut la voir sans se connecter, et ces adresses ne sont pas conçues pour être secrètes. Considérez qu'une photo que vous publiez peut être vue par toute personne qui en reçoit le lien.

## 17. Durée de conservation
Voir la politique de conservation des données.

## 18. Vos droits
En vertu de la LPRPDE — et de la Loi 25 si vous résidez au Québec — vous pouvez exercer les droits ci-dessous. Écrivez à contact@happynevents.com. Nous répondons dans un délai de 30 jours, et pouvons d'abord vous demander de confirmer votre identité, afin de ne jamais transmettre vos renseignements à quelqu'un d'autre.
- Consulter les renseignements que nous détenons sur vous. La plupart sont dans l'application ; pour une copie complète, écrivez-nous.
- Les corriger, en modifiant votre profil ou en nous écrivant.
- En obtenir une copie dans un format structuré et couramment utilisé.
- Retirer votre consentement et supprimer votre compte, dans les Réglages (voir la politique de suppression de compte), ou supprimer une publication ou un commentaire.
- Cesser l'utilisation de votre position, en revenant à une ville dans « Autour de moi » ou en désactivant la localisation dans les réglages de votre téléphone.
- Cesser de recevoir des notifications, dans les réglages de votre téléphone.
- Porter plainte auprès du Commissariat à la protection de la vie privée du Canada ou, si vous résidez au Québec, de la Commission d'accès à l'information du Québec.

## 19. Sécurité
Aucun système n'est parfaitement sûr. Si un incident crée un risque réel de préjudice grave, nous vous en aviserons, ainsi que le Commissariat à la protection de la vie privée du Canada et — lorsque des résidents du Québec sont concernés — la Commission d'accès à l'information du Québec, comme la loi l'exige.
- L'accès à chaque table est contrôlé par la base de données elle-même, pas seulement par l'application, et ces règles sont testées automatiquement.
- Les mots de passe sont chiffrés de façon irréversible ; personne chez HAPPYN ne peut les lire.
- Les codes QR sont signés cryptographiquement et changent toutes les cinq minutes.
- Sur Android, les captures et l'enregistrement d'écran sont bloqués sur l'écran du billet. iOS n'offre pas d'équivalent, mais le code d'une capture expire.
- Les données de carte n'atteignent jamais nos serveurs.

## 20. Personnes mineures
HAPPYN est réservé aux adultes de 18 ans et plus. Si nous apprenons qu'un compte appartient à une personne de moins de 18 ans, nous le supprimons, avec les renseignements qui s'y rattachent.

## 21. Modifications
Nous vous aviserons dans l'application au moins 30 jours avant l'entrée en vigueur d'une modification importante de la présente politique, et vous demanderons d'accepter la nouvelle version.
$fr$, 'Version 1.2', now()),

-- ─────────────────────────────────────────────────────────────────────────────
('community', 'fr', 'Règles de la communauté', $fr$
## En bref
HAPPYN existe pour que chacun trouve des sorties qui en valent la peine — et en profite en toute sécurité. Soyez authentique, soyez respectueux, publiez ce que vous avez le droit de publier, et respectez les personnes qui ne veulent pas apparaître sur vos photos.

## Ce qui est interdit
- Les événements faux ou trompeurs : des événements qui n'existent pas, pour lesquels vous n'avez pas le droit de vendre des billets, ou dont la description travestit ce qui va se passer.
- Le harcèlement et la haine : insultes, menaces ou contenus dégradants visant quelqu'un ; contenus qui s'en prennent à des personnes en raison de leur origine ethnique, de leur origine nationale, de leur religion, d'un handicap, de leur sexe, de leur identité de genre, de leur orientation sexuelle ou de leur âge. Cela vaut partout — publications, commentaires et messages privés.
- Le contenu sexuel : nudité et contenu sexuellement explicite. Tout contenu sexuel impliquant une personne mineure est signalé aux autorités.
- La violence : menaces, glorification de la violence ou contenu destiné à intimider.
- L'usurpation d'identité : se faire passer pour une autre personne, une organisation ou un événement avec lequel vous n'avez aucun lien.
- Les activités illégales : vendre des produits réglementés ou interdits (drogues, armes, alcool à des mineurs…), ou organiser des activités illégales là où elles ont lieu.
- Le pourriel et la manipulation : contenus ou messages non désirés et répétés, faux comptes, « j'aime » ou abonnements artificiels.
- La vie privée d'autrui : publier les renseignements personnels de quelqu'un (adresse, numéro de téléphone…), ou des photos de personnes reconnaissables qui vous ont demandé de ne pas le faire.

## Les photos d'autres personnes
Les événements sont sociaux, et les photos montrent souvent d'autres personnes. Si quelqu'un vous demande de retirer une photo de lui, retirez-la. S'il la signale, nous pouvons la retirer nous-mêmes.

## Les messages privés
Les messages sont faits pour des gens qui se connaissent — vous ne pouvez écrire qu'aux personnes que vous suivez. Ne vous en servez pas pour vendre, faire de la promotion ou contacter des gens qui n'ont pas demandé à avoir de vos nouvelles. Si quelqu'un vous envoie un message abusif, signalez-le et bloquez le compte.

## Si vous enfreignez ces règles
Selon la gravité : le contenu est retiré, votre compte est suspendu, ou — pour un contenu illégal — l'affaire est signalée aux autorités. Vous conservez les billets que vous avez déjà payés.

## Signaler et bloquer
Chaque événement, publication, commentaire, message et compte peut être signalé. Les signalements sont examinés par une personne. Vous pouvez aussi bloquer un compte : ses publications et ses événements disparaissent pour vous, et aucun de vous deux ne peut plus écrire à l'autre.
$fr$, 'Version 1.0', now()),

-- ─────────────────────────────────────────────────────────────────────────────
('content-moderation', 'fr', 'Politique de modération des contenus', $fr$
## En bref
- Tout le monde peut signaler un événement, une publication, un commentaire, un message ou un compte.
- Chaque signalement alerte immédiatement nos modérateurs, et une personne l'examine dans les 24 heures.
- Nous pouvons rejeter un signalement, retirer une publication, dépublier un événement ou suspendre un compte. Chaque décision est consignée.
- Le contenu illégal — en particulier tout contenu sexuel impliquant une personne mineure — est retiré et signalé aux autorités.
- Si vous pensez que nous nous sommes trompés, écrivez-nous : quelqu'un réexamine la décision dans les 7 jours.

## 1. Comment les signalements nous parviennent
Tout membre peut signaler un événement, une publication, un commentaire, un message privé ou un compte, en choisissant un motif et en ajoutant des précisions s'il le souhaite. La personne signalée n'apprend pas qui l'a signalée. Chaque signalement :
- est consigné avec son auteur, ce qu'il vise, le motif et la date ;
- envoie immédiatement une alerte à notre équipe de modération ;
- est examiné par une personne dans les 24 heures.

## 2. Ce que nous pouvons faire
Chaque action est consignée : qui l'a prise, ce qu'elle visait, le signalement auquel elle répond et la date — pour qu'une décision puisse être expliquée après coup.
- Rejeter : le signalement n'était pas fondé, rien ne change.
- Retirer une publication : la publication et sa photo sont supprimées.
- Dépublier un événement : l'événement n'est plus visible. Les billets déjà vendus ne sont pas détruits ; les acheteurs gardent la trace de ce qu'ils ont payé.
- Suspendre un compte : le compte ne peut plus publier, commenter ni créer d'événement. Il conserve les billets qu'il a payés.

## 3. Le contenu illégal
Certains contenus ne relèvent pas de nos règles mais du droit criminel : contenu sexuel impliquant une personne mineure, menace crédible de violence contre une personne, contenu faisant la promotion du terrorisme. Quand nous en trouvons, ou qu'on nous en signale de façon crédible, nous :
- le retirons immédiatement ;
- le signalons à l'autorité compétente — au Canada, le matériel d'abus pédosexuel est signalé à Cyberaide.ca, exploité par le Centre canadien de protection de l'enfance, et à la police lorsque c'est requis ;
- prenons les mesures que la loi exige, y compris la conservation des renseignements dont les autorités ont besoin ;
- suspendons le compte.

## 4. Contester une décision
Si votre contenu a été retiré ou votre compte suspendu et que vous pensez qu'il s'agit d'une erreur, écrivez à contact@happynevents.com : indiquez ce qui a été retiré et pourquoi vous pensez que la décision est erronée. Nous répondons dans les 7 jours. Dans la mesure du possible, le réexamen est fait par une personne qui n'a pas participé à la décision initiale.

## 5. Le blocage
Le blocage est un outil personnel, distinct du signalement. Il ne retire rien pour les autres, et vous pouvez débloquer un compte dans les Réglages. Quand vous bloquez un compte :
- ses publications et les événements qu'il organise disparaissent pour vous ;
- aucun de vous deux ne peut plus écrire à l'autre, y compris dans une conversation déjà commencée ;
- il ne voit jamais où vous allez ;
- il n'est pas avisé que vous l'avez bloqué.
$fr$, 'Version 1.0', now()),

-- ─────────────────────────────────────────────────────────────────────────────
('account-deletion', 'fr', 'Politique de suppression de compte', $fr$
## En bref
- Supprimez votre compte dans Réglages → Supprimer mon compte. Aucune raison à donner, aucun courriel à écrire.
- Avant toute chose, HAPPYN vous montre exactement ce qui sera touché.
- Si de l'argent est encore en jeu, la suppression attend — pour que personne ne perde d'argent : ni vous, ni les personnes qui ont acheté vos billets.
- Votre profil, vos publications, commentaires, « j'aime » et abonnements sont supprimés. Ce dont d'autres dépendent (billets, événements passés, messages envoyés) est conservé sans votre nom.
- La suppression est définitive : le compte ne peut pas être récupéré.

## 1. Ce que vous voyez d'abord
Avant toute suppression, HAPPYN vous montre combien d'événements vous organisez (et lesquels seront annulés), combien de billets vous détenez et combien de publications vous avez faites. Rien n'est supprimé tant que vous n'avez pas confirmé.

## 2. Quand la suppression doit attendre
Pour que personne ne perde d'argent, la suppression est refusée tant que :
- vous détenez un billet payé pour un événement qui n'a pas encore eu lieu — annulez-le (remboursé si la date limite le permet) ou transférez-le d'abord ;
- vous avez vendu des billets payants pour un événement qui n'a pas encore eu lieu — annulez d'abord l'événement, et les acheteurs sont remboursés automatiquement ;
- des ventes de billets ne vous ont pas encore été versées — attendez le versement.

## 3. Ce qui est supprimé
- Votre profil : nom, nom d'utilisateur, photo, bio, ville, centres d'intérêt, date de naissance, langue.
- Vos publications et leurs photos, et vos commentaires.
- Vos « j'aime », vos abonnements (dans les deux sens), vos événements sauvegardés et les comptes que vous bloquez.
- Vos mentions de présence et vos identifiants de notification.
- Vos identifiants de connexion — le compte ne peut pas être récupéré.
- Les billets gratuits pour des événements à venir ; la place est remise en vente.
- Les événements à venir que vous organisiez et qui n'ont aucun participant.

## 4. Ce qui est annulé
Les événements à venir que vous organisiez et qui ont des participants sont annulés. Chaque participant en est avisé, et remboursé en entier s'il a payé.

## 5. Ce qui est conservé, sans votre identité
- Les billets passés, utilisés ou annulés — nécessaires à la comptabilité.
- Les événements passés que vous avez organisés, affichés comme « Organisateur supprimé » — les personnes qui y ont assisté les retrouvent toujours dans leur historique.
- Les messages privés que vous avez envoyés, conservés chez leurs destinataires et affichés comme venant d'un « Compte supprimé » — un message appartient aussi à qui le reçoit, et peut servir de preuve dans un signalement. Une conversation est supprimée pour de bon quand les deux personnes ont supprimé leur compte.
- Les signalements que vous avez faits.
- Les signalements visant votre contenu, et les mesures de modération — un compte ne peut pas effacer son dossier en partant.
- Si vous organisiez des événements payants, votre compte de versement Stripe est déconnecté de HAPPYN ; Stripe conserve ses propres dossiers selon ses propres obligations.

## 6. Supprimer une seule chose
Pas besoin de supprimer votre compte pour retirer quelque chose :
- vous pouvez supprimer une publication ou un commentaire à tout moment ;
- vous pouvez annuler un billet jusqu'à la date limite de l'organisateur ;
- vous pouvez annuler un événement que vous organisez — les acheteurs sont remboursés automatiquement ;
- vous ne pouvez pas supprimer un message privé une fois envoyé (voir la politique de confidentialité).
$fr$, 'Version 1.0', now()),

-- ─────────────────────────────────────────────────────────────────────────────
('data-retention', 'fr', 'Politique de conservation des données', $fr$
## En bref
Nous ne conservons les renseignements que le temps nécessaire à la raison pour laquelle nous les avons recueillis ; ensuite, nous les supprimons ou nous en retirons votre identité.

## Durées de conservation
La LPRPDE exige de ne conserver les renseignements personnels que le temps nécessaire à leur fin ; la Loi 25 exige de les détruire ou de les anonymiser une fois cette fin atteinte.
- Compte et profil, y compris votre date de naissance : tant que le compte existe.
- Publications, photos et commentaires : jusqu'à ce que vous les supprimiez ou que vous supprimiez votre compte.
- Messages privés : tant qu'au moins une des deux personnes a un compte.
- Position enregistrée pour « Autour de moi » : sur votre téléphone seulement, jusqu'à ce que vous la changiez.
- Position envoyée pour une recherche : non conservée.
- Billets et relevés de paiement : aussi longtemps que l'exigent les lois comptables et fiscales, sans votre identité si vous avez supprimé votre compte.
- Mentions de présence : supprimées avec le billet ou le compte.
- Signalements et mesures de modération : aussi longtemps que nécessaire pour expliquer et réexaminer les décisions.
- Renseignements liés à un contenu illégal : aussi longtemps que la loi l'exige.
- Journaux d'envoi de courriels, rapports de plantage et mesures de performance : conservés par nos fournisseurs (Resend, Sentry) pendant une durée limitée fixée par leur service, pour acheminer les courriels et corriger les défauts.
- Copies de sauvegarde : conservées pendant une durée limitée par notre fournisseur de base de données, puis écrasées.
$fr$, 'Version 1.0', now()),

-- ─────────────────────────────────────────────────────────────────────────────
('cookie', 'fr', 'Politique relative aux témoins et au stockage local', $fr$
## En bref
HAPPYN n'utilise aucun témoin publicitaire, aucun témoin d'analyse et rien qui vous suive sur d'autres sites Web. C'est pourquoi on ne vous demande jamais d'accepter des témoins (cookies).

## Dans l'application
L'application conserve quelques éléments sur votre téléphone :
- votre session, pour que vous ne soyez pas déconnecté chaque fois que vous fermez l'application — jusqu'à ce que vous vous déconnectiez ;
- votre choix de langue — jusqu'à ce que vous le changiez ;
- votre réglage « Autour de moi » (une ville ou une position approximative, et une distance) — jusqu'à ce que vous le changiez.

## Vos événements sauvegardés
Vos événements sauvegardés ne sont pas conservés sur votre téléphone : ils sont enregistrés dans votre compte, et vous suivent d'un téléphone à l'autre.

## Sur le site Web
Le site Web ne charge aucun script de tiers ni aucune police externe. Sa seule connexion extérieure est notre propre base de données, pour afficher ces documents.
- La page de réinitialisation du mot de passe garde temporairement le code de réinitialisation dans le stockage de session de votre navigateur, pour qu'un rechargement de la page ne le perde pas. Il est effacé quand vous fermez l'onglet, et dès que votre mot de passe est changé.
- Votre choix de langue (FR/EN) est retenu par votre navigateur.
$fr$, 'Version 1.0', now()),

-- ─────────────────────────────────────────────────────────────────────────────
('copyright', 'fr', 'Politique sur le droit d''auteur', $fr$
## En bref
Ne publiez que ce que vous avez le droit de publier. Si quelqu'un utilise votre œuvre sur HAPPYN sans permission, dites-le-nous et nous nous en occuperons.

## Publier du contenu
Ne publiez que du contenu que vous avez créé ou que vous avez la permission d'utiliser. Mettre en ligne la photo, l'affiche, l'œuvre ou la musique de quelqu'un d'autre sans permission peut porter atteinte à son droit d'auteur.

## Signaler une atteinte
Écrivez à contact@happynevents.com. Nous accusons réception de votre avis dans les 3 jours ouvrables et agissons dans les 10. Indiquez :
- une description de l'œuvre qui vous appartient ;
- où le contenu en cause apparaît sur HAPPYN ;
- vos coordonnées ;
- une déclaration selon laquelle vous croyez de bonne foi que l'utilisation n'est pas autorisée ;
- une déclaration selon laquelle les renseignements sont exacts et que vous êtes le titulaire des droits, ou autorisé à agir en son nom.

## Contre-avis
Si votre contenu a été retiré et que vous pensez qu'il l'a été à tort, dites-le-nous et expliquez pourquoi vous avez le droit de le publier. Nous réexaminerons la situation et pourrons le rétablir.

## Atteintes répétées
Les comptes qui portent atteinte au droit d'auteur de façon répétée sont suspendus.
$fr$, 'Version 1.0', now()),

-- ─────────────────────────────────────────────────────────────────────────────
('payments', 'fr', 'Politique de paiement', $fr$
## En bref
- Les paiements sont traités par Stripe. Les données de votre carte vont directement à Stripe et n'atteignent jamais HAPPYN.
- Le prix affiché est le prix que vous payez, en dollars canadiens. Les frais de HAPPYN sont prélevés sur la part de l'organisateur, et non ajoutés à votre prix.
- Votre billet apparaît dès que Stripe confirme le paiement.
- Si vous annulez vous-même un billet, de petits frais de service ne sont pas remboursés. Si l'organisateur annule, tout vous est rendu.
- Les organisateurs sont payés après leur événement.

## 1. Fonctionnement du paiement
Les paiements sont traités par Stripe, un fournisseur de paiement réglementé. Le numéro de votre carte, sa date d'expiration et son code de sécurité sont saisis dans le formulaire de paiement de Stripe et vont directement à Stripe : ils n'atteignent jamais les serveurs de HAPPYN. Nous ne conservons que la réussite du paiement, son montant, sa date et la référence de Stripe.

## 2. Le prix
- Le prix affiché est le total que vous payez, en dollars canadiens.
- Aucuns frais de service ne s'ajoutent au moment de payer. Les frais de HAPPYN sont déduits de la part de l'organisateur.
- Vous pouvez acheter plusieurs billets du même type en un seul paiement.
- Avant de payer, l'écran indique jusqu'à quand vous pouvez annuler, et les frais de service qui ne seraient pas remboursés.

## 3. Quand votre billet apparaît
Nos serveurs émettent votre billet dès que Stripe confirme le paiement — en général immédiatement. Si la confirmation tarde, l'application vous le dit, et le billet apparaît dans Mes billets dès qu'elle arrive.
Un paiement sans billet est toujours corrigé : écrivez à contact@happynevents.com en indiquant la date et le montant.

## 4. À qui vous payez
Vous payez un billet pour un événement tenu par son organisateur. HAPPYN perçoit le paiement pour le compte de l'organisateur, par l'intermédiaire de Stripe, et le lui remet moins nos frais.

## 5. Comment les organisateurs sont payés
- Pour vendre des billets payants, un organisateur ouvre d'abord depuis HAPPYN un compte de versement Stripe, où Stripe vérifie son identité et ses coordonnées bancaires. Un événement payant ne peut pas être publié tant que ce compte ne peut pas recevoir d'argent.
- Les frais de HAPPYN sont de 5 % du prix du billet. Le taux en vigueur à la création de l'événement s'applique à cet événement, même s'il change par la suite.
- La part de l'organisateur lui est versée après la fin de l'événement, une fois écoulée une courte période d'attente. Cette période permet de traiter les remboursements et de vérifier que l'événement a bien eu lieu.
- HAPPYN peut retenir un versement le temps de vérifier un événement — par exemple quand aucun billet n'a été lu à l'entrée, ou pour les premiers événements d'un organisateur.

## 6. Paiements refusés et doublons
Si votre paiement échoue, vous n'êtes pas débité et aucun billet n'est émis. Si vous êtes débité deux fois, ou débité sans recevoir de billet, écrivez-nous : nous vérifions, et remboursons toujours en entier les doublons et les paiements sans billet.
$fr$, 'Version 1.0', now()),

-- ─────────────────────────────────────────────────────────────────────────────
('refund', 'fr', 'Politique de remboursement et d''annulation', $fr$
## En bref
- Si l'organisateur annule l'événement, vous êtes remboursé en entier, automatiquement, sur la carte qui a payé. Vous n'avez rien à demander.
- Vous pouvez annuler vous-même votre billet dans l'application jusqu'à une date limite choisie par l'organisateur : 24 heures, 48 heures ou 7 jours avant l'événement — ou pas du tout.
- Quand vous annulez vous-même, le prix du billet vous est rendu, moins de petits frais de service non remboursables : 2,9 % + 0,30 $ (0,88 $ sur un billet de 20 $).
- La date limite et les frais sont indiqués juste au-dessus du bouton de paiement, avant que vous payiez, et rappelés sur votre billet.
- Débité deux fois, ou débité sans billet ? Toujours remboursé en entier.
- Un billet reçu par transfert ne peut pas être remboursé à son nouveau détenteur.

## 1. Si l'organisateur annule l'événement
Vous n'avez rien à demander, et aucuns frais de service ne sont retenus. Un remboursement apparaît en général sur votre relevé dans un délai de 5 à 10 jours ouvrables, selon votre banque. Quand un organisateur annule un événement :
- la vente des billets s'arrête immédiatement ;
- chaque billet payé et valide est remboursé en entier, automatiquement, sur la carte qui a payé ;
- chaque détenteur de billet en est avisé.

## 2. Annuler votre propre billet
Chaque organisateur choisit, en créant l'événement, jusqu'à quand les acheteurs peuvent annuler : 24 heures, 48 heures ou 7 jours avant le début — ou aucune annulation. La date limite est indiquée juste au-dessus du bouton de paiement, avant que vous payiez, et rappelée sur votre billet.
Avant la date limite, annulez depuis votre billet dans l'application. Le prix de ce billet vous est remboursé, moins des frais de service non remboursables, et votre place est remise en vente. Vous ne pouvez pas annuler un billet déjà lu à l'entrée, ni un billet reçu par transfert — le remboursement ne peut aller qu'à la carte qui a payé.

## 3. Les frais de service
Ces frais sont de 2,9 % du prix du billet + 0,30 $, et ne dépassent jamais le prix du billet. Ils correspondent exactement à ce que notre fournisseur de paiement conserve sur un paiement remboursé : ni HAPPYN ni l'organisateur n'en tirent quoi que ce soit. Ils sont indiqués avant le paiement, sur votre billet et dans la confirmation qui précède l'annulation. Par exemple :
- billet de 10 $ : 0,59 $ retenus, 9,41 $ remboursés ;
- billet de 20 $ : 0,88 $ retenus, 19,12 $ remboursés ;
- billet de 50 $ : 1,75 $ retenus, 48,25 $ remboursés.

## 4. Toujours remboursé en entier
Écrivez à contact@happynevents.com en indiquant la date et le montant si :
- vous avez été débité deux fois pour le même billet ;
- vous avez été débité sans qu'aucun billet ne soit émis.

## 5. Non remboursé
À moins que la date limite de l'organisateur vous permette encore d'annuler :
- vous avez changé d'avis après la date limite ;
- vous n'êtes pas allé à l'événement ;
- l'événement a eu lieu comme annoncé, mais n'a pas répondu à vos attentes.

## 6. Si un problème survient lors d'un événement qui a eu lieu
Si un événement était très différent de sa description, contactez d'abord l'organisateur. S'il ne répond pas dans les 7 jours, écrivez à contact@happynevents.com : nous examinons la situation, et pouvons retenir le versement de l'organisateur pendant ce temps. Rien dans la présente politique ne vous retire les droits que vous accorde la loi sur la protection du consommateur.
$fr$, 'Version 1.0', now()),

-- ─────────────────────────────────────────────────────────────────────────────
('fraud-prevention', 'fr', 'Politique de prévention de la fraude', $fr$
## En bref
Les billets HAPPYN sont difficiles à contrefaire : le serveur les émet, le code QR change toutes les cinq minutes et chaque billet ne fait entrer qu'une fois. Achetez uniquement sur HAPPYN — jamais auprès de quelqu'un qui dit avoir un billet en trop.

## Comment les billets sont protégés
- Seuls nos serveurs créent des billets, une fois le paiement confirmé. Aucune application ne peut en créer ni en modifier.
- Chaque billet affiche un code QR signé cryptographiquement qui change toutes les cinq minutes. Une capture d'écran montre un code expiré : elle ne fera entrer personne.
- Un billet ne peut être lu qu'une fois. Une deuxième lecture est refusée.
- Seul l'organisateur de l'événement peut lire ses billets — nos serveurs refusent toute autre personne.
- Un billet transféré reçoit un nouveau code ; l'ancien cesse de fonctionner.

## Les événements frauduleux
Créer un événement que vous n'avez pas l'intention de tenir, ou vendre des billets pour un événement que vous n'avez pas le droit de vendre, est une fraude. Nous retirons ces événements, suspendons les comptes, remboursons les acheteurs lorsque c'est possible et collaborons avec les autorités.
Seuls des organisateurs dont Stripe a vérifié l'identité peuvent créer des événements payants, et leur argent ne leur est versé qu'après l'événement — ce qui limite ce qu'un fraudeur pourrait obtenir.

## Ce que vous devriez faire
- N'achetez de billets que sur HAPPYN. Ne payez jamais quelqu'un qui dit avoir un billet en trop : demandez-lui de vous le transférer dans l'application, ce qui émet un vrai nouveau billet.
- HAPPYN ne vous demandera jamais votre mot de passe, votre numéro de carte complet ou un paiement en dehors de l'application — ni par message, ni par courriel, ni par téléphone.
- Signalez les événements et les comptes suspects.
$fr$, 'Version 1.0', now()),

-- ─────────────────────────────────────────────────────────────────────────────
('safety', 'fr', 'Politique de sécurité', $fr$
## En bref
HAPPYN vous aide à trouver des événements, mais ne les tient pas et ne vérifie pas l'identité des gens. Servez-vous des outils — signalement, blocage, présence privée — et fiez-vous à votre instinct. En cas d'urgence, appelez d'abord le 911.

## Ce que fait HAPPYN
- Les signalements sont examinés par une personne dans les 24 heures.
- Le blocage cache les publications et les événements d'un compte et coupe tous les messages entre vous, y compris dans une conversation déjà commencée.
- Votre présence est privée par défaut. Quelqu'un ne peut voir que vous allez à un événement que si vous vous suivez mutuellement et que vous avez choisi de le montrer.
- Les messages ne sont possibles qu'avec les personnes que vous suivez.
- L'adresse exacte d'un événement privé est réservée aux détenteurs de billets.
- Les organisateurs peuvent fixer un âge minimum, et l'application ne vend pas de billet à une personne trop jeune.

## Ce que HAPPYN ne fait pas
- Nous ne vérifions pas l'identité. Un nom sur un profil ne prouve pas qui est la personne.
- Nous ne faisons pas de vérification des antécédents des organisateurs et n'inspectons pas les lieux.
- Nous ne sommes pas présents aux événements.

## Rencontrer des gens
Un événement, c'est aussi rencontrer des inconnus. Donnez-vous rendez-vous dans des lieux publics quand c'est possible, dites à quelqu'un où vous allez, prévoyez votre propre moyen de rentrer, et partez si vous ne vous sentez pas en sécurité.

## Si vous êtes en danger
Communiquez d'abord avec les services d'urgence — composez le 911. HAPPYN ne peut pas intervenir lors d'une urgence physique. Signalez ensuite le compte, pour que nous puissions agir.
$fr$, 'Version 1.0', now()),

-- ─────────────────────────────────────────────────────────────────────────────
('organizer', 'fr', 'Normes pour les organisateurs', $fr$
## En bref
- Vous devez avoir 18 ans ou plus pour créer des événements.
- Décrivez votre événement honnêtement, tenez-le à jour et déroulez-le comme annoncé.
- L'événement lui-même relève de votre responsabilité : légalité, sécurité, permis, assurances.
- Pour vendre des billets payants, ouvrez un compte de versement Stripe. Vous êtes payé après l'événement, moins les frais de 5 % de HAPPYN.
- Si vous annulez, utilisez le bouton Annuler : les acheteurs sont remboursés automatiquement.

## 1. Qui peut organiser
Créer des événements exige d'avoir 18 ans ou plus et d'accepter les présentes normes. Vendre des billets payants exige aussi un compte de versement Stripe à votre nom, où Stripe vérifie votre identité et vos coordonnées bancaires.

## 2. Vos responsabilités
- Décrivez votre événement avec exactitude : date, heure, lieu, prix, ce qui est inclus et tout âge minimum. Si un élément important change, mettez l'événement à jour — les détenteurs de billets sont avisés automatiquement quand la date, l'heure ou le lieu change.
- L'événement lui-même relève de votre responsabilité : sa légalité, sa sécurité, les permis, les assurances et son déroulement. HAPPYN fournit la billetterie et la visibilité ; il n'est pas coorganisateur.
- Vérifiez l'âge à l'entrée si vous avez fixé un âge minimum. HAPPYN empêche les personnes trop jeunes d'acheter, mais ne vérifie pas l'identité.
- Choisissez votre date limite d'annulation honnêtement (24 heures, 48 heures, 7 jours, ou aucune). Les acheteurs la voient avant de payer, et elle s'applique automatiquement. Quand un acheteur annule, les frais du fournisseur de paiement sont à sa charge, pas à la vôtre.
- Répondez aux acheteurs dans les 7 jours.
- Annulez dans les règles. Si l'événement n'aura pas lieu, utilisez la fonction Annuler : la vente s'arrête, chaque acheteur est remboursé en entier automatiquement et tout le monde est avisé. Ne vous contentez pas de cesser de répondre.

## 3. Si vous annulez un événement
Chaque acheteur est remboursé en entier. Les frais du fournisseur de paiement sur ces billets (2,9 % + 0,30 $ chacun) ne sont pas rendus par le fournisseur, et peuvent être déduits de vos versements.

## 4. Les événements privés
Un événement privé n'apparaît jamais dans Découvrir ni dans « Autour de moi ». On ne peut y accéder qu'avec le code d'invitation que vous communiquez, et son adresse exacte n'est visible que par vous et les détenteurs de billets.
Vous choisissez aussi si les publications à son sujet sont visibles par tous ou seulement par les détenteurs de billets. Choisissez en connaissance de cause : si les publications sont publiques, le nom et la date de votre événement deviennent publics avec elles.

## 5. Vos participants
Pour chacun de vos événements, vous pouvez voir la liste des détenteurs de billets : nom, photo de profil, type de billet, état et date d'achat. Vous ne voyez jamais leur adresse courriel ni leur date de naissance. N'utilisez cette liste que pour tenir votre événement — jamais pour contacter les gens à d'autres fins, ni pour la communiquer.

## 6. Les versements
- Les frais de HAPPYN sont de 5 % du prix de chaque billet. Le taux en vigueur à la création de l'événement s'applique à cet événement.
- Votre part est versée sur votre compte Stripe après la fin de l'événement, une fois écoulée une courte période d'attente.
- Si un billet est remboursé, son montant ne vous est pas versé.
- HAPPYN peut retenir un versement le temps de vérifier qu'un événement a bien eu lieu comme annoncé — par exemple quand aucun billet n'a été lu à l'entrée, ou pour vos premiers événements.

## 7. Ce que nous pouvons faire
Nous pouvons dépublier les événements qui enfreignent les présentes normes, retenir des versements pendant une vérification et suspendre les organisateurs qui les enfreignent de façon répétée ou qui fraudent les acheteurs.
$fr$, 'Version 1.0', now())

on conflict (slug, locale) do update set
  title      = excluded.title,
  content    = excluded.content,
  version    = excluded.version,
  updated_at = excluded.updated_at;

-- Chaque traduction doit porter la version de son original : sinon elle ne
-- s'afficherait jamais, et personne ne s'en apercevrait.
do $$
begin
  if exists (select 1 from public.legal_document_translations t
             join public.legal_documents d using (slug)
             where t.locale = 'fr' and t.version <> d.version) then
    raise exception 'une traduction ne porte pas la version de son original';
  end if;
  if (select count(*) from public.legal_document_translations where locale = 'fr')
     <> (select count(*) from public.legal_documents) then
    raise exception 'il manque des traductions francaises';
  end if;
end $$;
