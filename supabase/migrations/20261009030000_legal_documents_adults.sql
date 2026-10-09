-- Textes légaux 1.1 : HAPPYN réservé aux 18 ans et plus.
--
-- Suit `20261009020000_adults_only`. Seuls les passages sur l'âge changent,
-- dans les conditions d'utilisation et la politique de confidentialité ; les
-- autres documents ne parlaient pas des 14-17 ans. Version 1.1 plutôt qu'une
-- correction silencieuse de la 1.0 : des comptes l'ont déjà acceptée, et une
-- acceptation doit porter sur le texte exact qui a été lu. Chacun ré-accepte
-- au prochain lancement ; les acceptations de la 1.0 restent, comme preuves.
--
-- `replace()` sur des passages exacts, puis vérification : si un passage avait
-- changé entre-temps, le remplacement ne ferait rien en silence — le bloc
-- final fait alors échouer la migration plutôt que de publier un texte à
-- moitié corrigé.
--
-- Après application :
--   node web/tools/sync-legal-fallback.mjs

update public.legal_documents
set content = replace(replace(replace(content,
    $t$- You need an account, and you must be at least 14. Organizing events requires being 18 or older.$t$,
    $t$- You need an account, and you must be 18 or older.$t$),
    $t$## 2. Minimum age
You must be at least 14 years old to create an account. Quebec's Law 25 requires a parent's consent to collect personal information from a child under 14, and HAPPYN has no parental consent process; HAPPYN is based in Ontario, but much of our community lives in Quebec, so this rule applies to everyone.
HAPPYN asks every new account for a date of birth, whatever the sign-in method. If the date shows you are under 14, the account is deleted immediately, along with the information received at sign-up.

## 3. If you are 14 to 17
- You can browse events, follow people, save events, post, comment, and send messages.
- You can buy a ticket only where the event allows your age, and only with the permission of a parent or legal guardian, who is responsible for that purchase.
- You cannot create events, sell tickets, or receive payouts.
$t$,
    $t$## 2. Minimum age
You must be at least 18 years old — the age of majority in Ontario and Quebec — to create an account and use HAPPYN.
HAPPYN asks every new account for a date of birth, whatever the sign-in method, and it cannot be changed afterwards. If the date shows you are under 18, the account is deleted immediately, along with the information received at sign-up.

## 3. Minors at events
A person under 18 cannot have a HAPPYN account. For an event open to all ages, a parent or legal guardian can buy the ticket on their own account and accompany the minor; they remain responsible for that ticket.
$t$),
    $t$Organizers can set a minimum age for their event: 14+, 16+, 18+ or 21+, or none.$t$,
    $t$Organizers can set a minimum age for their event: 18+ or 21+, or none (all ages).$t$),
    version = 'Version 1.1', effective_date = date '2026-10-09', updated_at = now()
where slug = 'terms';

update public.legal_documents
set content = replace(replace(content,
    $t$- Date of birth — required. Used to apply the minimum age of 14, event age limits, and the 18+ rule for organizers. Seen only by you.$t$,
    $t$- Date of birth — required, and cannot be changed afterwards. Used to apply the minimum age of 18 and event age limits. Seen only by you.$t$),
    $t$HAPPYN is not for anyone under 14. If we learn that an account belongs to a child under 14, we delete it and the information attached to it.$t$,
    $t$HAPPYN is only for adults, 18 and older. If we learn that an account belongs to someone under 18, we delete it and the information attached to it.$t$),
    version = 'Version 1.1', effective_date = date '2026-10-09', updated_at = now()
where slug = 'privacy';

do $$
begin
  if exists (select 1 from public.legal_documents where (slug = 'terms' and position($t$- You need an account, and you must be 18 or older.$t$ in content) = 0) or (slug = 'terms' and position($t$## 2. Minimum age
You must be at least 18 years old — the age of majority in Ontario and Quebec — to create an account and use HAPPYN.
HAPPYN asks every new account for a date of birth, whatever the sign-in method, and it cannot be changed afterwards. If the date shows you are under 18, the account is deleted immediately, along with the information received at sign-up.

## 3. Minors at events
A person under 18 cannot have a HAPPYN account. For an event open to all ages, a parent or legal guardian can buy the ticket on their own account and accompany the minor; they remain responsible for that ticket.
$t$ in content) = 0) or (slug = 'terms' and position($t$Organizers can set a minimum age for their event: 18+ or 21+, or none (all ages).$t$ in content) = 0) or (slug = 'privacy' and position($t$- Date of birth — required, and cannot be changed afterwards. Used to apply the minimum age of 18 and event age limits. Seen only by you.$t$ in content) = 0) or (slug = 'privacy' and position($t$HAPPYN is only for adults, 18 and older. If we learn that an account belongs to someone under 18, we delete it and the information attached to it.$t$ in content) = 0)) then
    raise exception 'textes 1.1 : un passage attendu est introuvable, rien n''est publie';
  end if;
  if exists (select 1 from public.legal_documents
             where slug in ('terms','privacy')
               and (content like '%under 14%' or content like '%at least 14%' or content like '%14 to 17%')) then
    raise exception 'textes 1.1 : il reste une mention de 14 ans';
  end if;
end $$;
