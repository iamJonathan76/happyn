-- =============================================================================
-- HAPPYN — Documents légaux pilotés par la base (+ traçabilité du consentement)
-- =============================================================================
-- But : pouvoir corriger un texte juridique SANS republier l'app (App Store /
-- Play Store). Le contenu est stocké en markdown léger (## titres, - puces,
-- paragraphes séparés par une ligne vide) et rendu côté app.
--
--   * legal_documents        : source de vérité des politiques (lecture publique)
--   * user_legal_acceptances : qui a accepté quelle version et quand (conformité
--                              PIPEDA / Loi 25 — preuve de consentement)
--
-- À exécuter dans le SQL Editor du dashboard Supabase.
-- =============================================================================

create table if not exists public.legal_documents (
  slug                text primary key,
  title               text not null,
  content             text not null,          -- markdown léger
  version             text not null,
  effective_date      date not null default current_date,
  requires_acceptance boolean not null default false,
  sort_order          int not null default 0,
  updated_at          timestamptz not null default now()
);

alter table public.legal_documents enable row level security;

-- Lecture publique (le légal doit être accessible même déconnecté)
drop policy if exists "legal readable by all" on public.legal_documents;
create policy "legal readable by all"
  on public.legal_documents for select
  to anon, authenticated
  using (true);
-- (Pas de policy d'écriture : édition via le dashboard / service role uniquement.)

-- ── Traçabilité du consentement ─────────────────────────────────────────────
create table if not exists public.user_legal_acceptances (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  slug        text not null,
  version     text not null,
  accepted_at timestamptz not null default now(),
  unique (user_id, slug, version)
);

alter table public.user_legal_acceptances enable row level security;

drop policy if exists "own acceptances select" on public.user_legal_acceptances;
create policy "own acceptances select"
  on public.user_legal_acceptances for select
  to authenticated using (auth.uid() = user_id);

drop policy if exists "own acceptances insert" on public.user_legal_acceptances;
create policy "own acceptances insert"
  on public.user_legal_acceptances for insert
  to authenticated with check (auth.uid() = user_id);

-- ── Seed du « Legal & Policy Handbook v1.1 » ────────────────────────────────
insert into public.legal_documents (slug, title, content, version, sort_order)
values
('terms', 'Terms of Service', $doc$Welcome to HAPPYN. By accessing or using HAPPYN, you agree to these Terms.

## 1. Eligibility
Users must be at least 14 years old. Some features are restricted by age, and organizing paid events or receiving payouts requires users to be 18 or older.

## 2. Minors
If you are under 18, you may browse, follow organizers, save events, and purchase a ticket only where the event allows it, and you confirm that a parent or legal guardian authorizes any purchase made through your account.

## 3. Accounts
Users are responsible for maintaining the security of their account credentials.

## 4. Platform Purpose
HAPPYN enables users to discover, create, promote, and attend events.

## 5. Prohibited Conduct
Fraudulent events, harassment, impersonation, illegal activity, spam, and abuse are prohibited.

## 6. Event Organizers
Organizers are responsible for the accuracy, legality, safety, and execution of their events, including verifying attendee age at the door where an event sets an age requirement.

## 7. Suspension and Termination
HAPPYN may suspend or terminate accounts that violate these Terms.

## 8. Limitation of Liability
HAPPYN is not responsible for losses, injuries, disputes, or damages resulting from attendance at events.

## 9. Modifications
HAPPYN may update these Terms at any time.$doc$, 'Version 1.1', 1),

('privacy', 'Privacy Policy', $doc$HAPPYN respects user privacy.

## Information collected may include:
- Name
- Email address
- Date of birth
- Profile photo
- City and location preferences
- Event activity and attendance history
- Device and usage information

## We use this information to:
- Provide recommendations
- Confirm eligibility and apply age requirements
- Improve the platform
- Process registrations
- Send important notifications

We do not sell personal information.

Users may request access, correction, or deletion of their data.$doc$, 'Version 1.1', 2),

('community', 'Community Guidelines', $doc$Our goal is to maintain a safe and welcoming community.

## Users must:
- Respect others
- Provide accurate information
- Follow applicable laws

## Users may not:
- Harass or threaten others
- Post hateful content
- Create fake accounts
- Promote illegal activity
- Mislead attendees

Violations may result in warnings, suspensions, or permanent bans.$doc$, 'Version 1.1', 3),

('cookie', 'Cookie Policy', $doc$HAPPYN uses cookies and similar technologies to:
- Keep users signed in
- Remember preferences
- Improve performance
- Analyze platform usage

Users may disable cookies through their device or browser settings, although some features may not function properly.$doc$, 'Version 1.1', 4),

('copyright', 'Copyright Policy', $doc$All HAPPYN trademarks, branding, software, designs, and original content are protected by intellectual property laws.

Users retain ownership of content they upload but grant HAPPYN a non-exclusive license to display and distribute that content on the platform.

Copyright complaints may be submitted to HAPPYN support.$doc$, 'Version 1.1', 5),

('refund', 'Refund Policy', $doc$Refund policies are determined by event organizers.

If an event is cancelled, attendees may be eligible for refunds according to the organizer's policy and applicable law.

Platform service fees may be non-refundable unless otherwise required.$doc$, 'Version 1.1', 6),

('payments', 'Payments', $doc$HAPPYN processes payments through secure third-party payment providers.

Platform fees are non-refundable unless required by law.

Organizers are responsible for refund decisions according to their selected refund policy.

HAPPYN reserves the right to delay payouts when fraud is suspected.$doc$, 'Version 1.1', 7),

('fraud-prevention', 'Fraud Prevention', $doc$HAPPYN may temporarily suspend ticket sales or organizer payouts while investigating reports of fraud.

Accounts engaged in fraudulent activity may be permanently banned.$doc$, 'Version 1.1', 8),

('safety', 'Safety Policy', $doc$Users should exercise good judgment when attending events.

## HAPPYN encourages users to:
- Meet in safe environments
- Follow venue rules
- Report suspicious activity

Emergency situations should be reported directly to local authorities.$doc$, 'Version 1.1', 9),

('organizer', 'Organizer Standards', $doc$## Organizers must:
- Provide accurate event information
- Honor ticket commitments
- Comply with local laws
- Respect attendee privacy
- Enforce any age requirement at the door

Repeated violations may result in organizer account removal.$doc$, 'Version 1.1', 10),

('data-retention', 'Data Retention', $doc$Deleted accounts may have certain information retained where required by law or for fraud prevention.

Retained data is limited to what is necessary and is removed once no longer required.$doc$, 'Version 1.1', 11)

on conflict (slug) do update
  set title      = excluded.title,
      content    = excluded.content,
      version    = excluded.version,
      sort_order = excluded.sort_order,
      updated_at = now();
