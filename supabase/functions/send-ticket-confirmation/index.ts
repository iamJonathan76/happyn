// =============================================================================
// HAPPYN — Edge Function `send-ticket-confirmation`
// =============================================================================
// Envoie le courriel de confirmation d'un billet — GRATUIT comme PAYANT.
//
// Appelée par un déclencheur en base sur la notification `ticket_confirmed`
// (créée une seule fois par achat dans `issue_tickets` et `issue_tickets_paid`).
// Un seul endroit décide du courriel, quel que soit le mode d'émission.
//
// Protégée par un secret partagé (TICKET_HOOK_SECRET) comparé en temps constant,
// comme `send-push` et `notify-report` : la fonction n'est appelée que par la
// base, jamais par un utilisateur.
//
// Best-effort absolu : dès que le secret est bon, on répond 200 même si l'envoi
// échoue. L'appelant est un trigger ; une erreur ne doit jamais remonter
// jusqu'à l'émission du billet.
//
// Le QR d'entrée n'est PAS dans le courriel : il est minté et validé côté
// serveur, un QR figé par courriel serait rejouable. Le courriel confirme et
// renvoie vers l'app où vit le vrai billet.
// =============================================================================

import { createClient } from "jsr:@supabase/supabase-js@2";

const RESEND_ENDPOINT = "https://api.resend.com/emails";

function secretsMatch(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

function escapeHtml(input: unknown): string {
  return String(input ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("method_not_allowed", { status: 405 });
  }

  const expected = Deno.env.get("TICKET_HOOK_SECRET");
  if (!expected) return new Response("server_misconfigured", { status: 500 });
  const provided = req.headers.get("x-happyn-secret") ?? "";
  if (!secretsMatch(provided, expected)) {
    return new Response("forbidden", { status: 403 });
  }

  const apiKey = Deno.env.get("RESEND_API_KEY");
  if (!apiKey) {
    console.warn("send-ticket-confirmation: RESEND_API_KEY absente");
    return new Response("ok", { status: 200 });
  }

  let payload: { user_id?: string; event_id?: string; quantity?: number };
  try {
    payload = await req.json();
  } catch {
    return new Response("invalid_json", { status: 400 });
  }
  const buyerId = payload.user_id;
  if (!buyerId) return new Response("ok", { status: 200 });
  const qty = Number(payload.quantity) || 1;

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  try {
    const { data: userRes } = await admin.auth.admin.getUserById(buyerId);
    const email = userRes?.user?.email;
    if (!email) return new Response("ok", { status: 200 });

    const { data: prof } = await admin
      .from("profiles")
      .select("language, full_name")
      .eq("id", buyerId)
      .maybeSingle();
    const fr = (prof?.language ?? "en") === "fr";
    const firstName = String(prof?.full_name ?? "").trim().split(/\s+/)[0] ?? "";

    let title = "";
    let whenLabel = "";
    if (payload.event_id) {
      const { data: ev } = await admin
        .from("events")
        .select("title, start_date")
        .eq("id", payload.event_id)
        .maybeSingle();
      title = String(ev?.title ?? "");
      if (ev?.start_date) {
        // Date seule, pas l'heure : la fonction tourne en UTC et on n'a pas le
        // fuseau de l'evenement sous la main. L'heure exacte est dans l'app.
        whenLabel = new Date(String(ev.start_date)).toLocaleDateString(
          fr ? "fr-CA" : "en-CA",
          { weekday: "long", day: "numeric", month: "long", year: "numeric" },
        );
      }
    }

    const evName = title || (fr ? "ton événement" : "your event");

    const subject = fr
      ? `HAPPYN — ton billet pour ${evName}`
      : `HAPPYN — your ticket for ${evName}`;
    const hello = firstName
      ? `${fr ? "Salut" : "Hi"} ${escapeHtml(firstName)},`
      : (fr ? "Salut," : "Hi,");
    const line1 = fr
      ? `C'est confirmé. ${qty > 1 ? `Tes ${qty} billets` : "Ton billet"} pour <strong>${escapeHtml(evName)}</strong> ${qty > 1 ? "t'attendent" : "t'attend"} dans l'app.`
      : `You're all set. ${qty > 1 ? `Your ${qty} tickets` : "Your ticket"} for <strong>${escapeHtml(evName)}</strong> ${qty > 1 ? "are" : "is"} waiting in the app.`;
    const whenRow = whenLabel
      ? `<p style="margin:4px 0;color:#444"><strong>Date :</strong> ${escapeHtml(whenLabel)}</p>`
      : "";
    const cta = fr
      ? "Ton billet, avec le QR d'entrée, est dans HAPPYN → Mes billets."
      : "Your ticket, with the entry QR, is in HAPPYN → My Tickets.";
    const footer = fr
      ? "Tu reçois ce courriel parce qu'un billet a été émis sur HAPPYN."
      : "You're receiving this because a ticket was issued on HAPPYN.";

    const html = `
      <div style="font-family:system-ui,-apple-system,sans-serif;max-width:480px;margin:0 auto;color:#1a1535">
        <h2 style="color:#7C3AED;margin:0 0 12px">HAPPYN</h2>
        <p>${hello}</p>
        <p>${line1}</p>
        <div style="background:#f5f3ff;border-radius:12px;padding:16px;margin:16px 0">
          <p style="margin:0 0 8px;font-size:16px"><strong>${escapeHtml(evName)}</strong></p>
          ${whenRow}
          <p style="margin:4px 0;color:#444"><strong>${fr ? "Billets" : "Tickets"} :</strong> ${qty}</p>
        </div>
        <p style="color:#444">${cta}</p>
        <p style="color:#6b6280;font-size:12px;margin-top:24px">${footer}</p>
      </div>
    `;

    const res = await fetch(RESEND_ENDPOINT, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: "HAPPYN <no-reply@happynevents.com>",
        to: [email],
        subject,
        html,
      }),
    });
    if (!res.ok) {
      console.error("send-ticket-confirmation: resend a repondu", res.status);
    }
  } catch (e) {
    console.error("send-ticket-confirmation: echoue", String(e));
  }

  return new Response("ok", { status: 200 });
});
