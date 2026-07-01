// =============================================================================
// HAPPYN — Edge Function `create-payment-intent`
// =============================================================================
// Crée un PaymentIntent Stripe pour l'achat de billets.
// SÉCURITÉ : le montant est calculé ICI, côté serveur, à partir du prix réel du
// ticket_type en base — jamais envoyé par le client.
//
// Body attendu : { ticket_type_id: string, quantity: int }
// Réponse : { client_secret, payment_intent_id, amount, currency }
//
// Les metadata (ticket_type_id, quantity, user_id) sont attachées au
// PaymentIntent : le webhook s'en sert pour émettre les bons tickets.
// =============================================================================

import { createClient } from "jsr:@supabase/supabase-js@2";

const CURRENCY = "cad";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }

  const stripeKey = Deno.env.get("STRIPE_SECRET_KEY");
  if (!stripeKey) {
    return jsonResponse({ error: "server_misconfigured" }, 500);
  }

  // Authentifier l'appelant
  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader) return jsonResponse({ error: "not_authenticated" }, 401);

  const userClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );
  const { data: userData } = await userClient.auth.getUser();
  const user = userData?.user;
  if (!user) return jsonResponse({ error: "not_authenticated" }, 401);

  // Lire la requête
  let ticketTypeId: string | undefined;
  let quantity = 1;
  try {
    const body = await req.json();
    ticketTypeId = body?.ticket_type_id;
    quantity = parseInt(body?.quantity ?? 1, 10);
  } catch {
    return jsonResponse({ error: "invalid_body" }, 400);
  }
  if (!ticketTypeId) return jsonResponse({ error: "missing_ticket_type" }, 400);
  if (!Number.isFinite(quantity) || quantity < 1 || quantity > 10) {
    return jsonResponse({ error: "invalid_quantity" }, 400);
  }

  // Montant calculé côté serveur depuis le prix réel
  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  const { data: tt, error: ttErr } = await admin
    .from("ticket_types")
    .select("price, quantity_total, quantity_sold, max_per_order")
    .eq("id", ticketTypeId)
    .maybeSingle();

  if (ttErr || !tt) return jsonResponse({ error: "ticket_type_not_found" }, 404);

  const maxPerOrder = (tt.max_per_order ?? 10) as number;
  if (quantity > maxPerOrder) {
    return jsonResponse(
      { error: "exceeds_max_per_order", max: maxPerOrder },
      400,
    );
  }

  const remaining = (tt.quantity_total ?? 0) - (tt.quantity_sold ?? 0);
  if (remaining < quantity) {
    return jsonResponse({ error: "insufficient_stock" }, 409);
  }

  const unitPrice = Number(tt.price ?? 0);
  if (unitPrice <= 0) {
    // Event gratuit : pas de Stripe, l'app doit utiliser le flux `issue_tickets`.
    return jsonResponse({ error: "free_event_no_payment" }, 400);
  }

  const amount = Math.round(unitPrice * quantity * 100); // en cents

  // Créer le PaymentIntent via l'API REST Stripe
  const form = new URLSearchParams();
  form.append("amount", String(amount));
  form.append("currency", CURRENCY);
  form.append("automatic_payment_methods[enabled]", "true");
  form.append("metadata[ticket_type_id]", ticketTypeId);
  form.append("metadata[quantity]", String(quantity));
  form.append("metadata[user_id]", user.id);

  const stripeRes = await fetch("https://api.stripe.com/v1/payment_intents", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${stripeKey}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: form.toString(),
  });

  const pi = await stripeRes.json();
  if (!stripeRes.ok) {
    return jsonResponse(
      { error: "stripe_error", detail: pi?.error?.message },
      502,
    );
  }

  return jsonResponse({
    client_secret: pi.client_secret,
    payment_intent_id: pi.id,
    amount,
    currency: CURRENCY,
  });
});
