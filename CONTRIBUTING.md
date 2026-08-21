# Contribuer à HAPPYN

Guide de l'équipe. À lire **entièrement** avant le premier commit.

---

## 1. Le projet en 30 secondes

**HAPPYN** = application mobile de découverte et de billetterie d'événements
(Ottawa-Gatineau). Deux piliers : la **billetterie sécurisée** (fonctionnelle) et
la **communauté** (v2, pas encore construite).

| Couche | Techno |
|---|---|
| Mobile | Flutter (Dart), Riverpod pour l'état |
| Backend | Supabase (Postgres + RLS + Edge Functions Deno) |
| Paiements | Stripe (mode **test** pour l'instant) |
| Langues | FR / EN via `flutter_localizations` |

---

## 2. Démarrer

```bash
git clone https://github.com/iamJonathan76/happyn.git
cd happyn
flutter pub get
flutter run
```

Prérequis : Flutter avec Dart SDK `^3.11.0`, un émulateur Android ou un
téléphone en mode développeur.

Ça marche **directement après le clone** : les clés présentes dans le repo sont
publiques (voir §5). Aucun `.env` à créer.

> **Attention** : après un `git pull` qui contient une nouvelle migration SQL,
> il faut l'exécuter dans Supabase avant de relancer l'app (voir §4).

---

## 3. Workflow Git

`main` est **protégée** : pas de push direct, tout passe par une Pull Request.

```bash
git checkout main && git pull
git checkout -b feat/nom-de-la-feature
# ... travail ...
git push -u origin feat/nom-de-la-feature
# puis ouvrir une PR sur GitHub
```

**Conventions de branches** : `feat/…`, `fix/…`, `refactor/…`, `docs/…`

**Règles de PR**
- Une PR = une feature. Les grosses PR fourre-tout sont impossibles à relire.
- Relecture par l'autre développeur avant merge.
- `flutter analyze` doit être **propre** (0 error) avant de demander la revue.
- Si la PR ajoute une migration SQL, **le dire explicitement** dans la
  description — l'autre devra l'exécuter de son côté.

### Fichiers « chauds » (risque de conflit élevé)

Préviens l'autre avant d'y toucher longuement :

- `lib/l10n/app_en.arb` et `app_fr.arb` (vous ajouterez des clés tous les deux)
- `lib/core/theme/app_colors.dart`
- `lib/main.dart`, `lib/features/main_shell.dart`
- `pubspec.yaml`
- les providers partagés (`lib/core/providers/`)

**Les refactors transverses** (qui touchent 15+ fichiers) se font **seul**,
idéalement quand l'autre est sur une zone isolée. Sinon les merges deviennent
ingérables.

---

## 4. Migrations SQL — la règle la plus importante

Nous partageons **un seul projet Supabase**. Une migration appliquée par l'un
change la base de l'autre.

**Les 4 règles :**

1. **Ne jamais modifier une migration déjà appliquée.** On corrige toujours en
   ajoutant une **nouvelle** migration.
2. **Nom horodaté** : `supabase/migrations/AAAAMMJJHHMMSS_description.sql`
   (ex. `20260722020000_age.sql`). L'ordre chronologique est ce qui garantit la
   reproductibilité.
3. **Écrire des migrations idempotentes** : `create table if not exists`,
   `add column if not exists`, `drop policy if exists` avant `create policy`.
   On doit pouvoir la rejouer sans casse.
4. **Prévenir l'autre** dès qu'une migration est mergée. Lui doit la coller dans
   le SQL Editor de Supabase, sinon son app plantera avec une erreur du genre
   `column "xxx" does not exist`.

**Symptôme classique** : l'app fonctionnait, tu fais `git pull`, et soudain un
écran plante ou une insertion échoue → il te manque une migration.

---

## 5. Sécurité — règle absolue sur les clés

**Ce qui peut être dans le code** (clés publiques, conçues pour être exposées) :

- `lib/main.dart` : URL Supabase + clé **anon/publishable**
- `lib/core/config/stripe_config.dart` : clé **publishable** Stripe (`pk_test_…`)
- `lib/core/config/auth_config.dart` : Google **Web Client ID**

**Ce qui ne doit JAMAIS entrer dans le repo** :

- Clé secrète Stripe (`sk_…`), secret du webhook (`whsec_…`)
- Clé `service_role` Supabase
- Le secret HMAC des QR codes
- Keystores (`.jks`, `.keystore`), `google-services.json`, tout `.env`

Ces valeurs vivent **uniquement** dans les *Secrets* du projet Supabase, lues
côté serveur par les Edge Functions.

**Avant chaque push, vérifie** :

```bash
git diff --cached | grep -iE "sk_live|sk_test|whsec_|service_role|BEGIN.*PRIVATE KEY"
```

Si ça retourne quelque chose : **stop**, ne pousse pas.

Le `.gitignore` est déjà durci contre ces fichiers, mais il ne remplace pas la
vigilance.

---

## 6. Architecture du code

```
lib/
  core/            # transverse, réutilisable
    config/        # clés publiques (Stripe, Google)
    providers/     # état Riverpod partagé (events, auth, tickets, favorites…)
    theme/         # AppColors ← toutes les couleurs
    utils/         # helpers (dates, age, maps, secure_screen)
    widgets/       # widgets partagés (EventListCard…)
    events/        # règles métier events (isEventVisible, isEventPast…)
  features/        # un dossier par domaine fonctionnel
    auth/ home/ discover/ events/ ticketing/ profile/ notifications/ settings/
  l10n/            # traductions FR/EN (.arb) + classes générées
supabase/
  migrations/      # SQL horodaté
  functions/       # Edge Functions Deno
```

**Principe** : `features/` peut dépendre de `core/`, jamais l'inverse. Une
feature n'importe pas une autre feature (sauf navigation vers son écran).

**État** : tout ce qui est partagé passe par un provider Riverpod dans
`core/providers/`. Après une écriture en base, on invalide le provider
concerné (`ref.invalidate(eventsProvider)`) — les écrans se rafraîchissent
seuls, pas de rechargement manuel.

---

## 7. Conventions de code

**Couleurs** — jamais de hex en dur. Toujours `AppColors.primary`,
`AppColors.background`, `AppColors.textMed`… Si une couleur manque, on
l'ajoute à `app_colors.dart` (elle servira au futur mode clair).

**Textes traduits** — aucune chaîne visible en dur. Le processus :

1. Ajouter la clé dans `lib/l10n/app_en.arb` **et** `app_fr.arb`
2. `flutter gen-l10n`
3. L'utiliser via `AppLocalizations.of(context).maCle`

Les **contenus utilisateur** (titre d'event, bio…) ne sont pas traduits : ils
restent dans la langue de saisie. C'est voulu.

**Anti-débordement** — tout `Text` placé dans une `Row` doit être enveloppé
dans `Expanded` ou `Flexible`, avec `maxLines` + `overflow: TextOverflow.ellipsis`.
Le français est ~25 % plus long que l'anglais : sans ça, ça déborde.

**Dates** — passer par `AppDates` (`lib/core/utils/dates.dart`), jamais de
tableau de mois écrit à la main : le formatage doit suivre la langue.

**Commentaires** — en français, et seulement pour expliquer le *pourquoi*
(une contrainte, un piège), pas le *quoi* que le code dit déjà.

---

## 8. Avant de demander une revue

```bash
flutter analyze          # doit être propre (0 error)
flutter run              # tester réellement l'écran modifié
```

Checklist rapide :

- [ ] Testé en **français ET en anglais** (Réglages → Langue)
- [ ] Aucun débordement (pas de rayures jaunes/noires)
- [ ] Aucune couleur ni chaîne en dur
- [ ] Aucun secret dans le diff
- [ ] Migration signalée dans la PR si applicable
