# Soumission App Store — notes de revue, étiquettes, câblage

Document de travail pour **passer la revue Apple**. Trois parties : ce qu'il
reste à câbler dans Xcode (les fichiers viennent d'être créés mais pas rattachés
à la cible), les **App Review Information** à remplir dans App Store Connect, et
le **mapping des étiquettes de confidentialité**. Les décisions produit vivent
dans `LANCEMENT.md` ; ici, uniquement la mécanique de soumission.

---

## 1. Fichiers iOS — câblés et vérifiés dans l'IPA ✅

Les trois fichiers sont rattachés à la cible **Runner** et **embarqués** : vérifié
en dépaquetant l'IPA (`en.lproj/`, `fr.lproj/InfoPlist.strings` et
`PrivacyInfo.xcprivacy` présents dans le bundle). Xcode les a placés à la **racine
`ios/`** (groupe projet), au même endroit que `GoogleService-Info.plist` — c'est
la convention déjà en place ici, on la garde.

### a) Traductions de permissions — `ios/en.lproj` / `ios/fr.lproj/InfoPlist.strings` ✅

`CFBundleLocalizations` (en, fr) et `knownRegions` (en, **fr**) sont en place.
Contenu FR vérifié dans le bundle. Un iPhone en français affiche désormais les
phrases françaises.

> ⚠️ **Portée de la caméra** : la phrase ne parle que de *scanner les billets*.
> Si l'app permet de **prendre** une photo (profil, affiche) avec l'appareil
> photo, élargir la phrase (EN + FR) sinon Apple relève l'écart.

### b) Manifeste de confidentialité — `ios/PrivacyInfo.xcprivacy` ✅

Embarqué (ne piste pas, aucun domaine de pistage). Si le téléversement de
l'archive signale une « API à motif obligatoire » manquante pour le binaire
principal, l'ajouter dans ce fichier avec le code de motif exact qu'Apple nomme.

### c) `aps-environment` — vérifié `production` dans l'IPA ✅

`Runner.entitlements` porte `development`, mais la signature automatique bascule
sur `production` pour la distribution : vérifié sur l'IPA construit
(`codesign -d --entitlements` → `production`). Le push TestFlight fonctionnera.
Rien à faire. (Re-vérifier seulement si un jour le push ne passe pas en
TestFlight : `codesign -d --entitlements :- build/ios/ipa/Payload/Runner.app`.)

### d) `GoogleService-Info.plist` — présent et câblé ✅

Vérifié : le fichier est à **`ios/GoogleService-Info.plist`** (racine `ios/`, pas
dans `ios/Runner/`), `BUNDLE_ID = com.happyn.happyn`, projet `happyn-b8648`, et
il est référencé dans *Copy Bundle Resources* de la cible Runner. Rien à faire
ici. Il reste **ignoré par git** (comme son équivalent Android) : sur une
**machine neuve**, le re-télécharger depuis la console Firebase et vérifier qu'il
est bien coché pour la cible Runner, sinon `Firebase.initializeApp()` se bloque.

---

## 2. App Review Information (App Store Connect)

### Compte démo — OBLIGATOIRE (l'app exige une connexion)

Créer un compte de test **déjà majeur (18+)**, le garder stable, et le fournir
dans *App Review Information → Sign-In required*. Donner identifiant + mot de
passe. Ne pas utiliser un vrai compte personnel.

### Notes au reviewer (à coller)

> HAPPYN est une billetterie d'événements **physiques** (soirées, spectacles,
> rencontres) avec un volet social (profils, publications, commentaires).
>
> **Paiements** : les billets donnent accès à des événements qui se déroulent
> **hors de l'application**. Conformément à la Guideline 3.1.3(e), ils sont
> vendus via un prestataire de paiement tiers et **non via l'achat intégré** —
> c'est le bon mécanisme pour des biens/services du monde réel.
>
> **Comment tester** : un événement **gratuit** de démonstration est disponible
> dès l'ouverture (« [NOM DE L'ÉVÉNEMENT DÉMO] ») — s'y inscrire montre
> l'émission d'un billet et son QR, sans paiement. [Si une vente payante doit
> être testée : indiquer ici l'événement payant de test + une carte de test
> Stripe `4242 4242 4242 4242`, date future, CVC quelconque.]
>
> **Connexion** : e-mail/mot de passe (compte démo fourni), ou *Sign in with
> Apple*. La connexion Google requiert un compte sur liste blanche et n'est pas
> nécessaire pour la revue.
>
> **Âge** : l'app est réservée aux **18 ans et plus** (messagerie, événements
> avec alcool). Le compte démo est déjà majeur.
>
> **Modération** : tout contenu publié peut être signalé (bouton *Signaler*) et
> un utilisateur bloqué ; les signalements nous alertent par courriel et sont
> traités sous 24 h. Suppression de compte disponible dans Réglages et sur
> `happynevents.com/delete-account.html`.

### Garde-fous à cocher AVANT de soumettre
- [ ] **Google OAuth en « Production »** (Google Cloud Console) — sinon la
      connexion Google est cassée pour les testeurs externes.
- [ ] Un **événement gratuit de démo** visible dès l'ouverture, pour que le
      reviewer teste l'émission d'un billet sans paiement.
- [ ] URL **politique de confidentialité** = page du site ; URL **support**
      renseignée.
- [ ] Build **sans crash au lancement** (`GoogleService-Info.plist` présent ✅).

---

## 3. Étiquettes de confidentialité (« nutrition labels »)

À reporter dans *App Store Connect → App Privacy*. **À confirmer contre la
politique de confidentialité publiée** avant de valider. Rappel transversal :
**aucune donnée n'est utilisée pour le pistage** (« Data Not Used to Track You »).

| Donnée | Collectée | Liée à l'identité | Finalité | Note |
|---|---|---|---|---|
| **Adresse e-mail** | Oui | Oui | Fonctionnement de l'app | Compte |
| **Nom** | Oui | Oui | Fonctionnement de l'app | Profil |
| **Date de naissance** (Autre donnée) | Oui | Oui | Fonctionnement de l'app | Vérif. 18+ |
| **Identifiant utilisateur** | Oui | Oui | Fonctionnement de l'app | ID de compte |
| **Photos ou vidéos** (contenu) | Oui | Oui | Fonctionnement de l'app | Profil, affiches, publications |
| **Autre contenu utilisateur** | Oui | Oui | Fonctionnement de l'app | Publications, commentaires, bio |
| **Localisation approximative** | Oui | **Non** | Fonctionnement de l'app | Événements proches ; non enregistrée (voir ci-dessous) |
| **Achats** (historique) | Oui | Oui | Fonctionnement de l'app | Billets achetés |
| **Infos de paiement** (carte) | **Non par l'app** | — | — | Gérées par le prestataire de paiement (SDK), l'app ne voit jamais le numéro |
| **Données de plantage** | Oui | **Non** | Analyses | Sentry, 20 % des sessions, sans donnée personnelle |
| **Données de performance** | Oui | **Non** | Analyses | Sentry |

**Points à trancher avec la politique en main :**
- **Localisation** : la phrase de permission dit « jamais enregistrée ». Si elle
  n'est vraiment que transmise pour la requête et **non stockée**, on peut la
  déclarer *non liée à l'identité* (fait ci-dessus), voire discuter « non
  collectée ». Choisir une seule lecture, cohérente avec la politique.
- **Infos de paiement** : à ne déclarer **que si** l'app elle-même les reçoit.
  Avec le SDK du prestataire, la carte ne transite pas par notre code → ne pas
  les déclarer côté app. Déclarer en revanche **Achats** (historique de billets).
- **Nom / contenu** : « liées à l'identité » car rattachées au compte.

---

## 4. Ordre de marche (résumé)

1. `GoogleService-Info.plist` déjà présent et câblé (§1d) → rien à faire.
2. Les 3 fichiers câblés dans Xcode (§1a, §1b) + `aps-environment` vérifié (§1c).
3. `flutter build ipa --dart-define-from-file=dart_defines.json`, upload, symboles Sentry.
4. App Store Connect : fiche, captures (6,7" + 6,5"), classification **18+**,
   étiquettes (§3), **compte démo + notes** (§2), événement gratuit de démo.
5. Google OAuth → Production. TestFlight interne, test sur iPhone réel.
6. Soumettre. `kAppStoreUrl` rempli dès que l'ID d'app est connu
   (`lib/core/config/store_config.dart`).
