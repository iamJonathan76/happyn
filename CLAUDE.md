# Travailler sur HAPPYN

Ce fichier est lu automatiquement au début de chaque session. Il ne décrit pas
le projet — `CONTRIBUTING.md` le fait déjà — mais ce qu'il faut savoir avant de
toucher à quoi que ce soit.

## À lire en premier, dans cet ordre

1. **`docs/LANCEMENT.md`** — l'état réel du projet : ce qui est fait, ce qui
   attend une décision, ce qui est écrit mais pas activé. C'est la source de
   vérité, tenue à jour à chaque changement notable. **Ne jamais répondre « où
   en est-on » sans l'avoir relu** : la réponse y est, et elle est plus à jour
   que n'importe quel souvenir.
2. **`CONTRIBUTING.md`** — architecture, conventions, et la règle sur les clés.
3. **`docs/SECURITY.md`** — le modèle de menace et les décisions de RLS.

L'historique git est volontairement bavard : les messages de commit expliquent
POURQUOI, pas quoi. `git log --format=%B -5` en dit plus qu'une relecture du
diff.

## Ce que l'environnement infonuagique ne peut pas faire

**Aucun SDK Flutter.** Pas de `flutter analyze`, pas de `flutter test`, pas de
`dart`, pas de `flutter gen-l10n`. Trois conséquences, toutes apprises à mes
dépens :

- **Les changements de mise en page ne peuvent pas être validés ici.** Deux
  régressions sont parties en production de cette façon : un `Flexible` dans une
  `Row` à largeur non bornée, et un `Center` sans `heightFactor` qui a fait
  occuper tout l'écran à la barre d'onglets. L'équilibre des parenthèses ne dit
  rien des contraintes de Flutter. **Pousser un écran à la fois, et attendre que
  la personne l'ait lancé avant d'en modifier un autre.**
- **Les fichiers `lib/l10n/app_localizations*.dart` sont générés**, mais ils
  doivent être édités à la main ici. Toujours modifier les deux `.arb` ET les
  trois `.dart`, puis vérifier la parité des clés et la validité du JSON avant
  de pousser.
- Un `Expanded` ou un `Flexible` n'est légal que si l'ancêtre `Row`/`Column`
  reçoit une contrainte bornée. Dans une `Row`, les enfants NON flexibles sont
  posés avec une largeur infinie — y mettre un `Flexible` fait planter le rendu
  de tout l'écran.

## Ce que l'environnement PEUT faire — et qu'il faut utiliser

**Postgres est installé.** Une migration SQL se vérifie pour de vrai au lieu
d'être relue : monter une instance jetable, recréer un schéma minimal
(`auth.users`, `events`, `tickets`, `ticket_types`, `profiles`, plus un
`auth.uid()` qui lit une variable de session), exécuter la migration, puis
tester les comportements — idempotence, valeurs figées, et surtout les droits
(`set role authenticated` doit se voir refuser les fonctions serveur).

**Node et TypeScript sont disponibles.** Les fonctions Edge se vérifient avec
`tsc --noEmit` et un fichier qui déclare le global `Deno`.

Une migration poussée sans avoir été exécutée, ou une fonction Edge poussée sans
avoir été typée, est une négligence : les outils sont là.

## Git

La personne travaille en parallèle sur sa machine. **Toujours `git pull
--no-rebase` avant de pousser**, sinon le push est rejeté.

Les trois fichiers `app_localizations*.dart` sont régénérés par Flutter à chaque
`flutter pub get` côté machine : ils bloquent régulièrement les `git pull`
là-bas. Le remède est `git checkout --` dessus, pas une modification du dépôt.

Messages de commit : en français, à l'indicatif, et ils expliquent la raison
d'être du changement. Jamais d'identifiant de modèle dans un commit, un
commentaire ou un fichier du dépôt.

## Conventions de code propres à ce projet

Les commentaires sont en français et expliquent **pourquoi**, jamais ce que le
code fait déjà lire. Un commentaire qui paraphrase la ligne suivante est du
bruit ; un commentaire qui dit « l'inverse laisserait le client sans place et
sans argent » est ce qui empêche la prochaine personne de le casser.

L'argent est en **cents** partout — base, fonctions Edge, modèles Dart. La
conversion en dollars n'a lieu qu'à l'affichage.

Le calcul d'un versement existe à **un seul endroit** : `public.event_ledger()`.
La classe Dart `Pricing` le reproduit pour l'affichage et lit le taux en base
(`platform_fee_bps()`) au lieu de le recopier. Deux définitions finiraient par
diverger, et l'app annoncerait un montant que le virement ne tiendrait pas.

## Avant de dire qu'une chose est faite

Dire ce qui a été vérifié et comment, et nommer ce qui ne l'a pas été. « Les
fonctions Edge passent `tsc`, la migration a été exécutée sur Postgres, mais
l'affichage reste à confirmer sur un téléphone » est une réponse ; « c'est bon »
n'en est pas une.
