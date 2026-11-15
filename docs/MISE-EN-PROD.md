# HAPPYN — Chemin vers la mise en production

Liste de travail, établie le 2026-11-13, vérifiée dans le dépôt le même jour.
Le **pourquoi** de chaque décision vit dans `LANCEMENT.md` ; ici c'est le
**quoi faire**, dans l'ordre. Légende :

- 🧑 = toi, dans une console / un contact externe (je ne peux pas le faire)
- 🤖 = du code ou de la config que je peux faire avec toi
- 🚪 **Porte** : la plus petite étape que l'item débloque
  — `interne` = TestFlight interne (équipe, ≤ 100, sans revue)
  — `public` = TestFlight externe « ouvert à tous » (passe la Beta App Review)
  — `store` = App Store / Google Play publics

On avance par **phases** : d'abord l'interne (court), puis l'ouverture au
public, puis le store. Un item d'une phase ne bloque pas les suivantes tant
qu'on ne franchit pas sa porte.

---

## Phase 0 — Décisions à trancher (elles bloquent du code)

Ce sont des choix produit/juridiques ; tant qu'ils ne sont pas pris, certains
écrans et textes restent en suspens. Détail dans `LANCEMENT.md` § 2.

- [ ] 🧑 **Plancher d'annulation** — retirer le choix « 0 / aucune annulation »
  (option A, recommandée) ou le garder mais l'afficher à l'achat (option B).
  `LANCEMENT.md` § 2.3. → un petit `🤖` suit selon le choix.
- [ ] 🧑 **Entité juridique** — personne physique pour commencer, ou société ?
  Conditionne le compte Apple (particulier vs organisation) et la
  responsabilité Stripe. § 2.4.
- [ ] 🧑 **Qui absorbe les frais Stripe d'un billet remboursé** — à trancher une
  fois. § 2.1 (fin).
- [ ] 🧑 **Contestations bancaires** — qui porte les 15 $ et le prix du billet.
  § 2.2 ter. *Pas bloquant tant que tu es seul organisateur.*

---

## Phase 1 — TestFlight **interne** (le chemin le plus court)

But : l'app sur de vrais iPhone, ton équipe, sans revue Apple. Rien ici n'est
un vrai bloqueur — c'est surtout mécanique.

- [x] ✅ Compte Apple Developer pris (2026-10-10)
- [x] ✅ Mac de build, entitlements (Push + Apple), `GoogleService-Info.plist`,
  `dart_defines.json` (Sentry) — présents et vérifiés
- [ ] 🧑 **Clé APNs (.p8)** créée dans le portail Apple et ajoutée au projet
  Firebase (si pas déjà fait pour le test push du 2026-10-30). `LANCEMENT.md`
  § chemin, étape 3
- [ ] 🧑 **Créer l'app dans App Store Connect** — nom, `com.happyn.happyn`,
  langue principale 🚪 interne
- [ ] 🤖 **Remplir `kAppStoreUrl` / `kPlayStoreUrl`** dans
  `lib/core/config/store_config.dart` dès qu'App Store Connect donne
  l'identifiant (sinon le bouton « Mets à jour HAPPYN » n'apparaît pas)
- [ ] 🧑 **Fiche de confidentialité** App Store (« étiquettes nutritionnelles »)
  à partir de la politique déjà publiée 🚪 interne
- [ ] 🧑 **Archive + envoi** : `flutter build ipa --dart-define-from-file=dart_defines.json`,
  puis Xcode/Transporter ; téléverser les symboles Sentry 🚪 interne
- [ ] 🧑 **Inviter les testeurs internes** (jusqu'à 100) — build dispo dès
  traitement, pas de revue

> À ce stade : l'équipe teste tout le **gratuit** de bout en bout. Le **payant
> ne marche pas encore** (voir Phase 2 / Stripe).

---

## Phase 2 — Ouvrir au **public** (TestFlight externe, lien ouvert à tous)

Ici on passe la **Beta App Review** d'Apple, et surtout on lève les deux vrais
bloqueurs qui cassent l'expérience d'un inconnu.

### 2.a — Les deux bloqueurs durs

- [ ] 🧑 **Google OAuth → « Production »** (Google Cloud Console → Écran de
  consentement). En « Test », Google refuse tout compte hors liste de testeurs :
  la connexion Google est cassée pour le public. Pas de vérification longue à
  subir (portées `email`/`profile` seulement). `LANCEMENT.md` § 3.1 bis
  🚪 **public — bloqueur**
- [ ] 🧑🤖 **Stripe Connect en production** — sinon aucun billet payant ne se
  vend (`organizer_not_payable`, mode test). Sous-liste `LANCEMENT.md` § 4 :
  - [ ] 🧑 Activer Connect dans le tableau de bord Stripe
  - [ ] 🤖 Appliquer la migration `20260927000000_stripe_connect.sql`
  - [ ] 🧑 Poser les secrets Edge : `PAYOUT_HOOK_SECRET`, (`CONNECT_RETURN_URL` /
    `CONNECT_REFRESH_URL` — les pages existent déjà)
  - [ ] 🧑🤖 Déployer `connect-onboard`, `connect-refresh`, `run-payouts`, et
    **redéployer** `create-payment-intent` + `stripe-webhook`
  - [ ] 🧑 Ajouter au webhook Stripe : `charge.refunded`,
    `charge.dispute.created`, `charge.dispute.closed`
  - [ ] 🧑 Passer Stripe en **mode production**
  - [ ] 🧑 **Ton propre parcours d'inscription Connect** (pour vendre tes events)
  🚪 **public — bloqueur du payant**

### 2.b — Revue Apple et finitions

- [ ] 🤖 **`fr.lproj/InfoPlist.strings`** — phrases de permission en français
  (aujourd'hui anglais seulement) 🚪 public
- [ ] 🧑 **Relecture légale par un avocat** (ON + QC), FR et EN — pas un bloqueur
  Apple, mais exposition réelle avec de vrais inconnus. `LANCEMENT.md` § 3.4
  🚪 public (décision de risque)
- [ ] 🧑 **Soumettre à la Beta App Review** puis diffuser le **lien public**

---

## Phase 3 — Activations serveur (à faire avant/pendant l'ouverture)

Du code déjà écrit qui ne tourne pas tant que le cron n'est pas posé. À faire
dans l'éditeur SQL Supabase.

- [ ] 🧑 **Cron des rappels d'événement** — `private.send_event_reminders()`
  existe (migration 2026-11-12) mais **aucun `cron.schedule`** ne l'appelle.
  Planifier un passage horaire. `LANCEMENT.md` (haut + § 5)
- [ ] 🧑 **Cron des demandes de note** — `private.send_rating_requests()` ;
  à activer **une fois la version avec l'écran de notation chez les testeurs**.
  `LANCEMENT.md` § 5 (commande fournie)
- [x] ✅ **Cron des versements** planifié (2026-10-16) — reste juste à poser
  `payout_hook_url` / `payout_hook_secret` dans `private.settings` et à
  surveiller **le premier versement réel à la main**. § 2.2 / § 8

---

## Phase 4 — App Store & Google Play **publics**

- [ ] 🧑 **App Store** : soumettre à la revue complète (après TestFlight externe
  concluant)
- [ ] 🧑 **Google Play, test interne** : clé de signature + empreinte SHA-1 de
  publication, `google-services.json`, Play Console (25 $), bundle
  `--dart-define-from-file`, symboles Sentry. `LANCEMENT.md` § chemin 2
- [ ] 🧑 **Google Play, production** après le test interne

---

## Ce qui est **déjà fait** (ne pas refaire)

Pour mémoire, vérifié le 2026-11-13 — ne revient pas dans la liste :

- Sign in with Apple (natif, testé iPhone), Google (nonce rétabli), reset mot de passe
- Notifications poussées **Android + iOS** testées
- Entitlements, `GoogleService-Info.plist`, `dart_defines.json`, pages web Connect
- Textes légaux publiés FR/EN (Version 1.0/1.1), écran de consentement
- Sentry branché et vérifié
- **Tableau de bord organisateur** (revenu net, vendus, entrées, taux, versement, classement)
- Modération + alerte courriel, suppression de compte, registre des paiements
- Maintenance & version minimale (il reste juste à remplir les URLs store)

---

## Hors périmètre du lancement (reporté exprès)

`LANCEMENT.md` § 7 et § 2.2 ter/§ 2 : la dette organisateur et les vérifs
« l'événement a-t-il eu lieu » ne se construisent **qu'avant d'accepter des
organisateurs tiers** — pas avant le lancement tant que tu es seul organisateur.
Vues/impressions des stats, recommandation, demandes de message : après.
