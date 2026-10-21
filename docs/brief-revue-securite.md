# Brief — revue de sécurité de HAPPYN avant lancement

But : vérifier, avant le lancement sur les stores, que chaque contrôle d'accès
tient réellement. On ne cherche pas à nuire : on confirme que les protections
déjà écrites font ce qu'elles promettent, et on écrit un test pour chaque trou
qu'on soupçonne. Les quatre vraies failles du projet venaient toutes des règles
d'accès à la base : c'est le premier endroit à couvrir.

**À lire d'abord :** `docs/SECURITY.md` (modèle de menace et décisions de RLS),
puis `CONTRIBUTING.md`. Le réflexe de livraison est en §7 de `SECURITY.md`.

## Cadre — à respecter

- **Tout se vérifie en local, sur un Postgres jetable.** Le banc de tests
  `tests/rls/run.sh` monte une instance, rejoue le schéma réel de production,
  applique une migration et vérifie chaque règle de `access_rules.sql`. C'est
  l'outil principal.
- **La production ne se touche qu'en lecture**, avec la clé anon (publique),
  pour confirmer ce qu'un visiteur non connecté peut voir. Aucune écriture dans
  les tables d'argent (`tickets`, `payout_reviews`, versements). Aucun test qui
  cherche à saturer le service — ce serait aussi contraire aux conditions de
  Supabase.
- **Aucune donnée de production fabriquée.** On raisonne sur le schéma et les
  politiques, pas sur de faux enregistrements réels.
- **Une faille confirmée devient d'abord une règle dans `access_rules.sql`**,
  puis un correctif de migration, puis un `run.sh` vert. On ne corrige jamais
  sans laisser le test qui garde la porte fermée.

## Ce qu'il faut confirmer, par surface

### 1. Règles d'accès à la base (priorité)
Pour chaque table de la liste « Qui peut lire quoi » de `SECURITY.md`, confirmer
qu'un utilisateur connecté **ne peut pas** lire ni modifier les lignes d'un
autre : `profiles`, `tickets`, `events`, `ticket_types`, `event_unlocks`,
`notifications`, `posts`, `reports`, `event_ratings`, `payout_reviews`,
`app_status`. Confirmer aussi que `set role authenticated` se voit refuser les
fonctions réservées au serveur et aux admins (modération, versements,
`admin_set_app_status`, `admin_set_payout_review`). Les aides du banc
(`t.sees`, `t.fails_with`, `t.cannot_write`, `t.as_user`, `t.as_anon`,
`t.as_server`) sont dans `tests/rls/helpers.sql`.

### 2. Fonctions `SECURITY DEFINER`
Vérifier que chacune a un `search_path` fixe et contrôle l'appelant au lieu de
faire confiance à ses arguments. Points sensibles : émission de billets,
versements, notes. Confirmer qu'on ne peut pas émettre un billet pour
l'événement d'un autre, ni se verser l'argent avant le délai de 7 jours, ni
contourner les trois retenues.

### 3. Fonctions Edge (`supabase/functions/`)
Liste : cancel-event, cancel-ticket, connect-onboard, connect-refresh,
create-payment-intent, delete-account, mint-qr, notify-report, run-payouts,
send-push, stripe-webhook, validate-ticket. Pour chacune, confirmer : qu'un
appel non authentifié est refusé ; qu'un montant ou un identifiant d'événement
fourni par l'appelant est revérifié côté serveur et jamais cru sur parole ; que
le webhook Stripe vérifie bien la signature et résiste à un rejeu. Chaque
fonction se type avec `tsc --noEmit` (déclarer le global `Deno`).

### 4. Logique de billetterie
Confirmer que la limite de billets par personne tient même avec des achats
simultanés (le verrou `pg_advisory_xact_lock` est déjà en place), qu'un code QR
ne peut pas être validé deux fois, et qu'un billet en capture d'écran ne passe
pas (code renouvelé).

### 5. Notes d'événement
Confirmer que seule une personne dont le billet a été scanné peut noter, dans
la fenêtre du versement, et que les commentaires restent anonymes pour
l'organisateur comme prévu.

### 6. Stockage
Trois buckets : `avatars`, `events`, `posts`. `SECURITY.md` §6.2 note qu'ils
sont publics en lecture. Confirmer surtout l'écriture : un utilisateur ne doit
pas pouvoir remplacer ou supprimer le fichier d'un autre. Vérifier le chemin
des politiques de `storage.objects`.

### 7. Site
Confirmer que les en-têtes de `netlify.toml` (dont la politique de sécurité du
contenu) sont bien servis, et que la page de réinitialisation du mot de passe
ne divulgue rien et ne garde pas de jeton réutilisable. Le serveur local qui
imite Netlify est dans le scratchpad (`netlocal/serve.mjs`), config
`site-v2-netlify` dans `.claude/launch.json`.

## Comment rendre compte

Un tableau : surface, ce qui a été vérifié et comment, verdict (tient / à
corriger), et pour chaque « à corriger » la règle de test ajoutée. Nommer ce
qui n'a pas pu être vérifié en local et pourquoi. Pas de « c'est bon » global.
