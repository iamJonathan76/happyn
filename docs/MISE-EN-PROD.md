# HAPPYN — Chemin vers la mise en production

Liste de travail, établie le 2026-11-13, **restructurée le 2026-11-15 en mode
« gratuit d'abord »**. Le **pourquoi** de chaque décision vit dans
`LANCEMENT.md` ; ici c'est le **quoi faire**, dans l'ordre. Légende :

- 🧑 = toi, dans une console / un contact externe (je ne peux pas le faire)
- 🤖 = du code ou de la config que je peux faire avec toi
- 🚪 **Porte** : la plus petite étape que l'item débloque
  — `interne` = TestFlight interne (équipe, ≤ 100, sans revue)
  — `public` = TestFlight externe « ouvert à tous » (passe la Beta App Review)
  — `store` = App Store / Google Play publics

---

## Le principe : deux paliers

Décidé le 2026-11-15. On lance HAPPYN **avec les événements gratuits seulement**,
puis on ouvre le **payant** plus tard comme une **annonce** (« le boom »). Ce
n'est pas qu'une idée marketing : ça **sort du lancement** les trois chantiers
les plus lourds — Stripe Connect en production, le barème de commission, et
l'incorporation — parce qu'**un événement gratuit ne fait circuler aucun
argent**, donc aucune de ces pièces n'est nécessaire pour ouvrir.

| | **Palier 1 — Lancement GRATUIT** | **Palier 2 — Ouverture du PAYANT (le « boom »)** |
|---|---|---|
| Argent | aucun | Stripe, commission, versements |
| Entité | personne physique (Emmanuel) suffit | incorporer **avant** d'ouvrir à des tiers |
| Bloqueurs | Google OAuth prod, revue Apple, textes légaux | Stripe Connect prod, commission prod, incorporation |
| Risque juridique | quasi nul (pas de marchand, pas de taxe, pas de contestation) | réel — c'est là qu'il faut la société |

**Le mécanisme technique** : un drapeau `paid_events_enabled` (défaut **off**)
qui bloque la création d'events payants. Tout le payant est **déjà codé** ; il
dort derrière le drapeau, se teste en interne, et le « boom » se résume à
**basculer le drapeau** — rien à redéployer. Voir Palier 2.a.

> **La règle qui gouverne les deux paliers** : une fois de vrais utilisateurs
> installés, toute migration de base reste **additive** (on ajoute, on ne
> renomme/supprime pas une colonne qu'un vieux build lit encore), et passe
> **toujours** par `tests/rls/run.sh` avant la prod. Le code de l'app est isolé
> par build ; la base est partagée par tout le monde, en direct.

---

## Phase 0 — Décisions

Les décisions d'argent **ne bloquent plus le lancement** : elles sont déplacées
au Palier 2, où elles ont lieu. Au Palier 1, il ne reste rien à trancher qui
bloque le gratuit.

- [x] 🧑 **Entité juridique — décidé le 2026-11-15 : personne physique pour
  démarrer.** Au nom d'Emmanuel ; transfert vers une société (+ D-U-N-S) étudié
  et documenté (note de décision / PDF du 2026-11-15), à faire **avant** le
  Palier 2. `LANCEMENT.md` § 2.4.
- [x] 🧑 **Plancher d'annulation — décidé : option A** (retirer « aucune
  annulation »). Concept **payant** (il porte sur le remboursement d'un billet) :
  le `🤖` qui le code part au **Palier 2.a**. `LANCEMENT.md` § 2.3.
- [ ] 🧑 **Qui absorbe les frais Stripe d'un billet remboursé** — à trancher
  **avant le Palier 2**, pas avant le lancement. `LANCEMENT.md` § 2.1 (fin).
- [ ] 🧑 **Contestations bancaires** — qui porte les 15 $ et le prix du billet.
  **Palier 2**, et de toute façon pas bloquant tant que tu es seul organisateur.
  `LANCEMENT.md` § 2.2 ter.

---

# PALIER 1 — Lancer en gratuit

## 1.a — Le verrou « gratuit seulement » (🤖, à faire en premier)

- [ ] 🤖 **Drapeau `paid_events_enabled`** (lu en base, défaut **off**) : l'écran
  de création masque la billetterie payante quand il est off, **et** une garde
  SQL refuse un prix > 0 — testée au banc RLS comme le reste. Réversible ; le
  « boom » (Palier 2) est une seule ligne à changer. *Décision ouverte, § 2 à
  confirmer : un compte admin peut-il outrepasser le drapeau pour vos propres
  events payants de test ?* 🚪 interne

> À décider avec toi avant de coder : **zéro payant pour tout le monde**, ou un
> **passe-droit admin** pour qu'Emmanuel teste une vraie vente en coulisse.

## 1.b — TestFlight interne (le plus court)

But : l'app sur de vrais iPhone, ton équipe, sans revue Apple. Le **gratuit** se
teste de bout en bout. (Une app gratuite n'a même pas besoin de l'accord « Paid
Apps » d'Apple — un verrou de moins qu'au Palier 2.)

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

> À ce stade : l'équipe teste tout le **gratuit** de bout en bout. Le payant est
> en veille derrière le drapeau — normal, c'est le Palier 2.

## 1.c — Ouvrir au public (TestFlight externe, lien ouvert à tous)

On passe la **Beta App Review** d'Apple. Un seul vrai bloqueur ici, et il n'a
rien à voir avec l'argent.

- [ ] 🧑 **Google OAuth → « Production »** (Google Cloud Console → Écran de
  consentement). En « Test », Google refuse tout compte hors liste de testeurs :
  la connexion Google est cassée pour le public. Pas de vérification longue à
  subir (portées `email`/`profile` seulement). `LANCEMENT.md` § 3.1 bis
  🚪 **public — bloqueur**
- [ ] 🤖 **`fr.lproj/InfoPlist.strings`** — phrases de permission en français
  (aujourd'hui anglais seulement) 🚪 public
- [ ] 🧑 **Relecture légale par un avocat** (ON + QC), FR et EN — pas un bloqueur
  Apple, mais exposition réelle avec de vrais inconnus. Même en gratuit, les
  textes engagent. `LANCEMENT.md` § 3.4 🚪 public (décision de risque)
- [ ] 🧑 **Soumettre à la Beta App Review** puis diffuser le **lien public**

## 1.d — Activations serveur (gratuit)

Du code déjà écrit qui ne tourne pas tant que le cron n'est pas posé. Éditeur SQL
Supabase. Rien de payant ici.

- [ ] 🧑 **Cron des rappels d'événement** — `private.send_event_reminders()`
  existe (2026-11-12) mais **aucun `cron.schedule`** ne l'appelle. Passage
  horaire. `LANCEMENT.md` (haut + § 5)
- [ ] 🧑 **Cron des demandes de note** — `private.send_rating_requests()` ;
  à activer **une fois la version avec l'écran de notation chez les testeurs**.
  `LANCEMENT.md` § 5 (commande fournie)

---

# PALIER 2 — Ouvrir le payant (le « boom »)

Tout ce qui touche l'argent se regroupe ici. À préparer **en coulisse pendant que
le gratuit est live** (le drapeau garde les utilisateurs côté gratuit), puis à
ouvrir d'un coup le jour de l'annonce.

## 2.a — À régler avant d'ouvrir

- [ ] 🧑 **Incorporer la société + numéro D-U-N-S** — **avant** d'ouvrir le
  payant à des organisateurs tiers (le moment où quelqu'un d'autre peut faire
  perdre de l'argent). ~1-2 semaines. Note de décision du 2026-11-15.
  `LANCEMENT.md` § 2.4
- [ ] 🧑 **Trancher : frais Stripe d'un remboursement**, et **contestations
  bancaires** (§ 2.1 fin, § 2.2 ter) — avant la première vente.
- [ ] 🤖 **Coder l'option A du plancher d'annulation** — retirer « aucune
  annulation » de l'écran de création + garde-fou en base (min 24 h), banc RLS.
  Textes « aucune annulation » à reprendre. `LANCEMENT.md` § 2.3

## 2.b — Stripe Connect en production

Sinon aucun billet payant ne se vend (`organizer_not_payable`, mode test).
Sous-liste `LANCEMENT.md` § 4 :

- [ ] 🧑 Activer Connect dans le tableau de bord Stripe (comme entreprise
  individuelle au nom d'Emmanuel, puis la société une fois incorporée)
- [ ] 🤖 Appliquer la migration `20260927000000_stripe_connect.sql`
- [ ] 🧑 Poser les secrets Edge : `PAYOUT_HOOK_SECRET`, (`CONNECT_RETURN_URL` /
  `CONNECT_REFRESH_URL` — les pages existent déjà)
- [ ] 🧑🤖 Déployer `connect-onboard`, `connect-refresh`, `run-payouts`, et
  **redéployer** `create-payment-intent` + `stripe-webhook`
- [ ] 🧑 Ajouter au webhook Stripe : `charge.refunded`,
  `charge.dispute.created`, `charge.dispute.closed`
- [ ] 🧑 Passer Stripe en **mode production**
- [ ] 🧑 **Ton propre parcours d'inscription Connect** (pour vendre tes events)
- [ ] 🧑 **Poser `payout_hook_url` / `payout_hook_secret`** dans
  `private.settings` et **surveiller le premier versement réel à la main**
  (le cron des versements est déjà planifié depuis le 2026-10-16). § 2.2 / § 8

## 2.c — Barème de commission 3 % + 0,99 $ en production

Modèle d'Emmanuel, codé et testé le 2026-11-15 (commit `c70075d`). Sans ça, l'app
facture encore l'ancien 5 %. Dans l'ordre :

- [ ] 🧑 Appliquer la migration `20261115000000_commission_fixed_fee.sql` dans
  l'éditeur SQL Supabase (d'abord : l'Edge lit la nouvelle colonne)
- [ ] 🧑 Redéployer `create-payment-intent` et `stripe-webhook` — **les mêmes
  deux fonctions que le redéploiement Connect ci-dessus** : à faire en une seule
  fois, pas deux

## 2.d — Le « boom »

- [ ] 🤖 **Basculer `paid_events_enabled` → on.** Une ligne. À ce moment la
  billetterie payante réapparaît dans la création et la garde SQL laisse passer
  les prix > 0.
- [ ] 🧑 **L'annonce** : « vos événements payants sont maintenant possibles ».

---

# PALIER 3 — App Store & Google Play publics

Peut chevaucher les paliers 1 et 2 (un build gratuit peut aller au store avant
l'ouverture du payant).

- [ ] 🧑 **App Store** : soumettre à la revue complète (après TestFlight externe
  concluant)
- [ ] 🧑 **Google Play, test interne** : clé de signature + empreinte SHA-1 de
  publication, `google-services.json`, Play Console (25 $), bundle
  `--dart-define-from-file`, symboles Sentry. `LANCEMENT.md` § chemin 2
- [ ] 🧑 **Google Play, production** après le test interne

---

## Ce qui est **déjà fait** (ne pas refaire)

Vérifié le 2026-11-13 :

- Sign in with Apple (natif, testé iPhone), Google (nonce rétabli), reset mot de passe
- Notifications poussées **Android + iOS** testées
- Entitlements, `GoogleService-Info.plist`, `dart_defines.json`, pages web Connect
- Textes légaux publiés FR/EN (Version 1.0/1.1), écran de consentement
- Sentry branché et vérifié
- **Tableau de bord organisateur** (revenu net, vendus, entrées, taux, versement, classement)
- Modération + alerte courriel, suppression de compte, registre des paiements
- Maintenance & version minimale (il reste juste à remplir les URLs store)
- **Tout le chemin payant est écrit et testé** (Stripe Connect, commission
  3 % + 0,99 $) — il ne manque que l'activation, au Palier 2

---

## Hors périmètre du lancement (reporté exprès)

`LANCEMENT.md` § 7 et § 2.2 ter/§ 2 : la dette organisateur et les vérifs
« l'événement a-t-il eu lieu » ne se construisent **qu'avant d'accepter des
organisateurs tiers** — donc au Palier 2, pas avant. Vues/impressions des stats,
recommandation, demandes de message : après.
