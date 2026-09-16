# HAPPYN — État et ce qui reste

État au 2026-09-16. **Le code n'est plus le goulot d'étranglement.** Ce qui
reste se répartit en trois familles très inégales : des **décisions** (rapides,
mais elles bloquent le reste), de la **configuration** (mécanique), et un seul
vrai **chantier de développement**.

---

## 1. Fait, et vérifié de bout en bout

| | |
|---|---|
| Découverte, billetterie, QR signé rotatif, scanner | ✅ |
| Transfert de billet | ✅ |
| Événements privés, code d'invitation, portée des photos | ✅ |
| Partie sociale : publications, fil, profils, suivi, « Qui y va » | ✅ |
| Âge (14 / 18), FR-EN dans l'app | ✅ |
| Suppression de compte | ✅ |
| Modération complète + alerte courriel — Apple 1.2 | ✅ testée |
| Domaine, SMTP, adresse de contact | ✅ |
| Réinitialisation du mot de passe | ✅ testée |
| Compteur de ventes pour l'organisateur | ✅ |
| Annulation de billet + remboursement | ✅ code |
| Adresses structurées, coordonnées, adresse privée protégée | ✅ |
| « Near You » — GPS, ville, trois états | ✅ |
| **Notifications poussées (Android)** | ✅ testées |

---

## 2. Décisions en attente

### 2.1 Le modèle économique — le plus bloquant

**HAPPYN ne prend aucune commission.** Stripe prélève 2,9 % + 0,30 $. Si le prix
intégral va à l'organisateur, **chaque vente coûte de l'argent** — 0,88 $ sur un
billet à 20 $, de ta poche.

À trancher : commission sur l'organisateur, frais de service à l'acheteur, les
deux, ou rien. **Stripe Connect ne peut pas être construit avant**, puisque le
montant du virement en dépend.

### 2.2 Le moment du versement

Recommandation : **jour de l'événement + 3 à 7 jours**. La fenêtre d'annulation
doit être fermée avant de verser, un faux événement devient impossible à
monétiser, et une contestation bancaire reste possible 120 jours.

### 2.3 Le plancher d'annulation

L'organisateur peut choisir `0` (aucune annulation), et **rien ne le signale à
l'acheteur**.

- **A** — retirer `0` : minimum 24 h garanti par HAPPYN
- **B** — garder `0` mais l'afficher clairement à l'achat

Recommandation : **A** pour le lancement.

### 2.4 L'entité juridique

Sans entreprise, les conditions te lient **personnellement**, et tu portes la
responsabilité des événements d'autrui vendus sur ta plateforme. Stripe Connect
l'exigera probablement. C'est aussi ce qui ouvrirait `happyn.ca`.

### 2.5 Les onze `[À DÉCIDER]` du recueil légal

Voir `docs/LEGAL-DRAFT.md`. Les plus urgents : la taxe de vente (qui perçoit et
remet), et le remboursement automatique ou non d'un événement annulé.

---

## 3. Avant de donner l'app à qui que ce soit

### 3.1 Le DSN Sentry — 30 minutes

Le code est branché, il ne manque que `--dart-define=SENTRY_DSN=…`.

**Déclencheur atteint** : dès que l'app quitte tes mains, tu deviens aveugle aux
plantages — les gens ne les signalent pas, ils désinstallent. Et les plantages
survenus avant l'installation de l'outil sont perdus définitivement.

### 3.2 Les textes légaux existent à trois endroits

`legal_documents` en base, `web/assets/data/legal-fallback.json`, et **254
lignes en dur dans `lib/core/legal/legal_content.dart`**. Quand les textes
seront remplacés, l'app affichera encore ceux de juillet si on ne touche qu'à la
base — une app qui affiche des conditions périmées est un problème juridique en
soi.

### 3.3 La relecture légale

Le brouillon complet est écrit (`docs/LEGAL-DRAFT.md`, 31 000 caractères contre
7 300 pour les textes en ligne). Il reste à trancher les `[À DÉCIDER]` et à
**faire relire par un avocat** admis en Ontario et à l'aise avec le droit
québécois.

Les magasins d'applications exigent une politique de confidentialité
accessible : c'est aussi un prérequis de publication, pas seulement une
précaution.

---

## 4. Le seul gros chantier de code

### Stripe Connect — reverser l'argent aux organisateurs

Aujourd'hui l'argent arrive sur un seul compte et rien ne le redistribue.
**HAPPYN ne peut pas vendre les billets d'autrui**, ce qui est pourtant le
produit. Stripe est aussi toujours en **mode test**.

Bloqué par les décisions 2.1, 2.2 et 2.4.

---

## 5. Publier

| | Coût |
|---|---|
| Google Play Console | 25 $ US, une fois |
| Apple Developer Program | 99 $ US/an |

**iOS est doublement bloqué** : le compte Apple, et macOS pour compiler. Les
notifications poussées iOS en dépendent aussi (APNs).

**Ordre conseillé :** Google Play en **test interne** d'abord. Pas de Mac, 25 $,
et l'app arrive sur de vrais téléphones sans passer par la validation publique.

---

## 6. Dette technique connue

- **Buckets de stockage publics** → URLs signées
- **Limitation de débit** sur `unlock_private_event`
- **`path_provider_foundation` figé en 2.4.1** (surcharge dans `pubspec.yaml`) —
  à retirer quand la chaîne amont sera réparée, un paquet figé ne reçoit plus
  les correctifs de sécurité
- **Aucun test sur les policies** — les trois failles de ce projet étaient
  toutes dans des policies, et les 17 tests ne couvrent que de la logique pure
- **Test avec grande police système** jamais fait
- **Trois clés de traduction orphelines** (`venueHint`, `cityHint`,
  `errEnterLocation`)
- **Aperçu sur carte** à la création d'événement — demande un fournisseur de
  tuiles, donc un coût récurrent

---

## 7. Reporté volontairement

- **Recommandation** — `docs/RECOMMANDATION.md`. Signal pour y revenir : quand
  un utilisateur ne peut plus voir tout ce qui l'intéresse en une page.
- **Admin web** — `docs/LOCALISATION.md` § 8. Signal : ~100 signalements.
- **Modération à l'échelle** — regroupement par cible, seuil de retrait
  automatique, attribution entre modérateurs.
- **Journalisation comportementale** — après le texte légal, jamais avant.

---

## Le chemin le plus court vers de vrais utilisateurs

1. **Brancher Sentry** — avant que l'app quitte tes mains
2. **Google Play, test interne** — 25 $, une soirée
3. **Trancher 2.1, 2.2, 2.3** — une soirée de réflexion
4. **Relecture légale** + les trois copies de textes à réconcilier
5. **Stripe Connect**, une fois 2.1 et 2.4 tranchés

Les étapes 1 et 2 peuvent se faire **cette semaine**. Tout le reste attend soit
une décision, soit un avocat.
