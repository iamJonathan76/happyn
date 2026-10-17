# Brief — vidéo promotionnelle HAPPYN (animation 2D)

Ce document suffit pour réaliser la vidéo sans autre contexte. Il dit ce
qu'est HAPPYN, à quoi la vidéo doit ressembler, où trouver chaque élément
visuel, et ce qu'il ne faut jamais montrer ni affirmer.

**Ce que la personne fournit en plus :** le fichier de la voix off, avec si
possible un minutage par section. La voix off suit le script de la section 6 ;
si elle s'en écarte, c'est l'audio qui fait foi.

---

## 1. HAPPYN en une phrase

Une app mobile gratuite (iPhone et Android) pour découvrir les événements
d'Ottawa–Gatineau, réserver son billet en quelques secondes, entrer avec un
billet impossible à copier, et revivre la soirée avec ceux qui y étaient.

- **Slogan :** « Trouve les bons. Vis l'instant. » / « Find the ones. Be the moment. »
- **Territoire :** Ottawa et Gatineau, rien d'autre (ni Montréal, ni Toronto).
- **Public :** jeunes adultes qui sortent (18+), et les organisateurs
  d'événements.
- **Langues :** français et anglais.

## 2. Le problème et le besoin

- **Le problème :** les événements sont éparpillés (stories qui disparaissent,
  groupes privés, bouche-à-oreille). On les découvre trop tard. Et un billet
  envoyé en capture d'écran peut être copié et revendu.
- **Le besoin :** savoir ce qui se passe près de chez soi, y aller sans stress,
  et retrouver ceux qui y étaient.

## 3. Ce que l'app fait vraiment

Ne montrer que ces fonctions : elles existent. N'en inventer aucune autre.

| Fonction | Ce qu'on peut montrer |
|---|---|
| Découvrir | Accueil avec recherche, catégories (soirées, musique, sport, bouffe, tech…) et liste d'événements avec la ville |
| Réserver | Choix du billet, paiement en quelques secondes |
| Le billet | Code QR qui se renouvelle toutes les quelques secondes, avec une barre de décompte : une capture d'écran ne passe pas la porte |
| Offrir | Envoyer un billet à un ami (« Léa t'a envoyé un billet ») |
| Moments | Photos et publications partagées avec les gens qui étaient à l'événement ; grille sur le profil |
| Notes | Seules les personnes dont le billet a été scanné peuvent noter un événement ; la moyenne apparaît sur le profil de l'organisateur |
| Organisateurs | Créer un événement, vendre des billets, scanner à l'entrée, être payé |
| Itinéraire | Ouvrir l'adresse dans Plans, Google Maps ou Waze |

**Chiffres exacts, si on en parle :**
- **Frais :** HAPPYN prend 5 % par billet vendu, plus les frais de paiement de Stripe. Exemple du site : un billet de 20 $ rapporte 18,12 $ à l'organisateur, après 0,88 $ de Stripe et 1,00 $ de HAPPYN.
- **Versement à l'organisateur :** 7 jours après la fin de l'événement.
- **Réponse du soutien :** 2 jours ouvrables.

## 4. Style visuel

**Ambiance :** nuit, sortie, énergie. Fond sombre, accents violet-rose
lumineux, beaucoup de mouvement. Ni corporate, ni enfantin.

**Couleurs** (source : `~/Projects/happyn-site-v2/web/assets/css/v2.css`, bloc `:root`) :

| Rôle | Valeur |
|---|---|
| Fond | `#08080f` |
| Surfaces (cartes, écrans) | `#13111c`, `#1a1535` |
| Violet principal | `#7c3aed` |
| Rose | `#ec4899` |
| Dégradé signature | `linear-gradient(90deg, #7c3aed, #ec4899)` |
| Lavande (textes secondaires accentués) | `#a78bfa`, `#c4b5fd` |
| Texte | `#ffffff`, secondaire `#b0a8d4` |
| Succès (billet validé) | `#34d399` |

**Polices** (fichiers dans `~/Projects/happyn-site-v2/web/assets/fonts/`) :
- Titres : **Poppins** 700–800, interlettrage légèrement serré ;
- Texte : **Inter**.

**Logo** (dossier `web/assets/img/`) :
- `happyn-mark.svg` : le symbole « H » en dégradé ;
- `happyn.png` : l'icône de l'app ;
- `og-card.png` : la carte de partage, utile comme référence de mise en page.

## 5. Écrans de l'app à reprendre

Les écrans sont déjà dessinés en HTML/CSS, avec des données fictives, dans la
page d'accueil du nouveau site :
**`~/Projects/happyn-site-v2/web/index.html`** (branche `site-v2`), avec ses
styles `.screen` et `.s-*` dans `v2.css`. Pour les voir en mouvement :
`python3 -m http.server 5175 --directory ~/Projects/happyn-site-v2/web`, puis
<http://localhost:5175>.

- **Accueil :** « Bonsoir, Léa », recherche, catégories, événements fictifs
  (Nuit Violette, Jazz sur le canal…).
- **Billet :** code QR animé qui se renouvelle, barre de décompte « Nouveau
  code dans 6 s ».
- **Billet offert :** carte « Léa t'a envoyé un billet ».
- **Profil :** Inès, ★ 4,8, grille de Moments animée.
- **Frais :** carte « 20 $ → 18,12 $ ».

La maquette d'origine se trouve dans
`~/Projects/happyn-site-v2/design/site-predesign/index.html`.
**Attention :** ses images `home.jpg`, `grid.jpg` et `feed.jpg` sont de vraies
captures avec de vraies données. Elles servent de référence de mise en page
seulement et ne doivent **jamais** apparaître dans la vidéo.

## 6. Le script (environ 75 s)

| # | Temps | Image | Voix off | Texte à l'écran |
|---|---|---|---|---|
| 1 | 0:00–0:06 | Vendredi soir, quelqu'un fait défiler stories, groupes, captures ; soupir | « Vendredi soir. Il se passe quelque chose quelque part… mais où ? » | *Il se passe quoi ce soir ?* |
| 2 | 0:06–0:18 | Story qui disparaît, message « c'était hier 😭 », billet en capture transféré à trois personnes | « Les événements sont partout et nulle part : une story qui disparaît, un groupe dont tu n'as jamais entendu parler. Tu l'apprends le lendemain. Et quand tu trouves un billet, c'est une capture d'écran que n'importe qui peut copier. » | *Éparpillé. Raté. Copié.* |
| 3 | 0:18–0:24 | Le téléphone posé, la ville la nuit | « Ce qu'on veut, c'est simple : savoir ce qui se passe près de chez nous, y aller sans stress, et retrouver ceux qui y étaient. » | — |
| 4 | 0:24–0:28 | Logo sur fond violet | « Voici HAPPYN. » | *HAPPYN — Trouve les bons. Vis l'instant.* |
| 5a | 0:28–0:34 | Écran d'accueil, catégories | « Tous les événements d'Ottawa–Gatineau, au même endroit. Tu choisis ton style, tu trouves ta soirée. » | — |
| 5b | 0:34–0:37 | Appui sur « Acheter », paiement confirmé | « Tu réserves en quelques secondes. » | — |
| 5c | 0:37–0:44 | Billet au QR qui se renouvelle, scan à l'entrée, validation verte | « Ton billet a un code qui change toutes les quelques secondes : une capture d'écran ne passe pas la porte. Le tien, si. » | — |
| 5d | 0:44–0:47 | Carte « Léa t'a envoyé un billet » | « Et tu peux même offrir un billet à un ami. » | — |
| 5e | 0:47–0:52 | Grille de Moments | « Après la soirée, les Moments : tu revis l'instant avec ceux qui étaient là. » | — |
| 6 | 0:52–1:04 | Organisatrice : billets vendus, entrées scannées, note ★ 4,8 | « Tu organises ? Crée ton événement, vends tes billets, scanne à l'entrée. Des frais clairs, un versement 7 jours après l'événement, et des notes laissées uniquement par les gens qui étaient vraiment là. » | *Frais clairs · Versement en 7 jours · Avis vérifiés* |
| 7 | 1:04–1:15 | La personne du début dans la foule, fondu sur le logo | « Moins de temps à chercher. Plus de temps à vivre. HAPPYN, gratuit sur iPhone et Android. » | *HAPPYN — Bientôt sur l'App Store et Google Play · Ottawa · Gatineau · 18+* |

Les temps sont indicatifs. Le minutage réel vient de la voix off.

## 7. Règles

**Ce qu'il ne faut jamais faire :**
- **Nommer ou montrer un concurrent** : aucune marque, aucun logo d'une autre plateforme de billetterie ou de réseau social.
- **Utiliser de vraies données** : pas de vrais événements, de vrais noms, de vraies photos de profil ni de captures de la vraie app.
- **Inventer des chiffres** : rien comme « des milliers d'événements » ou « 10 000 utilisateurs ». On n'en a pas encore.
- **Inventer des avis ou des notes présentés comme réels.** La note ★ 4,8 d'Inès est une simulation et doit le rester visiblement : on la montre dans l'interface, jamais comme un témoignage client.
- **Promettre autre chose qu'Ottawa–Gatineau.**

**Ce qu'il faut toujours faire :**
- **Garder « 18+ »** visible à la fin.
- **Choisir la bonne dernière ligne :**
  - avant la sortie sur les stores : « Bientôt sur l'App Store et Google Play » ;
  - après la sortie : « Télécharge HAPPYN sur l'App Store et Google Play ».
- **Garder une seule langue par version.** Une version française, et une version anglaise distincte si on en fait une : pas de mélange dans la même vidéo.

## 8. Musique et rythme

- **Musique :** calme et un peu frustrante pendant le problème (sections 1 à 3) ; elle monte, puis explose à l'apparition du logo (section 4).
- **Montage :** rapide et rythmé pendant les fonctions (section 5) ; plus posé sur l'appel à l'action final.
- **Format :** 16:9 pour le site et YouTube. Une déclinaison 9:16 pour Instagram et TikTok est la bienvenue.
