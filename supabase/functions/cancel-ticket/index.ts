// =============================================================================
// HAPPYN — Edge Function `cancel-ticket`
// =============================================================================
// Annule un billet à la demande de son détenteur, et rembourse s'il était payant.
//
// Pourquoi une fonction Edge et pas une simple RPC : le remboursement exige la
// clé secrète Stripe, qui ne doit jamais quitter le serveur. Et l'ordre compte —
// on rembourse D'ABORD, on annule ensuite. L'inverse laisserait un billet annulé
// et non remboursé si Stripe refusait, c'est-à-dire un client qui a perdu à la
// fois sa place et son argent.
//
// Schéma habituel du projet : on identifie l'appelant avec un client anon
// portant son jeton, PUIS seulement on passe en service_role.
//
// Remboursement PARTIEL : un `payment_intent_id` couvre souvent plusieurs
// billets (achat groupé). Rembourser l'intention entière rendrait l'argent des
// billets qu'on garde. On rembourse le montant du seul billet annulé.
// =============================================================================

import { createClient } from "jsr:@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const stripeKey = Deno.env.get("STRIPE_SECRET_KEY");
  const url = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  // 1. Qui appelle ?
  const authHeader = req.headers.get("Authorization") ?? "";
  const userClient = createClient(url, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData } = await userClient.auth.getUser();
  const caller = userData?.user;
  if (!caller) return json({ error: "not_authenticated" }, 401);

  let ticketId: string;
  try {
    const body = await req.json();
    ticketId = String(body.ticket_id ?? "");
  } catch (_) {
    return json({ error: "bad_request" }, 400);
  }
  if (!ticketId) return json({ error: "bad_request" }, 400);

  // 2. Le droit d'annuler est évalué par la base, pas ici. La fonction vérifie
  //    la propriété, le statut, l'événement et la fenêtre de l'organisateur.
  const { data: checkRows, error: checkErr } = await userClient
    .rpc("can_cancel_ticket", { p_ticket: ticketId });
  if (checkErr) {
    console.error("can_cancel_ticket:", checkErr.message);
    return json({ error: "check_failed" }, 500);
  }
  const check = Array.isArray(checkRows) ? checkRows[0] : checkRows;
  if (!check?.allowed) {
    return json({ error: check?.reason ?? "not_allowed" }, 403);
  }

  const admin = createClient(url, serviceKey);

  // 3. Le billet était-il payant ?
  const { data: ticket, error: ticketErr } = await admin
    .from("tickets")
    .select("id, payment_intent_id, user_id, status")
    .eq("id", ticketId)
    .maybeSingle();
  if (ticketErr || !ticket) return json({ error: "not_found" }, 404);
  if (ticket.user_id !== caller.id) return json({ error: "not_owner" }, 403);
  if (ticket.status !== "valid") return json({ error: "ticket_not_valid" }, 409);

  const amount = Number(check.amount ?? 0);
  let refundId: string | null = null;

  // 4. Rembourser AVANT d'annuler.
  if (ticket.payment_intent_id && amount > 0) {
    if (!stripeKey) {
      console.error("cancel-ticket: STRIPE_SECRET_KEY absente");
      return json({ error: "not_configured" }, 500);
    }

    const form = new URLSearchParams({
      payment_intent: ticket.payment_intent_id,
      // Stripe compte en cents. Math.round évite qu'un prix à 19,99 devienne
      // 1998 par imprécision des flottants.
      amount: String(Math.round(amount * 100)),
      reason: "requested_by_customer",
    });

    const res = await fetch("https://api.stripe.com/v1/refunds", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${stripeKey}`,
        "Content-Type": "application/x-www-form-urlencoded",
        // Deux appuis sur le bouton ne doivent pas rembourser deux fois.
        "Idempotency-Key": `cancel-${ticketId}`,
      },
      body: form,
    });

    const payload = await res.json();
    if (!res.ok) {
      console.error("stripe refund:", res.status, payload?.error?.code);
      // On n'annule PAS : mieux vaut un billet toujours valide qu'un client
      // sans place et sans argent.
      return json({ error: "refund_failed" }, 502);
    }
    refundId = payload.id ?? null;
  }

  // 5. Annuler et rendre la place.
  const { error: cancelErr } = await admin.rpc("cancel_ticket", {
    p_ticket: ticketId,
    p_actor: caller.id,
    p_refund_id: refundId,
  });
  if (cancelErr) {
    // Cas le plus délicat du flux : l'argent est rendu mais le billet reste
    // valide. On le journalise explicitement pour pouvoir le rattraper à la
    // main — c'est une incohérence à corriger, pas une erreur à ignorer.
    console.error(
      "REMBOURSE MAIS NON ANNULE — billet", ticketId,
      "remboursement", refundId, ":", cancelErr.message,
    );
    return json({ error: "cancel_failed", refunded: refundId !== null }, 500);
  }

  return json({ ok: true, refunded: refundId !== null, amount });
});
