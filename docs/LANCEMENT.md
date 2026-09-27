# HAPPYN — État et ce qui reste

État au 2026-09-27. **Le code n'est plus le goulot d'étranglement.** Ce qui
reste se répartit en trois familles très inégales : des **décisions** (rapides,
mais elles bloquent le reste), de la **configuration** (mécanique), et ce qui
n'est **pas encore écrit**.

Ce dernier groupe a changé : Stripe Connect est fait (§ 4). Ce qui manque encore
et **n'est pas du peaufinage** : l'organisateur ne voit nulle part ses
statistiques (aucun écran `analytics` dans `lib/`), aucun rappel avant un
événement n'existe (ni `pg_cron` ni courriel destiné à un utilisateur), et Sign
in with Apple n'est pas implémenté alors que la guideline 4.8 peut l'exiger dès
que Google est proposé.

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
| Registre des paiements (`payments`) — répond à « il a payé, pas de billet » | ✅ code |
| Stripe Connect : inscription, versements, contestations | ✅ code, § 4 |

---

## 2. Décisions en attente

### 2.1 Le taux de commission — la dernière décision d'affaires

Le mécanisme existe désormais (§ 4), mais **le taux est un placeholder à 5 %**,
posé dans `public.platform_fee_bps()`. Il faut le trancher avant la première
vente réelle : le taux est **figé sur chaque événement à sa création**, donc le
changer ne corrigera pas les événements déjà publiés.

Le calcul actuel : l'organisateur touche `brut − remboursements − frais Stripe −
commission`. C'est-à-dire que **les frais Stripe sont à la charge de
l'organisateur**, pas de HAPPYN. C'est ce qui rend le modèle viable : à 5 % de
commission sur un billet à 20 $, HAPPYN garde 1,00 $ ; si HAPPYN absorbait aussi
les 0,88 $ de Stripe, il resterait 0,12 $ par billet.

Reste à décider si un **frais de service à l'acheteur** s'ajoute. Les deux
modèles coexistent dans l'industrie ; le choix se voit à l'achat, donc il change
le texte affiché, pas seulement le calcul.

### 2.2 Le moment du versement — décidé et implémenté

**Fin de l'événement + 3 jours**, dans `public.payout_delay_days()`.

La fenêtre d'annulation se ferme avant le début de l'événement
(`events.cancellation_hours`), donc au moment du versement plus aucun
remboursement ne peut être demandé depuis l'app. Les contestations bancaires
restent possibles 120 jours : elles sont traitées à part (§ 4), en neutralisant
le paiement contesté au lieu d'attendre.

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

### 3.2 Le contrôle du nonce est désactivé sur la connexion Google

Le fournisseur Google de Supabase tourne avec **« Skip Nonce Check » activé**.
Il a fallu le désactiver pour que la connexion Google fonctionne sur iPhone : le
SDK iOS de Google renvoie un nonce haché dont la valeur d'origine est
irrécupérable, et `google_sign_in` 6.x n'expose aucun paramètre pour en fournir
un. Supabase attendait donc un nonce que personne ne pouvait lui donner.

Ce que ça coûte : Supabase accepte désormais **n'importe quel** jeton Google
valide et non expiré dont l'audience est un de nos client IDs, sans vérifier
qu'il a été émis pour cette tentative de connexion précise. Un jeton qui fuit
— journal de plantage, log serveur, appareil compromis — peut être rejoué pour
ouvrir une session au nom de son propriétaire, dans l'heure qui suit son
émission.

Ce qui limite la portée : le jeton est signé par Google, son audience doit être
un de nos client IDs, Google lie l'émission d'un client iOS au bundle
`com.happyn.happyn`, et le jeton expire en une heure.

**Déclencheur atteint** : avant d'ouvrir les inscriptions à des gens qu'on ne
connaît pas. Tant que l'app est entre nos mains, la fenêtre est étroite ; elle
s'élargit avec chaque compte réel.

**Le correctif** : migrer vers `google_sign_in` 7.x, adossé au SDK
GoogleSignIn-iOS 9.0, qui permet enfin de passer un nonce. On le génère, on le
donne à Google *et* à `signInWithIdToken`, et on redécoche la case. La 7.x casse
l'API (`signIn()` devient `authenticate()`), il faut donc réécrire
`_signInWithGoogle` dans `login_screen.dart` — compter un cycle de compilation
et de test sur appareil.

### 3.3 Les textes légaux existent à trois endroits

`legal_documents` en base, `web/assets/data/legal-fallback.json`, et **254
lignes en dur dans `lib/core/legal/legal_content.dart`**. Quand les textes
seront remplacés, l'app affichera encore ceux de juillet si on ne touche qu'à la
base — une app qui affiche des conditions périmées est un problème juridique en
soi.

### 3.4 La relecture légale

Le brouillon complet est écrit (`docs/LEGAL-DRAFT.md`, 31 000 caractères contre
7 300 pour les textes en ligne). Il reste à trancher les `[À DÉCIDER]` et à
**faire relire par un avocat** admis en Ontario et à l'aise avec le droit
québécois.

Les magasins d'applications exigent une politique de confidentialité
accessible : c'est aussi un prérequis de publication, pas seulement une
précaution.

---

## 4. Stripe Connect — écrit, reste à activer

Le code est en place : `stripe_connect.sql`, les fonctions `connect-onboard`,
`connect-refresh`, `run-payouts`, et l'écran **Réglages → Outils organisateur →
Versements**.

### Le montage retenu, et ce qu'il implique

« **Separate charges and transfers** » : HAPPYN encaisse la totalité, puis vire à
l'organisateur 3 jours après l'événement. Les deux autres montages Stripe
envoient l'argent à l'achat, ce qui rendrait un remboursement dépendant du solde
d'un compte qu'on ne contrôle pas.

**La contrepartie est juridique, pas technique** : HAPPYN est le marchand
officiel. C'est HAPPYN qui apparaît sur le relevé bancaire de l'acheteur, qui
porte les contestations de carte, et qui est redevable des taxes de vente. À
rapprocher de la décision 2.4 sur l'entité juridique — tant que l'entité est une
personne physique, c'est une responsabilité personnelle.

### Ce qui reste à faire, dans l'ordre

1. **Activer Connect** dans le tableau de bord Stripe (profil de plateforme). En
   attendant l'incorporation, l'inscription se fait comme particulier /
   entreprise individuelle.
2. **Appliquer la migration** `20260927000000_stripe_connect.sql`.
3. **Poser les secrets** des fonctions Edge :
   - `PAYOUT_HOOK_SECRET` — à générer, long et aléatoire. C'est lui seul qui
     protège la fonction qui déplace l'argent.
   - `CONNECT_RETURN_URL` / `CONNECT_REFRESH_URL` — optionnels, deux pages web
     qui renvoient vers l'app. Par défaut `happynevents.com/connect-return.html`
     et `connect-refresh.html` : **ces pages doivent exister**, sinon
     l'organisateur tombe sur une 404 en sortant du formulaire.
4. **Déployer** `connect-onboard`, `connect-refresh` (avec JWT), `run-payouts`
   (`--no-verify-jwt`), et **redéployer** `create-payment-intent` et
   `stripe-webhook`.
5. **Ajouter les événements au webhook Stripe** : `charge.refunded`,
   `charge.dispute.created`, `charge.dispute.closed` en plus de
   `payment_intent.succeeded`. Sans eux, un remboursement ne serait pas déduit
   du versement — donc versé deux fois.
6. **Planifier `run-payouts`** une fois par jour. À exécuter dans le SQL Editor,
   avec le vrai secret — **ne jamais committer cette version** :

   ```sql
   -- pg_cron + pg_net doivent etre actives (Database > Extensions).
   select cron.schedule(
     'happyn-payouts', '17 9 * * *',
     $$select net.http_post(
         url     := 'https://<projet>.supabase.co/functions/v1/run-payouts',
         headers := '{"x-happyn-secret":"<PAYOUT_HOOK_SECRET>"}'::jsonb
       )$$);
   ```

   En attendant, la fonction s'appelle à la main — elle est idempotente, un
   appel de plus ne verse rien deux fois.
7. **Passer Stripe en mode production** (toujours en mode test aujourd'hui).

### Effet immédiat sur les ventes

`create-payment-intent` **refuse désormais de vendre un billet payant** si
l'organisateur n'a pas de compte Connect actif (`organizer_not_payable`). C'est
délibéré : encaisser sans pouvoir reverser crée une dette. Conséquence pratique —
**il faut faire son propre parcours d'inscription avant de tester une vente
payante**, y compris sur ses propres événements de test.

### Ce qui reste hors périmètre

- **Reprise d'un virement échoué** : la ligne passe en `failed` avec son motif
  (`balance_insufficient` étant le cas courant) et se reprend à la main. Un
  réessai automatique sur un versement demande d'être certain de ne pas doubler.
- **Réponse aux contestations** : le paiement est neutralisé automatiquement et
  journalisé en erreur, mais répondre à la banque se fait dans le tableau de bord
  Stripe, dans le délai imparti.

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
  `errEnterLocation`) — plus `analytics` et `attendeeManagement`, restes des
  entrées « bientôt » retirées des Réglages
- **Frais Stripe indisponibles au moment du webhook** : si la
  `balance_transaction` n'est pas encore lisible, le registre garde `null` et le
  calcul compte 0 — HAPPYN absorbe alors ces frais. Rare, mais l'écart est
  silencieux : à surveiller dans les journaux (`frais indisponibles`)
- **`accountState` est dupliqué** dans `connect-onboard` et `connect-refresh`,
  faute de CLI Supabase sur le poste (un import `_shared/` casserait le
  déploiement depuis le tableau de bord). Si l'une change, changer l'autre
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
3. **Trancher 2.1 (le taux) et 2.3** — une soirée de réflexion
4. **Activer Stripe Connect** — les 7 étapes du § 4, dont une seule dépend d'une
   décision (le taux) ; le reste est de la configuration
5. **Relecture légale** + les trois copies de textes à réconcilier

Les étapes 1, 2 et 4 peuvent se faire **cette semaine**. Le reste attend soit une
décision, soit un avocat.

Ensuite, et seulement ensuite : revenus/statistiques de l'organisateur, rappels
avant événement, Sign in with Apple. Aucun des trois n'est cosmétique.
