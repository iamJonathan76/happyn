// =============================================================================
// HAPPYN — Edge Function `validate-ticket`
// =============================================================================
// Rôle : valider un QR scanné à l'entrée d'un événement. Utilisée par le futur
// écran scanner organisateur.
//
// Étapes :
//   1. Parse le payload `{ticket_id}.{exp}.{sig}` produit par `mint-qr`.
//   2. Recalcule le HMAC-SHA256 et compare (rejette tout payload forgé/altéré).
//   3. Rejette si expiré (QR de plus de 5 min).
//   4. Vérifie que l'appelant est l'organisateur de l'event (event.created_by).
//   5. Marque le ticket `used` de façon ATOMIQUE -> usage unique garanti.
//
// Réponses : { status: "admitted" | "already_used" | "expired"
//            | "invalid" | "not_authorized" | "not_found", ... }
// =============================================================================

import { createClient } from "jsr:@supabase/supabase-js@2";

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

// Comparaison à temps constant pour éviter les timing attacks sur la signature.
function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) {
    diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return diff === 0;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse({ status: "invalid", error: "method_not_allowed" }, 405);
  }

  const secret = Deno.env.get("TICKET_HMAC_SECRET");
  if (!secret) {
    return jsonResponse({ status: "invalid", error: "server_misconfigured" }, 500);
  }

  // --- Identifier l'appelant (l'organisateur qui scanne) -------------------
  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader) {
    return jsonResponse({ status: "not_authorized", error: "not_authenticated" }, 401);
  }

  const userClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );
  const { data: userData } = await userClient.auth.getUser();
  const caller = userData?.user;
  if (!caller) {
    return jsonResponse({ status: "not_authorized", error: "not_authenticated" }, 401);
  }

  // --- Parse et vérifie le payload -----------------------------------------
  let payload: string | undefined;
  try {
    const body = await req.json();
    payload = body?.qr_payload;
  } catch {
    return jsonResponse({ status: "invalid", error: "invalid_body" }, 400);
  }
  if (!payload || typeof payload !== "string") {
    return jsonResponse({ status: "invalid", error: "missing_payload" }, 400);
  }

  const parts = payload.split(".");
  if (parts.length !== 3) {
    return jsonResponse({ status: "invalid", error: "malformed" }, 400);
  }
  const [ticketId, expStr, providedSig] = parts;

  // Vérifie la signature
  const expectedSig = await sign(`${ticketId}.${expStr}`, secret);
  if (!timingSafeEqual(expectedSig, providedSig)) {
    return jsonResponse({ status: "invalid", error: "bad_signature" }, 401);
  }

  // Vérifie l'expiration
  const exp = parseInt(expStr, 10);
  if (!Number.isFinite(exp) || Math.floor(Date.now() / 1000) > exp) {
    return jsonResponse({ status: "expired" }, 200);
  }

  // --- Vérifications métier avec le service role (bypass RLS) ---------------
  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data: ticket, error: lookupErr } = await admin
    .from("tickets")
    .select("id, status, event_id, events!inner(created_by, title)")
    .eq("id", ticketId)
    .maybeSingle();

  if (lookupErr) {
    return jsonResponse({ status: "invalid", error: "lookup_failed" }, 500);
  }
  if (!ticket) {
    return jsonResponse({ status: "not_found" }, 404);
  }

  // Seul l'organisateur (créateur de l'event) peut valider ses tickets.
  const event = ticket.events as unknown as { created_by: string; title: string };
  if (event.created_by !== caller.id) {
    return jsonResponse({ status: "not_authorized", error: "not_organizer" }, 403);
  }

  // --- Marquage atomique : ne passe que si encore `valid` ------------------
  const { data: updated, error: updErr } = await admin
    .from("tickets")
    .update({ status: "used", used_at: new Date().toISOString() })
    .eq("id", ticketId)
    .eq("status", "valid")
    .select("id")
    .maybeSingle();

  if (updErr) {
    return jsonResponse({ status: "invalid", error: "update_failed" }, 500);
  }
  if (!updated) {
    // La ligne existait mais n'était plus `valid` -> déjà scannée (ou refunded).
    return jsonResponse({ status: "already_used" }, 200);
  }

  return jsonResponse({
    status: "admitted",
    ticket_id: ticketId,
    event_title: event.title,
  });
});
