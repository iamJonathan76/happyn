# HAPPYN — Ce qui reste avant le lancement

État au 2026-08-23. Le produit est construit ; l'essentiel de ce qui reste
n'est pas du développement.

---

## 1. Le chemin critique

Dans cet ordre, parce que chaque étape en débloque d'autres.

### 1.1 Le domaine — ACHETÉ le 2026-08-23

`happyn.ca`, avec une boîte `contact@happyn.ca`. 17 $ la première année,
~36 $/an ensuite.

C'était le jalon central : il débloque le SMTP (§1.2), une adresse de contact
propre, et une URL présentable.

Le code est déjà basculé (`kSupportEmail`, `kPasswordResetUrl`, `supportEmail`
côté site). **Reste à brancher :**

1. **Netlify** → Domain management → ajouter `happyn.ca`, créer les
   enregistrements DNS chez le registraire ;
2. **Resend** → vérifier le domaine, récupérer les identifiants SMTP ;
3. **Supabase** → SMTP Settings, puis URL Configuration (§1.3).

⚠️ Les points 1 et 3 doivent aboutir **ensemble**. Tant que Supabase ne connaît
pas la nouvelle URL de redirection, il retombe silencieusement sur sa Site URL —
c'est exactement le bug « le lien pointe sur localhost » rencontré le 2026-08-14.

### 1.2 SMTP externe — gratuit (Resend, 3 000 courriels/mois)

**Bloquant.** Le service intégré de Supabase est plafonné à **2 courriels par
heure pour tout le projet**, tous utilisateurs confondus, et le plafond ne se
lève qu'après configuration d'un SMTP externe. Le troisième inscrit d'une
soirée ne recevrait rien.

S'ajoute la délivrabilité : le service intégré envoie depuis un domaine
partagé, une bonne part des messages finit en indésirables. Quelqu'un qui perd
son mot de passe sans recevoir le lien perd ses billets.

Configuration : Project Settings → Authentication → SMTP Settings.

### 1.3 Finir la réinitialisation du mot de passe

Le code est écrit et testé des deux côtés (app + `web/reset.html`). Il reste :

- **Supabase → Authentication → URL Configuration** : Site URL =
  `https://happyn.ca`, Redirect URLs = `https://happyn.ca/**` ;
- **un essai réel depuis un courriel**, non encore fait, bloqué par la limite
  de débit (§1.2).

Une inconnue subsiste : la forme du lien. `#access_token=` → tout fonctionne.
`?code=` → flux PKCE, dont l'échange exige le « code verifier » généré sur le
téléphone, qu'une page web ne peut pas avoir ; il faudra alors passer le
gabarit de courriel sur `{{ .TokenHash }}`.

### 1.4 Relire l'intégralité du recueil légal

**Bloquant, décidé de longue date.** Onze documents, déjà publics sur
`happyn.ca/legal.html` puisque la page les lit depuis la base.

À ajouter pendant cette relecture : **la description du processus de
suppression de compte** (le mécanisme existe, le texte non), et la mention de
toute collecte comportementale si elle est un jour ajoutée.

Ils se corrigent en base, sans redéploiement.

### 1.5 Alerter quand un signalement arrive

L'outillage est livré (2026-08-14) : rôle administrateur, file de traitement
dans les réglages, retrait de contenu depuis le contenu lui-même, suspension de
compte, journal d'audit. Voir `docs/SECURITY.md` §3 bis.

**Reste l'alerte.** Rien ne prévient qu'un signalement est arrivé — il faut
penser à ouvrir la file, ce qui tient mal la contrainte des 24 h d'Apple. Le
minimum : un déclencheur en base appelant une fonction Edge qui envoie un
courriel. Dépend donc du SMTP (§1.2).

---

## 2. Publier sur les stores

| | Coût |
|---|---|
| Google Play Console | **25 $ US**, une seule fois |
| Apple Developer Program | **99 $ US/an**, obligatoire même pour une app gratuite |

**Le piège iOS :** compiler pour l'App Store exige macOS. Sans Mac, deux
sorties — un service de build cloud (Codemagic, gratuit en petit volume) ou un
Mac mini d'occasion. À trancher avant de s'engager sur une date iOS.

**Ordre conseillé :** Google Play seul d'abord. 25 $, pas de Mac, en ligne
rapidement. Apple ensuite.

---

## 3. Exploitation — savoir ce qui se passe

Aujourd'hui, « gérer l'app » veut dire ouvrir le tableau de bord Supabase et
écrire du SQL à la main. Ça marche à dix utilisateurs ; à cent c'est dangereux
(aucune trace de qui a fait quoi, un `update` sans `where` casse la production)
et impossible à déléguer.

### 3.1 Rapport de plantage — gratuit (Sentry)

**Déclencheur : avant la première version donnée à quelqu'un d'autre que
nous** — première bêta, premier APK envoyé à un ami. Pas avant les stores.

Les plantages survenus avant l'installation sont perdus définitivement. Une
erreur silencieuse dans le tunnel de paiement le soir du lancement, sans cet
outil, ne serait jamais connue.

### 3.2 Rôle administrateur + actions tracées

Une colonne `is_admin` sur `profiles`, et quelques fonctions `SECURITY
DEFINER` : dépublier un événement, suspendre un compte, traiter un
signalement. Chaque action laisse une ligne dans `admin_actions` — qui, quoi,
quand, pourquoi.

L'intérêt n'est pas le confort : **du SQL à la main ne laisse aucune trace**.
Le jour où Apple ou un utilisateur demande ce qui a été fait d'un signalement,
il faut pouvoir répondre.

### 3.3 Requêtes SQL enregistrées

Inscrits, événements, billets de la semaine. Aucun code : les snippets
enregistrés de Supabase suffisent. Un vrai tableau de bord seulement si ça
devient pénible.

---

## 4. Le seul gros chantier de développement restant

### Stripe Connect — reverser l'argent aux organisateurs

**Non construit.** Aujourd'hui l'argent d'une vente arrive sur un seul compte
et rien ne le redistribue. Tant que ce n'est pas réglé, HAPPYN ne peut pas
vendre les billets d'autrui — ce qui est pourtant le produit.

Stripe prélève 2,9 % + 0,30 $ par transaction (0,88 $ sur un billet à 20 $).
Connect exige presque certainement une **entreprise enregistrée** (Québec :
~40 à 350 $ selon la forme) — à vérifier directement auprès de Stripe.

Ne bloque pas un lancement en test, bloque toute vente réelle pour un tiers.

---

## 5. Points ouverts de sécurité

Détail complet dans `docs/SECURITY.md` §6.

- **Buckets de stockage publics** — les URLs d'images sont imprévisibles mais
  servies sans authentification. Correction : bucket privé + URLs signées.
- **Limitation de débit sur `unlock_private_event`** — le code d'invitation
  compte 33 millions de combinaisons, mais rien n'empêche de le marteler.
- **Pas de protection capture d'écran sur iOS** — assumé, le jeton QR rotatif
  limite les dégâts.
- **`public_profiles` reste lisible par les comptes bloqués** — le blocage
  filtre l'affichage, il ne rend pas un profil invisible via l'API.

---

## 6. Reporté volontairement

- **Recommandation** — voir `docs/RECOMMANDATION.md`. Un utilisateur voit déjà
  presque tout en un défilement ; classer n'aurait aucun effet. Signal pour y
  revenir : quand il ne peut plus tout voir en une page.
- **Liste des participants** pour l'organisateur — utile à la porte, demande
  une fonction `SECURITY DEFINER` (l'organisateur n'a par construction aucun
  accès à `tickets`).
- **Notifications poussées**, annulation de réservation, autocomplétion
  d'adresse, version française du site.

---

## Récapitulatif des coûts

| Étape | Coût |
|---|---|
| Bêta privée | **17 $** — payé |
| + Google Play | **~45 $** |
| + Apple | **~145 $ US** la première année |
| Vendre pour des tiers | Connect + entreprise enregistrée |

Netlify, Supabase, Resend et Sentry restent gratuits au volume prévu.
