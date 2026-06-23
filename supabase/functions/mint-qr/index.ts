// =============================================================================
// HAPPYN — Edge Function `mint-qr`
// =============================================================================
// Rôle : émettre un payload QR signé, à courte durée de vie (5 min), pour un
// ticket que l'utilisateur appelant possède réellement.
//
// L'app rappelle cette fonction périodiquement (avant expiration) pour
// rafraîchir le QR affiché. Le secret HMAC (TICKET_HMAC_SECRET) ne quitte
// jamais le serveur, donc le client ne peut pas forger de payload valide.
//
// Format du payload renvoyé (et encodé dans le QR) :
//   {ticket_id}.{exp}.{sig}
//   - ticket_id : uuid du ticket
//   - exp       : timestamp d'expiration (epoch secondes)
//   - sig       : HMAC-SHA256( "{ticket_id}.{exp}" ) en hex
//
// La fonction `validate-ticket` (step 3) vérifiera sig + exp + usage unique.
// =============================================================================

import { createClient } from "jsr:@supabase/supabase-js@2";

const TTL_SECONDS = 5 * 60; // 5 minutes

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

// Signature HMAC-SHA256 -> hex
async function sign(data: string, secret: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sigBuf = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(data),
  );
  return Array.from(new Uint8Array(sigBuf))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }

  const secret = Deno.env.get("TICKET_HMAC_SECRET");
  if (!secret) {
    return jsonResponse({ error: "server_misconfigured" }, 500);
  }

  // Auth : on utilise le JWT de l'appelant pour que la RLS s'applique.
  // L'utilisateur ne pourra lire que SES propres tickets (policy SELECT).
  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader) {
    return jsonResponse({ error: "not_authenticated" }, 401);
  }

  let ticketId: string | undefined;
  try {
    const body = await req.json();
    ticketId = body?.ticket_id;
  } catch {
    return jsonResponse({ error: "invalid_body" }, 400);
  }
  if (!ticketId || typeof ticketId !== "string") {
    return jsonResponse({ error: "missing_ticket_id" }, 400);
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );

  // Grâce à la RLS, ceci ne renvoie le ticket que s'il appartient à l'appelant.
  const { data: ticket, error } = await supabase
    .from("tickets")
    .select("id, status")
    .eq("id", ticketId)
    .maybeSingle();

  if (error) {
    return jsonResponse({ error: "lookup_failed" }, 500);
  }
  if (!ticket) {
    // Soit le ticket n'existe pas, soit il n'appartient pas à l'utilisateur.
    return jsonResponse({ error: "ticket_not_found" }, 404);
  }
  if (ticket.status !== "valid") {
    return jsonResponse({ error: "ticket_not_valid", status: ticket.status }, 409);
  }

  const exp = Math.floor(Date.now() / 1000) + TTL_SECONDS;
  const payloadData = `${ticket.id}.${exp}`;
  const sig = await sign(payloadData, secret);
  const qrPayload = `${payloadData}.${sig}`;

  return jsonResponse({
    qr_payload: qrPayload,
    expires_at: exp,
    ttl_seconds: TTL_SECONDS,
  });
});
