// =============================================================================
// HAPPYN — Edge Function `stripe-webhook`
// =============================================================================
// Reçoit les événements Stripe. Sur `payment_intent.succeeded`, émet les
// tickets via la RPC `issue_tickets_paid` (service role, idempotente).
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

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("method_not_allowed", { status: 405 });
  }

  const secret = Deno.env.get("STRIPE_WEBHOOK_SECRET");
  if (!secret) return new Response("server_misconfigured", { status: 500 });

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

  if (event.type === "payment_intent.succeeded") {
    const pi = event.data.object as {
      id: string;
      metadata?: Record<string, string>;
    };
    const meta = pi.metadata ?? {};
    const ticketTypeId = meta.ticket_type_id;
    const quantity = parseInt(meta.quantity ?? "1", 10);
    const userId = meta.user_id;

    if (ticketTypeId && userId) {
      const admin = createClient(
        Deno.env.get("SUPABASE_URL")!,
        Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      );
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
    }
  }

  // Toujours 200 pour les événements qu'on ne traite pas (sinon Stripe réessaie).
  return new Response("ok", { status: 200 });
});
