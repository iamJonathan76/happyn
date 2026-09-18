# HAPPYN — Recueil légal, brouillon complet

**Statut : brouillon rédigé le 2026-09-02, juridiction corrigée le même jour (Ontario, pas Québec). Rien de ceci n'est en ligne.**
Les textes actuellement publiés sur `happynevents.com/legal.html` sont les
ébauches de juillet (7 342 caractères pour onze documents). Ce fichier les
remplace, une fois relu et validé.

---

## Comment lire ce document

**Ce que j'ai fait :** rédigé onze politiques complètes, structurées selon ce
que la **LPRPDE** (fédérale, applicable en Ontario), la *Loi de 2002 sur la
protection du consommateur* (Ontario) et les règles des magasins d'applications
exigent, et fidèles à ce que HAPPYN fait **réellement** — je décris le code
qu'on a écrit ensemble, pas un produit générique.

⚠️ **La double juridiction est le point le plus délicat de tout ce recueil.**
HAPPYN est établie à **Ottawa, Ontario** : c'est la LPRPDE qui gouverne le
traitement des données, et le droit ontarien qui s'applique au contrat. Mais le
marché visé est **Ottawa-Gatineau** — donc une partie de tes utilisateurs
résideront au **Québec**.

Or la **Loi 25** s'applique en fonction de la résidence de la personne, pas de
l'adresse de l'entreprise : dès que tu collectes les renseignements personnels
d'un résident québécois, plusieurs de ses obligations te suivent. Il en va de
même pour la *Loi sur la protection du consommateur* du Québec vis-à-vis d'un
acheteur québécois, et pour la Charte de la langue française à l'égard d'un
contrat de consommation conclu au Québec.

Je n'ai pas retiré ces exigences du texte — je les ai **conservées comme
prudentes**, parce qu'il est plus sûr de tenir le standard le plus élevé que de
découvrir après coup qu'il s'appliquait. **Mais c'est la première question à
poser à ton avocat :** dans quelle mesure le droit québécois te suit de l'autre
côté de la rivière.

**Ce que je n'ai pas fait, et que je ne peux pas faire :** valider
juridiquement. Je ne suis pas avocat. Sur les paiements et les données
personnelles au Québec, l'écart entre « raisonnable » et « conforme » se paie.
**Fais relire par un avocat en droit des technologies avant publication.** Une
relecture coûte bien moins cher qu'une rédaction, et tu arrives avec un texte
déjà fidèle à ton produit.

**Trois décisions t'appartiennent** et sont marquées `[À DÉCIDER]` dans le
texte. Je ne peux pas les prendre à ta place.

### Deux problèmes de structure à régler avant publication

**1. La version française.** En Ontario, aucune loi ne t'oblige à publier en
français. Mais la moitié de ton marché est à Gatineau, et pour un contrat de
consommation conclu avec un résident québécois, la Charte de la langue
française entre en jeu. Traite-la donc comme requise. Or
`legal_documents` n'a **aucune colonne de langue** : un slug = une ligne = une
langue. Il faut ajouter `locale` et une clé unique `(slug, locale)`, puis
adapter le site et l'app pour demander la bonne. C'est une migration courte,
mais elle doit exister avant que ces textes soient publiés.

**2. Deux documents n'existent pas encore** dans la table :
`content-moderation` et `account-deletion`. Les slugs actuels sont : `terms`,
`privacy`, `community`, `cookie`, `copyright`, `refund`, `payments`,
`fraud-prevention`, `safety`, `organizer`, `data-retention`.

---

# 1. Terms of Service

`terms`

**Effective date:** [À DÉCIDER — date de publication]
**Version:** 2.0

## 1. Who we are and what this agreement covers

HAPPYN ("HAPPYN", "we", "us") operates a mobile application and website that
let people discover events, buy tickets, and share what happened at those
events. These Terms form a binding agreement between you and HAPPYN.

`[À DÉCIDER]` — Legal entity name and address. If you incorporate before
launch, the incorporated company must appear here. Until then this agreement is
with you personally, and you carry personal liability for it. This is the single
strongest practical argument for incorporating before selling tickets for third
parties.

By creating an account or using HAPPYN, you accept these Terms, the Privacy
Policy, and the Community Guidelines.

## 2. Eligibility and age

You must be at least **14 years old** to create an account. This threshold
exists because Quebec's Law 25 requires parental consent for the collection of
personal information from children under 14, and HAPPYN does not operate a
parental consent process. HAPPYN is established in Ontario, where no fixed
statutory age applies, but a significant part of our community lives in Quebec —
so we apply the stricter threshold to everyone.

If you are between 14 and 17:

- you may browse events, follow organizers, save events, and publish content;
- you may purchase a ticket only where the event permits your age, and only if
  a parent or legal guardian authorizes that purchase;
- you may **not** create events, sell tickets, or receive payouts.

Organizing events and receiving payouts requires you to be **18 or older**.

Event organizers may set a minimum age for their event (14, 16, 18 or 21).
HAPPYN records your date of birth at sign-up and uses it to warn you when you
are below an event's minimum age. **HAPPYN does not verify identity.** The
organizer is responsible for checking age at the door.

## 3. Your account

You are responsible for your credentials and for everything done through your
account. Tell us immediately at contact@happynevents.com if you believe someone
else has access to it.

One person, one account. Accounts may not be sold, rented, or transferred.

## 4. What HAPPYN is, and what it is not

HAPPYN is a **platform**. Events are created, described, priced, and run by
their organizers, not by us. We do not host events, verify their accuracy, or
guarantee they will take place as described.

When you buy a ticket, you enter into a contract **with the organizer**. HAPPYN
processes the payment and issues the ticket, but the obligation to deliver the
event is the organizer's.

## 5. Tickets

Tickets are issued by our servers after payment is confirmed. Each ticket
carries a cryptographically signed QR code that **refreshes regularly** and can
be scanned only once. A screenshot of a QR code will not admit anyone: the code
it shows expires.

You may transfer a ticket to another HAPPYN user through the app. A transferred
ticket is invalidated for the sender and reissued to the recipient. **We do not
support resale**, and HAPPYN takes no part in any money exchanged between
private individuals for a ticket.

## 6. Prohibited conduct

You may not:

- create fraudulent, misleading, or non-existent events;
- harass, threaten, defame, or impersonate anyone;
- publish content you do not have the right to publish;
- use HAPPYN for any illegal purpose, including selling regulated goods;
- attempt to forge, duplicate, or reuse tickets;
- scrape, probe, or attempt to bypass our access controls;
- automate account creation or interactions.

## 7. Content you publish

You keep ownership of what you publish. You grant HAPPYN a non-exclusive,
worldwide, royalty-free licence to host, display and distribute that content
**within HAPPYN**, for as long as you keep it published, solely to operate the
service. This licence ends when you delete the content or your account, except
where we must retain it under section 11 of the Privacy Policy.

Photos published on HAPPYN must be attached to an event you organized or hold a
ticket for. This is enforced by our servers.

Where an organizer marks a private event's photos as "invitees only", those
photos are visible only to the organizer and to ticket holders. Where the
organizer marks them public, they appear in the public feed along with the
event's name and date. **Understand which setting your event uses before
publishing.**

## 8. Moderation and enforcement

We may remove content and suspend accounts that violate these Terms or the
Community Guidelines. See the Content Moderation Policy for how reports are
handled and how to contest a decision.

A suspended account keeps its purchased tickets — you paid for them — but can
no longer publish or create events.

## 9. Payments, refunds and cancellations

See the Payments Policy and the Refund Policy. In short: card data never reaches
HAPPYN's servers, refunds are the organizer's responsibility, and a cancelled
event marks its tickets as cancelled and notifies buyers.

## 10. Availability

HAPPYN is provided as-is. We do not guarantee uninterrupted availability, and we
may change or discontinue features. We will give reasonable notice before
discontinuing anything you have paid for.

## 11. Limitation of liability

To the extent permitted by law, HAPPYN is not liable for:

- what happens at an event, including injury, loss, or damage;
- an organizer's failure to hold, run, or refund an event;
- content published by users;
- losses caused by your failure to keep your account secure.

Nothing in these Terms limits liability that cannot be limited by law,
including under Ontario's *Consumer Protection Act, 2002* and, for consumers
resident in Quebec, that province's *Consumer Protection Act*.

`[À DÉCIDER]` — Whether to cap liability at the amount you paid in the previous
12 months. This is standard, but its enforceability against consumers — under
Ontario's Act, and under Quebec's for Gatineau users — is a question for your
lawyer.

## 12. Governing law

These Terms are governed by the laws of the Province of **Ontario** and the
laws of Canada applicable there. Disputes are subject to the courts of Ontario,
sitting in Ottawa.

`[À DÉCIDER]` — **A forum selection clause does not reliably bind a consumer.**
A Gatineau resident who buys a ticket may be entitled to sue where they live,
whatever this clause says. Confirm the wording with your lawyer, and do not
assume this clause keeps every dispute in Ontario.

## 13. Changes

We may update these Terms. Material changes will be announced in the app at
least 30 days before they take effect. Continuing to use HAPPYN after that date
means you accept the new version.

## 14. Contact

contact@happynevents.com

---

# 2. Privacy Policy

`privacy`

**Effective date:** [À DÉCIDER]
**Version:** 2.0

This policy explains what personal information HAPPYN collects, why, how long
we keep it, who else sees it, and how you exercise your rights.

HAPPYN is established in **Ottawa, Ontario**, so the federal *Personal
Information Protection and Electronic Documents Act* (**PIPEDA**) governs how we
handle personal information. Because a substantial part of our community lives
in **Quebec**, we also apply the standards of Quebec's *Act respecting the
protection of personal information in the private sector* (as amended by
**Law 25**) to everyone, rather than treating people differently depending on
which side of the river they live on.

## 1. Who is responsible

`[À DÉCIDER]` — Name, address, and the **person accountable for personal
information**. PIPEDA requires you to designate someone accountable for
compliance and to make their identity available on request; Law 25 goes further
and requires publishing their title and contact details. We publish them, which
satisfies both. By default this person is the highest-ranking person in the
business — you — until you designate someone else in writing.

Contact: contact@happynevents.com

## 2. What we collect, and why

### Information you give us

| Information | Why we need it | Consequence of not providing |
|---|---|---|
| Email address | Account identity, sign-in, transactional email | Cannot create an account |
| Password | Authentication (stored hashed, never in plain text) | Cannot create an account |
| Full name | Displayed to other users on your profile and posts | Cannot create an account |
| **Date of birth** | Enforcing the 14-year minimum and event age limits | Cannot create an account |
| Profile photo, bio, city | Optional. Shown on your public profile | None — these are optional |
| Event details you create | Publishing your event | Cannot create events |
| Photos and captions | Publishing your content | Cannot publish |
| Report details | Handling your report | Cannot submit a report |

### Information created by your use of HAPPYN

- Tickets you hold, and their status (valid, used, transferred, cancelled).
- Attendance records, generated automatically when a ticket is issued.
- Follows, likes, and blocks.
- Moderation records where you report content or where content of yours is
  reported.

### Information we deliberately do **not** collect

- **We do not track your location.** The city on your profile is text you type.
  When you tap an address, it opens your device's map app — HAPPYN does not
  receive your position.
- **We do not track your behaviour for advertising or profiling.** We do not log
  what you look at, how long, or in what order. There is no advertising network
  in HAPPYN and we do not sell personal information.
- **We do not receive your card details.** See the Payments Policy.

## 3. Sign-in with Google

If you sign in with Google, Google tells us your email address, your name, and
your profile picture. We receive nothing else, and we send Google nothing about
your activity on HAPPYN.

## 4. Who else sees your information

### Other users

Your **name, username, profile photo, bio and city** are visible to anyone
using HAPPYN, and other signed-in users can find your profile by searching
your name or username. Accounts you have blocked, and accounts that have
blocked you, cannot find you this way. The lists of who you follow and who
follows you are visible to other signed-in users.
Your **email address and date of birth are never visible to other users** — they
are technically restricted to your own account row.

Your **attendance at an event** is visible only when two conditions are both
met: you and the other person follow each other, and you have explicitly made
that specific attendance visible. Holding a ticket does not make your attendance
public. This is enforced by our servers, not only by the interface.

### The organizer of an event you hold a ticket for

The person who created an event can see **the name and profile photo** of
everyone holding a valid ticket for it, which ticket type they bought, when they
bought it, and whether they have already been scanned in at the door. They need
this to run the door — in particular to let you in when your phone is dead.

The organizer **never sees your email address**, your date of birth, or anything
about the other events you attend. This list is restricted to the one event they
created; it is enforced by our servers, not by the interface.

Buying a ticket therefore means accepting that the organizer of that event knows
you are coming. Cancelled tickets are removed from that list.

### Service providers

| Provider | What they process | Where |
|---|---|---|
| Supabase | Database, authentication, file storage | `[À VÉRIFIER — région du projet]` |
| Stripe | Payment processing | Canada / United States |
| Resend | Transactional email delivery | United States |
| Netlify | Website hosting | Global CDN |
| Sentry | Crash reports, when enabled | United States |

`[À DÉCIDER]` — Several of these providers process data in the **United
States**. Under PIPEDA you must disclose that personal information may be
processed outside Canada, and you remain accountable for protecting it through
contractual means. Under Law 25, a **privacy impact assessment is required
before transferring** a Quebec resident's personal information outside the
province — and your Gatineau users make that relevant.

Your lawyer should confirm what documentation your situation requires. This is
one of the two places where I would not launch without advice.

### Legal disclosure

We may disclose information where required by law, or where necessary to protect
someone's safety. See the Content Moderation Policy.

## 5. Automated decisions

HAPPYN makes **no automated decision** that produces legal effects for you.
Content is removed and accounts are suspended by a human being, and every such
action is logged.

## 6. Storage of images

Photos are stored in cloud storage and served through long, unguessable
addresses. **Anyone who obtains such an address can view the image without
signing in.** We are moving to time-limited signed addresses; until then, treat
a photo you publish as potentially reachable by anyone who receives its link.

## 7. Cookies and local storage

See the Cookie and Local Storage Policy. In short: HAPPYN uses no advertising or
analytics cookies.

## 8. How long we keep information

See the Data Retention Policy.

## 9. Your rights

Under PIPEDA — and under Law 25 if you reside in Quebec — you may:

- **access** the personal information we hold about you;
- **correct** it if it is inaccurate;
- **withdraw consent** and delete your account (see the Account Deletion
  Policy);
- **obtain portability** of the information you provided, in a structured,
  commonly used technical format;
- **complain** to the Office of the Privacy Commissioner of Canada, or, if you
  reside in Quebec, to the Commission d'accès à l'information du Québec.

Write to contact@happynevents.com. We respond within **30 days**.

## 10. Security

- Access to every table is enforced at the database level, not only in the app.
- Passwords are hashed; we never see them.
- Ticket QR codes are cryptographically signed and rotate.
- The ticket screen is protected against screenshots on Android. **iOS provides
  no equivalent protection**, and screenshots remain possible there.
- Card data never reaches our servers.

No system is perfectly secure. If we discover a breach that creates a real risk
of significant harm, we will notify you and the Office of the Privacy
Commissioner of Canada, as PIPEDA requires — and the Commission d'accès à
l'information du Québec where Quebec residents are affected.

## 11. Children

HAPPYN is not intended for anyone under 14. If we learn that we hold information
about a child under 14, we delete it.

## 12. Changes

We will announce material changes in the app at least 30 days in advance.

---

# 3. Community Guidelines

`community`

**Effective date:** [À DÉCIDER]
**Version:** 2.0

HAPPYN exists so people can find things worth showing up for. These rules keep
it usable.

## What is not allowed

**Fake and misleading events.** Events that do not exist, that you have no right
to sell tickets for, or whose description misrepresents what will happen.

**Harassment and hate.** Targeting people with insults, threats, or degrading
content. Content attacking people on the basis of race, ethnicity, national
origin, religion, disability, sex, gender identity, sexual orientation, or age.

**Sexual content.** Nudity and sexually explicit content. Any sexual content
involving minors is reported to the authorities — see the Content Moderation
Policy.

**Violence.** Threats, glorification of violence, or content designed to
intimidate.

**Impersonation.** Presenting yourself as another person, an organization, or an
event you have no connection to.

**Illegal activity.** Selling regulated or prohibited goods, or organizing
activity that is illegal where it takes place.

**Spam and manipulation.** Repeated unsolicited content, fake accounts, or
artificial engagement.

**Other people's privacy.** Publishing someone's personal information, or photos
of identifiable people who have asked you not to.

## Photos of other people

Events are social, and photos usually contain other people. If someone asks you
to remove a photo of them, remove it. If they report it, we may remove it.

## What happens when you break these rules

Depending on severity: the content is removed, your account is suspended, or —
for illegal content — the matter is reported to the authorities. You keep any
tickets you have already paid for.

## Reporting

Every event, post, and account has a **Report** option. Reports are reviewed by
a human being. You can also block an account, which removes its content and its
events from your view.

---

# 4. Content Moderation Policy

`content-moderation` — **NOUVEAU DOCUMENT, à créer**

**Effective date:** [À DÉCIDER]
**Version:** 1.0

## 1. How reports reach us

Any user can report an event, a post, or an account. Every report generates an
immediate alert to our moderation address. Reports are reviewed **within 24
hours**.

## 2. What we can do

| Action | Effect |
|---|---|
| Dismiss | The report was not founded. Nothing changes. |
| Remove a post | The post is deleted permanently. |
| Unpublish an event | The event stops being visible. **Tickets already sold are not destroyed** — buyers keep the record of what they paid for. |
| Suspend an account | The account can no longer publish or create events. It keeps its purchased tickets. |

Every action is recorded with who took it, what it affected, and when. We keep
that record for **two years** so that we can answer questions about a decision
after the fact.

## 3. Illegal content — escalation

Some content is not a policy matter but a criminal one. Where we identify, or
are credibly informed of:

- **sexual content involving minors**,
- **credible threats of violence against a person**,
- **content promoting terrorism**,

we will:

1. remove the content from public view immediately;
2. **preserve** the content and the associated account data rather than deleting
   them, so that evidence is not destroyed;
3. report to the appropriate authority — in Canada, child sexual abuse material
   is reported to **Cybertip.ca**, operated by the Canadian Centre for Child
   Protection, and to police where required;
4. suspend the account.

`[À DÉCIDER]` — **This is the second point where I would not launch without
legal advice.** Canada's *Act respecting the mandatory reporting of Internet
child pornography by persons who provide an Internet service* imposes specific
obligations, including a preservation period, on providers. Your lawyer must
confirm what applies to HAPPYN, what you must preserve and for how long, and
who must be notified. "We deleted it" is not compliance.

This obligation does not depend on your size. It applies from your first user.

## 4. Contesting a decision

If your content was removed or your account suspended and you believe it was a
mistake, write to contact@happynevents.com. State what was removed and why you
believe the decision was wrong. We respond within **7 days**. A human being who
was not involved in the original decision reviews it where possible.

## 5. Blocking

Blocking is a personal tool, distinct from reporting. When you block an account,
its posts and the events it organizes disappear from your view. The blocked
account is not told. Blocking does not remove content for anyone else.

---

# 5. Account Deletion Policy

`account-deletion` — **NOUVEAU DOCUMENT, à créer**

**Effective date:** [À DÉCIDER]
**Version:** 1.0

You can delete your account from **Settings → Delete my account**, without
contacting us and without giving a reason.

## What you see first

Before anything is deleted, HAPPYN shows you what will be affected: how many
events you organize, how many tickets you hold, how many posts you published.
Nothing is deleted until you confirm.

## What is deleted immediately

- Your profile: name, photo, bio, city, **date of birth**.
- Your posts and their images.
- Your likes, follows, and blocks.
- Your attendance records.
- Your sign-in credentials. **The account cannot be recovered.**

## What is kept, and why

| Kept | Why | For how long |
|---|---|---|
| Ticket and payment records | Accounting and tax obligations, and the organizer's right to know who attended | 7 years |
| Events you organized | Other people bought tickets for them; erasing them would erase their purchase | Kept, with your name removed |
| Reports you submitted or that concerned you | Moderation integrity; an account cannot erase its record by leaving | 2 years |
| Moderation actions taken about your content | Audit obligations | 2 years |

Where information is kept, it is **dissociated from your identity** wherever the
purpose allows.

`[À DÉCIDER]` — The 7-year figure follows the usual Canadian record-keeping
period for financial records. Confirm it with your accountant.

## Deleting individual content

You can delete a post at any time without deleting your account. You cannot
delete a ticket you have used, or an event other people hold tickets for — but
you can cancel that event, which notifies the buyers.

---

# 6. Data Retention Policy

`data-retention`

**Effective date:** [À DÉCIDER]
**Version:** 2.0

PIPEDA requires that personal information be kept only as long as necessary for
the purpose it was collected for, and Law 25 requires its destruction once that
purpose is fulfilled. This is how long each category lives.

| Category | Retention | Reason |
|---|---|---|
| Account and profile | While the account exists | Operating the service |
| Date of birth | While the account exists | Age enforcement |
| Posts and images | Until deleted by you, or account deletion | Your content |
| Tickets and payment records | **7 years** after the event | Accounting and tax |
| Attendance records | Deleted with the account | Social features |
| Reports and moderation actions | **2 years** | Moderation integrity, audit |
| Preserved illegal content | As required by law, then destroyed | Legal obligation |
| Email delivery logs (Resend) | Per Resend's retention | Deliverability |
| Crash reports (Sentry, when enabled) | 90 days | Fixing defects |

Backups may retain deleted information for up to **30 days** before they are
overwritten.

---

# 7. Cookie and Local Storage Policy

`cookie`

**Effective date:** [À DÉCIDER]
**Version:** 2.0

**HAPPYN uses no advertising cookies, no analytics cookies, and no tracking
across other websites.** This is why you are not asked to accept cookies.

## What we do store

**In the app:** your session token, so you are not signed out every time you
close HAPPYN; your language preference; and your saved events. This lives on
your device.

**On the website:** the password reset page temporarily stores the reset token
in your browser's session storage so that reloading the page does not lose it.
It is erased when you close the tab, and as soon as your password is changed.

**Nothing else.** The website loads no third-party script and no external font.

---

# 8. Copyright Policy

`copyright`

**Effective date:** [À DÉCIDER]
**Version:** 2.0

## Publishing content

Publish only what you have the right to publish. Uploading someone else's photo,
poster, or artwork without permission infringes their copyright.

## Reporting an infringement

Write to contact@happynevents.com with:

1. a description of the work you own;
2. where the infringing content appears on HAPPYN;
3. your contact details;
4. a statement that you believe in good faith the use is unauthorized;
5. a statement that the information is accurate and that you are the owner or
   authorized to act for them.

We acknowledge within **3 business days** and act within **10**.

## Counter-notice

If your content was removed and you believe it was wrongly removed, tell us and
give the basis for your right to publish it. We will review and may restore it.

## Repeat infringement

Accounts that repeatedly infringe are suspended.

`[À DÉCIDER]` — Canada uses a **notice-and-notice** regime, which differs from
the American notice-and-takedown your lawyer may be more used to. The obligation
is to forward notices to the alleged infringer, not necessarily to remove
content. Have this section reviewed specifically.

---

# 9. Payments Policy

`payments`

**Effective date:** [À DÉCIDER]
**Version:** 2.0

## How payment works

Payments are processed by **Stripe**. Your card number, expiry, and security
code go directly to Stripe and **never reach HAPPYN's servers**. We store only
that a payment succeeded, and its amount.

The price you see is the price charged, in Canadian dollars, taxes included
where applicable.

## Sales tax — who charges it, and when

`[À DÉCIDER]` — **This must be settled with an accountant before a single real
ticket is sold for someone else.** It is not a wording question; it changes the
accounting, the Terms, and how Stripe Connect must be configured.

### The question underneath

Everything depends on **who the seller is**:

| Model | Consequence |
|---|---|
| HAPPYN sells, the organizer supplies | HAPPYN charges and remits tax on the whole ticket |
| The organizer sells, HAPPYN collects on their behalf | Each organizer is responsible for their own tax; HAPPYN owes tax only on its commission |

The second model is the intended one. But it has a practical trap: **today all
money lands in HAPPYN's own Stripe account**, which accounting-wise looks like
HAPPYN's revenue. Demonstrating that it is collected *for a third party*
requires a written agreement with the organizer and books that separate the
flows — which is a strong argument for building Stripe Connect properly, where
funds are attributed to the organizer's connected account from the moment they
are charged.

### Most organizers will charge no tax at all

This is the part people get wrong. An organizer who is **not registered** for
GST/HST — which will be the case for most small organizers, below the
small-supplier threshold — **charges no tax**. A $20 ticket costs $20.

An organizer who is registered must charge it. Both a tax-included price and a
price-plus-tax presentation are acceptable, **provided the total is clear before
payment**. What is not acceptable is a surprise at the end.

| Organizer | $20 ticket |
|---|---|
| Not registered | $20 |
| Registered | $20 tax included, **or** $20 + tax |

### What this means for the product

Organizer onboarding will eventually need to ask: *are you registered for
GST/HST, and what is your number?* — and the app must price accordingly. That is
what established ticketing platforms do.

None of this blocks today: HAPPYN is the only organizer and Stripe is in test
mode. It becomes blocking the day a third party sells here.

## When your ticket appears

Tickets are issued by our servers once Stripe confirms payment. This is usually
immediate. If it takes longer, the app tells you, and your ticket appears in
**My Tickets** as soon as confirmation arrives. **A charge without a ticket is
always corrected** — write to us.

## Who you are paying

You are paying for a ticket to an event run by its organizer. HAPPYN collects
the payment.

`[À DÉCIDER]` — **Payouts to organizers are not implemented.** Until they are,
HAPPYN receives the money for events it does not run. This is a legal exposure,
not just a missing feature: you would be holding funds for third parties without
a defined mechanism to remit them. Either restrict paid events to your own until
Stripe Connect is in place, or settle the arrangement in writing with each
organizer.

## Failed payments and duplicates

If you are charged and receive no ticket, write to contact@happynevents.com with
the date and amount. We investigate and refund duplicates.

---

# 10. Refund Policy

`refund`

**Effective date:** [À DÉCIDER]
**Version:** 2.0

## The organizer sets the terms

Each event's refund terms are the organizer's. HAPPYN does not impose a uniform
policy, and does not refund on the organizer's behalf except in the cases below.

## When you are entitled to a refund

**The event is cancelled.** Tickets are marked cancelled and buyers notified.
`[À DÉCIDER]` — Is a refund automatic, or must the buyer request it from the
organizer? Answer this before launch; it is the question people will ask most.

**You were charged twice for the same ticket.** Always refunded.

**You were charged and no ticket was issued.** Always refunded.

## When you are not

- You changed your mind, unless the organizer allows it.
- You did not attend.
- The event was not what you hoped, but took place as described.

## How to ask

For a cancelled or misdescribed event, contact the organizer first. If they do
not respond within 7 days, write to contact@happynevents.com.

`[À DÉCIDER]` — Consumer protection statutes give buyers rights that a policy
cannot remove. **Ontario's *Consumer Protection Act, 2002*** governs distance
contracts with Ontario consumers, including disclosure requirements before a
purchase and cancellation rights where those disclosures are missing.
**Quebec's Act** applies to your Gatineau buyers and is stricter in places. Have
this document reviewed as a priority: it is the one most likely to be tested,
and the one where the two provinces diverge most.

---

# 11. Fraud Prevention Policy

`fraud-prevention`

**Effective date:** [À DÉCIDER]
**Version:** 2.0

## How tickets are protected

- Tickets are **issued by our servers** after payment is confirmed. No client
  application can create a ticket.
- Each ticket displays a **cryptographically signed QR code that refreshes
  regularly**. A screenshot shows a code that expires — it will not admit
  anyone.
- A ticket can be **scanned once**. A second scan is refused.
- **Only the organizer of that event can scan its tickets.** The scanner refuses
  anyone else, server-side.
- Ticket records cannot be modified by any client application.

## Fraudulent events

Creating an event you do not intend to hold, or selling tickets for an event you
have no right to, is fraud. We remove such events, suspend the accounts, and
where money changed hands, cooperate with authorities.

## What you should do

- Buy tickets **through HAPPYN**, never from an individual claiming to have a
  spare. Use the in-app transfer feature instead — it reissues the ticket
  properly.
- HAPPYN will **never** ask for your password, your full card number, or a
  payment outside the app.
- Report suspicious events. Reports are reviewed within 24 hours.

---

# 12. Safety Policy

`safety`

**Effective date:** [À DÉCIDER]
**Version:** 2.0

## What HAPPYN does

- Reports are reviewed within 24 hours.
- Blocking removes an account's content and events from your view.
- Attendance is never public by default. Someone can see you are attending an
  event only if you follow each other **and** you chose to make that attendance
  visible.
- Organizers can set a minimum age; the app warns you when you are below it.

## What HAPPYN does not do

**We do not verify identity.** A profile name is not proof of who someone is.
We do not conduct background checks on organizers, and we do not inspect venues.

## Meeting people

Events involve meeting strangers. Meet in public where possible, tell someone
where you are going, and leave if you feel unsafe.

## If you are in danger

**Contact local emergency services first — call 911.** HAPPYN cannot intervene
in a physical emergency. Report to us afterwards so we can act on the account.

---

# 13. Organizer Standards

`organizer`

**Effective date:** [À DÉCIDER]
**Version:** 2.0

Creating events on HAPPYN requires you to be **18 or older**, and to accept
these standards.

## Your responsibilities

**Describe your event accurately.** Date, time, location, price, what is
included, and any age restriction. If something changes materially, update the
event — buyers are notified.

**You are responsible for the event itself.** Its legality, its safety, its
permits, its insurance, and its execution. HAPPYN provides ticketing; it does
not co-organize.

**Check age at the door** where you set an age requirement. HAPPYN warns buyers
who are below it, but does not verify identity.

**Honour your refund terms**, and respond to buyers within 7 days.

**Cancel properly.** Use the cancel function, which marks tickets cancelled and
notifies buyers. Do not simply stop responding.

## Private events

If your event is private, it never appears in Discover — it can only be reached
with your invitation code. You separately choose whether photos published about
it are visible to everyone or only to invitees. **Choose deliberately:** if
photos are public, your event's name and date become public with them.

## What we may do

We may unpublish events that violate these standards, and suspend organizers who
do so repeatedly or who defraud buyers.

## Payouts

`[À DÉCIDER]` — Not implemented. See the Payments Policy. Until it is, this
section must state honestly how and when an organizer receives their money, or
paid events must be restricted to HAPPYN's own.

---

# Ce qu'il reste à faire sur ce brouillon

1. **Trancher les `[À DÉCIDER]`** — onze au total. Les trois plus urgents :
   l'entité juridique, la taxe de vente, et le remboursement automatique ou non
   d'un événement annulé.
2. **Faire relire par un avocat** en droit des technologies, **admis en Ontario
   et à l'aise avec le droit québécois** — c'est la combinaison dont tu as
   besoin pour un marché Ottawa-Gatineau. Priorité : la double juridiction,
   puis Remboursement, Paiements, Confidentialité (transferts hors Canada), et
   l'escalade pour contenu illégal.
3. **Migration `locale`** sur `legal_documents`, puis **traduction française** —
   légalement requise pour les consommateurs québécois.
4. **Créer les deux nouveaux documents** : `content-moderation` et
   `account-deletion`.
5. **Fixer les dates d'entrée en vigueur** et passer les versions à 2.0.

Quand ces points seront réglés, j'écris les textes en base et le site les
affichera immédiatement — il les lit directement, sans redéploiement.
