# HAPPYN — Sécurité

Document de référence, tenu à jour à chaque changement touchant les données, les
policies, les fonctions Edge ou les secrets. Il sert à trois choses : ne rien
oublier avant publication, permettre au second développeur de travailler sans
casser un contrôle sans le savoir, et pouvoir répondre à Apple, Google ou à une
demande Loi 25 sans improviser.

Dernière revue : 2026-08-14.

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
`delete_my_account_data`, `sync_event_attendance`, `notify_event_change`.

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

## 5. Secrets

**Autorisés dans le code** (publics par conception) : clé publiable Stripe
(`pk_...`), clé anon Supabase, Google Web Client ID.

**Interdits dans le dépôt, uniquement dans les secrets Supabase** :
`STRIPE_SECRET_KEY` (`sk_...`), `STRIPE_WEBHOOK_SECRET` (`whsec_...`),
`TICKET_HMAC_SECRET`, `SUPABASE_SERVICE_ROLE_KEY`.

`.gitignore` couvre `.env`, `.env.*`, `*.env`, `secrets.json`,
`google-services.json`, `*.keystore`, `*.jks`.

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

### 6.3 IMPORTANT — les signalements ne sont lus par personne

`reports` se remplit, mais il n'existe aucun outil pour les traiter, ni délai de
réponse. Apple (guideline 1.2) attend une modération effective sous 24 h pour du
contenu généré par les utilisateurs. Le minimum viable : une vue admin, ou même
une alerte e-mail à chaque insertion.

### 6.4 À traiter avant publication

- **Relire l'intégralité du recueil légal**, en détail — jalon bloquant déjà
  acté, distinct de la sécurité technique.
- **Décrire la suppression de compte** dans les documents légaux (le mécanisme
  existe, le texte non).
- **Protéger `main`** sur GitHub maintenant que le dépôt est partagé.
- **Réinitialisation du mot de passe** : impossible sans le site web (lien de
  redirection). Un utilisateur qui perd son mot de passe perd ses billets.
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
