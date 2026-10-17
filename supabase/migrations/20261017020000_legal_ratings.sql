-- Textes légaux : les notes d'événement, et le délai de versement écrit en
-- toutes lettres.
--
-- Les notes créent de nouvelles données personnelles (note, tags,
-- commentaire) : la politique de confidentialité et les règles de la
-- communauté changent de version, et l'écran de consentement redemande
-- l'accord une fois. Publication immédiate, décidée le 2026-10-17 : la fonction
-- est facultative et nouvelle, rien ne change pour les données déjà traitées,
-- et les seuls comptes sont des testeurs. Le préavis de 30 jours (conditions
-- § 18) est à confirmer par l'avocat lors de la relecture.
--
-- Anglais (référence) et français passent à la MÊME version dans la même
-- transaction : une traduction dont la version diffère ne s'affiche pas.
-- Textes repris de la production le 2026-10-17, ajouts insérés par section.

update public.legal_documents
   set content = $legal$
## In short
- We collect what we need to run HAPPYN: your account details, what you publish, your tickets, and how you use the social features.
- We don't sell your information. There are no third-party ads in HAPPYN, and we don't track you across other apps or websites.
- Your email and date of birth are never shown to anyone. Your name, username, photo, bio and city are visible to other members.
- Your location is only used if you turn on "Near me", to find events close to you. It is never shown to anyone.
- Nobody can see which events you go to unless you follow each other and you choose to show it.
- Our database is in Montréal, Canada. Some of our providers (payments, email, crash reports, notifications) are in the United States.
- You can see, correct, get a copy of, and delete your information. Deleting your account is in Settings.
- After an event where your ticket was scanned at the door, you can rate it. The organizer sees your rating without knowing it is yours; the public only sees an organizer's average rating, from 5 ratings.

## 1. Who is responsible
HAPPYN is responsible for the personal information described in this policy. Our Privacy Officer is accountable for how we handle it and answers your questions and requests at contact@happynevents.com.

## 2. Which law applies
HAPPYN is based in Ottawa, Ontario, so the federal Personal Information Protection and Electronic Documents Act (PIPEDA) governs how we handle personal information. Because many members live in Quebec, we also apply the standards of Quebec's Act respecting the protection of personal information in the private sector (Law 25) to everyone, rather than treating people differently depending on which side of the river they live on.

## 3. What you give us when you create your account
- Email address — required. Your identity, sign-in, and emails about your account (password reset, receipts). Seen only by you.
- Password — required for email sign-up. Stored hashed by our authentication provider; nobody at HAPPYN can read it.
- Full name — required. Shown on your profile, posts, comments and messages.
- Date of birth — required, and cannot be changed afterwards. Used to apply the minimum age of 18 and event age limits. Seen only by you.
- Username — required (generated if you don't choose one). How people find and mention you. Visible to members.
- Profile photo, bio and city — optional. Shown on your profile. Your city is text you type, not a location.
- Interests — optional. Stored on your profile; not shown to others.
- App language — automatic. Used to show the app and send notifications in your language.

## 4. If you sign in with Google
Google sends us your email address, your name, and your profile picture. We receive nothing else from Google — not your contacts, not your Google activity — and we send Google nothing about what you do on HAPPYN. HAPPYN then asks for your date of birth, because Google does not provide it.

## 5. What is created when you use HAPPYN
- Tickets you hold and their status (valid, used, transferred, cancelled) — to admit you to events and handle refunds. Seen by you and the event's organizer.
- Purchase records: amount, date, and Stripe's payment reference — for accounting, refunds and disputes.
- Events you create, including their address — to publish them (see section 11 for private events).
- Posts, photos, captions and comments — to publish them (see the Terms of Service).
- Private messages, and events or posts you share in them — to deliver them (see section 6).
- Follows, likes and saved events. Follows and likes are visible to members; saved events only to you.
- Event attendance, created when you get a ticket — shown to friends only if you allow it (see section 10).
- Blocks — only you see them.
- Reports you submit, or that concern your content — handled by our moderators.
- Notifications we send you, and your device's notification token — to deliver push notifications.
- The ratings you give an event: the number of stars, the tags you choose, your optional comment and the date — to help the organizer improve and other members choose. Only someone whose ticket was scanned at the door can rate, for a limited time after the event.
- The rating request we send you, once, 24 hours after the end of an event you attended.

## 6. Private messages
You can send a private message to someone you follow, unless one of you has blocked the other. Messages can contain text and shared events or posts.
- Messages are stored on our servers so they can be delivered and kept in your conversation history. They are not end-to-end encrypted.
- HAPPYN staff do not read messages, except a message that has been reported to us, which a moderator reviews to handle the report.
- You cannot delete a message once sent; it stays in the other person's history, like a letter. If you delete your account, your messages stay with their recipients, shown as coming from "Deleted account".
- If one of you blocks the other, neither can message the other any more, and the conversation disappears for both while the block lasts.

## 7. Your location — only if you turn on "Near me"
"Near me" shows events within a distance you choose. You either pick a city from a list, or allow HAPPYN to use your phone's location. If you allow location:
- HAPPYN asks for your approximate position, never a precise one, and only while the app is open — never in the background;
- the position is sent to our server each time you search for nearby events, to calculate distances, and is not stored there;
- the position is saved on your phone so the next search is quicker. You can switch back to a city, or turn location off in your phone's settings, at any time;
- nobody else ever sees your location, and HAPPYN never uses it for anything but finding events near you.

## 8. If you organize paid events
To receive money from ticket sales, you open a payout account with Stripe, our payment provider. Stripe — not HAPPYN — collects your identity information and bank details, as financial regulations require. HAPPYN keeps only your Stripe account identifier and whether it can receive payouts.

## 9. What we deliberately do not collect
- No third-party advertising or tracking. There is no advertising network in HAPPYN, we don't build an advertising profile of you, and we don't sell personal information — to anyone.
- No tracking across other apps or websites.
- No card details. Your card number goes directly to Stripe.
- No contacts. HAPPYN never reads your phone's address book.
- No background location.

## 10. What other members see
Visible to members: your name, username, profile photo, bio, city, your posts and comments, who you follow and who follows you.
Never visible to other members: your email address, your date of birth, your interests, your saved events, your blocks, your location. This is enforced by our database, not only by the app's screens.
Getting a ticket creates an attendance record that, by default, nobody can see. Someone can see that you're going to an event only if you follow each other and you have chosen to show that particular attendance. Blocked accounts never see it.
Visible to members: an organizer's average rating and number of ratings, from 5 ratings — never an individual rating. Never visible to other members: your ratings and comments on events.

## 11. What event organizers see
When you have a ticket for an event, its organizer can see, in their list of attendees, your name, profile photo, ticket type, its status, and when you got it. Organizers never see your email address or date of birth.
For a private event, the exact address is visible only to the organizer and to ticket holders; other members see only the city.
Organizers see the ratings, tags and comments left on their events, without the name, photo or any other way to identify who wrote them.

## 12. Our service providers
We use providers to run HAPPYN. Each receives only what it needs for its task.
- Supabase — database, accounts, account emails, file storage and server functions. Holds the data described in this policy. Montréal, Canada.
- Stripe — payments, refunds and payouts to organizers. Payment details; organizers' identity and bank details. Canada and United States.
- Google Firebase Cloud Messaging — delivering push notifications. Your device's notification token and the notification's text. United States.
- Google Sign-In — if you choose it (see section 4). United States.
- Resend — sending some emails, such as report alerts to our moderators. The email's recipient and content. United States.
- Netlify — hosting the website. Technical data from your visit (IP address, browser). Global network.
- Sentry — crash and error reports, and app performance measurements. Technical details of an error or a slow screen; no name, email, IP address or screenshot. United States.

## 13. Information processed outside Canada
Some of these providers process information in the United States, where it may be accessible to authorities under the laws of that country. We protect it by contract with each provider, and we remain responsible for it.

## 14. When the law requires it
We may disclose information when the law requires it (for example, a court order), or when necessary to protect someone's life or safety. If HAPPYN were sold or merged, your information would pass to the new owner, who would remain bound by this policy; we would tell you beforehand.

## 15. Automated decisions
HAPPYN makes no automated decision that has legal or similarly significant effects on you. Content is removed and accounts are suspended by a person, and every such action is logged. Automatic rules that do exist — refusing a ticket transfer to someone too young, refusing a second scan of a ticket — apply the rules described in these policies; you can always write to us about them.

## 16. Photos and files
Photos (profile pictures, event images, post photos) are stored in cloud storage in Montréal. Anyone who obtains a photo's web address can view it without signing in, and those addresses are not designed to be secret. Treat a photo you publish as reachable by anyone who receives its link.

## 17. How long we keep information
See the Data Retention Policy.

## 18. Your rights
Under PIPEDA — and under Law 25 if you live in Quebec — you can exercise the rights below. Write to contact@happynevents.com. We respond within 30 days, and may first ask you to confirm your identity, so that we never send your information to someone else.
- See the information we hold about you. Most of it is in the app; for a complete copy, write to us.
- Correct it, by editing your profile or by writing to us.
- Get a copy in a structured, commonly used format.
- Withdraw consent and delete your account, in Settings (see the Account Deletion Policy), or delete individual posts and comments.
- Stop location use, by switching "Near me" to a city or turning location off in your phone's settings.
- Stop notifications, in your phone's settings.
- Complain to the Office of the Privacy Commissioner of Canada, or, if you live in Quebec, to the Commission d'accès à l'information du Québec.

## 19. Security
No system is perfectly secure. If a breach creates a real risk of significant harm, we will notify you, the Office of the Privacy Commissioner of Canada and — where Quebec residents are affected — the Commission d'accès à l'information du Québec, as the law requires.
- Access to every table is controlled by the database itself, not only by the app, and these rules are tested automatically.
- Passwords are hashed; nobody at HAPPYN can read them.
- QR codes are cryptographically signed and change every five minutes.
- On Android, screenshots and screen recording are blocked on the ticket screen. iOS offers no equivalent, but the code in a screenshot expires.
- Card details never reach our servers.

## 20. Children
HAPPYN is only for adults, 18 and older. If we learn that an account belongs to someone under 18, we delete it and the information attached to it.

## 21. Changes
We will notify you in the app at least 30 days before a material change to this policy takes effect, and ask you to accept the new version.
$legal$,
       version = 'Version 1.3', effective_date = current_date, updated_at = now()
 where slug = 'privacy';

update public.legal_document_translations
   set content = $legal$
## En bref
- Nous recueillons ce qu'il faut pour faire fonctionner HAPPYN : les renseignements de votre compte, ce que vous publiez, vos billets et votre utilisation des fonctions sociales.
- Nous ne vendons pas vos renseignements. Il n'y a pas de publicité de tiers dans HAPPYN, et nous ne vous suivons pas dans d'autres applications ou sites Web.
- Votre adresse courriel et votre date de naissance ne sont jamais montrées à personne. Votre nom, nom d'utilisateur, photo, bio et ville sont visibles par les autres membres.
- Votre position n'est utilisée que si vous activez « Autour de moi », pour trouver des événements près de vous. Elle n'est jamais montrée à personne.
- Personne ne peut voir à quels événements vous allez, sauf si vous vous suivez mutuellement et que vous choisissez de le montrer.
- Notre base de données est à Montréal, au Canada. Certains de nos fournisseurs (paiements, courriels, rapports de plantage, notifications) sont aux États-Unis.
- Vous pouvez consulter, corriger, obtenir une copie et supprimer vos renseignements. La suppression de votre compte se fait dans les Réglages.
- Après un événement où votre billet a été scanné à l'entrée, vous pouvez le noter. L'organisateur voit votre note sans savoir qu'elle vient de vous ; le public ne voit que la moyenne d'un organisateur, à partir de 5 notes.

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
- Les notes que vous donnez à un événement : le nombre d'étoiles, les tags que vous choisissez, votre commentaire facultatif et la date — pour aider l'organisateur à s'améliorer et les autres membres à choisir. Seule une personne dont le billet a été scanné à l'entrée peut noter, pendant une période limitée après l'événement.
- La demande de note que nous vous envoyons, une seule fois, 24 heures après la fin d'un événement auquel vous étiez.

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
Visible par les membres : la note moyenne d'un organisateur et le nombre de notes, à partir de 5 notes — jamais une note individuelle. Jamais visible par les autres membres : vos notes et vos commentaires sur les événements.

## 11. Ce que voient les organisateurs
Quand vous détenez un billet pour un événement, son organisateur peut voir, dans sa liste de participants, votre nom, votre photo de profil, votre type de billet, son état et la date à laquelle vous l'avez obtenu. Les organisateurs ne voient jamais votre adresse courriel ni votre date de naissance.
Pour un événement privé, l'adresse exacte n'est visible que par l'organisateur et les détenteurs de billets ; les autres membres ne voient que la ville.
Les organisateurs voient les notes, les tags et les commentaires laissés sur leurs événements, sans le nom, la photo ni aucun autre moyen d'identifier leurs auteurs.

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
$legal$,
       version = 'Version 1.3', updated_at = now()
 where slug = 'privacy' and locale = 'fr';

update public.legal_documents
   set content = $legal$
## In short
HAPPYN exists so people find things worth showing up for — and enjoy them safely. Be real, be respectful, post what you have the right to post, and respect people who don't want to be in your photos.

## What is not allowed
- Fake or misleading events: events that don't exist, that you have no right to sell tickets for, or whose description misrepresents what will happen.
- Harassment and hate: insults, threats, or degrading content aimed at someone; content attacking people because of race, ethnicity, national origin, religion, disability, sex, gender identity, sexual orientation, or age. This applies everywhere — posts, comments, and private messages.
- Sexual content: nudity and sexually explicit content. Any sexual content involving a minor is reported to the authorities.
- Violence: threats, glorifying violence, or content meant to intimidate.
- Impersonation: pretending to be another person, an organization, or an event you have nothing to do with.
- Illegal activity: selling regulated or prohibited goods (drugs, weapons, alcohol to minors…), or organizing activities that are illegal where they take place.
- Spam and manipulation: repeated unwanted content or messages, fake accounts, artificial likes or follows.
- Other people's privacy: publishing someone's personal information (address, phone number…), or photos of identifiable people who have asked you not to.

## Photos of other people
Events are social, and photos usually include other people. If someone asks you to remove a photo of them, remove it. If they report it, we may remove it ourselves.

## Private messages
Messages are for people who know each other — you can only message people you follow. Don't use them to sell, promote, or contact people who haven't asked to hear from you. If someone sends you something abusive, report the message and block the account.

## Ratings
A rating says how the event went, for the organizer and for people deciding whether to go.
- Rate what you experienced, honestly.
- No insults, harassment, hate or personal information about anyone in a comment.
- An organizer must not offer anything in exchange for a rating (free ticket, discount, gift), or pressure anyone to give a good one or remove a bad one.
- No fake accounts to rate.

Comments that break these rules can be reported and removed, like any other content.

## What happens if you break these rules
Depending on how serious it is: the content is removed, your account is suspended, or — for illegal content — the matter is reported to the authorities. You keep the tickets you have already paid for.

## Reporting and blocking
Every event, post, comment, message and account can be reported. Reports are reviewed by a person. You can also block an account: its posts and events disappear for you, and neither of you can message the other any more.
$legal$,
       version = 'Version 1.1', effective_date = current_date, updated_at = now()
 where slug = 'community';

update public.legal_document_translations
   set content = $legal$
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

## Les notes
Une note sert à dire comment s'est passé l'événement, pour l'organisateur et pour ceux qui hésitent.
- Notez ce que vous avez vécu, honnêtement.
- Pas d'insultes, de harcèlement, de propos haineux ni de renseignements personnels sur quelqu'un dans un commentaire.
- Un organisateur ne doit rien offrir en échange d'une note (billet gratuit, rabais, cadeau), ni faire pression sur qui que ce soit pour en obtenir une bonne ou en faire retirer une mauvaise.
- Pas de faux comptes pour noter.

Les commentaires qui enfreignent ces règles peuvent être signalés et retirés, comme tout autre contenu.

## Si vous enfreignez ces règles
Selon la gravité : le contenu est retiré, votre compte est suspendu, ou — pour un contenu illégal — l'affaire est signalée aux autorités. Vous conservez les billets que vous avez déjà payés.

## Signaler et bloquer
Chaque événement, publication, commentaire, message et compte peut être signalé. Les signalements sont examinés par une personne. Vous pouvez aussi bloquer un compte : ses publications et ses événements disparaissent pour vous, et aucun de vous deux ne peut plus écrire à l'autre.
$legal$,
       version = 'Version 1.1', updated_at = now()
 where slug = 'community' and locale = 'fr';

update public.legal_documents
   set content = $legal$
## In short
We keep information only as long as it is needed for the reason we collected it, then delete it or remove your identity from it.

## Retention
PIPEDA requires keeping personal information only as long as needed for its purpose; Law 25 requires destroying or anonymizing it once that purpose is fulfilled.
- Account and profile, including your date of birth: as long as the account exists.
- Posts, photos and comments: until you delete them or your account.
- Private messages: as long as at least one of the two people has an account.
- Saved "Near me" location: on your phone only, until you change it.
- Location sent for a search: not stored.
- Tickets and payment records: as long as accounting and tax law require, without your identity if you deleted your account.
- Attendance records: deleted with the ticket or the account.
- Reports and moderation actions: as long as needed to explain and review decisions.
- Information concerning illegal content: as long as the law requires.
- Email delivery logs, crash reports and performance data: kept by our providers (Resend, Sentry) for a limited period set in their service, to deliver emails and fix defects.
- Backups: kept for a limited period by our database provider, then overwritten.
- Event ratings: as long as the event exists. If you delete your account, your rating still counts in the average, with no link to you.

$legal$,
       version = 'Version 1.1', effective_date = current_date, updated_at = now()
 where slug = 'data-retention';

update public.legal_document_translations
   set content = $legal$
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
- Notes d'événement : tant que l'événement existe. Si vous supprimez votre compte, votre note reste comptée dans la moyenne, sans aucun lien avec vous.

$legal$,
       version = 'Version 1.1', updated_at = now()
 where slug = 'data-retention' and locale = 'fr';

update public.legal_documents
   set content = $legal$
## In short
- Delete your account in Settings → Delete my account. No reason needed, no email to write.
- Before anything happens, HAPPYN shows you exactly what will be affected.
- If money is still involved, deletion waits — so that nobody loses money: not you, not the people who bought your tickets.
- Your profile, posts, comments, likes and follows are deleted. Records others depend on (tickets, past events, messages you sent) are kept without your name.
- Deletion is final: the account cannot be recovered.

## 1. What you see first
Before anything is deleted, HAPPYN shows you how many events you organize (and which will be cancelled), how many tickets you hold, and how many posts you have published. Nothing is deleted until you confirm.

## 2. When deletion has to wait
To make sure nobody loses money, deletion is refused while:
- you hold a paid ticket for an event that hasn't happened yet — cancel it (refunded if the deadline allows) or transfer it first;
- you have sold paid tickets for an event that hasn't happened yet — cancel the event first, and buyers are refunded automatically;
- you have ticket sales not yet paid out to you — wait for the payout.

## 3. What is deleted
- Your profile: name, username, photo, bio, city, interests, date of birth, language.
- Your posts and their photos, and your comments.
- Your likes, follows (both ways), saved events and blocks.
- Your attendance records and notification tokens.
- Your sign-in credentials — the account cannot be recovered.
- Free tickets for upcoming events; the place goes back on sale.
- Upcoming events you organized that have no participants.

## 4. What is cancelled
Upcoming events you organized that have participants are cancelled. Every participant is notified, and refunded in full if they paid.

## 5. What is kept, without your identity
- Past, used or cancelled tickets — needed for accounting.
- Past events you organized, shown as "Deleted organizer" — people who attended still see them in their history.
- Private messages you sent, kept with their recipients and shown as "Deleted account" — a message belongs to its recipient too, and may be evidence in a report. A conversation is deleted for good once both people have deleted their accounts.
- Reports you submitted.
- Reports about your content, and moderation actions — an account cannot erase its record by leaving.
- If you organized paid events, your Stripe payout account is disconnected from HAPPYN; Stripe keeps its own records under its own obligations.
- Your event ratings, which still count in the organizer's average with no link to you.

## 6. Deleting just one thing
You don't need to delete your account to remove something:
- you can delete a post or a comment at any time;
- you can cancel a ticket until the organizer's deadline;
- you can cancel an event you organize — buyers are refunded automatically;
- you cannot delete a private message once sent (see the Privacy Policy).
$legal$,
       version = 'Version 1.1', effective_date = current_date, updated_at = now()
 where slug = 'account-deletion';

update public.legal_document_translations
   set content = $legal$
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
- Vos notes d'événement, qui restent comptées dans la moyenne de l'organisateur sans aucun lien avec vous.

## 6. Supprimer une seule chose
Pas besoin de supprimer votre compte pour retirer quelque chose :
- vous pouvez supprimer une publication ou un commentaire à tout moment ;
- vous pouvez annuler un billet jusqu'à la date limite de l'organisateur ;
- vous pouvez annuler un événement que vous organisez — les acheteurs sont remboursés automatiquement ;
- vous ne pouvez pas supprimer un message privé une fois envoyé (voir la politique de confidentialité).
$legal$,
       version = 'Version 1.1', updated_at = now()
 where slug = 'account-deletion' and locale = 'fr';

update public.legal_documents
   set content = $legal$
## In short
- You must be 18 or older to create events.
- Describe your event honestly, keep it up to date, and run it as described.
- You are responsible for the event itself: legality, safety, permits, insurance.
- To sell paid tickets, open a Stripe payout account. You're paid after the event, minus HAPPYN's 5% fee.
- If you cancel, use the Cancel button: buyers are refunded automatically.

## 1. Who can organize
Creating events requires being 18 or older and accepting these standards. Selling paid tickets also requires a Stripe payout account in your name, where Stripe verifies your identity and bank details.

## 2. Your responsibilities
- Describe your event accurately: date, time, location, price, what's included, and any age limit. If something important changes, update the event — ticket holders are notified automatically when the date, time or place changes.
- You are responsible for the event itself: its legality, safety, permits, insurance, and how it runs. HAPPYN provides ticketing and visibility; it does not co-organize.
- Check age at the door if you set an age limit. HAPPYN stops people below it from buying, but doesn't verify identity.
- Choose your cancellation deadline honestly (24 hours, 48 hours, 7 days, or none). Buyers see it before paying, and it applies automatically. When a buyer cancels, the payment provider's fee is paid by the buyer, not by you.
- Answer buyers within 7 days.
- Cancel properly. If the event won't happen, use the Cancel function: sales stop, every buyer is refunded in full automatically, and everyone is notified. Don't just stop responding.

## 3. If you cancel an event
Every buyer is refunded in full. The payment provider's fees on those tickets (2.9% + $0.30 each) are not returned by the provider, and may be deducted from your payouts.

## 4. Private events
A private event never appears in Discover or in "Near me". It can only be reached with the invitation code you share, and its exact address is visible only to you and to ticket holders.
You also choose whether posts about it are visible to everyone or only to ticket holders. Choose deliberately: if posts are public, your event's name and date become public with them.

## 5. Your attendees
For each of your events, you can see the list of ticket holders: name, profile photo, ticket type, status, and purchase time. You never see their email address or date of birth. Use this list only to run your event — never to contact people for other purposes, or to share it.
- After the event, attendees whose ticket was scanned can rate it. You see their ratings, tags and comments without knowing who wrote them. You cannot delete them — only report them if they break the Community Guidelines. Offering anything in exchange for a rating is not allowed.

## 6. Payouts
- HAPPYN's fee is 5% of each ticket's price. The rate when you create an event applies to that event.
- Your share is paid to your Stripe account 7 days after the event has ended.
- Your first payout goes through a check on our side.
- If a ticket is refunded, its amount is not paid out.
- HAPPYN may hold a payout while it checks that an event took place as described — for example when no ticket was scanned at the door, or for your first events.

## 7. What we may do
We may unpublish events that break these standards, hold payouts while we investigate, and suspend organizers who repeatedly break them or defraud buyers.
$legal$,
       version = 'Version 1.1', effective_date = current_date, updated_at = now()
 where slug = 'organizer';

update public.legal_document_translations
   set content = $legal$
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
- Après l'événement, les participants dont le billet a été scanné peuvent le noter. Vous voyez leurs notes, leurs tags et leurs commentaires, sans savoir qui les a écrits. Vous ne pouvez pas les supprimer — seulement les signaler s'ils enfreignent les règles de la communauté. Offrir quoi que ce soit en échange d'une note est interdit.

## 6. Les versements
- Les frais de HAPPYN sont de 5 % du prix de chaque billet. Le taux en vigueur à la création de l'événement s'applique à cet événement.
- Votre part est versée sur votre compte Stripe 7 jours après la fin de l'événement.
- Votre premier versement passe par une vérification de notre part.
- Si un billet est remboursé, son montant ne vous est pas versé.
- HAPPYN peut retenir un versement le temps de vérifier qu'un événement a bien eu lieu comme annoncé — par exemple quand aucun billet n'a été lu à l'entrée, ou pour vos premiers événements.

## 7. Ce que nous pouvons faire
Nous pouvons dépublier les événements qui enfreignent les présentes normes, retenir des versements pendant une vérification et suspendre les organisateurs qui les enfreignent de façon répétée ou qui fraudent les acheteurs.
$legal$,
       version = 'Version 1.1', updated_at = now()
 where slug = 'organizer' and locale = 'fr';

update public.legal_documents
   set content = $legal$
## In short
- Payments are processed by Stripe. Your card details go straight to Stripe and never reach HAPPYN.
- The price you see is the price you pay, in Canadian dollars. HAPPYN's fee is taken from the organizer's share, not added to your price.
- Your ticket appears as soon as Stripe confirms the payment.
- If you cancel a ticket yourself, a small service fee is not refunded. If the organizer cancels, you get everything back.
- Organizers are paid after their event has taken place.

## 1. How payment works
Payments are processed by Stripe, a regulated payment provider. Your card number, expiry date and security code are entered in Stripe's payment form and go directly to Stripe: they never reach HAPPYN's servers. We keep only that a payment succeeded, its amount, its date, and Stripe's reference for it.

## 2. The price
- The price shown is the total you pay, in Canadian dollars.
- There is no service fee added at checkout. HAPPYN's fee is deducted from the organizer's share.
- You can buy several tickets of the same type in one payment.
- Before you pay, the screen shows until when you can cancel, and the service fee that would not be refunded.

## 3. When your ticket appears
Our servers issue your ticket as soon as Stripe confirms the payment — usually immediately. If confirmation takes longer, the app tells you, and the ticket appears in My Tickets as soon as it arrives.
A charge without a ticket is always corrected: write to contact@happynevents.com with the date and amount.

## 4. Who you are paying
You are paying for a ticket to an event run by its organizer. HAPPYN collects the payment on the organizer's behalf through Stripe, and passes it on minus our fee.

## 5. How organizers are paid
- To sell paid tickets, an organizer first opens a Stripe payout account from HAPPYN, where Stripe verifies their identity and bank details. A paid event cannot be published until that account can receive money.
- HAPPYN's fee is 5% of the ticket price. The rate in force when the event is created applies to that event, even if the rate changes later.
- The organizer's share is paid 7 days after the event has ended. The waiting period allows refunds to be handled and checks that the event really took place.
- HAPPYN may hold a payout while it checks an event — for example, when no ticket was scanned at the door, or for an organizer's first events.

## 6. Failed payments and duplicates
If your payment fails, you are not charged and no ticket is issued. If you are charged twice, or charged without receiving a ticket, write to us: we investigate, and always refund duplicates and charges without tickets in full.
$legal$,
       version = 'Version 1.1', effective_date = current_date, updated_at = now()
 where slug = 'payments';

update public.legal_document_translations
   set content = $legal$
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
- La part de l'organisateur lui est versée 7 jours après la fin de l'événement. Cette période permet de traiter les remboursements et de vérifier que l'événement a bien eu lieu.
- HAPPYN peut retenir un versement le temps de vérifier un événement — par exemple quand aucun billet n'a été lu à l'entrée, ou pour les premiers événements d'un organisateur.

## 6. Paiements refusés et doublons
Si votre paiement échoue, vous n'êtes pas débité et aucun billet n'est émis. Si vous êtes débité deux fois, ou débité sans recevoir de billet, écrivez-nous : nous vérifions, et remboursons toujours en entier les doublons et les paiements sans billet.
$legal$,
       version = 'Version 1.1', updated_at = now()
 where slug = 'payments' and locale = 'fr';
