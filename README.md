# HAPPYN

Application mobile de découverte d'événements et de billetterie sécurisée pour
la région **Ottawa-Gatineau**.

> *More than events. A real community.*

## Stack

| Couche | Techno |
|---|---|
| Mobile | Flutter (Dart) + Riverpod |
| Backend | Supabase (Postgres, RLS, Edge Functions) |
| Paiements | Stripe (mode test) |
| Langues | FR / EN |

## Démarrer

```bash
flutter pub get
flutter run
```

Prérequis : Dart SDK `^3.11.0`. Aucun `.env` à créer — les clés présentes dans
le dépôt sont publiques.

## Fonctionnalités (v1)

Découverte et recherche d'événements · création d'événements avec billets
multi-tarifs · paiements Stripe · billets QR sécurisés (HMAC rotatif, usage
unique) · scan à l'entrée pour l'organisateur · transfert de billet ·
événements privés sur code d'invitation · favoris · notifications in-app ·
profils · interface bilingue FR/EN.

## Documentation

| Document | Pour qui |
|---|---|
| [CONTRIBUTING.md](CONTRIBUTING.md) | **À lire avant le premier commit** — workflow git, migrations, sécurité, conventions |
| [web/SPEC.md](web/SPEC.md) | Spécification du site vitrine |
| [docs/BRIEF-WEB.md](docs/BRIEF-WEB.md) | Brief complet et autonome du chantier web |

## Structure

```
lib/
  core/       transverse : providers, theme, utils, widgets partagés
  features/   un dossier par domaine (auth, events, ticketing, profile…)
  l10n/       traductions FR/EN
supabase/
  migrations/ SQL horodaté
  functions/  Edge Functions Deno
web/          site vitrine (chantier séparé)
```

## Sécurité

Seules des clés **publiques** figurent dans ce dépôt (clé anon Supabase, clé
publishable Stripe, Client ID Google). Toute clé secrète vit dans les *Secrets*
Supabase et ne doit **jamais** être commitée. Détails dans
[CONTRIBUTING.md](CONTRIBUTING.md).
