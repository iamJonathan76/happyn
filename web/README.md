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
├── index.html                     Landing (hero, features, organisateurs, contact)
├── legal.html                     Pages légales — ?doc=privacy, ?doc=terms, …
├── assets/
│   ├── css/styles.css             Toute la mise en forme
│   ├── js/config.js               URL + clé anon Supabase, email support
│   ├── js/legal.js                Chargement et rendu des documents légaux
│   ├── data/legal-fallback.json   Copie locale — GÉNÉRÉE, ne pas éditer
│   ├── img/happyn-mark.svg        Le « H » détouré (header, favicon)
│   └── img/happyn.png             Icône pleine (aperçu social, apple-touch-icon)
└── tools/sync-legal-fallback.mjs  Régénère la copie locale depuis la base
```

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

- [ ] **Captures d'écran.** `index.html` affiche un emplacement rayé à la place
      du téléphone. Prendre les captures de l'app, les mettre dans
      `assets/img/`, et remplacer le `<div class="screenshot-slot">` par une
      balise `<img>` (le commentaire dans le HTML indique où).
- [ ] **Domaine.** Le handbook annonce `happyn.com`. À vérifier / acheter — ça
      conditionne l'URL déclarée aux stores et l'adresse support.
- [ ] **Email support.** `assets/js/config.js` contient `support@happyn.com`,
      qui n'existe pas encore. Un seul endroit à changer.
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
