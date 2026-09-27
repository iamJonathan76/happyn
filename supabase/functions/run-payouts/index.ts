// =============================================================================
// HAPPYN — Edge Function `run-payouts`
// =============================================================================
// Vire aux organisateurs ce qu'ils ont gagné, pour chaque événement terminé
// depuis plus que le délai de retenue (`public.payout_delay_days()`).
//
// Appelée par `pg_cron` une fois par jour, et déclenchable à la main pendant la
// mise au point. Elle n'a pas besoin d'être rapide : elle a besoin de ne jamais
// payer deux fois.
//
// ── Les trois protections contre le double paiement ──────────────────────────
//
//   1. `event_payouts.event_id` est UNIQUE. Deux exécutions simultanées ne
//      peuvent pas réserver le même événement ; la seconde n'obtient rien.
//   2. On RÉSERVE en base avant d'appeler Stripe. Si l'écriture échouait après
//      un virement réussi, l'organisateur serait repayé au tour suivant.
//   3. Clé d'idempotence Stripe dérivée de l'identifiant de réservation. Même un
//      appel rejoué après un timeout réseau ne crée qu'un seul virement.
//
// ── Ce qu'elle ne fait pas ───────────────────────────────────────────────────
// Elle ne fait pas confiance au miroir `stripe_accounts` : elle relit le compte
// chez Stripe avant chaque virement. Un compte bloqué entre-temps (pièce
// expirée, vérification échouée) ne doit pas recevoir d'argent qui resterait
// gelé — l'organisateur attendrait sans comprendre, et le rappeler serait
// impossible.
//
// ⚠️ Comme `stripe-webhook`, elle N'EXIGE PAS de JWT : l'appelant est un
//    planificateur, pas un utilisateur. Elle est protégée par un secret partagé
//    (`PAYOUT_HOOK_SECRET`) comparé en temps constant. C'est la fonction la plus
//    sensible du projet — elle déplace de l'argent.
//    Déployer avec --no-verify-jwt.
// =============================================================================

import { createClient } from "jsr:@supabase/supabase-js@2";

const CURRENCY = "cad";

// Plafond par exécution : une fonction Edge a un temps limite, et chaque
// versement coûte deux appels Stripe. Le reste part au tour suivant — rien n'est
// perdu, `events_due_for_payout()` les reproposera.
const MAX_PER_RUN = 25;

/// Comparaison en temps constant : une comparaison naïve s'arrête au premier
/// caractère différent, et le temps de réponse laisse deviner le secret.
function secretsMatch(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

interface DueEvent {
  event_id: string;
  event_title: string | null;
  organizer_id: string;
  account_id: string;
  gross_cents: number;
  refunded_cents: number;
  stripe_fee_cents: number;
  platform_fee_cents: number;
  net_cents: number;
}

/// Le compte est-il TOUJOURS en état de recevoir ?
async function accountCanReceive(
  stripeKey: string,
  accountId: string,
): Promise<boolean> {
  const res = await fetch(`https://api.stripe.com/v1/accounts/${accountId}`, {
    headers: { Authorization: `Bearer ${stripeKey}` },
  });
  if (!res.ok) {
    console.error("run-payouts: compte illisible", accountId, res.status);
    return false;
  }
  const account = await res.json();
  const transfers = account?.capabilities?.transfers === "active";
  const blocked = account?.requirements?.disabled_reason != null;
  return transfers && !blocked;
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response("method_not_allowed", { status: 405 });
  }

  const expected = Deno.env.get("PAYOUT_HOOK_SECRET");
  const stripeKey = Deno.env.get("STRIPE_SECRET_KEY");
  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!expected || !stripeKey || !url || !serviceKey) {
    console.error("run-payouts: configuration incomplete");
    return new Response("not_configured", { status: 500 });
  }

  const provided = req.headers.get("x-happyn-secret") ?? "";
  if (!secretsMatch(provided, expected)) {
    return new Response("forbidden", { status: 403 });
  }

  const admin = createClient(url, serviceKey);

  const { data: due, error: dueErr } = await admin.rpc("events_due_for_payout");
  if (dueErr) {
    console.error("events_due_for_payout:", dueErr.message);
    return new Response("query_failed", { status: 500 });
  }

  const events = (due as DueEvent[] ?? []).slice(0, MAX_PER_RUN);
  let paid = 0;
  let skipped = 0;
  let failed = 0;

  for (const ev of events) {
    // On relit le compte AVANT de réserver : si on réservait d'abord, un compte
    // bloqué laisserait une ligne `pending` qu'aucun tour suivant ne reprendrait
    // (l'`unique` empêche de la recréer). Ne rien réserver le laisse dans la
    // file, ce qui est le comportement voulu : il sera payé quand son compte
    // sera en règle.
    if (!(await accountCanReceive(stripeKey, ev.account_id))) {
      console.warn(
        "run-payouts: compte pas en etat de recevoir —", ev.account_id,
        "evenement", ev.event_id, "reporte",
      );
      skipped++;
      continue;
    }

    const { data: payoutId, error: claimErr } = await admin.rpc("claim_payout", {
      p_event_id: ev.event_id,
      p_organizer_id: ev.organizer_id,
      p_account_id: ev.account_id,
      p_gross_cents: ev.gross_cents,
      p_refunded_cents: ev.refunded_cents,
      p_stripe_fee_cents: ev.stripe_fee_cents,
      p_platform_fee_cents: ev.platform_fee_cents,
      p_net_cents: ev.net_cents,
    });
    if (claimErr) {
      console.error("claim_payout:", ev.event_id, claimErr.message);
      failed++;
      continue;
    }
    if (!payoutId) {
      // Réservé entre-temps par une autre exécution. Ce n'est pas une erreur,
      // c'est exactement ce que la contrainte doit produire.
      skipped++;
      continue;
    }

    // Net à zéro : tout remboursé, ou les frais ont mangé la recette. La ligne
    // a déjà été posée en `skipped` par `claim_payout` — elle garde la trace du
    // calcul, ce qui vaut mieux qu'un événement qui réapparaîtrait chaque jour
    // dans la file.
    if (ev.net_cents <= 0) {
      skipped++;
      continue;
    }

    const form = new URLSearchParams();
    form.append("amount", String(ev.net_cents));
    form.append("currency", CURRENCY);
    form.append("destination", ev.account_id);
    // Rattache le virement aux encaissements du même événement, posés par
    // `create-payment-intent`. C'est ce qui rend le rapprochement lisible dans
    // le tableau de bord Stripe.
    form.append("transfer_group", `event_${ev.event_id}`);
    form.append("metadata[event_id]", ev.event_id);
    form.append("metadata[payout_id]", String(payoutId));
    form.append(
      "description",
      `HAPPYN — ${(ev.event_title ?? "evenement").slice(0, 80)}`,
    );

    const res = await fetch("https://api.stripe.com/v1/transfers", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${stripeKey}`,
        "Content-Type": "application/x-www-form-urlencoded",
        // Dérivée de la réservation : un rejeu après timeout retombe sur le même
        // virement au lieu d'en créer un second.
        "Idempotency-Key": `payout-${payoutId}`,
      },
      body: form.toString(),
    });
    const body = await res.json();

    if (!res.ok) {
      const code = body?.error?.code ?? String(res.status);
      // `balance_insufficient` est le cas qu'on reverra : le solde de la
      // plateforme n'a pas encore les fonds disponibles. La ligne reste en
      // `failed` avec la raison, et c'est à reprendre à la main — un réessai
      // automatique sur un versement demande d'être sûr de ne pas doubler, et
      // ça se conçoit avec les vrais chiffres sous les yeux, pas d'avance.
      console.error(
        "run-payouts: virement refuse — evenement", ev.event_id,
        "montant", ev.net_cents, "motif", code,
      );
      await admin.rpc("settle_payout", {
        p_payout_id: payoutId,
        p_transfer_id: null,
        p_failure: String(code).slice(0, 200),
      });
      failed++;
      continue;
    }

    const { error: settleErr } = await admin.rpc("settle_payout", {
      p_payout_id: payoutId,
      p_transfer_id: body.id,
      p_failure: null,
    });
    if (settleErr) {
      // Virement PARTI, base pas à jour. La ligne reste `pending` avec son
      // identifiant de réservation : la clé d'idempotence `payout-<id>` protège
      // d'un second virement, mais l'écart doit être corrigé à la main.
      console.error(
        "VIRE MAIS NON ENREGISTRE — versement", payoutId,
        "virement", body.id, ":", settleErr.message,
      );
      failed++;
      continue;
    }

    paid++;
  }

  const summary = {
    considered: events.length,
    paid,
    skipped,
    failed,
    remaining: Math.max((due as DueEvent[] ?? []).length - events.length, 0),
  };
  console.log("run-payouts:", JSON.stringify(summary));
  return new Response(JSON.stringify(summary), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
