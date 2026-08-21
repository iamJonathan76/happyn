# HAPPYN — Spécification du site web (landing)

Version 1.0 · Périmètre : **site vitrine + pages légales**.
Ce n'est **pas** une version web de l'application.

---

## 1. Objectif et contraintes

Le site a **deux rôles**, dans cet ordre d'importance :

1. **Débloquer la publication sur les stores.** Google Play et l'App Store
   exigent une **URL publique de politique de confidentialité**. Sans site, on
   ne peut pas publier. C'est le vrai livrable critique.
2. **Vendre l'app.** Présenter HAPPYN et envoyer les visiteurs télécharger
   l'application.

**Hors périmètre** (ne pas construire) : connexion utilisateur, achat de
billets, création d'événement, liste des événements. Tout ça reste dans l'app
mobile. Le site ne fait **que lire** du contenu public.

---

## 2. Stack

| Choix | Recommandation | Pourquoi |
|---|---|---|
| Framework | **Next.js** (ou HTML/CSS/JS statique) | Simple, rendu serveur pour le SEO, déploiement gratuit |
| Style | Tailwind ou CSS simple | Peu importe, tant que c'est propre et responsive |
| Hébergement | **Vercel** ou Netlify (offre gratuite) | Déploiement auto à chaque push |
| Emplacement | Dossier `web/` de ce repo | Zéro conflit avec `lib/` (fichiers disjoints) |

Contrainte : le site doit être **responsive** (mobile d'abord — la majorité du
trafic viendra de téléphones) et **rapide**.

---

## 3. Pages

### `/` — Accueil

| Section | Contenu |
|---|---|
| Hero | Logo HAPPYN, accroche **« More than events. A real community. »**, sous-titre, boutons de téléchargement |
| Fonctionnalités | 3–4 blocs : découverte d'événements · billetterie sécurisée (QR) · événements privés sur code · transfert de billet |
| Aperçu | Captures d'écran de l'app (Emmanuel les fournira) |
| Pour les organisateurs | Créer un événement, vendre des billets, scanner à l'entrée |
| Pied de page | Liens légaux, contacts, copyright |

**Boutons de téléchargement** : les applications ne sont pas encore publiées →
afficher les badges en état **« Bientôt disponible »** (désactivés). Ils
pointeront vers les stores plus tard.

### `/legal` — Index des documents

Liste tous les documents légaux, triés par `sort_order`.

### `/legal/[slug]` — Un document

Affiche un document légal. **Le contenu vient de la base de données**, il ne
doit jamais être recopié en dur dans le site (voir §4).

Slugs existants (11) :

```
terms · privacy · community · cookie · copyright · refund
payments · fraud-prevention · safety · organizer · data-retention
```

> `privacy` est le document dont l'URL sera donnée aux stores :
> `https://<domaine>/legal/privacy`

---

## 4. Source des données — `legal_documents`

**Règle absolue : une seule source de vérité.** Les textes légaux vivent dans
Supabase. L'app mobile **et** le site les lisent depuis la même table. Si
Emmanuel corrige une phrase en base, les deux se mettent à jour — sans
redéploiement.

### Accès

La table est en **lecture publique** (RLS `select` autorisé à `anon`). Aucun
secret n'est nécessaire : on utilise la clé **anon**, qui est publique par
conception.

```
GET https://jvjvuozvlzqqmcjanvnh.supabase.co/rest/v1/legal_documents
    ?select=*&order=sort_order.asc

Headers:
  apikey: sb_publishable_wkRU0rXDmrPaDyhP2b5Mdw_rkbXBrmO
  Authorization: Bearer sb_publishable_wkRU0rXDmrPaDyhP2b5Mdw_rkbXBrmO
```

Pour un seul document : `?slug=eq.privacy`

Alternative plus confortable : le SDK `@supabase/supabase-js`.

### Schéma

| Colonne | Type | Rôle |
|---|---|---|
| `slug` | text (PK) | Identifiant d'URL (`privacy`, `terms`…) |
| `title` | text | Titre affiché |
| `content` | text | Corps en **markdown léger** (voir ci-dessous) |
| `version` | text | Ex. « Version 1.1 » |
| `effective_date` | date | Date d'entrée en vigueur |
| `sort_order` | int | Ordre d'affichage |
| `updated_at` | timestamptz | Dernière modification |

### Format du `content`

Markdown volontairement minimal — trois règles seulement :

- `## Titre` → sous-titre de section
- `- élément` → puce
- Toute autre ligne non vide → paragraphe ; une ligne vide sépare les blocs

Un rendu markdown standard (`react-markdown`, `marked`…) fonctionne
parfaitement.

---

## 5. Identité visuelle

Reprendre exactement la charte de l'app (source :
`lib/core/theme/app_colors.dart`).

| Rôle | Hex |
|---|---|
| Fond principal | `#08080F` |
| Surface / carte | `#1A1535` |
| Violet (primaire) | `#7C3AED` |
| Rose (accent) | `#EC4899` |
| Lavande (liens, accents doux) | `#A78BFA` |
| Lavande claire | `#C4B5FD` |
| Texte principal | `#FFFFFF` |
| Texte secondaire | blanc à 65 % |

**Dégradé de marque** : `#7C3AED → #EC4899` (haut-gauche vers bas-droite).

**Typographie** : **Poppins** pour les titres (weights 700–900),
**Inter** pour le texte courant. Disponibles gratuitement sur Google Fonts.

**Ambiance** : sombre, premium, nocturne — cohérent avec l'app.

---

## 6. SEO et métadonnées

- `<title>` et `<meta description>` sur chaque page
- Balises Open Graph (`og:title`, `og:description`, `og:image`) pour un partage
  propre sur les réseaux
- Favicon depuis le logo HAPPYN (`assets/icon/happyn.png` dans le repo)
- Langue : **le site doit exister en français et en anglais** (marché
  Ottawa-Gatineau bilingue). L'app l'est déjà. À minima : sélecteur de langue
  sur l'interface du site. Les documents légaux restent en anglais pour
  l'instant (leur traduction est un travail juridique séparé).

---

## 7. Déploiement

1. Connecter le dépôt à Vercel/Netlify (racine du projet : `web/`)
2. Déploiement automatique à chaque merge sur `main`
3. Brancher le nom de domaine

> **Point bloquant à confirmer avec Emmanuel** : le nom de domaine
> (`happyn.com` ou autre) n'est pas encore acquis. Le site peut être développé
> et déployé sur une URL temporaire Vercel en attendant, mais l'URL définitive
> est nécessaire avant la soumission aux stores.

---

## 8. Définition du « terminé »

- [ ] Accueil complet et responsive (testé sur mobile **et** desktop)
- [ ] `/legal` liste les 11 documents, triés
- [ ] `/legal/[slug]` rend correctement le markdown de chaque document
- [ ] Le contenu vient **de la base**, aucun texte légal recopié en dur
- [ ] Une modification en base est visible sur le site sans redéploiement
- [ ] `https://<domaine>/legal/privacy` est accessible publiquement
- [ ] Interface FR/EN
- [ ] Métadonnées SEO + Open Graph + favicon
- [ ] Aucun secret dans le code (seule la clé anon publique est utilisée)
- [ ] Déployé et accessible en ligne
