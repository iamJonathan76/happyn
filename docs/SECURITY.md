# HAPPYN — Sécurité

Document de référence, tenu à jour à chaque changement touchant les données, les
policies, les fonctions Edge ou les secrets. Il sert à trois choses : ne rien
oublier avant publication, permettre au second développeur de travailler sans
casser un contrôle sans le savoir, et pouvoir répondre à Apple, Google ou à une
demande Loi 25 sans improviser.

Dernière revue : 2026-09-02.

---

## 1. Les trois règles qui ne se négocient pas

**1. Le contrôle d'accès vit dans la base, jamais dans l'app.**
La clé anon est publique par nature : elle est distribuée dans le binaire. Toute
personne qui installe HAPPYN peut interroger l'API directement, sans passer par
notre interface. Une condition écrite en Dart est donc du confort d'affichage,
pas une protection. Elle peut exister, mais toujours **en plus** d'une policy
RLS ou d'une fonction `SECURITY DEFINER`.

*Déjà pris deux fois :* la faille « n'importe qui pouvait rattacher une
publication à n'importe quel événement » (corrigée le 2026-08-09), et la portée
des publications appliquée seulement par la vue `feed_posts` alors que la table
`posts` restait en `using (true)` (corrigée le 2026-08-14).

**2. Aucun secret réel dans le dépôt.**
Voir §5. Un secret commité est compromis même après `git rm` — l'historique le
garde, et le dépôt sera partagé.

**3. Une policy sans RLS activée ne protège rien.**
`create policy` sur une table où `row level security` n'est pas activé est
silencieusement inerte. Pas d'erreur, pas d'avertissement. Voir le point
bloquant §6.1.

---

## 2. Qui peut lire quoi

### Tables couvertes par une RLS écrite dans les migrations

| Table | Lecture | Écriture |
|---|---|---|
| `profiles` | soi-même uniquement | soi-même |
| `posts` | événement à photos publiques, **ou** organisateur / détenteur de billet | auteur uniquement |
| `post_likes` | même règle que la publication liée | soi-même |
| `follows` | tous | soi-même |
| `favorites` | soi-même | soi-même |
| `blocked_users` | soi-même | soi-même |
| `reports` | son propre signalement | insertion seule |
| `event_attendance` | via `who_is_going()` uniquement | trigger + RPC, jamais le client |
| `notifications` | destinataire | destinataire (lu/non-lu) |
| `legal_documents` | tous | aucune (contenu géré en base) |
| `user_legal_acceptances` | soi-même | soi-même |
| `categories` | tous | aucune |
| `events` | public, ou createur, ou detenteur de billet | createur |
| `tickets` | ses propres billets | **aucune** — serveur uniquement |
| `ticket_types` | si l'evenement est lisible | organisateur |
| `event_unlocks` | soi-meme | `unlock_private_event` uniquement |
| `admin_actions` | **personne** — aucune policy | fonctions de modération uniquement |

### Données personnelles exposées

La vue `public_profiles` ne publie que `full_name`, `avatar_url`, `bio`, `city`.
**Ni l'e-mail, ni la date de naissance** n'en sortent — la date de naissance est
collectée pour la barrière d'âge (Loi 25, minimum 14 ans) et ne quitte jamais la
ligne de son propriétaire. `profiles` elle-même est en lecture strictement
personnelle.

### Événements privés — deux notions distinctes

- `events.visibility` = qui peut **entrer** (voir la fiche, prendre un billet).
  Un événement privé n'apparaît jamais dans Discover : il ne se découvre pas, il
  se raconte.
- `events.posts_visibility` = qui peut **voir les photos**. `invitees` par
  défaut : exposer sa soirée doit être un oui explicite de l'organisateur.

Cette séparation existe parce que les deux besoins réels sont opposés : un
lancement veut l'entrée fermée et les photos publiques, un mariage veut l'entrée
fermée et les photos entre invités.

### Fonctions `SECURITY DEFINER`

Utilisées quand la RLS ne suffit pas — elle est par ligne, pas par colonne — ou
quand un sous-select provoquerait une récursion de policy.

`can_attach_event`, `event_posts_are_public`, `user_holds_ticket_for`,
`who_is_going`, `unlock_private_event`, `my_attachable_events`,
`set_attendance_visibility`, `account_deletion_preview`,
`delete_my_account_data`, `sync_event_attendance`, `notify_event_change`,
`event_is_readable`, `i_am_admin`, `is_suspended`, `admin_reports`,
`admin_resolve_report`, `admin_remove_content`, `admin_set_suspended`,
`events_from_connections`.

**Règle à respecter en les modifiant :** chacune a `set search_path = public` et
un `grant execute` restreint. Une fonction `SECURITY DEFINER` sans `search_path`
fixe est une escalade de privilèges classique.

**Piège connu :** une policy sur `events` qui interroge `tickets` (elle-même sous
RLS) déclenche `infinite recursion detected in policy`. L'app recevait une
erreur, pas une liste vide, et affichait « aucun événement ». D'où
`user_holds_ticket_for()`. Ne jamais remettre de sous-select croisé dans une
policy.

---

## 3. Billetterie

- Les billets sont émis **côté serveur** après confirmation de paiement, jamais
  par le client.
- Le QR est un jeton **HMAC rotatif** (`mint-qr`), pas un identifiant fixe : une
  capture d'écran partagée expire.
- `validate-ticket` vérifie la signature HMAC **et** que l'appelant est bien
  l'organisateur de l'événement (`events.created_by`), sinon `403`.
- L'écran du billet est protégé par `FLAG_SECURE` natif sur Android.

**Non couvert :** iOS n'a pas d'équivalent à `FLAG_SECURE`. Une capture reste
possible sur iPhone — c'est le jeton rotatif qui limite les dégâts, pas
l'interface.

---

## 3 bis. Modération

**Le rôle.** `profiles.is_admin`. La policy d'UPDATE de `profiles` laisse chacun
modifier sa propre ligne : sans garde-fou, n'importe qui se nommerait
administrateur en une requête. Un trigger (`prevent_self_admin`) refuse donc
toute modification de cette colonne venant des rôles `authenticated` et `anon`.

Règle formulée en **liste de refus**, pas en liste d'autorisation. La version
initiale n'autorisait que `service_role` et bloquait de fait l'éditeur SQL du
tableau de bord (qui s'exécute en `postgres`) — donc plus personne ne pouvait
accorder le premier droit. Elle aurait aussi cassé toute migration touchant
`is_admin`, puisque les migrations s'exécutent en `postgres`. Une liste
d'autorisation suppose de connaître à l'avance tous les contextes légitimes ;
la liste de refus, elle, est courte et stable : tout ce qui vient d'un
téléphone.

Accorder le droit, depuis le tableau de bord uniquement :

```sql
update public.profiles set is_admin = true
where id = (select id from auth.users where email = 'adresse@exemple.com');
```

**Les actions.** `admin_reports`, `admin_resolve_report`,
`admin_remove_content`, `admin_set_suspended`. Chacune revérifie le droit
(`i_am_admin`) : l'affichage conditionnel dans l'app n'est qu'un confort.
Elles sont accessibles depuis deux chemins — la file dans les réglages
(réactif, ce qui a été signalé) et le menu ⋯ du contenu (opportuniste, ce qu'un
modérateur voit lui-même).

**Le journal.** `admin_actions` n'a **aucune policy** : il n'est ni lisible ni
modifiable par un client, seulement par les fonctions ci-dessus et le tableau
de bord. Un journal d'audit que l'audité peut modifier ne vaut rien. Toute
action de modération y laisse une trace — c'est ce qui permet de répondre le
jour où Apple ou un utilisateur demande ce qui a été fait d'un signalement, et
c'est pourquoi la modération ne doit **jamais** se faire en SQL manuel.

**La suspension.** `profiles.suspended_at`, testée par `is_suspended()` dans
les policies d'insertion de `posts` et `events`. Un compte suspendu ne perd ni
son compte ni ses billets — il a payé, il garde ce qu'il a acheté. Il perd la
capacité de publier. Un administrateur ne peut pas se suspendre lui-même : cela
verrouillerait la modération.

**Un événement est dépublié, jamais supprimé** par la modération : des gens ont
peut-être acheté des billets, et effacer la ligne les priverait de la trace de
ce qu'ils ont payé. Une publication, elle, est supprimée.

**L'alerte.** `notify-report` (fonction Edge) envoie un courriel à chaque
signalement déposé, pour ne pas dépendre de quelqu'un qui pense à ouvrir la
file — un signalement du vendredi soir attendrait sinon le lundi, hors des 24 h
attendues par Apple.

Elle n'exige **pas de JWT** : l'appelant est la base, pas un utilisateur. Sa
protection est un secret partagé `REPORT_HOOK_SECRET`, comparé **en temps
constant** (une comparaison naïve s'arrête au premier caractère différent, et
le temps de réponse laisse deviner le secret caractère par caractère). Sans ce
contrôle, quiconque connaîtrait l'URL pourrait déclencher des envois, épuiser
le quota de courriels et noyer les vraies alertes.

Le champ `details` est saisi par un utilisateur : il est échappé avant d'entrer
dans le HTML du courriel, et tronqué à 500 caractères.

**Configuration hors dépôt** (elle contient un secret) — posée et testée le
2026-09-02. L'intégration Database Webhooks doit être activée avant, sinon le
schéma `supabase_functions` n'existe pas :

1. Secrets Supabase : `REPORT_HOOK_SECRET` (chaîne aléatoire longue),
   `RESEND_API_KEY`, `MODERATION_EMAIL`.
2. Déploiement : `supabase functions deploy notify-report --no-verify-jwt`.
3. Database → Webhooks → nouveau webhook sur `public.reports`, événement
   INSERT, type HTTP Request, URL de la fonction, en-tête
   `x-happyn-secret: <REPORT_HOOK_SECRET>`.

C'est la seule configuration volontairement non versionnée du projet, parce
qu'un webhook ne peut pas porter son secret dans un fichier du dépôt.

---

## 4. Fonctions Edge

Toutes suivent le même schéma, à vérifier avant d'en écrire une nouvelle :

1. lire l'en-tête `Authorization` de l'appelant ;
2. créer un client **anon** portant cet en-tête, appeler `auth.getUser()` pour
   savoir **qui** appelle ;
3. seulement ensuite, créer un client `service_role` pour l'écriture privilégiée.

Ne jamais faire l'inverse : un client `service_role` créé avant l'identification
exécute l'action de n'importe quel appelant.

| Fonction | Contrôle |
|---|---|
| `create-payment-intent` | utilisateur identifié, montant recalculé côté serveur |
| `mint-qr` | utilisateur identifié, billet lui appartenant |
| `validate-ticket` | signature HMAC + appelant = organisateur |
| `delete-account` | utilisateur identifié, supprime son propre compte |
| `stripe-webhook` | **pas de JWT** (`verify_jwt = false`) — authentifié par la signature Stripe sur le corps brut |

`stripe-webhook` est la seule fonction sans JWT, et c'est obligatoire : Stripe ne
peut pas en présenter un. Sa seule protection est la vérification de signature.
**Ne jamais la retirer, ne jamais logger le corps brut.**

---

## 4 bis. Webhooks de base de données

Deux déclencheurs appellent des fonctions Edge : `notify_report_on_insert` sur
`reports`, et `send_push_on_notification` sur `notifications`. Chacun porte un
secret partagé dans un en-tête HTTP, vérifié **en temps constant** par la
fonction.

**Ce secret vit dans la définition du déclencheur**, donc en clair pour qui a un
accès base. C'est la seule exception à la règle « aucun secret en SQL », et elle
est imposée par le mécanisme : un déclencheur doit porter l'en-tête qu'il
envoie.

C'est acceptable pour une raison précise : **quiconque peut lire
`pg_get_triggerdef` a déjà la clé `service_role`**, donc lecture et écriture sur
toute la base. Ce secret ne serait pas son objectif.

Vérifié le 2026-09-16 : avec la clé publiable, `pg_trigger` et
`pg_get_triggerdef` répondent `404` — l'API REST n'expose que le schéma
`public`, jamais `pg_catalog`. Ni l'app ni le site ne peuvent donc lire ces
définitions.

Le vrai maillon faible est **l'accès au tableau de bord Supabase**, et la 2FA
sur ce compte protège plus que tout le reste de cette section.

### Créer ces déclencheurs en SQL, pas par le formulaire

Le 2026-09-16, les notifications poussées n'arrivaient pas. Cause : le
formulaire avait enregistré l'en-tête sous le nom `x-happyn_secret` — un tiret
bas au lieu d'un trait d'union. La fonction cherchait `x-happyn-secret`, ne
trouvait rien, et répondait `403` sans que rien n'explique pourquoi.

Deux enseignements :

**1. Vérifier ce qui est réellement enregistré**, pas ce qu'on croit avoir
saisi :

```sql
select tgname, pg_get_triggerdef(oid) from pg_trigger
where tgrelid = 'public.notifications'::regclass and not tgisinternal;
```

**2. Journaliser la LONGUEUR du secret reçu, jamais sa valeur.** Le message
« en-tête reçu 0 car., secret attendu 43 car. » distingue immédiatement un
en-tête absent, un collage tronqué et un caractère invisible — sans rien
exposer. À reprendre dans toute nouvelle fonction protégée par secret partagé.

---

## 5. Secrets

**Autorisés dans le code** (publics par conception) : clé publiable Stripe
(`pk_...`), clé anon Supabase, Google Web Client ID.

**Interdits dans le dépôt, uniquement dans les secrets Supabase** :
`STRIPE_SECRET_KEY` (`sk_...`), `STRIPE_WEBHOOK_SECRET` (`whsec_...`),
`TICKET_HMAC_SECRET`, `SUPABASE_SERVICE_ROLE_KEY`.

`.gitignore` couvre `.env`, `.env.*`, `*.env`, `secrets.json`,
`google-services.json`, `*.keystore`, `*.jks`.

Nuance sur `google-services.json` : il n'est pas de la même nature que les
autres. Sa clé API est expédiée dans chaque APK et restreinte par nom de paquet
et SHA-1 de signature — la garder hors du dépôt ne protège donc rien qu'un
`unzip` sur l'APK ne révèle. Son exclusion a un coût réel : le build Android
échoue sur toute machine qui ne l'a pas, sans message qui explique pourquoi. La
marche à suivre est décrite dans `CONTRIBUTING.md` §2, et le classement reste à
rediscuter.

**Avant chaque commit et chaque push** : balayer le diff à la recherche de
`sk_live`, `sk_test_`, `whsec_`, `service_role`, `-----BEGIN`. Fait
systématiquement jusqu'ici, rien n'est jamais sorti.

---

## 6. Ce qui reste ouvert

Classé par ce qu'il faut faire en premier.

### 6.1 RÉSOLU — RLS d'`events`, `tickets`, `ticket_types`

Vérifié le 2026-08-14 : la RLS est **active** sur les trois, et les policies
sont saines.

`tickets` n'a qu'une policy, `SELECT` sur ses propres billets. **L'absence de
policy d'écriture est délibérée** : c'est elle qui empêche un client de se
fabriquer un billet ou de repasser le sien de `used` à `valid`. L'émission
passe par les fonctions Edge en `service_role`, non soumises à la RLS. Ne
jamais ajouter d'`insert`/`update` sur cette table.

Les policies, qui n'existaient que dans le tableau de bord, sont désormais
versionnées (20260814020000) avec une correction : `ticket_types` était en
`using (true)`, exposant les noms, prix et quantités des catégories de billets
d'un événement privé. La lisibilité suit maintenant celle de l'événement.

Ce resserrage imposait de rendre le déverrouillage durable : après avoir saisi
le code, un invité n'est ni organisateur ni encore détenteur de billet, donc la
liste des catégories lui serait revenue vide. D'où la table `event_unlocks`,
écrite uniquement par `unlock_private_event` (qui vérifie le code) — jamais par
le client.

### 6.2 IMPORTANT — les buckets de stockage sont publics

`events`, `avatars` et `posts` sont créés avec `public: true`. Les URLs sont
imprévisibles, mais ce n'est pas un contrôle d'accès : c'est de l'obscurité.
Quiconque obtient l'URL d'une photo d'un événement « entre invités » peut la
consulter sans compte, indéfiniment.

Correction : bucket privé + URLs signées à durée limitée. Touche le fil, le
profil, les moments d'événement et le cache d'images. Décidé le 2026-08-14 de ne
pas le faire avant le lancement — le trou suppose de déjà posséder l'URL, donc
un invité légitime qui la partage volontairement.

### 6.3 EN GRANDE PARTIE RÉSOLU — les signalements

Outillage livré le 2026-08-14 : rôle administrateur, file de traitement,
retrait de contenu, suspension, journal d'audit (voir §3 bis). **Reste ouvert :
l'alerte** — rien ne prévient qu'un signalement est arrivé, il faut penser à
ouvrir la file, ce qui tient mal la contrainte des 24 h.

Historique : Apple (guideline 1.2) attend une modération effective sous 24 h pour du
contenu généré par les utilisateurs. Le minimum viable : une vue admin, ou même
une alerte e-mail à chaque insertion.

### 6.3 bis BLOQUANT — le service de courriel est celui du developpement

Verifie le 2026-08-14 : **2 courriels par heure pour tout le projet**, tous
utilisateurs confondus. C'est le plafond que Supabase impose au service
integre, et le champ ne devient modifiable qu'apres configuration d'un SMTP
externe — c'est leur facon de dire que ce service n'est pas fait pour la
production.

Consequence concrete : le troisieme inscrit d'une soiree ne recoit rien. Et
quelqu'un qui perd son mot de passe sans jamais recevoir le lien perd ses
billets — le bloquant qu'on vient de refermer cote code reste donc ouvert cote
infrastructure.

S'ajoute la delivrabilite : le service integre envoie depuis un domaine
partage, une bonne part des messages finit en indesirables.

Correction : SMTP externe (Resend, gratuit jusqu'a 3 000 courriels/mois), dans
Project Settings > Authentication > SMTP Settings. **Depend de l'achat du
domaine** : on ne peut pas envoyer depuis une adresse Gmail.

### 6.3 ter — Aucun rapport de plantage

Rien n'est installe. En production on ne saurait pas pourquoi l'app plante :
les utilisateurs ne signalent pas, ils desinstallent.

**Declencheur : avant la premiere version donnee a quelqu'un d'autre que
nous** — premiere beta, premier APK envoye a un ami, premier TestFlight. Pas
avant les stores. Les plantages survenus avant l'installation de l'outil sont
perdus definitivement, il n'y a pas de rattrapage retroactif.

Sentry, gratuit jusqu'a 5 000 erreurs/mois, une dependance et une dizaine de
lignes dans main.dart.

Argument supplementaire : ce projet a deja produit trois fois des erreurs
avalees en silence qui se deguisaient en ecran vide (« Mes evenements » vide,
transfert de billet, recursion RLS). C'est exactement ce que cet outil attrape.

### 6.4 À traiter avant publication

- **Relire l'intégralité du recueil légal**, en détail — jalon bloquant déjà
  acté, distinct de la sécurité technique.
- **Décrire la suppression de compte** dans les documents légaux (le mécanisme
  existe, le texte non).
- **Protéger `main`** sur GitHub maintenant que le dépôt est partagé.
- **Le domaine** est devenu le jalon central : il debloque d'un coup le SMTP
  (§6.3 bis), une adresse de contact propre, et une URL presentable.
  Achete le 2026-08-23 : happynevents.com. Reste a brancher (Netlify, Resend,
  Supabase).
- **Limitation de débit** : rien n'empêche aujourd'hui de marteler
  `unlock_private_event` pour deviner un code d'invitation. Vérifier la longueur
  et l'entropie du code, et envisager une temporisation.

### 6.5 Connu, assumé pour l'instant

- Pas de Stripe Connect : aucun modèle de versement aux organisateurs. Bloque le
  passage en production réelle des paiements, pas le lancement en test.
- Pas de protection capture d'écran sur iOS (voir §3).
- `public_profiles` reste lisible par les comptes bloqués. Le blocage filtre
  l'affichage côté app ; il ne rend pas un profil invisible en interrogeant
  l'API directement.

---

## 7. Réflexe avant chaque livraison

1. Toute nouvelle table : `enable row level security` **dans la migration**, pas
   dans le tableau de bord.
2. Toute nouvelle vue exposant des données restreintes : la règle doit exister
   aussi sur la table sous-jacente.
3. Toute nouvelle fonction `SECURITY DEFINER` : `set search_path = public` et
   `grant execute` restreint.
4. Toute nouvelle fonction Edge : identifier l'appelant **avant** de créer le
   client `service_role`.
5. Balayage des secrets sur le diff.
6. Se demander : « si quelqu'un appelle l'API directement, sans notre app,
   qu'est-ce qu'il obtient ? »
