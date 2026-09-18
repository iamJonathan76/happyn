# HAPPYN — État et ce qui reste

État au 2026-09-18. Le produit est construit. Ce qui reste se répartit en trois
familles très inégales : des **décisions** (rapides, mais elles bloquent tout le
reste), de la **configuration** (mécanique), et du **code** (un seul gros
chantier).

---

## 1. Fait, et vérifié de bout en bout

| | Livré |
|---|---|
| Découverte, billetterie, QR signé rotatif, scanner | ✅ |
| Transfert de billet | ✅ |
| Événements privés, code d'invitation, portée des photos | ✅ |
| Partie sociale : publications, fil, profils, suivi, « Qui y va » | ✅ |
| Âge (14 / 18), FR-EN complet dans l'app | ✅ |
| Suppression de compte | ✅ |
| Modération complète — Apple 1.2 | ✅ testée |
| Domaine, SMTP, adresse de contact | ✅ |
| Réinitialisation du mot de passe | ✅ testée |
| Compteur de ventes pour l'organisateur | ✅ |
| Sécurité : RLS versionnée, 3 failles fermées, doc | ✅ |
| Site en ligne (`happynevents.com`) | ✅ |
| Notifications poussées : envoi, jeton, greffon google-services | ✅ |
| Adresses structurées, autocomplétion, masquage de l'adresse exacte | ✅ |
| Liste des participants pour l'organisateur | ⏳ migration à appliquer |

---

## 2. Décisions en attente

Elles ne prennent que du temps de réflexion, mais **rien n'avance sans elles**.

### 2.1 Le modèle économique — le plus bloquant

**HAPPYN ne prend aucune commission aujourd'hui.** Stripe prélève 2,9 % + 0,30 $.
Si le prix intégral du billet va à l'organisateur, **chaque vente coûte de
l'argent** — 0,88 $ sur un billet à 20 $, de ta poche.

À trancher : commission sur l'organisateur, frais de service à l'acheteur, les
deux, ou rien (subvention). Le montant du virement en dépend directement, donc
**Stripe Connect ne peut pas être construit avant**.

### 2.2 Le moment du versement

Recommandation : **jour de l'événement + 3 à 7 jours**. Trois raisons — la
fenêtre d'annulation doit être fermée avant de verser, un faux événement devient
impossible à monétiser, et une contestation bancaire reste possible 120 jours.

### 2.3 Le plancher d'annulation

Aujourd'hui l'organisateur peut choisir `0` (aucune annulation), et **rien ne le
signale à l'acheteur**. C'est le défaut de ce qui vient d'être livré.

- **A** — retirer `0` : minimum 24 h garanti par HAPPYN
- **B** — garder `0` mais l'afficher clairement à l'achat

Recommandation : **A** pour le lancement.

### 2.4 L'entité juridique

Tant qu'il n'y a pas d'entreprise, les conditions te lient **personnellement**,
et tu portes la responsabilité des événements d'autrui vendus sur ta plateforme.
Stripe Connect l'exigera probablement de toute façon. C'est aussi ce qui
ouvrirait `happyn.ca`.

### 2.5 Les onze `[À DÉCIDER]` du recueil légal

Voir `docs/LEGAL-DRAFT.md`. Les plus urgents : la taxe de vente (TPS/TVH — qui
perçoit et remet), et le remboursement automatique ou non d'un événement annulé.

---

## 3. Configuration en attente

- **Migration `20260902000000_cancel_ticket.sql`** à appliquer
- **`supabase functions deploy cancel-ticket`** (avec JWT)
- **Migration `20260918000000_event_attendees.sql`** à appliquer — sans elle, la
  liste des participants affiche son message d'erreur : l'écran est livré, la
  fonction `event_attendees` n'existe pas encore en base
- **DSN Sentry** — le code est branché, il ne manque que
  `--dart-define=SENTRY_DSN=…`. Déclencheur : avant la première version donnée à
  quelqu'un d'autre que nous.

---

## 4. Code restant

### 4.1 Le seul gros chantier — Stripe Connect

Aujourd'hui l'argent d'une vente arrive sur un seul compte et rien ne le
redistribue. **HAPPYN ne peut pas vendre les billets d'autrui**, ce qui est
pourtant le produit. Bloqué par les décisions 2.1, 2.2 et 2.4.

Stripe est aussi toujours en **mode test** : aucun vrai paiement n'est possible.

### 4.2 Manques fonctionnels

Les trois manques listés ici au 2026-09-02 — notifications poussées, liste des
participants, autocomplétion d'adresse — ont été livrés depuis. Voir le
tableau § 1. Il ne reste dans cette famille que la migration de la liste des
participants à appliquer, notée en § 3.

### 4.3 Dette à traiter avant publication

**⚠️ Les textes légaux existent à trois endroits** : `legal_documents` en base,
`web/assets/data/legal-fallback.json`, et **254 lignes en dur dans
`lib/core/legal/legal_content.dart`**. Quand les textes seront remplacés, l'app
affichera encore ceux de juillet si on ne touche qu'à la base — une app qui
affiche des conditions périmées est un problème juridique en soi.

- **Migration `locale`** sur `legal_documents` (aucune colonne de langue
  aujourd'hui), puis traduction française
- **Deux documents à créer** : `content-moderation`, `account-deletion`
- **Test avec grande police système** — jamais fait, et un débordement s'y
  cachait déjà
- **Version française du site** (l'app est bilingue, le site non)

### 4.4 Sécurité — points ouverts

Détail dans `docs/SECURITY.md` § 6.

- **Buckets publics** → URLs signées
- **Limitation de débit** sur `unlock_private_event`
- **Pas de protection capture d'écran iOS** — assumé
- **`public_profiles` lisible par les comptes bloqués**
- **Aucun test sur les policies** — les trois failles de ce projet étaient
  toutes dans des policies, et les 17 tests actuels ne couvrent que de la
  logique pure

---

## 5. Publier

| | Coût |
|---|---|
| Google Play Console | 25 $ US, une fois |
| Apple Developer Program | 99 $ US/an |

**Le piège iOS :** compiler exige macOS. Sans Mac — service de build cloud ou
Mac mini d'occasion.

**Ordre conseillé :** Google Play d'abord. Pas de Mac, 25 $, en ligne
rapidement.

---

## 6. Reporté volontairement

- **Recommandation** — voir `docs/RECOMMANDATION.md`. Signal pour y revenir :
  quand un utilisateur ne peut plus voir tout ce qui l'intéresse en une page.
- **Modération à l'échelle** — regroupement par cible, seuil de retrait
  automatique, attribution entre modérateurs, tableau de bord web. Déclencheurs
  détaillés dans `docs/SECURITY.md`.
- **Requêtes SQL enregistrées** pour le suivi produit.

---

## Le chemin le plus court vers un lancement

1. **Décider 2.1, 2.2, 2.3** — une soirée de réflexion
2. **Appliquer les migrations en attente** (annulation, participants) et
   déployer `cancel-ticket`
3. **Relire le recueil légal**, trancher les `[À DÉCIDER]`, faire relire par un
   avocat
4. **Régler la dette des trois copies** de textes légaux
5. **Google Play**, en bêta fermée d'abord

Stripe Connect vient après : il ne bloque pas une bêta où tu es le seul
organisateur. Les notifications poussées, elles, ne sont plus un sujet — elles
sont livrées.
