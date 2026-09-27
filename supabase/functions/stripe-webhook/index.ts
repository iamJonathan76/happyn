// =============================================================================
// HAPPYN — Edge Function `stripe-webhook`
// =============================================================================
// Reçoit les événements Stripe et tient le registre des paiements à jour.
//
//   payment_intent.succeeded → enregistre le paiement, PUIS émet les billets
//   charge.refunded          → note le montant remboursé
//   charge.dispute.created   → neutralise le paiement (argent retiré du solde)
//   charge.dispute.closed    → le rétablit si la contestation est gagnée
//
// ── Pourquoi enregistrer AVANT d'émettre ─────────────────────────────────────
// L'ordre inverse semblait plus logique — pas de trace sans billet. Mais c'est
// précisément le cas « il a payé et n'a pas de billet » qu'on veut voir : si
// l'émission échoue, une ligne de registre sans billet le signale. Dans l'autre
// ordre, un échec d'émission ne laisserait rien du tout, et il faudrait
// découvrir le problème par le message du client.
//
// SÉCURITÉ : vérifie la signature Stripe (STRIPE_WEBHOOK_SECRET) sur le corps
// BRUT avant de faire confiance à l'événement.
//
// ⚠️ Cette fonction NE doit PAS exiger de JWT (Stripe n'en envoie pas).
//    Déployer avec --no-verify-jwt (et verify_jwt = false dans config.toml).
// =============================================================================

import { createClient } from "jsr:@supabase/supabase-js@2";

const encoder = new TextEncoder();

// Vérifie la signature Stripe (schéma t=...,v1=...) sur le corps brut.
async function verifyStripeSignature(
  payload: string,
  sigHeader: string,
  secret: string,
): Promise<boolean> {
  const parts = Object.fromEntries(
    sigHeader.split(",").map((kv) => kv.split("=") as [string, string]),
  );
  const timestamp = parts["t"];
  const v1 = parts["v1"];
  if (!timestamp || !v1) return false;

  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sigBuf = await crypto.subtle.sign(
    "HMAC",
    key,
    encoder.encode(`${timestamp}.${payload}`),
  );
  const expected = Array.from(new Uint8Array(sigBuf))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");

  // Comparaison à temps constant
  if (expected.length !== v1.length) return false;
  let diff = 0;
  for (let i = 0; i < expected.length; i++) {
    diff |= expected.charCodeAt(i) ^ v1.charCodeAt(i);
  }
  return diff === 0;
}

/// Frais réellement prélevés par Stripe sur ce paiement, en cents.
///
/// Lus sur la `balance_transaction` du paiement plutôt qu'estimés à
/// « 2,9 % + 0,30 $ » : le barème réel varie (carte étrangère, Amex, carte
/// commerciale), et une estimation créerait un écart permanent entre ce que
/// l'organisateur voit et ce qui a été encaissé.
///
/// Renvoie `null` si l'information n'est pas encore disponible. Le registre
/// l'accepte, et le calcul compte alors 0 : c'est HAPPYN qui absorbe ces frais,
/// jamais l'organisateur qui se voit débiter un montant inventé.
async function stripeFeeCents(
  stripeKey: string,
  chargeId: string,
): Promise<number | null> {
  try {
    const res = await fetch(
      `https://api.stripe.com/v1/charges/${chargeId}?expand[]=balance_transaction`,
      { headers: { Authorization: `Bearer ${stripeKey}` } },
    );
    if (!res.ok) {
      console.error("stripe-webhook: lecture de la charge refusee", res.status);
      return null;
    }
    const charge = await res.json();
    const bt = charge?.balance_transaction;
    if (bt && typeof bt === "object" && typeof bt.fee === "number") {
      return bt.fee as number;
    }
    console.warn(
      "stripe-webhook: frais indisponibles pour la charge", chargeId,
      "— comptes a 0, a la charge de la plateforme",
    );
    return null;
  } catch (e) {
    console.error("stripe-webhook: frais illisibles", String(e));
    return null;
  }
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("method_not_allowed", { status: 405 });
  }

  const secret = Deno.env.get("STRIPE_WEBHOOK_SECRET");
  if (!secret) return new Response("server_misconfigured", { status: 500 });
  const stripeKey = Deno.env.get("STRIPE_SECRET_KEY");

  const sigHeader = req.headers.get("stripe-signature") ?? "";
  const rawBody = await req.text();

  const valid = await verifyStripeSignature(rawBody, sigHeader, secret);
  if (!valid) {
    return new Response("invalid_signature", { status: 400 });
  }

  let event: { type: string; data: { object: Record<string, unknown> } };
  try {
    event = JSON.parse(rawBody);
  } catch {
    return new Response("invalid_json", { status: 400 });
  }

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // ── Paiement réussi ───────────────────────────────────────────────────────
  if (event.type === "payment_intent.succeeded") {
    const pi = event.data.object as {
      id: string;
      amount?: number;
      latest_charge?: string | { id?: string };
      metadata?: Record<string, string>;
    };
    const meta = pi.metadata ?? {};
    const ticketTypeId = meta.ticket_type_id;
    const quantity = parseInt(meta.quantity ?? "1", 10);
    const userId = meta.user_id;

    if (!ticketTypeId || !userId) {
      // Un PaymentIntent sans nos metadata ne vient pas de l'app (test manuel
      // depuis le tableau de bord Stripe, par exemple). Rien à faire.
      return new Response("ok", { status: 200 });
    }

    // ── 1. Le registre ──────────────────────────────────────────────────────
    //
    // `event_id` et `organizer_id` viennent des metadata posées par
    // `create-payment-intent`. Un paiement d'avant cette version ne les a pas :
    // on le laisse passer sans l'enregistrer plutôt que de bloquer l'émission
    // du billet, qui est ce qui compte pour l'acheteur.
    const eventId = meta.event_id;
    const organizerId = meta.organizer_id;
    if (eventId && organizerId) {
      const chargeId = typeof pi.latest_charge === "string"
        ? pi.latest_charge
        : pi.latest_charge?.id;

      const feeCents = (stripeKey && chargeId)
        ? await stripeFeeCents(stripeKey, chargeId)
        : null;

      const { error: ledgerErr } = await admin.rpc("record_payment", {
        p_payment_intent_id: pi.id,
        p_event_id: eventId,
        p_organizer_id: organizerId,
        p_buyer_id: userId,
        p_ticket_type_id: ticketTypeId,
        p_quantity: quantity,
        p_gross_cents: pi.amount ?? 0,
        p_stripe_fee_cents: feeCents,
        p_platform_fee_bps: parseInt(meta.platform_fee_bps ?? "0", 10),
      });
      if (ledgerErr) {
        // 500 => Stripe rejoue. `record_payment` est idempotente, donc rejouer
        // est sans danger, et perdre une ligne de registre ne l'est pas.
        console.error("record_payment:", ledgerErr.message);
        return new Response("ledger_failed", { status: 500 });
      }
    } else {
      console.warn(
        "stripe-webhook: paiement sans event_id/organizer_id —", pi.id,
        "absent du registre",
      );
    }

    // ── 2. Les billets ──────────────────────────────────────────────────────
    const { error } = await admin.rpc("issue_tickets_paid", {
      p_ticket_type_id: ticketTypeId,
      p_quantity: quantity,
      p_user_id: userId,
      p_payment_intent_id: pi.id,
    });
    if (error) {
      // 500 => Stripe rejouera le webhook (l'émission est idempotente)
      console.error("issue_tickets_paid failed:", error.message);
      return new Response("issuance_failed", { status: 500 });
    }

    return new Response("ok", { status: 200 });
  }

  // ── Remboursement ─────────────────────────────────────────────────────────
  //
  // Émis pour un remboursement partiel comme total. `amount_refunded` est le
  // cumul depuis le début, ce qui rend le traitement naturellement idempotent :
  // on pose une valeur absolue, on n'additionne pas.
  if (event.type === "charge.refunded") {
    const charge = event.data.object as {
      payment_intent?: string;
      amount_refunded?: number;
    };
    if (charge.payment_intent) {
      const { error } = await admin.rpc("record_refund", {
        p_payment_intent_id: charge.payment_intent,
        p_refunded_cents: charge.amount_refunded ?? 0,
      });
      if (error) {
        console.error("record_refund:", error.message);
        return new Response("ledger_failed", { status: 500 });
      }
    }
    return new Response("ok", { status: 200 });
  }

  // ── Contestation de carte ─────────────────────────────────────────────────
  //
  // Dès l'ouverture, Stripe retire le montant du solde de la plateforme, avant
  // tout examen. Le paiement est donc neutralisé immédiatement : sans ça, le
  // versement à l'organisateur partirait d'un argent déjà reparti chez la
  // banque de l'acheteur, et HAPPYN paierait deux fois.
  //
  // Journalisé en `error` volontairement : une contestation demande une réponse
  // humaine dans un délai court (généralement 7 à 21 jours), et un `log` se
  // perdrait dans le flux.
  if (event.type === "charge.dispute.created") {
    const dispute = event.data.object as {
      id?: string;
      payment_intent?: string;
      amount?: number;
      reason?: string;
    };
    console.error(
      "CONTESTATION OUVERTE — litige", dispute.id,
      "paiement", dispute.payment_intent,
      "montant", dispute.amount,
      "motif", dispute.reason,
      "— repondre depuis le tableau de bord Stripe avant l'echeance",
    );
    if (dispute.payment_intent) {
      const { error } = await admin.rpc("record_dispute", {
        p_payment_intent_id: dispute.payment_intent,
        p_open: true,
      });
      if (error) {
        console.error("record_dispute:", error.message);
        return new Response("ledger_failed", { status: 500 });
      }
    }
    return new Response("ok", { status: 200 });
  }

  // Contestation tranchée. Gagnée, l'argent revient et le paiement redevient
  // normal. Perdue, il est parti pour de bon : on laisse le paiement neutralisé,
  // sinon il serait versé à l'organisateur alors qu'il n'existe plus.
  if (event.type === "charge.dispute.closed") {
    const dispute = event.data.object as {
      payment_intent?: string;
      status?: string;
    };
    const won = dispute.status === "won";
    console.error(
      "CONTESTATION CLOSE — paiement", dispute.payment_intent,
      "resultat", dispute.status,
    );
    if (dispute.payment_intent && won) {
      const { error } = await admin.rpc("record_dispute", {
        p_payment_intent_id: dispute.payment_intent,
        p_open: false,
      });
      if (error) {
        console.error("record_dispute:", error.message);
        return new Response("ledger_failed", { status: 500 });
      }
    }
    return new Response("ok", { status: 200 });
  }

  // Toujours 200 pour les événements qu'on ne traite pas (sinon Stripe réessaie).
  return new Response("ok", { status: 200 });
});
