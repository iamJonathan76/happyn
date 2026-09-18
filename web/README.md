# HAPPYN — Site vitrine

Landing page publique de HAPPYN. Elle sert deux buts, dans cet ordre
d'importance :

1. **Débloquer la publication sur les stores.** Apple et Google exigent une URL
   publique de politique de confidentialité. C'est le seul livrable de ce
   dossier qui soit un vrai bloquant.
2. Présenter l'app avant sa sortie (pitch, captures, badges stores, contact).

Site 100 % statique : pas de build, pas de framework, pas de `node_modules`.
Du HTML, du CSS et un fichier JS. C'est volontaire — moins il y a de machinerie,
moins il y a à maintenir sur une page que les stores vont auditer.

## Lancer en local

Ouvrir `index.html` directement dans le navigateur **ne marche pas** : le
`fetch()` de la copie locale des documents légaux est bloqué en `file://`.
Il faut un serveur, n'importe lequel :

```bash
cd web
python -m http.server 8000
# puis http://localhost:8000
```

## Structure

```
web/
├── index.html                     Accueil : billet animé, parcours, galerie,
│                                  confiance, organisateurs, liste d'attente
├── legal.html                     Pages légales — ?doc=privacy, ?doc=terms, …
├── reset.html                     Réinitialisation du mot de passe
├── assets/
│   ├── css/styles.css             Toute la mise en forme
│   ├── fonts/                     Poppins + Inter, hébergées ici (voir § Polices)
│   ├── js/i18n.js                 Dictionnaire FR/EN + bascule de langue
│   ├── js/site.js                 Accueil : billet animé, galerie, liste d'attente
│   ├── js/config.js               URL + clé anon Supabase, email support
│   ├── js/legal.js                Chargement et rendu des documents légaux
│   ├── js/reset.js                Échange du jeton + nouveau mot de passe
│   ├── data/legal-fallback.json   Copie locale — GÉNÉRÉE, ne pas éditer
│   ├── img/screens/               Captures de l'app pour la galerie
│   ├── img/og-card.png            Aperçu au partage (1200×630)
│   ├── img/happyn-mark.svg        Le « H » détouré (header, favicon)
│   └── img/happyn.png             Icône pleine (apple-touch-icon)
└── tools/sync-legal-fallback.mjs  Régénère la copie locale depuis la base
```

## Bilingue

Tout le texte des trois pages vit dans `assets/js/i18n.js`, en français et en
anglais. Le HTML est écrit en anglais ; chaque élément traduisible porte
`data-i18n="clé"` (son texte) ou `data-i18n-attr="attribut:clé"` (un
placeholder, un aria-label…).

**Ajouter ou changer un texte :** modifier la clé dans les DEUX langues de
`i18n.js`. Une clé absente en français retombe sur l'anglais — pas de trou,
mais une phrase anglaise au milieu d'une page française.

La langue suit, dans l'ordre : `?lang=fr` dans l'adresse, puis le choix fait
avec le sélecteur (mémorisé sur l'appareil), puis la langue du navigateur.

Les **documents légaux** eux-mêmes restent dans la langue de la base —
l'anglais pour l'instant. En français, la page le dit franchement
(`legal.englishOnly`). Le jour où les versions françaises existent en base,
vider cette clé.

## Captures d'écran (galerie)

Déposer les fichiers dans `assets/img/screens/`, **sous ces noms exacts** :

| fichier         | écran                                  |
| --------------- | -------------------------------------- |
| `home.png`      | Accueil — « Bientôt »                  |
| `event.png`     | La fiche d'un événement, avec « qui y va » |
| `ticket.png`    | Le billet QR                           |
| `moments.png`   | Les Moments                            |
| `people.png`    | La recherche de personnes              |
| `dashboard.png` | Le tableau de bord organisateur        |

Rien d'autre à modifier : tant qu'un fichier manque, son emplacement affiche
un écran squelette, et l'image apparaît d'elle-même dès qu'elle existe.
Format portrait de téléphone (≈ 9 × 19,5). Du **vrai contenu** : des
événements réalistes, pas « test test » — ces images sont la preuve que l'app
existe.

## Liste d'attente

Les deux formulaires de l'accueil (`name="waitlist"`) sont reçus par
**Netlify Forms** — aucun serveur, aucune clé.

**À activer une fois dans Netlify** (sinon les inscriptions sont perdues) :
Site configuration → Forms → *Enable form detection*, puis redéployer. Le
formulaire « waitlist » doit alors apparaître dans l'onglet Forms. Y régler
aussi une notification par courriel à chaque inscription.

**Loi canadienne anti-pourriel (LCAP).** Le consentement doit être exprès et
prouvable. D'où :

- une case à cocher, **jamais pré-cochée**, sans laquelle rien n'est envoyé ;
- le champ `consent_text` : la phrase exacte acceptée, dans la langue de la
  personne. Netlify horodate l'envoi ; les deux ensemble sont la preuve ;
- tout courriel envoyé plus tard doit dire qui écrit (HAPPYN, adresse
  postale) et offrir un désabonnement qui fonctionne.

Les inscriptions sont stockées chez Netlify (États-Unis). La politique de
confidentialité doit le mentionner **avant** d'ouvrir la liste — voir
`docs/LEGAL-DRAFT.md`.

## Polices

Poppins (titres) et Inter (texte), comme l'app. Elles sont **hébergées sur le
site** : la politique de sécurité de `netlify.toml` (`default-src 'self'`)
bloquerait Google Fonts sans le moindre message. Fichiers attendus dans
`assets/fonts/` :

- `poppins-600.woff2`, `poppins-700.woff2`, `poppins-800.woff2`
- `inter-var.woff2` (Inter variable, graisses 400 à 700)

Toutes deux sont sous licence SIL Open Font License : libres d'hébergement.
Sans ces fichiers, le site retombe sur la police système — lisible, mais ce
n'est plus la marque.

## Aperçu au partage

`assets/img/og-card.png` est l'image affichée quand on partage le lien
(WhatsApp, iMessage, réseaux). Elle porte les deux langues, parce que les
robots de ces services n'exécutent pas le JavaScript. Les balises `og:image`
utilisent une adresse **absolue** : un chemin relatif n'est pas résolu, et
l'aperçu s'affichait sans image.

## Le contenu légal

La source unique de vérité est la table **`legal_documents`** dans Supabase.
La lecture est publique, donc le site n'a besoin d'aucun secret : la clé anon,
déjà publique, suffit.

Schéma réel de la table :

| colonne               | type          | note                                        |
| --------------------- | ------------- | ------------------------------------------- |
| `slug`                | `text`        | clé utilisée dans l'URL : `?doc=privacy`    |
| `title`               | `text`        | titre affiché                               |
| `content`             | `text`        | **markdown simplifié** (voir plus bas)      |
| `version`             | `text`        | ex. `Version 1.1`                           |
| `effective_date`      | `date`        | date affichée — c'est elle qui engage       |
| `requires_acceptance` | `boolean`     | utilisé côté app, pas par le site           |
| `sort_order`          | `int`         | ordre d'affichage                           |
| `updated_at`          | `timestamptz` |                                             |

Le markdown accepté est volontairement pauvre, et `legal.js` le rend à la main
sans bibliothèque :

- `## Titre` → un sous-titre
- `- élément` → une puce
- toute autre ligne → un paragraphe
- une ligne vide sépare les blocs

### Modifier une phrase

1. Éditer la ligne dans la table `legal_documents` (SQL Editor), et penser à
   monter `version` / `effective_date` si le changement est substantiel.
2. Régénérer la copie locale, puis committer le JSON obtenu :
   ```bash
   node web/tools/sync-legal-fallback.mjs
   ```

### Pourquoi une copie locale

Si la page de confidentialité dépendait uniquement d'un appel réseau, une base
momentanément indisponible pendant la revue du store = page vide = revue
refusée. `assets/data/legal-fallback.json` est servi uniquement quand la base ne
répond pas. Il est **généré** par le script ci-dessus : l'éditer à la main
serait écrasé à la prochaine exécution, et surtout ferait diverger les deux.

## Déploiement

Hébergement gratuit, au choix — la configuration est déjà à la racine du dépôt :

- **Netlify** → `netlify.toml`, publie `web/`
- **Vercel** → `vercel.json`, `outputDirectory: web`

Brancher le dépôt et déployer : il n'y a rien à configurer de plus. Les deux
fichiers posent aussi les en-têtes de sécurité (CSP, `X-Frame-Options`…), avec
Supabase comme seule destination réseau autorisée.

## Ce qu'il reste à faire

- [ ] **Captures d'écran.** Voir § Captures d'écran : six fichiers à déposer.
- [ ] **Polices.** Voir § Polices : quatre fichiers à déposer.
- [ ] **Liste d'attente.** Activer la détection des formulaires dans Netlify,
      et mettre à jour la politique de confidentialité EN BASE avant.
- [ ] **Liens stores.** Toujours en « Bientôt disponible ». Renseigner
      `appStoreUrl` / `playStoreUrl` dans `config.js` une fois les apps
      publiées, et activer les badges.

## Deux écarts constatés, hors périmètre de ce dossier

Trouvés en branchant le site sur la base — à traiter côté app, pas ici :

1. **L'app affiche du texte légal périmé.** `lib/core/legal/legal_content.dart`
   est figé en v1.0 et annonce « at least 13 years old ». La base est en v1.1
   (effective 2026-07-23), dit « at least 14 years old », ajoute une section
   *Minors* et des exigences d'âge pour les organisateurs. Elle contient aussi
   trois documents absents du Dart : `payments`, `fraud-prevention` et
   `data-retention`. Tant que l'app lit son fichier Dart, elle affiche autre
   chose que le site et que la base.

2. **La table n'est versionnée dans aucune migration.** Elle existe en
   production mais rien dans `supabase/migrations/` ne la crée : un nouveau
   projet Supabase repartirait sans elle. Il manque une migration qui documente
   son schéma — à écrire par qui connaît le DDL d'origine, pour ne pas
   reconstruire de travers.

## Règle des secrets

Comme dans l'app : **uniquement des clés publiques dans ce dossier.** La clé
`anon` de Supabase est conçue pour être exposée au client. Tout le reste — clé
`service_role`, secrets Stripe, secret HMAC des QR codes — reste dans les
secrets Supabase et ne doit jamais apparaître ici. Ce site est statique et
public : tout ce qui y est écrit est lisible par n'importe qui.
