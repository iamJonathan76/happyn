-- Completer les frais Stripe d'un paiement, quand Stripe les publie.
--
-- Constate sur la premiere vente reelle (2026-10-01) : au moment ou
-- `payment_intent.succeeded` nous parvient, la `balance_transaction` du
-- paiement n'existe pas encore. Les frais etaient donc enregistres a NULL,
-- comptes comme zero, et absorbes par la plateforme.
--
-- Consequence visible : l'ecran Versements promettait 14,25 $ a l'organisateur
-- la ou l'ecran de creation du tarif lui avait annonce 13,52 $. Deux ecrans qui
-- parlent du meme argent et ne disent pas le meme chiffre, c'est un litige.
--
-- Stripe renseigne la transaction de solde deux secondes plus tard et emet
-- `charge.updated`. C'est ce message qui appelle cette fonction.

create or replace function public.record_stripe_fee(
  p_payment_intent_id text,
  p_fee_cents         bigint
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_fee_cents is null or p_fee_cents < 0 then
    return;
  end if;

  update public.payments
     set stripe_fee_cents = p_fee_cents
   where payment_intent_id = p_payment_intent_id
     -- Seulement si le chiffre manque. `charge.updated` est emis a chaque
     -- modification de la charge — un remboursement, par exemple — et il ne
     -- doit jamais ecraser des frais deja etablis.
     and stripe_fee_cents is null;
end;
$$;

revoke all on function public.record_stripe_fee(text, bigint)
  from public, anon, authenticated;
grant execute on function public.record_stripe_fee(text, bigint) to service_role;

comment on function public.record_stripe_fee(text, bigint) is
  'Complete les frais Stripe d''un paiement une fois la balance_transaction '
  'disponible. Appelee par stripe-webhook sur charge.updated. N''ecrase '
  'jamais un montant deja enregistre.';
