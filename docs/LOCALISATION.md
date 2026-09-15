# HAPPYN — Adresses, localisation, « Near You », admin web

Note de conception, écrite le 2026-09-15 à partir de la spécification de Merve,
avec les corrections retenues après discussion.

---

## 1. Ce qui est vrai aujourd'hui, et ne devrait pas l'être

Vérifié le 2026-09-15 :

- **Aucune colonne géographique n'existe.** `events.location` et `events.city`
  sont du texte libre. Ni latitude, ni longitude, ni code postal.
- **`unlock_private_event` fait `select *`** : quiconque possède le code d'accès
  reçoit l'adresse exacte, avant tout achat.

Le second point n'est pas une amélioration à prévoir, c'est un défaut à
corriger.

---

## 2. Pourquoi les adresses structurées passent en premier

**Ça ne se rattrape pas.** Un événement enregistré en texte libre ne pourra
jamais être géocodé de façon fiable après coup — « Bank Street » sans numéro ni
ville ne redevient pas des coordonnées. Chaque semaine qui passe crée des
données définitivement mortes pour la recherche géographique.

C'est le même raisonnement que pour les intérêts déclarés à l'inscription
(`docs/RECOMMANDATION.md`) : ce qui ne peut pas être reconstitué rétroactivement
passe avant ce qui peut attendre.

---

## 3. Où vit l'adresse exacte — et pourquoi pas dans `events`

**Décision : une table séparée, `event_addresses`.**

Le raisonnement : la RLS de Postgres est **par ligne, pas par colonne**. Pour
cacher une colonne, il faut soit une vue qui réénumère toutes les colonnes —
fragile, elle casse dès qu'on ajoute un champ à `events` — soit des privilèges
par colonne, qui font échouer tout `select *` existant dans l'app.

En isolant l'adresse précise dans sa propre table, **la ligne devient l'élément
sensible** et la RLS ordinaire suffit. Aucune vue à maintenir, aucune requête
existante cassée.

| Où | Quoi | Visible par |
|---|---|---|
| `events.city`, `province`, `country` | localisation générale | tout le monde |
| `events.location` | nom du lieu / repère | tout le monde |
| `event_addresses` | numéro, rue, code postal, **latitude, longitude** | selon la règle ci-dessous |

### La règle d'accès

L'adresse exacte est lisible si l'événement est **public**, ou si on en est
l'**organisateur**, ou si on **détient un billet valide**.

**Pas** si on a seulement le code d'accès. Ta spécification a raison sur ce
point : connaître un événement privé et savoir où il se tient exactement sont
deux niveaux différents.

### Correction apportée à la spécification

Elle disait « adresse révélée **après achat** ». Formulé ainsi, un événement
**gratuit** ne révélerait jamais son adresse — il n'y a pas d'achat.

La règle retenue est « **détient un billet valide** ». Un billet gratuit est
émis exactement comme un billet payant, donc les deux cas sont couverts sans
exception à écrire.

---

## 4. Autocomplétion — Photon

Décidé de longue date : **Photon** (fondé sur OpenStreetMap), gratuit et sans
clé, avant d'envisager un service payant.

Limites assumées : l'instance publique n'offre aucune garantie de service et
demande un usage raisonnable, et la couverture est moins fine que Google sur
les commerces. Pour des adresses postales à Ottawa-Gatineau, c'est suffisant.

Si un jour la qualité ne suffit plus, Google Places ou Mapbox se branchent au
même endroit — mais ils facturent à la requête, et c'est le seul coût récurrent
que cette spécification introduirait.

---

## 5. « Near You » — trois états, aucun ML

Retenu tel quel de la spécification, avec un point souligné : **ne jamais
afficher une distance si la position réelle est inconnue**. Une app qui annonce
« 2,3 km » alors qu'elle ne connaît que la ville ment à son utilisateur, et ça
se remarque.

Rappel : pas de moteur de recommandation en V1 — voir `docs/RECOMMANDATION.md`,
où le raisonnement complet est déjà écrit. « Near You » répond à *« qu'est-ce
qui se passe autour de moi »*, ce qui est une question géographique, pas une
question de goût.

---

## 6. Ce qui a été corrigé dans la spécification

### ⚠️ La journalisation comportementale (§23) — à ne pas lancer

C'était la seule partie créant une **exposition juridique**. La politique de
confidentialité dit aujourd'hui, explicitement, que HAPPYN ne suit pas le
comportement de ses utilisateurs. Écrire la première ligne de journalisation
rend ce texte faux.

Sous la LPRPDE, une finalité doit être déclarée **avant** la collecte. Rien ne
doit être enregistré tant que le texte ne le couvre pas — et quand ce sera le
cas, en agrégats par catégorie plutôt qu'en journal détaillé.

### « Revenue » sur le tableau de bord admin

Sans Stripe Connect, l'argent encaissé n'appartient pas entièrement à HAPPYN.
Afficher un chiffre de revenus donnerait une image fausse de sa propre activité.
À ajouter après le modèle de commission.

### `ban` distinct de `suspend`

`suspend` existe : réversible, l'utilisateur garde ses billets. Un `ban`
définitif est une **politique de conservation**, pas un bouton — que deviennent
ses données, ses billets achetés, les événements auxquels d'autres ont assisté ?
À écrire avant de le construire.

---

## 7. 🔴 L'admin web ne doit jamais porter la clé `service_role`

C'est l'erreur classique du panneau d'administration : « c'est réservé aux
admins, autant utiliser la clé qui peut tout ». Or le JavaScript d'un site est
lisible par n'importe qui, et cette clé donne un accès total en lecture et en
écriture à toute la base, RLS contournée.

**L'admin web utilise la clé publiable et la session de l'administrateur**, et
appelle les fonctions `admin_*` déjà écrites (`admin_reports`,
`admin_resolve_report`, `admin_remove_content`, `admin_set_suspended`). Chacune
revérifie `i_am_admin()`. Rien n'est à refaire côté base.

---

## 8. App ou web pour la modération ?

Les deux, mais pas au même moment.

L'argument de la spécification — pagination, recherche, actions groupées — est
juste **à 100 signalements**, pas à 3. L'argument inverse est qu'Apple attend une
réponse sous 24 h, et qu'un outil dans la poche y répond mieux qu'un tableau de
bord qui suppose d'être devant un ordinateur.

L'app reste pour l'urgence, le web arrive pour le volume. Rien n'est perdu : la
logique vit en base, les deux interfaces l'appellent.

---

## 9. Ordre retenu

1. **Adresses structurées + coordonnées** — maintenant, parce que ça ne se
   rattrape pas
2. **Masquage de l'adresse exacte côté serveur** — même migration
3. **« Near You »** — une fois que les coordonnées existent
4. **Admin web** — quand le volume le justifie
5. **Journalisation comportementale** — après le texte légal, jamais avant
