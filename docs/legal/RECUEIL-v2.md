# HAPPYN — Recueil légal, version 2 · BROUILLON, non publié

> **Statut :** brouillon de travail, à faire relire par un avocat avant toute
> publication. Rien de ce fichier n'est en ligne : l'app et le site lisent la
> table `legal_documents`, qui contient encore la version 1.1.
>
> **Dernière vérification contre le code :** 2026-10-08 (commit `03a5a85`).

---

## Comment lire ce document

### Ce qui a changé depuis le premier brouillon

Le premier brouillon a été **confronté ligne à ligne au code et à la base de
production**. Neuf affirmations étaient fausses ou dépassées ; elles sont
corrigées ici :

| Le premier brouillon disait | Ce que l'app fait réellement |
|---|---|
| « We do not track your location » | « Autour de moi » demande le GPS (précision moyenne, optionnel) et envoie la position au serveur pour chercher les événements proches. |
| Les remboursements sont à l'organisateur, HAPPYN ne rembourse pas | Un événement annulé rembourse **automatiquement**. L'acheteur peut annuler lui-même jusqu'à un délai choisi par l'organisateur. |
| Versements non implémentés | Stripe Connect est en place ; un événement payant ne se publie pas sans compte de versement ; commission de 5 % prise sur l'organisateur. Aucun versement n'a encore été exécuté. |
| La suppression de compte efface tout immédiatement | Elle est **refusée** tant que de l'argent est en jeu, annule les événements à venir et garde les billets détachés de l'identité. |
| Transfert « to another HAPPYN user » | Seulement à une personne **que l'on suit**, avant l'événement. |
| Conservation : 2 ans, 7 ans, 30 jours | Aucune purge automatique n'existe aujourd'hui. Les durées sont gardées comme **engagement**, avec le chantier marqué. |
| Événements sauvegardés stockés sur l'appareil | Ils sont en base (`favorites`). |
| Adresses d'images « long, unguessable » | Elles contiennent l'identifiant de l'auteur et l'heure : devinables. |
| Hébergement Supabase « à vérifier » | `ca-central-1` — **Montréal, Canada**. |

Et sept sujets manquaient entièrement : la **messagerie privée**, les
**commentaires**, les **notifications push** (Firebase), la **localisation**,
**Stripe Connect** côté organisateurs, la **liste des participants** que voit un
organisateur, et la **date de naissance** des comptes Google (corrigée dans
l'app le même jour).

### Le principe de rédaction

Instagram ou TikTok publient des politiques complètes mais où l'on se perd.
Celles-ci veulent être **aussi complètes, et lisibles** :

- chaque politique commence par **« In short »** — cinq à huit phrases qui
  suffisent à la plupart des gens ;
- le détail suit, organisé par question (« What we collect », « Who sees it »…)
  plutôt que par article de loi ;
- chaque affirmation décrit **ce que l'app fait**, vérifié dans le code, et non
  une intention ;
- les tableaux remplacent les énumérations quand on compare des choses.

### Les marques dans le texte

- **[À DÉCIDER]** — une décision qui t'appartient (entité, taxe, clauses).
- **[À CONSTRUIRE]** — le texte promet quelque chose que l'app ne fait pas
  encore. **Soit on le construit avant publication, soit on retire la phrase.**
  Un texte légal qui promet plus que l'app est une exposition, pas un détail.
- **[À VÉRIFIER]** — un fait que je n'ai pas pu confirmer depuis le code.
- **[AVOCAT]** — un point où je ne lancerais pas sans avis juridique.

### La double juridiction

HAPPYN est établie à Ottawa (Ontario) : la **LPRPDE** gouverne les données
personnelles et le droit ontarien s'applique au contrat. Mais le marché est
Ottawa-Gatineau : une partie des utilisateurs réside au Québec, et la **Loi 25**,
la **Loi sur la protection du consommateur** du Québec et la **Charte de la
langue française** suivent la résidence de la personne. Le texte applique donc
le standard le plus exigeant à tout le monde. **[AVOCAT]** : dans quelle mesure
le droit québécois s'applique réellement de l'autre côté de la rivière.

### La langue

Ces textes sont rédigés en anglais pour la relecture. **Une version française
est requise** pour les consommateurs québécois (Charte de la langue française,
modifiée par la loi 96) et doit être disponible au moins aussi facilement que
l'anglaise. Elle se traduit **après** la relecture juridique : traduire un
texte qui va encore changer, c'est le traduire deux fois. Côté technique, voir
« Chantiers » en fin de document.

---

## Sommaire

1. Terms of Service — `terms`
2. Privacy Policy — `privacy`
3. Community Guidelines — `community`
4. Content Moderation Policy — `content-moderation` *(nouveau)*
5. Account Deletion Policy — `account-deletion` *(nouveau)*
6. Data Retention Policy — `data-retention`
7. Cookie and Local Storage Policy — `cookie`
8. Copyright Policy — `copyright`
9. Payments Policy — `payments`
10. Refund and Cancellation Policy — `refund`
11. Fraud Prevention Policy — `fraud-prevention`
12. Safety Policy — `safety`
13. Organizer Standards — `organizer`

Annexe A — Ce que l'app doit rattraper avant publication
Annexe B — Chantiers techniques liés aux textes

---

# 1. Terms of Service

`terms` · Version 2.0 · Effective date: **[À DÉCIDER — date de publication]**

## In short

- HAPPYN is an app and website to discover events, buy tickets, and share what
  happened there.
- You need an account, and you must be **at least 14**. Organizing events
  requires being **18 or older**.
- **Organizers run their events, not HAPPYN.** When you buy a ticket, your
  contract for the event is with the organizer; HAPPYN handles the payment and
  the ticket.
- If an organizer cancels, **you are refunded automatically**. You can also
  cancel a ticket yourself until the deadline the organizer set.
- Your tickets have a QR code that changes every few minutes and works once.
  Screenshots don't get anyone in.
- You own what you post. You give us permission to show it inside HAPPYN, and
  that permission ends when you delete it.
- Break the rules and we can remove content or suspend your account. You keep
  the tickets you paid for.

## 1. Who we are

HAPPYN ("HAPPYN", "we", "us") operates the HAPPYN mobile application and the
website happynevents.com. These Terms are a binding agreement between you and
HAPPYN.

**[À DÉCIDER] — Legal entity.** Name and address of the legal entity. If you
incorporate before launch, the corporation appears here. Until then, this
agreement is with you personally — and you carry personal liability for it.
That is the strongest practical reason to incorporate before selling tickets
for third parties.

By creating an account or using HAPPYN, you accept these Terms, the Privacy
Policy, and the Community Guidelines. The other policies listed at the top of
this page form part of these Terms where they apply to what you do (for
example, the Organizer Standards when you create an event).

## 2. Who can use HAPPYN

### Minimum age

You must be **at least 14 years old** to create an account.

Why 14: Quebec's Law 25 requires a parent's consent to collect personal
information from a child under 14, and HAPPYN has no parental consent process.
HAPPYN is based in Ontario, where no fixed age applies, but much of our
community lives in Quebec — so the stricter rule applies to everyone.

HAPPYN asks every new account for a date of birth, whatever the sign-in method.
If the date shows you are under 14, the account is **deleted immediately**,
along with the information received at sign-up.

### If you are 14 to 17

- You can browse events, follow people, save events, post, comment, and send
  messages.
- You can buy a ticket only where the event allows your age, and only with the
  permission of a parent or legal guardian, who is responsible for that
  purchase.
- You cannot create events, sell tickets, or receive payouts.

### Event age limits

Organizers can set a minimum age for their event: **14+, 16+, 18+ or 21+**, or
none. HAPPYN uses your date of birth to stop you from buying a ticket for an
event you are too young for, and to stop a ticket being transferred to someone
too young.

**HAPPYN does not verify identity or the date of birth you give.** The organizer
is responsible for checking age at the door.

**[À CONSTRUIRE]** — The age check on purchase is done by the app only; the
server does not repeat it. See Annex A.

## 3. Your account

### Signing up

You can create an account with an email address and a password, or with your
Google account. *(Sign in with Apple: **[À CONSTRUIRE]** — required by Apple
before the iPhone version can be published.)*

### Your responsibilities

- Keep your password to yourself. You are responsible for what is done through
  your account.
- Tell us immediately at **contact@happynevents.com** if you think someone else
  has access to it.
- One person, one account. Accounts may not be sold, rented, shared, or
  transferred.
- The information you give must be accurate — in particular your date of birth.

### Your username

Your username is public and unique. If you don't choose one, HAPPYN generates
one from your name. You can change it later, as long as the new one is free.

## 4. What HAPPYN is — and what it is not

HAPPYN is a **platform**. Events are created, described, priced, and run by
their organizers — not by us. We do not host events, check that their
descriptions are accurate, or guarantee they will take place as described.

When you buy a ticket, you enter into a contract **with the organizer** for the
event. HAPPYN collects the payment, issues the ticket, and passes the money on
to the organizer, minus our fee (see the Payments Policy).

## 5. Tickets

### How tickets are issued

Tickets are created by our servers, and only after payment is confirmed (or
immediately, for free events). No app, and no person, can create a ticket any
other way.

### Your QR code

Each ticket shows a **cryptographically signed QR code that changes every five
minutes**. A screenshot shows a code that expires: it will not admit anyone.
A ticket can be scanned **once**; a second scan is refused. Only the organizer
of that event can scan its tickets — our servers refuse anyone else.

### Transferring a ticket

You can give a ticket to another HAPPYN user from the app, under these
conditions:

- you **follow** the person you are giving it to;
- the ticket has not been scanned or cancelled;
- the event has not been cancelled and has not ended;
- the recipient meets the event's minimum age.

The transfer issues a **new QR code** to the recipient; yours stops working
immediately. The recipient is notified.

A ticket received by transfer **cannot be refunded by its new holder** — the
refund can only go back to the card that paid for it.

### No resale

HAPPYN does not support resale. HAPPYN takes no part in any money exchanged
between individuals for a ticket, and cannot help if such an exchange goes
wrong.

## 6. Prohibited conduct

You may not:

- create fraudulent, misleading, or non-existent events, or sell tickets for an
  event you have no right to sell;
- harass, threaten, defame, or impersonate anyone;
- publish content you do not have the right to publish;
- use HAPPYN for anything illegal, including selling regulated or prohibited
  goods;
- try to forge, copy, or reuse tickets or QR codes;
- scrape HAPPYN, probe it for weaknesses, or try to get around its access
  controls;
- create accounts or interact automatically (bots, scripts);
- use private messages to send spam or unwanted solicitations.

The Community Guidelines describe these rules in more detail.

## 7. Content you publish

"Content" means anything you put on HAPPYN: posts and their photos, captions,
comments, messages, event descriptions and images, and your profile.

**You keep ownership of your content.** You grant HAPPYN a non-exclusive,
worldwide, royalty-free licence to host, store, display, and distribute it
**within HAPPYN**, only to operate the service, and only for as long as it stays
published. The licence ends when you delete the content or your account, except
where we must keep it (see the Data Retention Policy and the Content Moderation
Policy).

### Posts are tied to events

A post on HAPPYN must be attached to an event that you **organize** or for which
you **hold a ticket**. Our servers enforce this.

### Who sees a post

Posts are visible only to people **signed in** to HAPPYN — never to visitors
without an account. Within that:

- posts about a **public event** are visible to all members;
- for a **private event**, the organizer chooses whether posts are visible to
  everyone or **only to the organizer and ticket holders**. If posts are
  public, the event's name and date become visible with them.

**[À CONSTRUIRE]** — Photos themselves are stored at addresses that work without
signing in. See the Privacy Policy, "Photos and files", and Annex A.

### Comments

Members who can see a post can comment on it. The author of a post can turn
comments off for that post.

## 8. Moderation and enforcement

We may remove content and suspend accounts that break these Terms or the
Community Guidelines. The Content Moderation Policy explains how reports are
handled and how to contest a decision.

A suspended account:

- **keeps the tickets it has paid for**;
- can no longer publish posts, comment, or create events.

## 9. Payments, refunds and cancellations

See the Payments Policy and the Refund and Cancellation Policy. In short: your
card details go to Stripe and never reach us; a cancelled event is refunded
automatically; you can cancel a ticket yourself until the organizer's deadline.

## 10. Availability

HAPPYN is provided "as is". We do not guarantee it will always be available or
free of errors, and we may change or stop features. We will give reasonable
notice before stopping anything you have paid for.

## 11. Limitation of liability

To the extent the law allows, HAPPYN is not liable for:

- what happens at an event, including injury, loss, or damage;
- an organizer's failure to hold or run an event (refunds for cancelled events
  are handled as described in the Refund and Cancellation Policy);
- content published by other users;
- losses caused by your failure to keep your account secure.

Nothing in these Terms limits liability that the law does not allow to be
limited, including under Ontario's *Consumer Protection Act, 2002* and, for
consumers resident in Quebec, Quebec's *Consumer Protection Act*.

**[À DÉCIDER] [AVOCAT]** — Whether to cap our liability at the amount you paid in
the previous 12 months. Common, but its enforceability against consumers in
both provinces is a question for your lawyer.

## 12. Governing law

These Terms are governed by the laws of the Province of Ontario and the federal
laws of Canada applicable there.

**[AVOCAT]** — A clause choosing the courts of Ontario does not reliably bind a
consumer. A Gatineau resident may be entitled to sue where they live, whatever
this clause says. Confirm the wording; don't assume every dispute stays in
Ontario.

## 13. Changes to these Terms

We may update these Terms. For a **material change**, we will notify you in the
app at least **30 days** before it takes effect, and ask you to accept the new
version. Small corrections (typos, clarifications that change nothing) take
effect when published.

**[À CONSTRUIRE]** — The app does not yet record which version of the Terms each
person accepted, nor ask for acceptance of a new version. See Annex A.

## 14. Contact

**contact@happynevents.com**

---

# 2. Privacy Policy

`privacy` · Version 2.0 · Effective date: **[À DÉCIDER]**

## In short

- We collect what we need to run HAPPYN: your account details, what you
  publish, your tickets, and how you use the social features.
- **We don't sell your information, show ads, or track you across other apps
  or websites.**
- Your **email and date of birth are never shown to anyone.** Your name,
  username, photo, bio and city are visible to other members.
- **Your location is only used if you turn on "Near me"**, to find events close
  to you. It is never shown to anyone.
- Nobody can see which events you go to unless **you follow each other *and*
  you choose to show it**.
- Our database is in **Montréal, Canada**. Some of our providers (payments,
  email, crash reports, notifications) are in the United States.
- You can see, correct, download (on request) and delete your information.
  Deleting your account is in Settings.

## 1. Who is responsible

**[À DÉCIDER] — Legal entity, address, and the person accountable for personal
information.** PIPEDA requires you to designate someone accountable and to make
their identity available; Law 25 requires publishing their title and contact
details. Publishing them here satisfies both. By default, this is the
highest-ranking person in the business — you — until you designate someone
else in writing.

Privacy questions and requests: **contact@happynevents.com**

## 2. Which law applies

HAPPYN is based in Ottawa, Ontario, so the federal *Personal Information
Protection and Electronic Documents Act* (PIPEDA) governs how we handle personal
information. Because many members live in Quebec, we also apply the standards of
Quebec's *Act respecting the protection of personal information in the private
sector* (Law 25) **to everyone**, rather than treating people differently
depending on which side of the river they live on.

## 3. What we collect, and why

### 3.1 When you create your account

| Information | Required? | Why | Who can see it |
|---|---|---|---|
| Email address | Yes | Your identity, sign-in, and transactional emails (password reset, receipts) | Only you |
| Password | Yes (email sign-up) | Signing in. Stored hashed by our authentication provider; nobody at HAPPYN can read it | Nobody |
| Full name | Yes | Shown on your profile, posts, comments and messages | Members |
| Date of birth | Yes | Enforcing the minimum age of 14, event age limits, and the 18+ rule for organizers | Only you |
| Username | Yes (generated if you don't choose) | How people find and mention you | Members |
| Profile photo | Optional | Shown on your profile | Members |
| Bio | Optional | Shown on your profile | Members |
| City | Optional | Shown on your profile. It is text you type, not a location | Members |
| Interests | Optional | Saved to your profile. **[À CONSTRUIRE]** — not used for anything yet (see Annex A) | Only you |
| App language | Automatic | Showing the app and sending notifications in your language | Only you |

### 3.2 If you sign in with Google

Google sends us your **email address, your name, and your profile picture**. We
receive nothing else from Google — not your contacts, not your Google activity —
and we send Google nothing about what you do on HAPPYN. HAPPYN then asks you for
your date of birth, because Google does not provide it.

### 3.3 When you use HAPPYN

| Information | Why | Who can see it |
|---|---|---|
| Tickets you hold, and their status (valid, used, transferred, cancelled) | Admitting you to events, refunds | You, and the event's organizer |
| Purchase records: amount, date, Stripe payment reference | Accounting, refunds, disputes | You; HAPPYN |
| Events you create, including their address | Publishing your events | Depends on the event (see 4.3) |
| Posts, photos, captions | Publishing your content | Members (see Terms, section 7) |
| Comments | Publishing your comments | Those who can see the post |
| Private messages, and content you share in them | Delivering your messages | You and the other person (see 3.4) |
| Follows, likes, saved events | Social features, your saved list | Follows and likes: members. Saved events: only you |
| Event attendance (generated when you get a ticket) | Showing friends where you're going — only if you allow it | See 4.2 |
| Blocks | Hiding accounts from you | Only you |
| Reports you submit, or that concern your content | Moderation | HAPPYN moderators |
| Notifications we send you | Your notification list | Only you |
| Device notification token | Sending push notifications to your phone | Nobody; used by our systems only |

### 3.4 Private messages

You can send a private message to someone **you follow**, unless one of you has
blocked the other. Messages can contain text and shared events or posts.

- Messages are stored on our servers so they can be delivered and shown in your
  conversation history. **They are not end-to-end encrypted.**
- HAPPYN staff do not read messages, except a message that has been **reported**
  to us, which a moderator reviews to handle the report.
- **You cannot delete a message once sent.** It stays in the other person's
  history, like a letter. If you delete your account, your messages stay with
  their recipients, shown as coming from "Deleted account".

### 3.5 Your location — only if you turn on "Near me"

"Near me" shows events within a distance you choose. To use it, you either pick
a city from a list, or allow HAPPYN to use your phone's location.

If you allow location:

- HAPPYN asks for your **approximate** position (accuracy of about a hundred
  metres), never a precise one, and only while the app is open — never in the
  background;
- the position is sent to our server **each time you search for nearby
  events**, to calculate distances, and is **not stored** there;
- the position is saved **on your phone** so the next search is quicker. You
  can switch back to a city, or turn location off in your phone's settings, at
  any time.

Nobody else ever sees your location. HAPPYN never shares it, and never uses it
for anything but finding events near you.

When you tap an event's address, it opens your phone's map app; HAPPYN does not
receive your position from it.

### 3.6 If you organize paid events

To receive money from ticket sales, you open a payout account with **Stripe**,
our payment provider. **Stripe** — not HAPPYN — collects your identity
information and bank details, as financial regulations require. HAPPYN keeps
only your Stripe account identifier and whether it can receive payouts.

### 3.7 What we deliberately do not collect

- **No advertising or tracking.** There is no advertising network in HAPPYN. We
  don't build an advertising profile of you, and we don't sell personal
  information — to anyone, ever.
- **No tracking across other apps or websites.**
- **No card details.** Your card number goes directly to Stripe.
- **No contacts.** HAPPYN never reads your phone's address book.
- **No background location.**

## 4. Who sees your information

### 4.1 Other members

- **Visible to members:** your name, username, profile photo, bio, city, your
  posts and comments, who you follow, and who follows you.
- **Never visible to other members:** your email address, your date of birth,
  your interests, your saved events, your blocks, your location. This is
  enforced by our database, not only by the app's screens.

### 4.2 Where you're going

Getting a ticket creates an attendance record. **By default, nobody can see
it.** Someone can see that you're going to an event only if **both**:

1. you follow each other, **and**
2. you have chosen to show that particular attendance.

Blocked accounts never see it. This is enforced by our servers.

### 4.3 Event organizers

When you have a ticket for an event, its organizer can see, in their list of
attendees: **your name, your profile photo, your ticket type, its status, and
when you got it**. Organizers never see your email address or date of birth.

For a **private** event, the exact address is visible only to the organizer and
to ticket holders; other members see only the city.

### 4.4 Service providers

We use providers to run HAPPYN. Each receives only what it needs for its task.

| Provider | What it does for us | What it receives | Where |
|---|---|---|---|
| **Supabase** | Database, accounts, file storage, server functions | All data described in this policy | **Montréal, Canada** (region ca-central-1) |
| **Stripe** | Payments, refunds, payouts to organizers | Payment details; organizers' identity and bank details | Canada / United States |
| **Google — Firebase Cloud Messaging** | Delivering push notifications | Your device's notification token, and the notification's text | United States |
| **Google — Sign-In** | Signing in with Google, if you choose it | See 3.2 | United States |
| **Resend** | Sending emails (for example report alerts to our moderators) | The email's recipient and content | United States |
| **Netlify** | Hosting the website | Technical data from your visit (IP address, browser) | Global network |
| **Sentry** | Crash and error reports, and app performance measurements | Technical details of an error or a slow screen. **No name, email, IP address or screenshot** | United States |

**[À VÉRIFIER]** — Which provider sends account emails (sign-up confirmation,
password reset): Supabase's built-in service or a custom one.

**[AVOCAT]** — Several providers process data **in the United States**. PIPEDA
requires us to disclose this and to protect the data by contract; Law 25
requires a **privacy impact assessment before transferring** a Quebec resident's
information outside Quebec. The main database being in Montréal helps, but
Stripe, Firebase, Resend and Sentry are still transfers. **This is one of the
two places where I would not launch without advice.**

### 4.5 When the law requires it

We may disclose information when the law requires it (for example, a court
order), or when necessary to protect someone's life or safety. See the Content
Moderation Policy for illegal content.

### 4.6 If HAPPYN changes hands

If HAPPYN is sold or merged, your information would pass to the new owner, who
would remain bound by this policy. We would tell you beforehand.

## 5. Automated decisions

HAPPYN makes **no automated decision that has legal or similarly significant
effects on you**. Content is removed and accounts are suspended by a person, and
every such action is logged. Automatic rules that do exist — refusing a ticket
transfer to someone too young, refusing a second scan of a ticket — apply the
rules described in these policies; you can always write to us about them.

## 6. Photos and files

Photos (profile pictures, event images, post photos) are stored in cloud
storage in Montréal. **Anyone who obtains a photo's web address can view it
without signing in**, and those addresses are not designed to be secret. Treat a
photo you publish as reachable by anyone who receives its link.

**[À CONSTRUIRE]** — Move to time-limited signed addresses, at least for photos
of private events. Until then, this paragraph must stay as written.

## 7. How long we keep information

See the Data Retention Policy.

## 8. Your rights

Under PIPEDA — and under Law 25 if you live in Quebec — you can:

| Right | How |
|---|---|
| **See** the information we hold about you | Most of it is in the app (profile, tickets, posts, messages). For a complete copy, write to us. |
| **Correct** it | Edit your profile in the app. For anything else, write to us. |
| **Get a copy** in a usable format (portability) | Write to us; we send it in a structured, common format (JSON). |
| **Withdraw consent / delete** | Delete your account in Settings (see the Account Deletion Policy), or delete individual posts and comments. |
| **Stop location use** | Switch "Near me" to a city, or turn location off in your phone's settings. |
| **Stop notifications** | In your phone's settings. |
| **Complain** | To the Office of the Privacy Commissioner of Canada, or, if you live in Quebec, to the Commission d'accès à l'information du Québec. |

Write to **contact@happynevents.com**. We respond **within 30 days**. We may ask
you to confirm your identity first, so that we never send your information to
someone else.

## 9. Security

- Access to every table is controlled by the database itself, not only by the
  app — and these rules are tested automatically.
- Passwords are hashed; nobody at HAPPYN can read them.
- QR codes are cryptographically signed and change every five minutes.
- On Android, screenshots and screen recording are blocked on the ticket
  screen. **iOS offers no equivalent**: screenshots remain possible there (but
  the code in them expires).
- Card details never reach our servers.

No system is perfectly secure. If a breach creates a **real risk of significant
harm**, we will notify you, the Office of the Privacy Commissioner of Canada, and
— where Quebec residents are affected — the Commission d'accès à l'information
du Québec, as the law requires.

## 10. Children

HAPPYN is not for anyone under 14. If we learn that an account belongs to a
child under 14, we delete it and the information attached to it.

## 11. Changes

We will notify you in the app at least **30 days** before a material change to
this policy takes effect.

---

# 3. Community Guidelines

`community` · Version 2.0 · Effective date: **[À DÉCIDER]**

## In short

HAPPYN exists so people find things worth showing up for — and enjoy them
safely. Be real, be respectful, post what you have the right to post, and
respect people who don't want to be in your photos.

## What is not allowed

**Fake or misleading events.** Events that don't exist, that you have no right
to sell tickets for, or whose description misrepresents what will happen.

**Harassment and hate.** Insults, threats, or degrading content aimed at
someone. Content attacking people because of race, ethnicity, national origin,
religion, disability, sex, gender identity, sexual orientation, or age. This
applies everywhere — posts, comments, and private messages.

**Sexual content.** Nudity and sexually explicit content. **Any sexual content
involving a minor is reported to the authorities** (see the Content Moderation
Policy).

**Violence.** Threats, glorifying violence, or content meant to intimidate.

**Impersonation.** Pretending to be another person, an organization, or an
event you have nothing to do with.

**Illegal activity.** Selling regulated or prohibited goods (drugs, weapons,
alcohol to minors…), or organizing activities that are illegal where they take
place.

**Spam and manipulation.** Repeated unwanted content or messages, fake accounts,
artificial likes or follows.

**Other people's privacy.** Publishing someone's personal information (address,
phone number…), or photos of identifiable people who have asked you not to.

## Photos of other people

Events are social, and photos usually include other people. If someone asks you
to remove a photo of them, remove it. If they report it, we may remove it
ourselves.

## Private messages

Messages are for people who know each other — you can only message people you
follow. Don't use them to sell, promote, or contact people who haven't asked to
hear from you. If someone sends you something abusive, **report the message and
block the account**.

## What happens if you break these rules

Depending on how serious it is: the content is removed, your account is
suspended, or — for illegal content — the matter is reported to the
authorities. **You keep the tickets you have already paid for.**

## Reporting and blocking

Every event, post, comment, message and account has a **Report** option.
Reports are reviewed by a person. You can also **block** an account: its posts
and events disappear for you, and neither of you can message the other any
more — including in a conversation that was already open.

---

# 4. Content Moderation Policy

`content-moderation` · Version 1.0 · Effective date: **[À DÉCIDER]**
*(nouveau document — à créer dans `legal_documents`)*

## In short

- Anyone can report an event, a post, a comment, a message, or an account.
- Every report alerts our moderators immediately; a person reviews it **within
  24 hours**.
- We can dismiss a report, remove a post, unpublish an event, or suspend an
  account. Every decision is logged.
- Illegal content — especially anything sexual involving a minor — is removed,
  **preserved as evidence**, and reported to the authorities.
- If you think we got it wrong, write to us: someone reviews it within 7 days.

## 1. How reports reach us

Any member can report an event, a post, a comment, a private message, or an
account, choosing a reason and optionally adding details. Each report:

- is recorded with who sent it, what it concerns, the reason, and when;
- immediately sends an alert email to our moderation address;
- is reviewed by a person **within 24 hours**.

The person you report is **not told who reported them**.

## 2. What we can do

| Action | Effect |
|---|---|
| **Dismiss** | The report was not founded. Nothing changes. |
| **Remove a post** | The post and its photo are deleted for good. |
| **Unpublish an event** | The event stops being visible. Tickets already sold are not destroyed: buyers keep the record of what they paid for. |
| **Suspend an account** | The account can no longer post, comment, or create events. It keeps the tickets it paid for. |

Every action is recorded: who took it, what it concerned, the report it answers,
and when. We keep this record for two years, so that a decision can be
explained afterwards. **[À CONSTRUIRE]** — automatic deletion after two years
(see the Data Retention Policy).

## 3. Illegal content

Some content is not a matter of rules but of criminal law. When we find, or are
credibly told about:

- sexual content involving a minor,
- a credible threat of violence against a person,
- content promoting terrorism,

we will:

1. remove the content from view immediately;
2. **preserve** the content and the related account data instead of deleting
   them, so that evidence is not destroyed;
3. report it to the competent authority — in Canada, child sexual abuse material
   is reported to **Cybertip.ca** (Canadian Centre for Child Protection), and to
   the police where required;
4. suspend the account.

**[AVOCAT]** — **The second point where I would not launch without advice.**
Canada's *Act respecting the mandatory reporting of Internet child pornography
by persons who provide an Internet service* imposes specific duties on
providers, including a preservation period. Your lawyer must confirm what
applies to HAPPYN, what to preserve and for how long, and whom to notify.
"We deleted it" is not compliance. This applies from your first user, whatever
your size.

**[À CONSTRUIRE]** — Removing content today deletes it. A way to **hide while
preserving** is needed for this section to be true.

## 4. Contesting a decision

If your content was removed or your account suspended and you think it was a
mistake, write to **contact@happynevents.com**: say what was removed and why you
think the decision was wrong. We answer **within 7 days**. Where possible, the
review is done by someone who was not involved in the original decision.

## 5. Blocking

Blocking is a personal tool, separate from reporting. When you block an
account:

- its posts and the events it organizes disappear for you;
- neither of you can message the other any more, **including in a
  conversation already open** — and that conversation disappears for both of
  you while the block lasts;
- it never sees where you're going;
- **it is not told** that you blocked it.

Blocking doesn't remove anything for other people. You can unblock in Settings.

---

# 5. Account Deletion Policy

`account-deletion` · Version 1.0 · Effective date: **[À DÉCIDER]**
*(nouveau document — à créer dans `legal_documents`)*

## In short

- Delete your account in **Settings → Delete my account**, or on the website.
  No reason needed, no email to write.
- Before anything happens, HAPPYN shows you exactly what will be affected.
- **If money is still involved, deletion waits** — so that nobody loses money:
  not you, not the people who bought your tickets.
- Your profile, posts, comments, likes and follows are deleted. Records others
  depend on (tickets, past events, messages you sent) are kept **without your
  name**.
- Deletion is final: the account cannot be recovered.

## 1. Where

- **In the app:** Settings → Delete my account.
- **On the website:** happynevents.com/delete-account.html, after signing in.

## 2. What you see first

HAPPYN shows you, before anything is deleted: how many events you organize (and
which will be cancelled), how many tickets you hold, and how many posts you have
published. **Nothing is deleted until you confirm.**

## 3. When deletion has to wait

To make sure nobody loses money, deletion is **refused** while:

| Situation | What to do first |
|---|---|
| You hold a **paid ticket** for an event that hasn't happened yet | Cancel it (and get refunded, if the deadline allows) or transfer it |
| You have **sold paid tickets** for an event that hasn't happened yet | Cancel the event — buyers are refunded automatically |
| You have ticket sales **not yet paid out** to you | Wait for the payout |

## 4. What happens when you delete

| Your data | What happens |
|---|---|
| Profile: name, username, photo, bio, city, interests, date of birth, language | **Deleted** |
| Posts and their photos | **Deleted** |
| Comments | **Deleted** |
| Likes, follows (both ways), saved events, blocks | **Deleted** |
| Attendance records | **Deleted** |
| Notification tokens | **Deleted** |
| Sign-in credentials | **Deleted** — the account cannot be recovered |
| **Free** tickets for upcoming events | **Deleted**; the place goes back on sale |
| Other tickets (past, used, or cancelled) | **Kept, without your identity** — needed for accounting |
| **Upcoming events with participants** | **Cancelled** — participants are notified (and refunded, if they paid) |
| Upcoming events without participants | **Deleted** |
| **Past events** | **Kept**, shown as "Deleted organizer" — people who attended still see them in their history |
| **Private messages you sent** | **Kept with the recipient**, shown as "Deleted account" — a message sent belongs to its recipient too, and may be evidence in a report |
| Conversations where both people have deleted their accounts | **Deleted** |
| Reports you submitted | **Kept without your identity** |
| Reports about your content, and moderation actions | **Kept** — an account cannot erase its record by leaving |
| Your Stripe payout account (organizers) | Disconnected from HAPPYN. Stripe keeps its own records under its own obligations |

## 5. How long kept data lasts

See the Data Retention Policy. Where data is kept, it is separated from your
identity wherever its purpose allows.

## 6. Deleting just one thing

You don't need to delete your account to remove something:

- you can delete a **post** or a **comment** at any time;
- you can **cancel a ticket** until the organizer's deadline;
- you can **cancel an event** you organize — buyers are refunded automatically;
- you cannot delete a **private message** once sent (see the Privacy Policy).

---

# 6. Data Retention Policy

`data-retention` · Version 2.0 · Effective date: **[À DÉCIDER]**

## In short

We keep information only as long as it is needed for the reason we collected
it, then destroy it — or remove your identity from it.

## Retention periods

PIPEDA requires keeping personal information only as long as needed for its
purpose; Law 25 requires destroying or anonymizing it once that purpose is
fulfilled.

| Information | How long | Why |
|---|---|---|
| Account and profile | As long as the account exists | Running the service |
| Date of birth | As long as the account exists | Age rules |
| Posts, photos, comments | Until you delete them or your account | Your content |
| Private messages | As long as at least one of the two people has an account | Your conversations; evidence in reports |
| Saved location ("Near me") | On your phone only, until you change it | Speed of the next search |
| Location sent for a search | Not stored | — |
| Tickets and payment records | **7 years** after the event, without your identity if you deleted your account | Accounting and tax obligations |
| Attendance records | Deleted with the ticket or the account | Social features |
| Notifications | **[À DÉCIDER]** (suggestion: 90 days) | Your notification list |
| Reports and moderation actions | **2 years** | Moderation integrity, audits |
| Preserved illegal content | As required by law, then destroyed | Legal obligation |
| Email delivery logs (Resend) | Per Resend's retention **[À VÉRIFIER]** | Deliverability |
| Crash reports and performance data (Sentry) | **90 days** **[À VÉRIFIER]** — Sentry plan setting | Fixing defects |
| Backups | Up to **[À VÉRIFIER — depends on the Supabase plan]** days before being overwritten | Recovery after an incident |

**[À CONSTRUIRE]** — **Nothing deletes data automatically today.** The "7 years",
"2 years" and "90 days" periods require scheduled clean-up jobs (the database's
scheduler, pg_cron, is not yet enabled). Either build them before publication,
or replace the figures with "as long as necessary for [purpose]" until they
exist. Promising a deletion that never happens is worse than promising none.

**[À DÉCIDER]** — Confirm the 7-year figure for financial records with your
accountant.

---

# 7. Cookie and Local Storage Policy

`cookie` · Version 2.0 · Effective date: **[À DÉCIDER]**

## In short

**HAPPYN uses no advertising cookies, no analytics cookies, and nothing that
tracks you across other websites.** That's why you're never asked to accept
cookies.

## In the app

The app stores a few things **on your phone**:

| What | Why | How long |
|---|---|---|
| Your session | So you aren't signed out every time you close the app | Until you sign out |
| Your language choice | Showing the app in your language | Until you change it |
| Your "Near me" setting (city or approximate position, and distance) | Finding nearby events faster | Until you change it |

Your **saved events** are not stored on your phone: they are saved to your
account, so they follow you from one phone to another.

## On the website

- The **password reset** page temporarily keeps the reset code in your
  browser's session storage, so that reloading the page doesn't lose it. It is
  erased when you close the tab, and as soon as your password is changed.
- Your **language choice** (FR/EN) is remembered in your browser.
- The **account deletion** page keeps your session while you are on it.

**[À VÉRIFIER]** — Confirm how the deletion page stores the session.

The website loads **no third-party script and no external font**. Its only
outside connection is to our own database, to display these documents.

---

# 8. Copyright Policy

`copyright` · Version 2.0 · Effective date: **[À DÉCIDER]**

## In short

Post only what you have the right to post. If someone uses your work on HAPPYN
without permission, tell us and we'll deal with it.

## Publishing content

Publish only content you created or have permission to use. Uploading someone
else's photo, poster, artwork, or music without permission may infringe their
copyright.

## Reporting an infringement

Write to **contact@happynevents.com** with:

1. a description of the work you own;
2. where the infringing content appears on HAPPYN (a screenshot or description
   of the post or event);
3. your contact details;
4. a statement that you believe in good faith the use is not authorized;
5. a statement that the information is accurate and that you are the owner, or
   authorized to act for them.

We acknowledge your notice **within 3 business days** and act **within 10**.

## Counter-notice

If your content was removed and you believe it was wrongly removed, tell us and
explain why you have the right to publish it. We'll review it and may restore it.

## Repeat infringement

Accounts that repeatedly infringe copyright are suspended.

**[AVOCAT]** — Canada uses a **notice-and-notice** regime, different from the
American notice-and-takedown. The legal obligation is to forward the notice to
the alleged infringer, not necessarily to remove the content. Have this section
reviewed specifically.

---

# 9. Payments Policy

`payments` · Version 2.0 · Effective date: **[À DÉCIDER]**

## In short

- Payments are processed by **Stripe**. Your card details go straight to Stripe
  and never reach HAPPYN.
- **The price you see is the price you pay**, in Canadian dollars. HAPPYN's fee
  is taken from the organizer's share, not added to your price.
- Your ticket appears as soon as Stripe confirms the payment.
- Organizers are paid by Stripe after their event has taken place.

## 1. How payment works

Payments are processed by **Stripe**, a regulated payment provider. Your card
number, expiry date, and security code are entered in Stripe's payment form and
go **directly to Stripe**: they never reach HAPPYN's servers. We keep only that a
payment succeeded, its amount, its date, and Stripe's reference for it.

Depending on your phone, you may also be able to pay with Apple Pay or Google
Pay, through Stripe. **[À VÉRIFIER]**

## 2. The price

- The price shown is **the price charged**, in **Canadian dollars**.
- There is **no service fee added at checkout**. HAPPYN's fee is deducted from
  the organizer's share (see section 5).
- You can buy several tickets of the same type in one payment.

**[À DÉCIDER] [AVOCAT]** — **Sales tax (GST/HST/QST).** Who charges and remits
it: HAPPYN or the organizer? It depends on how payouts are structured and on
registration thresholds. The app handles **no tax** today. This must be settled
with an accountant before the first real ticket is sold, and stated here — the
price shown must say whether taxes are included.

## 3. When your ticket appears

Our servers issue your ticket as soon as Stripe confirms the payment — usually
immediately. If confirmation takes longer, the app tells you, and the ticket
appears in **My Tickets** as soon as it arrives.

**A charge without a ticket is always corrected.** If you were charged and no
ticket appeared, write to **contact@happynevents.com** with the date and amount.

## 4. Who you are paying

You are paying for a ticket to an event run by its **organizer**. HAPPYN collects
the payment on the organizer's behalf through Stripe, and passes it on minus our
fee.

## 5. How organizers are paid

- To sell paid tickets, an organizer must first open a **Stripe payout account**
  from HAPPYN, where Stripe verifies their identity and bank details. **A paid
  event cannot be published until that account can receive money.**
- HAPPYN's fee is **5% of the ticket price**. The rate in force when the event is
  created applies to that event, even if the rate changes later.
- The organizer's share is paid **after the event has ended**, once the waiting
  period has passed: **[À DÉCIDER — 3 jours aujourd'hui dans le code, 5 jours
  décidés le 2026-10-08]**. The waiting period allows refunds and checks that
  the event really took place.
- HAPPYN may hold a payout while it checks an event — for example, when no
  ticket was scanned at the door, or for an organizer's first events.

**[À CONSTRUIRE]** — The automatic payout run, the 5-day hold, and the checks
described above are decided but not built; **no payout has been made yet.**
Until they are, this section must not promise a date.

## 6. Failed payments and duplicates

If your payment fails, you are not charged and no ticket is issued. If you are
charged twice, or charged without receiving a ticket, write to us: we
investigate and **always** refund duplicates and charges without tickets.

---

# 10. Refund and Cancellation Policy

`refund` · Version 2.0 · Effective date: **[À DÉCIDER]**

## In short

- **If the organizer cancels the event, you are refunded automatically**, in
  full, to the card you paid with. You don't need to ask.
- **You can cancel your ticket yourself** in the app, and be refunded, until a
  deadline the organizer chose: 24 hours, 48 hours, or 7 days before the event
  — or not at all. The event page shows it **before you buy**
  **[À CONSTRUIRE — voir l'annexe A]**.
- Charged twice, or charged without a ticket? Always refunded.
- A ticket you received as a gift (transfer) can't be refunded by you.

## 1. If the organizer cancels the event

When an organizer cancels an event:

1. ticket sales stop immediately;
2. **every valid paid ticket is refunded in full**, automatically, to the card
   that paid for it;
3. every ticket holder is notified.

You don't need to request anything. Refunds usually appear on your statement
within **5 to 10 business days**, depending on your bank.

## 2. Cancelling your own ticket

Each organizer chooses, when creating the event, until when buyers can cancel:

| Organizer's choice | You can cancel and be refunded until… |
|---|---|
| 24 hours | 24 hours before the event starts |
| 48 hours | 48 hours before the event starts |
| 7 days | 7 days before the event starts |
| No cancellation | You cannot cancel — the event page says so before you buy |

The deadline is shown on the event page before purchase **[À CONSTRUIRE]**,
and on your ticket.
Before the deadline, cancel from your ticket in the app: you are refunded the
**full price of that ticket**, and your place goes back on sale.

You can't cancel a ticket that has already been scanned, or a ticket you
received by transfer — the refund can only go to the card that paid.

## 3. Always refunded

- You were **charged twice** for the same ticket.
- You were **charged and no ticket was issued**.

Write to **contact@happynevents.com** with the date and amount.

## 4. Not refunded (unless the organizer's deadline allows it)

- You changed your mind after the deadline.
- You didn't attend.
- The event took place as described but wasn't what you hoped.

## 5. If something goes wrong with an event that did take place

If an event was seriously different from its description, contact the
organizer first. If they don't reply within **7 days**, write to
**contact@happynevents.com**: we review the case, and may hold the organizer's
payout while we do.

**[AVOCAT]** — Consumer protection laws give buyers rights that no policy can
remove. Ontario's *Consumer Protection Act, 2002* governs distance contracts
(disclosures before purchase, cancellation rights if they are missing); Quebec's
Act applies to buyers in Gatineau and is stricter in places. **Have this
document reviewed first**: it is the one most likely to be tested, and where the
two provinces differ most.

**[À CONSTRUIRE]** — Today the deadline appears **only on the ticket, after
purchase**. Consumer law requires it to be disclosed **before** payment: this
must be built before the first paid sale.

---

# 11. Fraud Prevention Policy

`fraud-prevention` · Version 2.0 · Effective date: **[À DÉCIDER]**

## In short

HAPPYN tickets are hard to fake: the server issues them, the QR code changes
every five minutes, and each ticket gets in once. Buy only through HAPPYN — never
from someone claiming to have a spare.

## How tickets are protected

- **Only our servers create tickets**, after payment is confirmed. No app can
  create or modify one.
- Each ticket shows a **cryptographically signed QR code that changes every five
  minutes**. A screenshot shows an expired code: it won't admit anyone.
- A ticket can be **scanned once**. A second scan is refused.
- **Only the event's organizer can scan its tickets** — our servers refuse
  anyone else.
- A transferred ticket gets a **new code**; the old one stops working.

## Fraudulent events

Creating an event you don't intend to hold, or selling tickets for an event you
have no right to sell, is fraud. We remove such events, suspend the accounts,
refund buyers where we can, and cooperate with the authorities.

Paid events can only be created by organizers whose identity has been verified
by Stripe, and their money is paid out only **after** the event — which limits
what a fraudster could take.

## What you should do

- **Buy tickets only through HAPPYN.** Never pay someone who claims to have a
  spare ticket: ask them to **transfer** it to you in the app, which issues a
  genuine new ticket.
- **HAPPYN will never ask** for your password, your full card number, or a
  payment outside the app — not by message, email, or phone.
- **Report** suspicious events and accounts.

---

# 12. Safety Policy

`safety` · Version 2.0 · Effective date: **[À DÉCIDER]**

## In short

HAPPYN helps you find events, but doesn't run them or check who people are.
Use the tools — reporting, blocking, private attendance — and trust your
instincts. **In an emergency, call 911 first.**

## What HAPPYN does

- **Reports** are reviewed by a person within 24 hours.
- **Blocking** hides an account's posts and events from you and stops all
  messages between you, including in a conversation already open.
- **Your attendance is private by default.** Someone can see you're going to an
  event only if you follow each other *and* you chose to show it.
- **Messages** are only possible with people you follow.
- **Private events** keep their exact address for ticket holders.
- **Age limits:** organizers can set a minimum age, and the app won't sell a
  ticket to someone below it.

## What HAPPYN does not do

- We don't verify identity. A name on a profile is not proof of who someone is.
- We don't run background checks on organizers or inspect venues.
- We are not present at events.

## Meeting people

Events mean meeting strangers. Meet in public places where you can, tell someone
where you're going, keep your own way home, and leave if you feel unsafe.

## If you are in danger

Contact emergency services first — **call 911**. HAPPYN cannot intervene in a
physical emergency. Report the account to us afterwards so we can act on it.

---

# 13. Organizer Standards

`organizer` · Version 2.0 · Effective date: **[À DÉCIDER]**

## In short

- You must be **18 or older** to create events.
- Describe your event honestly, keep it up to date, and run it as described.
- You are responsible for the event itself: legality, safety, permits,
  insurance.
- To sell paid tickets, open a Stripe payout account. You're paid after the
  event, minus HAPPYN's 5% fee.
- If you cancel, use the Cancel button: buyers are refunded automatically.

## 1. Who can organize

Creating events requires being **18 or older** and accepting these standards.
Selling paid tickets also requires a **Stripe payout account** in your name,
where Stripe verifies your identity and bank details.

**[À CONSTRUIRE]** — The 18+ rule is checked by the app, not yet by the server.
See Annex A.

## 2. Your responsibilities

**Describe your event accurately**: date, time, location, price, what's
included, and any age limit. If something important changes, update the event:
**ticket holders are notified automatically** when the date, time, or place
changes.

**You are responsible for the event itself**: its legality, safety, permits,
insurance, and how it runs. HAPPYN provides ticketing and visibility; it does
not co-organize.

**Check age at the door** if you set an age limit. HAPPYN stops people below it
from buying, but doesn't verify identity.

**Choose your cancellation deadline honestly** (24 hours, 48 hours, 7 days, or
none). Buyers see it before paying **[À CONSTRUIRE]**, and it applies
automatically.

**Answer buyers within 7 days.**

**Cancel properly.** If the event won't happen, use the **Cancel** function:
sales stop, every buyer is refunded automatically, and everyone is notified.
Don't just stop responding.

## 3. Private events

A private event **never appears in Discover or in "Near me"**. It can only be
reached with the invitation code you share. Its exact address is visible only to
you and to ticket holders.

You also choose whether posts about it are visible to everyone or **only to
ticket holders**. Choose deliberately: if posts are public, your event's name and
date become public with them.

## 4. Your attendees

For each of your events, you can see the list of ticket holders: **name, profile
photo, ticket type, status, and purchase time**. You never see their email
address or date of birth. Use this list only to run your event — never to
contact people for other purposes, or to share it.

## 5. Payouts

- HAPPYN's fee is **5% of each ticket's price**. The rate when you create an
  event applies to that event.
- Your share is paid to your Stripe account **after the event has ended** and
  the waiting period has passed (**[À DÉCIDER — 3 ou 5 jours]**).
- If a ticket is refunded, its amount is not paid out.
- HAPPYN may hold a payout while it checks that an event took place as
  described — for example when no ticket was scanned at the door, or for your
  first events.

**[À CONSTRUIRE]** — See the Payments Policy, section 5: payouts are not yet
automated, and none has been made.

## 6. What we may do

We may unpublish events that break these standards, hold payouts while we
investigate, and suspend organizers who repeatedly break them or defraud buyers.

---

# Annexe A — Ce que l'app doit rattraper avant publication

Le texte ci-dessus promet ces comportements. L'app ne les tient pas encore.
**Chaque ligne : soit on construit, soit on retire la phrase du texte.**

| # | Promesse du texte | État dans l'app | Gravité |
|---|---|---|---|
| 1 | Les conditions acceptées sont enregistrées, et une nouvelle version est re-présentée (Terms §13) | La table `user_legal_acceptances` existe mais **l'app n'y écrit jamais** | Haute — sans preuve d'acceptation, la clause des 30 jours est vide |
| 2 | L'âge minimum d'un événement bloque l'achat (Terms §2, Safety) | Vérifié **par l'app seulement** ; ni `create-payment-intent` ni `issue_tickets` ne le revérifient | Moyenne |
| 3 | 18 ans pour créer un événement (Terms §2, Organizer §1) | Vérifié **par l'app seulement** ; la règle d'insertion des événements ne regarde pas l'âge | Moyenne |
| 4 | Durées de conservation (Retention) | **Aucune purge** ; pg_cron absent | Haute si les durées restent écrites |
| 5 | Contenu illégal masqué mais **préservé** (Moderation §3) | Retirer une publication la **supprime** | Haute — obligation légale |
| 6 | Versements après retenue, vérifications (Payments §5) | Rien d'exécuté ; retenue à **3 jours** dans le code contre 5 décidés | Haute avant toute vente payante réelle |
| 7 | Photos privées non accessibles sans connexion (Privacy §6) | Adresses publiques et devinables | Moyenne — le texte le dit honnêtement en attendant |
| 8 | La date de naissance n'est pas modifiable à volonté | Elle l'est : métadonnées et profil acceptent une mise à jour par la personne elle-même | Moyenne — contourne toutes les règles d'âge |
| 9 | Connexion Apple | Bouton factice | Bloquant pour l'iPhone |
| 10 | ~~Bloquer coupe la messagerie~~ | **Vérifié tenu le 2026-10-08** : la règle d'envoi et de lecture exclut les paires bloquées, conversations déjà ouvertes comprises. L'audit du même jour s'était trompé ; quatre tests le gardent désormais (`tests/rls/access_rules.sql`) | — |
| 11 | Le délai d'annulation est annoncé **avant** l'achat (Refund §2) | Affiché seulement sur le billet, **après** l'achat | **Haute** — obligation d'information préalable (LPC Ontario et Québec) |
| 12 | Les centres d'intérêt servent à quelque chose (Privacy §3.1) | Collectés et stockés, **utilisés nulle part** | Basse — mais la LPRPDE et la Loi 25 demandent de ne collecter que ce qui sert : les utiliser ou cesser de les demander |

**Corrigé le 2026-10-08 :** la date de naissance des comptes Google (commit
`03a5a85`). Les comptes Google déjà créés la donnent au prochain lancement.

# Annexe B — Chantiers techniques liés aux textes

1. **Langue des documents.** `legal_documents` n'a pas de colonne de langue :
   un slug = une ligne = une langue. Ajouter `locale` et une clé unique
   `(slug, locale)`, puis faire demander la bonne version par l'app (langue de
   l'app) et par le site (bouton FR/EN, qui aujourd'hui ne traduit que
   l'habillage de la page).
2. **Deux nouveaux documents** à créer : `content-moderation` et
   `account-deletion`.
3. **Acceptation** (Annexe A, ligne 1) : écrire dans `user_legal_acceptances` à
   l'inscription, et re-présenter les documents `requires_acceptance` quand leur
   version change.
4. **Mise en ligne :** fixer les dates d'entrée en vigueur, passer les versions
   à 2.0, écrire les textes en base, puis régénérer la copie de secours du site
   (`node web/tools/sync-legal-fallback.mjs`) et de l'app (`kLegalDocs`).

## Ce qu'il reste à faire sur ce brouillon

1. Trancher les **[À DÉCIDER]** — les plus urgents : l'entité juridique, la taxe
   de vente, la durée de retenue des versements.
2. Décider, ligne par ligne, de l'Annexe A : construire ou retirer.
3. Faire relire par un avocat **admis en Ontario et à l'aise avec le droit
   québécois**. Priorité : double juridiction, Remboursement, Paiements,
   Confidentialité (transferts hors Canada), contenu illégal.
4. Traduire en français après la relecture.
