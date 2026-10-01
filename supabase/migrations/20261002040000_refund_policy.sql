-- Politique de remboursement : dire ce que le code fait vraiment.
--
-- Le texte en ligne datait d'avant l'automatisation et la contredisait sur
-- trois points :
--
--   « Refund policies are determined by event organizers »  — ce n'est plus
--   vrai : l'annulation d'un evenement rembourse automatiquement, quel que
--   soit l'avis de l'organisateur. Lui ne regle que le delai au-dela duquel un
--   acheteur ne peut plus annuler de lui-meme.
--
--   « attendees MAY BE ELIGIBLE for refunds »  — « peut etre eligible » est
--   faux et inquietant : c'est automatique et integral.
--
--   « Platform service fees may be non-refundable »  — annonce une retenue
--   que le code ne fait pas. Un texte qui promet moins que la realite est
--   aussi grave qu'un texte qui promet plus : un acheteur peut s'y appuyer,
--   un examinateur d'App Store aussi.
--
-- Decision du 2026-10-02 : remboursement INTEGRAL dans les deux cas. Les
-- frais Stripe perdus sur un remboursement restent a la charge de la
-- plateforme. Au stade d'un lancement, un dollar perdu coute moins qu'un
-- acheteur mecontent — et une retenue d'un dollar declenche des contestations
-- bancaires a quinze.
--
-- Rejouable : le texte n'est remplace que s'il n'a pas deja ete pose.

update public.legal_documents
set
  content =
$policy$## When the organizer cancels an event

You are refunded in full, automatically. You don't have to ask, and the organizer cannot decide otherwise. The refund is sent to the card you paid with as soon as the event is cancelled.

Allow 5 to 10 business days for your bank to show it. HAPPYN releases the money immediately; the delay is on the banking side, not ours.

## When you cancel your own ticket

Each organizer sets a deadline — often 24 or 48 hours before the event starts, and some do not allow it at all. The deadline is shown on your ticket before you confirm.

Within that window, you are refunded in full. HAPPYN keeps nothing.

## Free tickets

There is nothing to refund. Cancelling simply returns your place to whoever wants it.

## What is never refunded

Nothing. HAPPYN does not keep a service fee on a refunded ticket.

## If something looks wrong

Write to us before contacting your bank. A dispute takes weeks and costs everyone; we can usually settle it the same day.$policy$,
  version = 'Version 1.2',
  effective_date = current_date,
  updated_at = now()
where slug = 'refund'
  and position('## When the organizer cancels an event' in content) = 0;

-- Le slug peut differer : on verifie ce qui a ete touche.
select slug, title, version, effective_date,
       position('## When the organizer cancels an event' in content) > 0 as updated
from public.legal_documents
where slug ilike '%refund%' or title ilike '%refund%';
