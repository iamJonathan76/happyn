# Reprendre HAPPYN sur une autre machine

Écrit le 2026-10-06, en préparant le passage de Windows à macOS. Utile aussi
pour un nouveau développeur qui clone le dépôt pour la première fois.

Ce document répond à une seule question : **après `git clone`, qu'est-ce qui
manque, et où le retrouver ?**

---

## Ce qui ne suit PAS le dépôt, et pourquoi

Quatre fichiers sont volontairement hors de Git. Ce n'est pas un oubli : trois
d'entre eux identifient nos services ou nous authentifient auprès d'eux, et
n'ont rien à faire dans un historique public.

### 1. `android/app/google-services.json` — notifications push

Sans lui, l'app **compile et fonctionne, mais sans notifications poussées**.
C'est voulu : `android/app/build.gradle.kts` n'applique le greffon Google
Services que si le fichier existe, et affiche un avertissement sinon. Appliqué
sans condition, il faisait échouer toute la compilation chez quelqu'un qui
n'avait pas le fichier.

**Où le retrouver** : console Firebase → projet HAPPYN → Paramètres du projet →
l'app Android `com.happyn.happyn` → télécharger. Il se régénère à volonté, il
n'y a rien d'irremplaçable dedans.

### 2. `android/key.properties` + le fichier `.jks` — signature de publication

Google Play refuse un APK signé avec la clé de débogage. La vraie clé se lit
dans `android/key.properties` ; absente, le build retombe sur la signature de
débogage plutôt que d'échouer.

**⚠️ Cette clé est IRREMPLAÇABLE.** Perdue, aucune mise à jour de HAPPYN ne
peut plus être publiée sous le même identifiant : il faut republier une
nouvelle app, et les utilisateurs installés ne migrent pas.

**Ne jamais la déplacer d'une machine à l'autre par commodité.** La générer une
fois, la sauvegarder dans un gestionnaire de mots de passe ou un coffre
chiffré, et ne la copier que sur la machine qui publie réellement.

Pour la créer :

```bash
keytool -genkey -v -keystore android/app/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Puis `android/key.properties` :

```
storePassword=…
keyPassword=…
keyAlias=upload
storeFile=app/upload-keystore.jks
```

`.gitignore` couvre déjà `key.properties`, `*.keystore` et `*.jks` — vérifiable
avec `git check-ignore -v android/key.properties`.

### 3. `SENTRY_DSN` — remontée des erreurs

Lu dans `lib/core/config/observability.dart`, jamais écrit dans le dépôt. Il
vit dans `dart_defines.json` à la racine, ignoré par Git — copier
`dart_defines.example.json` et y mettre la vraie valeur. Les builds destinés
à d'autres le passent ainsi :

```bash
flutter build appbundle --release --dart-define-from-file=dart_defines.json
```

Le développement de tous les jours s'en passe exprès : sans clé, l'app tourne
normalement et n'envoie rien, ce qui évite de remplir Sentry de nos propres
erreurs. Pour vérifier que les rapports arrivent : `flutter run
--dart-define-from-file=dart_defines.json`, puis en mode debug, Paramètres →
« Envoyer une erreur de test ».

**Où le retrouver** : tableau de bord Sentry, paramètres du projet.

### 4. `android/local.properties`

Se régénère tout seul au premier build. Rien à faire.

---

## Ce qui ne bouge PAS

**Supabase, Stripe, Firebase côté serveur : rien à migrer.**

Tous les vrais secrets (`STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`,
`TICKET_HMAC_SECRET`, `SUPABASE_SERVICE_ROLE_KEY`, `RESEND_API_KEY`,
`FIREBASE_SERVICE_ACCOUNT`, et les secrets de webhooks) vivent dans les secrets
Supabase, jamais sur une machine de développement. Changer de portable ne les
touche pas.

Seules des clés **publiques** sont dans le code : la clé publiable Stripe
(`pk_`), la clé anonyme Supabase, l'identifiant client Google Web. C'est
normal et sûr — le contrôle d'accès vit dans la base, pas dans le binaire. Voir
`docs/SECURITY.md`.

---

## Remise en route, dans l'ordre

```bash
git clone https://github.com/iamJonathan76/happyn.git
cd happyn
flutter pub get
```

Puis déposer `google-services.json` dans `android/app/`, et :

```bash
flutter run                    # vérifier que ça démarre
flutter analyze                # doit rester à 0 error / 0 warning
flutter build appbundle --release
```

Versions de référence au moment d'écrire : Flutter 3.44.1 (stable), app en
`1.0.0+1`, Java 17, `compileSdk` 36.

---

## Pièges déjà rencontrés, pour ne pas les redécouvrir

**Le build de release échouait sur `flutter_stripe`.** Son module Android
déclare une dépendance de lint vers `com.google.android.gms:play-services-tapandpay`,
publiée sur aucun dépôt public. `android/build.gradle.kts` l'exclut des seules
configurations de lint — l'exclure partout casserait des classes attendues à
l'exécution. À retirer quand le paquet sera corrigé en amont.

**`sentry_flutter` fige Kotlin 1.6 et `compileSdk` 34**, tous deux refusés par
le reste du projet. Surcharge ciblée sur ce seul module, même fichier.

**Un seul projet Supabase pour toute l'équipe.** Si quelqu'un applique une
migration, l'app des autres casse tant qu'ils n'ont pas fait `git pull` et
rejoué les migrations. Ne jamais modifier une migration déjà appliquée : en
ajouter une nouvelle, horodatée, et idempotente.

**Le déclencheur d'envoi des notifications** a longtemps existé uniquement dans
le tableau de bord Supabase, invisible du dépôt. Il est désormais dans
`20261005000000_push_triggers.sql`, qui ne le recrée pas s'il existe déjà —
sinon chaque notification partirait en double. L'URL et le secret se mettent à
la main dans `private.settings`, jamais dans une migration.

---

## État au 2026-10-06 — ce qui reste avant les stores

**Fait** : chaîne de paiement complète et prouvée en test (achat → webhook →
frais → commission → écran de versement), billets QR signés, annulation
d'événement avec remboursement intégral des deux côtés, modération et
signalement (y compris des messages privés), messagerie privée, notifications
poussées vérifiées de bout en bout, build de release qui aboutit, signature de
publication câblée.

**Bloquant** :

- Générer la clé de signature et produire un bundle signé (jamais fait).
- Page publique de suppression de compte sur happynevents.com — exigée par
  Google Play.
- Relecture intégrale du handbook légal (en cours).

**À faire, non bloquant** :

- Prouver un vrai versement : événement terminé depuis plus de 3 jours, puis
  appel manuel de `run-payouts`. Jamais exécuté de bout en bout.
- Écrire des tests de politiques RLS. Les trois vrais trous de sécurité
  trouvés jusqu'ici appartenaient tous à cette classe — c'est le manque
  structurel le plus coûteux.
- Déployer `cancel-event` (écrite, jamais déployée).

**iOS** : le passage sur Mac ouvre la compilation iPhone, mais c'est un
chantier entier — compte développeur Apple, certificats, et les notifications
Apple passent par APNs, que `PushService` ne couvre pas aujourd'hui (c'est
écrit dans le fichier).
