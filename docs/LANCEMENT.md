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
| Suppression de compte — v2 : ne fait perdre ni argent ni preuves | ✅ code, en prod (2026-10-06) |
| Page publique de suppression, exigée par Google Play | ✅ code, `web/delete-account.html` |
| Annulation et versement ne peuvent plus se croiser | ✅ en prod (2026-10-06) |
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

### 2.1 Le taux de commission — décidé : 5 %

**5 %**, confirmé le 2026-09-29. `public.platform_fee_bps()` vaut déjà 500 : il
n'y a rien à changer. (Le commentaire « placeholder » dans
`20260927000000_stripe_connect.sql` est désormais périmé ; la migration est
appliquée, on ne la réécrit pas.)

Le taux est **figé sur chaque événement à sa création**. Le changer plus tard
ne touchera que les événements créés ensuite.

**Pas de frais de service à l'acheteur.** Le prix affiché est le prix payé.
Ajouter des frais à la dernière étape du paiement est précisément ce que la loi
ontarienne sur la protection du consommateur regarde de travers, et ce serait en
contradiction avec le reste du produit.

#### Le prix se saisit en NET, pas en brut

L'organisateur dit ce qu'il veut **toucher** ; l'app calcule ce que l'acheteur
paiera :

    prix affiché = (net + 0,30) / (1 − 0,029 − commission)

20 $ voulus donnent 22,05 $ affichés (arrondi au cent **supérieur** : on ne
rend jamais moins que demandé). Les deux champs se suivent dans les deux sens,
et des pastilles d'arrondi (0,25 / 0,50 / 1 / 5 $) permettent d'éviter un
« 22,05 $ » disgracieux — l'organisateur voit aussitôt ce que l'arrondi lui
rapporte.

Le calcul vit dans `lib/core/payments/pricing.dart`, couvert par
`test/pricing_test.dart`, et reproduit `event_ledger` : *brut − frais Stripe −
commission*. Le taux est **lu en base** (`platformFeeBpsProvider`) et non
recopié : deux définitions finiraient par diverger.

**C'est une estimation, et l'interface le dit** (« Tu reçois environ »). Une
carte étrangère coûte ~3,5 % à Stripe au lieu de 2,9 % : le montant exact
n'existe qu'après la vente, et c'est celui de l'écran Versements.

Reste ouvert : **qui absorbe les frais Stripe d'un billet remboursé** (Stripe ne
les rend pas). Faible enjeu tant que les annulations sont rares, mais à trancher
une fois.

### 2.2 Le moment du versement — décidé et implémenté

**Fin de l'événement + 3 jours**, dans `public.payout_delay_days()`.

La fenêtre d'annulation se ferme avant le début de l'événement
(`events.cancellation_hours`), donc au moment du versement plus aucun
remboursement ne peut être demandé depuis l'app. Les contestations bancaires
restent possibles 120 jours : elles sont traitées à part (§ 4), en neutralisant
le paiement contesté au lieu d'attendre.

### 2.2 bis Remboursements — décidé : intégral des deux côtés

**2026-10-02.** Qu'il s'agisse d'une annulation par l'organisateur ou par
l'acheteur, le remboursement est **intégral**. HAPPYN ne retient aucun frais.

Ce que ça coûte : Stripe ne rend pas sa commission sur un remboursement, donc
chaque billet remboursé coûte ~0,88 $ (sur 20 $) à la plateforme.

Pourquoi ne pas retenir ce dollar : une retenue d'un dollar déclenche des
contestations bancaires à **15 $**. Et au stade d'un lancement, un acheteur
mécontent coûte plus cher qu'un dollar. Le levier existe déjà ailleurs —
`cancellation_hours` à 0 interdit purement l'annulation par l'acheteur.

Révisable plus tard : une condition peut se durcir pour les achats à venir,
jamais rétroactivement.

#### L'asymétrie qui compte

Les deux cas n'ont pas la même forme de risque :

- **L'acheteur annule** : minoritaire au sein d'un événement. Les billets
  gardés du même événement couvrent la perte (1,00 $ de commission contre
  0,88 $ de frais perdus).
- **L'organisateur annule** : 100 % des billets remboursés, donc aucune
  commission sur cet événement. Rien ne le couvre à l'intérieur. Ce sont les
  AUTRES événements qui paient — 200 billets annulés coûtent 176 $, soit la
  marge de 3 520 $ de ventes réussies ailleurs.

Aujourd'hui le versement est borné à zéro (`greatest(..., 0)`) : le solde
négatif est effacé, pas reporté. **C'est donc HAPPYN qui absorbe**, et qui ne
récupère jamais.

#### La dette organisateur — à construire avant d'ouvrir à des tiers

La réponse à ce cas est de reporter le solde négatif sur les **prochains**
versements de l'organisateur : la plateforme avance, puis récupère. C'est ce
que font Eventbrite et Stripe.

Déclencheur : **avant d'accepter des organisateurs tiers**, pas avant le
lancement — tant que tu es seul organisateur, personne d'autre ne peut te
faire perdre d'argent en annulant.

Deux faiblesses connues du modèle, à traiter en même temps :

- l'organisateur qui ne revient jamais : dette irrécupérable. Parade —
  interdire de publier un événement payant tant qu'une dette existe ;
- l'organisateur découragé : il faut annoncer le coût **dans le dialogue
  d'annulation**, à côté de « 200 billets, 4 000 $ à rembourser ».

En attendant, la vraie protection est de **choisir à la main** qui a le droit
de vendre.

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

### 3.1 bis L'écran de consentement Google bloque tout le monde sauf toi

Symptôme observé : la connexion Google marche sur le téléphone du développeur,
pas sur celui d'un ami. Ce n'est pas un bug de l'app.

Tant que l'écran de consentement OAuth est en statut **« Test »**, Google
n'autorise QUE les comptes inscrits dans la liste des testeurs — 100 au maximum,
ajoutés un par un à la main. Tout autre compte reçoit un refus de Google avant
même d'atteindre l'app.

**C'est un bloqueur de lancement, pas un détail** : publier l'app dans cet état
signifie que personne ne peut se connecter avec Google.

Le correctif est le passage en **« Production »** dans Google Cloud Console →
API et services → Écran de consentement OAuth. Bonne nouvelle : l'app ne demande
que les portées `email` et `profile` (voir `login_screen.dart`), qui ne sont pas
sensibles — le passage en production n'exige donc pas l'examen de vérification
de Google, qui prend des semaines.

Dans l'intervalle, ajouter un compte à la liste des testeurs prend trente
secondes et prend effet immédiatement.

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

### Stripe Accounts v1 — compatibilité activée, migration v2 à prévoir

Le 2026-09-29, la création de compte connecté a été refusée :

> Stripe no longer recommends Accounts v1 for new Connect integrations.
> Create connected accounts with POST /v2/core/accounts instead.

Stripe a changé de modèle de comptes entre l'écriture de `connect-onboard` et
sa première exécution réelle. Débloqué en activant **Accounts v1 support** dans
le tableau de bord (un scénario de compatibilité que Stripe supporte
explicitement) :
`dashboard.stripe.com/settings/developers/api-policies/feat_accounts_v1_support`

**À faire un jour** : porter `connect-onboard` sur `POST /v2/core/accounts` et
le parcours d'inscription associé. Ce n'est pas urgent — l'interrupteur tient —
mais une compatibilité finit toujours par être retirée.

Au passage, la clé d'idempotence était purement dérivée de l'utilisateur. Stripe
mémorise la réponse d'une clé pendant 24 h, **échecs compris** : le premier refus
était donc rejoué à chaque nouvelle tentative, même après correction de la cause.
La date fait maintenant partie de la clé.



- **Buckets de stockage publics** → URLs signées
- **Limitation de débit** sur `unlock_private_event`
- **`path_provider_foundation` figé en 2.4.1** (surcharge dans `pubspec.yaml`) —
  à retirer quand la chaîne amont sera réparée, un paquet figé ne reçoit plus
  les correctifs de sécurité
- **Aucun test sur les policies** — les trois failles de ce projet étaient
  toutes dans des policies, et les 17 tests ne couvrent que de la logique pure
- ~~**Test avec grande police système** jamais fait~~ — fait sur iPhone, et il
  révélait cinq casses : barre d'onglets aux libellés collés (« TicketsProfile »),
  catégories tronquées à deux lettres sur l'accueil, statistiques du profil
  soudées (« FollowersFollowing »), et les titres de Découvrir et Créer un
  événement débordant hors de l'écran. Corrigé. Reste à reprendre le même
  passage sur les écrans non couverts par ces captures : détail d'événement,
  billets, achat
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
- **Demandes de message** — aujourd'hui, quiconque te suit peut t'écrire,
  ce qui garde l'organisateur joignable par son public. Au-delà de quelques
  centaines d'abonnés, sa messagerie devient ingérable et ouverte au
  harcèlement : les messages de gens qu'il ne suit pas devront arriver dans un
  dossier à part, sans notification. HAPPYN n'est pas une app de chat — ne pas
  aller plus loin que ça. Signal : un organisateur qui s'en plaint.
- **Notifications qui suivent la langue après coup** — aujourd'hui une
  notification est écrite une fois, dans la langue du profil à l'envoi
  (`translate_notification`, migration 20261006010000). Changer de langue ne
  traduit pas les anciennes. Version complète : stocker le type et ses valeurs,
  reconstruire la phrase dans l'app. La bulle push, elle, ne changera jamais.
  Signal : une personne qui demande à relire une ancienne notification dans sa
  langue.

---

## 8. Décisions en attente de ta réponse

Regroupées ici parce qu'elles traversent les sessions : ce sont les seules
choses qu'un nouveau contexte ne peut pas deviner.

- **Le taux de commission** — `platform_fee_bps()` est à 500 (5 %), un
  placeholder. Figé par événement à sa création, donc le changer ne corrige pas
  les événements déjà publiés. Voir § 2.1.
- **L'historique des migrations côté Supabase est vide.** Les migrations ont
  toujours été appliquées à la main (éditeur SQL, `db query`), jamais par
  `db push` : la CLI croit donc qu'aucune n'est passée. **Ne jamais lancer
  `supabase db push`** — il rejouerait les 57. Proposé, pas fait :
  `supabase migration repair --status applied` sur chacune, qui ne touche que
  la table de suivi. Vérifié le 2026-10-06 : la base de production contient
  bien tout, jusqu'à `20261006000000` incluse, et les 12 fonctions Edge
  déployées sont identiques au dépôt.
- **Les fichiers l10n générés** — ils sont versionnés et Flutter les réécrit à
  chaque `flutter pub get`, ce qui bloque un `git pull` sur deux. Soit on cesse
  de les versionner (recommandé), soit on garde l'habitude du
  `git checkout --`. Décision d'équipe, Soumare est concerné.
- **Le passage de l'écran de consentement Google en production** — § 3.1 bis.
  Tant qu'il est en « Test », personne d'autre que les comptes listés ne peut se
  connecter.

### L'état du poste de développement

Un Mac dédié au projet depuis le 2026-10-06, donc plus de fenêtre iOS qui se
referme. Depuis : Flutter 3.47.6 et CocoaPods 1.17.0, `flutter build ios
--release --no-codesign` vert.

**Swift Package Manager est interdit dans `pubspec.yaml`**, pas dans la config
d'une machine : le premier build sur ce Mac l'avait réactivé, avec le retour
assuré de `GoogleUtilities` en double (voir le commit `8b126f1`). CocoaPods
1.17 plante sans `LANG=en_US.UTF-8` dans le terminal. Postgres 17 est installé
(`brew install postgresql@17`) pour exécuter une migration sur une base
jetable avant de l'appliquer ; Docker, lui, n'y est pas. Et Firebase cesse de
publier sur CocoaPods après octobre 2026 : passer en SPM complet le jour où
`flutter_secure_storage` le supportera. Les versions connues pour donner un build vert : macOS 26, Xcode 27,
Flutter 3.44.1, Dart 3.12.1, CocoaPods 1.16.2, Firebase iOS 12.18.0, 41 pods.

Deux contournements à ne pas redécouvrir : `IPHONEOS_DEPLOYMENT_TARGET` doit
valoir **15.0** partout (Xcode 27 refuse 13.0, Firebase 12 exige 15), et
`flutter run` échoue sur `Failed to codesign Flutter.framework` à cause de
l'attribut étendu `com.apple.provenance` de macOS 26 — bogue Flutter ouvert.
Lancer depuis **Xcode** puis `flutter attach` ; Xcode tolère l'échec,
`flutter run` le traite comme fatal.

Ce qui n'est PAS dans le dépôt et ne descend pas avec un clone :
`android/app/google-services.json` (console Firebase),
`ios/Runner/GoogleService-Info.plist` (jamais créé — d'où l'absence de
notifications sur iOS), le DSN Sentry passé en `--dart-define`, et l'empreinte
SHA-1 du `debug.keystore`, propre à chaque machine : une machine neuve casse la
connexion Google sur Android tant que sa nouvelle empreinte n'est pas déclarée
dans Google Cloud.

Et ne jamais mettre le dépôt dans un dossier synchronisé (Bureau, iCloud, Google
Drive) : c'est ce qui avait corrompu `.git` avec 332 doublons « 2 ».

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
