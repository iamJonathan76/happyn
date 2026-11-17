# HAPPYN — Chemin vers la mise en production

Liste de travail, établie le 2026-11-13, **réécrite le 2026-11-16** autour du cap
décidé par Emmanuel : **app complète (paiement inclus) → validation Apple →
lancement à la main**. Le **pourquoi** vit dans `LANCEMENT.md` ; ici le **quoi
faire**, dans l'ordre. Légende :

- 🧑 = toi, dans une console / un contact externe (je ne peux pas le faire)
- 🤖 = du code ou de la config que je peux faire avec toi
- 🚪 **Porte** : la plus petite étape que l'item débloque
  — `interne` = TestFlight interne (équipe, ≤ 100, sans revue)
  — `revue` = la revue Apple (TestFlight externe / App Store)
  — `lancement` = la sortie publique, déclenchée **à la main**

---

## Le principe

On soumet **l'app complète, paiement compris** (pas de « bientôt » : Apple recale
les placeholders). On la fait **valider**, puis — comme on lance nous-mêmes — on
garde l'app approuvée en **sortie manuelle** (« manual release ») jusqu'au feu
vert. **Tout au nom d'Emmanuel** pour l'instant (personne physique). La société
et le transfert s'étudient **en parallèle**, sans bloquer la validation.

Conséquences (détail `LANCEMENT.md` § 0) :
- **Pas d'IAP Apple** : billets = service réel, Stripe permis (à reconfirmer en
  soumettant). Pas de 30 %.
- **Le paiement doit marcher pour la revue** → Stripe Connect fonctionnel + un
  **chemin de test** pour le relecteur (il ne saisit pas de vraie carte).
- **Valider ≠ lancer** : l'exposition de marchand ne devient réelle qu'au
  lancement ; on peut donc valider maintenant et incorporer avant de lancer.

> **Règle qui tient partout** : une fois de vrais utilisateurs installés,
> migrations **additives** seulement, et **toujours** `tests/rls/run.sh` avant la
> prod. Une migration ne devient live que lorsqu'on l'applique soi-même.

---

## Phase 0 — Décisions

- [x] 🧑 **Entité juridique — décidé : personne physique (Emmanuel).** Transfert
  vers une société documenté, à faire **avant le lancement réel**, pas avant la
  validation. `LANCEMENT.md` § 2.4.
- [ ] 🧑 **Qui absorbe les frais Stripe d'un billet remboursé** — à trancher
  avant les **premières vraies ventes** (donc avant le lancement, pas avant la
  revue). `LANCEMENT.md` § 2.1 (fin).
- [ ] 🧑 **Contestations bancaires** — qui porte les 15 $ et le prix du billet.
  Pas bloquant tant que tu es seul organisateur. `LANCEMENT.md` § 2.2 ter.
- [ ] 🧑 **Plancher d'annulation (option A)** — retirer « aucune annulation ».
  Un petit 🤖 suit (écran de création + garde-fou base). `LANCEMENT.md` § 2.3.

---

## Phase 1 — Rendre le paiement fonctionnel (pré-requis de la revue)

Une app « validée avec paiement » suppose un flux payant qui **marche** et que le
relecteur peut exercer.

- [ ] 🧑🤖 **Stripe Connect en production** — sous-liste `LANCEMENT.md` § 4 :
  - [ ] 🧑 Activer Connect dans Stripe (entreprise individuelle, au nom d'Emmanuel)
  - [ ] 🤖 Appliquer `20260927000000_stripe_connect.sql`
  - [ ] 🧑 Secrets Edge : `PAYOUT_HOOK_SECRET` ; (`CONNECT_RETURN_URL` /
    `CONNECT_REFRESH_URL` — pages déjà en place)
  - [ ] 🧑🤖 Déployer `connect-onboard`, `connect-refresh`, `run-payouts`, et
    **redéployer** `create-payment-intent` + `stripe-webhook`
  - [ ] 🧑 Webhook Stripe : ajouter `charge.refunded`, `charge.dispute.created`,
    `charge.dispute.closed`
  - [ ] 🧑 Passer Stripe en **mode production**
  - [ ] 🧑 **Ton propre parcours d'inscription Connect** (pour vendre tes events)
  - [ ] 🧑 Poser `payout_hook_url` / `payout_hook_secret` dans `private.settings`
    et **surveiller le premier versement réel à la main** (cron déjà planifié)
- [ ] 🧑 **Commission 3 % + 0,99 $ en production** (codée/testée, commit `c70075d`) :
  - [ ] 🧑 Appliquer `20261115000000_commission_fixed_fee.sql` (d'abord : l'Edge
    lit la nouvelle colonne)
  - [ ] 🧑 Redéployer `create-payment-intent` + `stripe-webhook` — **les mêmes
    deux fonctions que Connect ci-dessus** : en une seule fois
- [ ] 🧑🤖 **Chemin de test pour le relecteur Apple** — le relecteur ne saisit pas
  de vraie carte. Préparer un **événement de démo** + un **code promo/gratuit**
  (ou des instructions de test dans App Store Connect). À caler avec le flux réel.
  🚪 **revue — sans ça, le paiement n'est pas vérifiable**

---

## Phase 2 — TestFlight interne (sur de vrais iPhone)

- [x] ✅ Compte Apple Developer pris (2026-10-10)
- [x] ✅ Mac de build, entitlements (Push + Apple), `GoogleService-Info.plist`,
  `dart_defines.json` (Sentry)
- [x] ✅ **Permissions iOS en français** — `fr.lproj`/`en.lproj/InfoPlist.strings`
  posés le 2026-11-16 (le projet Xcode les référençait déjà)
- [ ] 🧑 **Clé APNs (.p8)** créée dans le portail Apple et ajoutée à Firebase
- [ ] 🧑 **Créer l'app dans App Store Connect** — nom, `com.happyn.happyn`,
  langue principale 🚪 interne
- [ ] 🤖 **Remplir `kAppStoreUrl` / `kPlayStoreUrl`** dans
  `lib/core/config/store_config.dart` dès qu'App Store Connect donne l'identifiant
- [ ] 🧑 **Fiche de confidentialité** App Store (d'après la politique publiée)
- [ ] 🧑 **Archive + envoi** : `flutter build ipa --dart-define-from-file=dart_defines.json`,
  puis Xcode/Transporter ; téléverser les symboles Sentry 🚪 interne
- [ ] 🧑 **Inviter les testeurs internes** (jusqu'à 100) — sans revue

---

## Phase 3 — Validation Apple (sortie manuelle)

- [ ] 🧑 **Google OAuth → « Production »** (Google Cloud Console). En « Test »,
  Google refuse tout compte hors liste : la connexion Google serait cassée pour
  le relecteur et le public. Portées `email`/`profile` seulement, pas de
  vérification longue. `LANCEMENT.md` § 3.1 bis 🚪 **revue — bloqueur**
- [x] ✅ **`fr.lproj/InfoPlist.strings`** — fait le 2026-11-16
- [ ] 🧑 **Relecture légale par un avocat** (ON + QC), FR et EN. `LANCEMENT.md`
  § 3.4 🚪 lancement (décision de risque)
- [ ] 🧑 **Soumettre à la revue**, avec le chemin de test (Phase 1) et la
  **sortie réglée sur « manuelle »** : l'app est approuvée puis **attend** ton
  feu vert. 🚪 revue

---

## Phase 4 — Activations serveur

Du code déjà écrit qui ne tourne pas tant que le cron n'est pas posé (éditeur SQL
Supabase).

- [ ] 🧑 **Cron des rappels d'événement** — `private.send_event_reminders()`
  existe, aucun `cron.schedule` ne l'appelle. `LANCEMENT.md` (haut + § 5)
- [ ] 🧑 **Cron des demandes de note** — `private.send_rating_requests()` ; une
  fois l'écran de notation chez les testeurs. `LANCEMENT.md` § 5

---

## Phase 5 — Lancement (à la main)

- [ ] 🧑 **Incorporer la société + D-U-N-S** si on veut lancer sous la société,
  ou lancer d'abord au nom d'Emmanuel — à trancher avec l'avocat. **Avant
  d'ouvrir à des organisateurs tiers** dans tous les cas. `LANCEMENT.md` § 2.4.
- [ ] 🧑 **Déclencher la sortie** dans App Store Connect (release manuelle).
- [ ] 🧑 **Google Play** : test interne (clé de signature + SHA-1,
  `google-services.json`, Play Console 25 $, bundle `--dart-define-from-file`,
  symboles Sentry), puis production. `LANCEMENT.md` § chemin 2

---

## Ce qui est **déjà fait** (ne pas refaire)

- Sign in with Apple (natif, testé iPhone), Google (nonce rétabli), reset mot de passe
- Notifications poussées **Android + iOS** testées
- Entitlements, `GoogleService-Info.plist`, `dart_defines.json`, pages web Connect
- **Permissions iOS en français** (fr.lproj / en.lproj)
- Textes légaux publiés FR/EN (Version 1.0/1.1), écran de consentement
- Sentry branché et vérifié
- **Tableau de bord organisateur** (revenu net, vendus, entrées, taux, versement, classement)
- Modération + alerte courriel, suppression de compte, registre des paiements
- Maintenance & version minimale (reste à remplir les URLs store)
- **Tout le chemin payant est écrit et testé** (Stripe Connect, commission
  3 % + 0,99 $) — il ne manque que l'activation (Phase 1)

---

## Hors périmètre du lancement (reporté exprès)

`LANCEMENT.md` § 7 et § 2.2 ter/§ 2 : la dette organisateur et les vérifs
« l'événement a-t-il eu lieu » ne se construisent **qu'avant d'accepter des
organisateurs tiers**. Vues/impressions des stats, recommandation, demandes de
message : après.
