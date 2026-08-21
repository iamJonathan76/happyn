# BRIEF COMPLET — Site web HAPPYN

> Document autonome. Il contient tout le contexte nécessaire : tu peux le lire
> directement, ou le coller tel quel dans un assistant IA (Claude Code) comme
> instruction de départ. Aucune connaissance préalable du projet n'est requise.

---

## 1. Ta mission en une phrase

Construire et déployer le **site web vitrine de HAPPYN** — présentation de
l'application + pages légales lues depuis la base de données — dans le dossier
`web/` du dépôt, sans jamais toucher au code de l'application mobile.

**Pourquoi c'est important et pas décoratif** : Google Play et l'App Store
**refusent** de publier une application sans URL publique de politique de
confidentialité. Tant que ce site n'existe pas, HAPPYN ne peut pas être publié.
Tu débloques la mise en ligne.

---

## 2. Le projet HAPPYN

**HAPPYN** est une application mobile de découverte d'événements et de
billetterie, ciblant la région **Ottawa-Gatineau** (marché bilingue
français/anglais). Accroche officielle : *« More than events. A real
community. »*

Deux piliers produit :
- **Billetterie** — fonctionnelle et sécurisée aujourd'hui
- **Communauté** (suivre des amis, fil d'actualité) — prévue en v2, pas encore
  construite

L'application est en **v1 fonctionnellement complète** : création d'événements,
paiements Stripe (mode test), billets QR sécurisés, scan à l'entrée, transfert
de billets, événements privés sur code d'invitation, notifications in-app,
profils, interface entièrement bilingue FR/EN.

### Stack technique

| Couche | Techno |
|---|---|
| Application mobile | Flutter (Dart) + Riverpod |
| Base de données & API | Supabase (Postgres, RLS, Edge Functions Deno) |
| Paiements | Stripe (mode test) |
| Dépôt | `https://github.com/iamJonathan76/happyn.git` |

### L'équipe

Vous êtes **deux développeurs de même profil**. Emmanuel (propriétaire du
projet) continue sur l'application mobile ; toi tu prends le web. Ce découpage
est volontaire : vos fichiers sont **totalement disjoints**, donc aucun conflit
git possible pendant cette phase.

---

## 3. Périmètre : ce que tu construis, ce que tu ne construis pas

### ✅ Dans le périmètre

- Page d'accueil marketing (présentation de l'app, captures, boutons stores)
- Pages légales (`/legal` + `/legal/[slug]`) alimentées **par la base**
- Interface bilingue FR/EN
- SEO, métadonnées de partage, favicon
- Déploiement en ligne

### ❌ Hors périmètre — ne construis pas ça

- Connexion / inscription utilisateur
- Achat de billets, création d'événements, liste d'événements
- Toute écriture en base de données

Le site est en **lecture seule** et ne lit que du contenu **public**. Toute la
logique métier reste dans l'application mobile.

### 🚫 Ne touche jamais à

- `lib/` (code Flutter de l'app)
- `supabase/migrations/` et `supabase/functions/` (backend)
- `pubspec.yaml`, `android/`, `ios/`

Ton travail vit **uniquement** dans `web/`. C'est ce qui garantit zéro conflit.

---

## 4. Mise en route

```bash
git clone https://github.com/iamJonathan76/happyn.git
cd happyn
git checkout -b feat/site-web
```

Avant d'écrire du code, **lis ces deux fichiers du dépôt** :
- `CONTRIBUTING.md` — workflow de l'équipe, règles git, règles de sécurité
- `web/SPEC.md` — la spécification fonctionnelle détaillée du site

### Stack recommandée

**Next.js** (App Router) + Tailwind, déployé sur **Vercel** (offre gratuite,
déploiement automatique). Un site statique HTML/CSS/JS convient aussi si tu
préfères — mais Next.js facilite le SEO et le rendu serveur des pages légales.

```bash
cd web
npx create-next-app@latest .
```

---

## 5. Les données — le cœur technique

C'est la partie la plus importante à faire correctement.

### Le principe : une seule source de vérité

Les textes juridiques de HAPPYN sont stockés dans une table Supabase
`legal_documents`. L'**application mobile** les lit déjà depuis cette table.
Ton site doit lire **la même table**.

**Conséquence à respecter absolument** : ne recopie **jamais** un texte légal en
dur dans le site. Si Emmanuel corrige une phrase des conditions d'utilisation
en base, l'app et le site doivent afficher la nouvelle version **sans
redéploiement ni mise à jour**. C'est toute la raison d'être de cette
architecture.

### Accès à l'API

La table est en **lecture publique** (politique RLS autorisant `select` à
`anon`). Tu utilises la clé **anon**, qui est **publique par conception** —
c'est la clé destinée aux clients, elle est déjà visible dans le code de l'app
mobile. Il n'y a **aucun secret** à manipuler.

```
URL Supabase : https://jvjvuozvlzqqmcjanvnh.supabase.co
Clé anon     : sb_publishable_wkRU0rXDmrPaDyhP2b5Mdw_rkbXBrmO
```

Requête REST — tous les documents :

```http
GET https://jvjvuozvlzqqmcjanvnh.supabase.co/rest/v1/legal_documents?select=*&order=sort_order.asc
apikey: sb_publishable_wkRU0rXDmrPaDyhP2b5Mdw_rkbXBrmO
Authorization: Bearer sb_publishable_wkRU0rXDmrPaDyhP2b5Mdw_rkbXBrmO
```

Un seul document : ajouter `&slug=eq.privacy`

Ou avec le SDK officiel (plus confortable) :

```bash
npm install @supabase/supabase-js
```

```js
import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
);

const { data } = await supabase
  .from('legal_documents')
  .select('*')
  .order('sort_order', { ascending: true });
```

> Mets ces deux valeurs dans des variables d'environnement `NEXT_PUBLIC_*`
> (elles sont publiques, donc `NEXT_PUBLIC_` est correct ici) et configure-les
> aussi dans Vercel.

### Schéma de la table

| Colonne | Type | Rôle |
|---|---|---|
| `slug` | text (clé primaire) | Identifiant d'URL (`privacy`, `terms`…) |
| `title` | text | Titre affiché |
| `content` | text | Corps du document, en markdown léger |
| `version` | text | Ex. « Version 1.1 » |
| `effective_date` | date | Date d'entrée en vigueur |
| `sort_order` | int | Ordre d'affichage |
| `updated_at` | timestamptz | Dernière modification |

### Les 11 documents existants

```
terms · privacy · community · cookie · copyright · refund
payments · fraud-prevention · safety · organizer · data-retention
```

**Le plus important : `privacy`.** C'est l'URL `https://<domaine>/legal/privacy`
qui sera déclarée aux stores. Elle doit être accessible publiquement, sans
connexion, et rester stable.

### Format du champ `content`

Markdown volontairement minimal, trois règles :

- `## Titre` → sous-titre de section
- `- élément` → puce
- Toute autre ligne non vide → paragraphe ; ligne vide = séparateur de blocs

Un rendu markdown standard (`react-markdown`) le gère nativement.

---

## 6. Identité visuelle

Reprends **exactement** la charte de l'application (source de vérité :
`lib/core/theme/app_colors.dart` dans le dépôt).

| Rôle | Hex |
|---|---|
| Fond principal | `#08080F` |
| Surface / carte | `#1A1535` |
| Violet primaire | `#7C3AED` |
| Rose accent | `#EC4899` |
| Lavande (liens) | `#A78BFA` |
| Lavande claire | `#C4B5FD` |
| Texte principal | `#FFFFFF` |
| Texte secondaire | blanc à 65 % |

**Dégradé de marque** : `#7C3AED → #EC4899`, orienté haut-gauche → bas-droite.
Il est utilisé partout dans l'app (boutons principaux, onglets actifs, bannière
de profil).

**Typographie** : **Poppins** pour les titres (weights 700 à 900), **Inter**
pour le texte courant. Les deux sont sur Google Fonts.

**Ambiance** : sombre, premium, nocturne. L'app est volontairement dark-only —
le site doit être cohérent, donc **pas de thème clair**.

Le logo est dans le dépôt : `assets/icon/happyn.png`.

---

## 7. Plan de travail suggéré

**Étape 1 — Fondations**
Initialiser Next.js dans `web/`, poser la charte (couleurs, polices), vérifier
le responsive. Déployer une page vide sur Vercel dès le début : mieux vaut
découvrir les problèmes de déploiement tôt.

**Étape 2 — Les pages légales (priorité absolue)**
C'est le livrable critique. Connecter Supabase, créer `/legal` (index trié) et
`/legal/[slug]` (rendu markdown). Vérifier avec Emmanuel qu'une modification en
base apparaît bien sur le site.

**Étape 3 — La page d'accueil**
Hero + accroche, sections fonctionnalités, section organisateurs, pied de page
avec les liens légaux. Demander les captures d'écran à Emmanuel.

**Étape 4 — Finitions**
Bilingue FR/EN, SEO, Open Graph, favicon, passe responsive, performance.

Fais une **Pull Request par étape**, pas une seule PR géante à la fin.

---

## 8. Règles non négociables

1. **Aucun secret dans le dépôt.** Seule la clé anon (publique) est utilisée.
   Si tu croises un jour une clé commençant par `sk_`, `whsec_` ou
   `service_role`, elle ne doit **jamais** apparaître dans le code ni dans une
   variable `NEXT_PUBLIC_*`. Avant chaque push :
   ```bash
   git diff --cached | grep -iE "sk_live|sk_test|whsec_|service_role"
   ```
2. **Ne modifie rien hors de `web/`.** C'est la garantie du zéro conflit.
3. **Aucun texte légal en dur.** Tout vient de la base.
4. **`main` est protégée** : branche + Pull Request, jamais de push direct.
5. **Mobile d'abord.** La majorité du trafic viendra de téléphones.

---

## 9. Points à confirmer avec Emmanuel

- **Le nom de domaine** (`happyn.com` ?) n'est pas encore acquis. Tu peux tout
  développer et déployer sur une URL temporaire Vercel, mais le domaine
  définitif est requis avant la soumission aux stores.
- **Les captures d'écran** de l'application pour la page d'accueil.
- **Les adresses de contact** : le manuel juridique mentionne
  `support@happyn.com` et `business@happyn.com` — à confirmer si elles sont
  actives.
- **Accès** : si tu as besoin de consulter la base Supabase directement,
  demande une invitation au projet.

---

## 10. Définition du « terminé »

- [ ] Site déployé et accessible en ligne
- [ ] Page d'accueil complète, responsive (mobile + desktop)
- [ ] `/legal` liste les 11 documents dans l'ordre
- [ ] `/legal/[slug]` rend correctement chaque document
- [ ] Le contenu vient de la base — **prouvé** : Emmanuel modifie un mot en
      base, le site l'affiche sans redéploiement
- [ ] `https://<domaine>/legal/privacy` public et stable
- [ ] Interface disponible en français et en anglais
- [ ] Métadonnées SEO, Open Graph, favicon
- [ ] Aucun secret dans le dépôt
- [ ] Charte respectée (couleurs et polices identiques à l'app)

---

## 11. Ce qui vient après

Le site est ta **première mission**, pas ta mission unique. Une fois livré, tu
rejoins le développement de l'application mobile sur des **features verticales**
(que tu prends de bout en bout : base de données → API → interface). Les
chantiers qui t'attendent, au choix :

- **Outils organisateur** : liste des participants, statistiques de vente
- **Autocomplete d'adresses** : normaliser les adresses à la création
  d'événement (aujourd'hui en texte libre, donc « Ottawa » / « ottawa » /
  « Otawa » coexistent)
- **Suppression de compte** : Edge Function d'anonymisation (exigée par Apple)
- **Notifications e-mail** en complément des notifications in-app

Le travail sur le site te fera déjà découvrir le modèle de données et
l'écosystème Supabase du projet — c'est un onboarding déguisé.

Bienvenue dans l'équipe 🎉
