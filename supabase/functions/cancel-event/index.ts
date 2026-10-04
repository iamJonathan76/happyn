// =============================================================================
// HAPPYN — Edge Function `cancel-event`
// =============================================================================
// Annule un événement À LA DEMANDE DE SON ORGANISATEUR, et rembourse tous les
// billets encore valides.
//
// Ce qui existait avant : l'app mettait `status = 'cancelled'` et s'arrêtait
// là. Les détenteurs recevaient une notification, leur bouton « se faire
// rembourser » était désactivé (`can_cancel_ticket` répond `event_cancelled`),
// et leur argent restait chez la plateforme jusqu'à un remboursement manuel
// dans Stripe, un par un. En Ontario, annuler un service payé oblige à
// rembourser : ce n'était pas tenable.
//
// ── L'ordre des opérations ───────────────────────────────────────────────────
//
//   1. On FERME d'abord l'événement. `create-payment-intent` refuse tout ce qui
//      n'est pas `published` : plus personne ne peut acheter pendant qu'on
//      rembourse. L'inverse laisserait quelqu'un payer un billet pour un
//      événement qu'on est en train d'annuler.
//   2. On rembourse ensuite, billet par billet.
//
// C'est l'ordre INVERSE de `cancel-ticket`, et pour une raison précise : là-bas
// un échec de Stripe doit laisser le billet valide (le client garde sa place).
// Ici l'événement n'aura pas lieu de toute façon — le fermer est vrai, et le
// laisser ouvert serait un mensonge.
//
// ── Reprise après échec ──────────────────────────────────────────────────────
// Chaque remboursement porte une clé d'idempotence dérivée du billet, et
// `cancel_ticket_for_event` ignore un billet déjà annulé. Rappeler la fonction
// reprend donc là où elle s'était arrêtée, sans jamais rembourser deux fois.
// Les échecs sont comptés et renvoyés : l'app doit le dire, pas l'avaler.
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

interface Refundable {
  ticket_id: string;
  payment_intent_id: string | null;
  amount: number | string | null;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const stripeKey = Deno.env.get("STRIPE_SECRET_KEY");
  const url = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  // 1. Qui appelle ? Client anon portant son jeton, comme partout ici.
  const authHeader = req.headers.get("Authorization") ?? "";
  const userClient = createClient(url, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData } = await userClient.auth.getUser();
  const caller = userData?.user;
  if (!caller) return json({ error: "not_authenticated" }, 401);

  let eventId: string;
  try {
    const body = await req.json();
    eventId = String(body.event_id ?? "");
  } catch (_) {
    return json({ error: "bad_request" }, 400);
  }
  if (!eventId) return json({ error: "bad_request" }, 400);

  const admin = createClient(url, serviceKey);

  // 2. Fermer. `cancel_event` vérifie elle-même que l'appelant est bien
  //    l'organisateur — ce n'est pas à cette fonction de l'affirmer.
  const { error: closeErr } = await admin.rpc("cancel_event", {
    p_event: eventId,
    p_actor: caller.id,
  });
  if (closeErr) {
    const msg = closeErr.message ?? "";
    if (msg.includes("not_organizer")) return json({ error: "not_organizer" }, 403);
    if (msg.includes("not_found")) return json({ error: "not_found" }, 404);
    // Deja verse : rembourser maintenant ferait payer HAPPYN deux fois, une
    // fois a l'organisateur et une fois aux acheteurs. L'app doit le dire,
    // pas reessayer.
    if (msg.includes("already_paid_out")) {
      return json({ error: "already_paid_out" }, 409);
    }
    console.error("cancel-event: fermeture impossible:", msg);
    return json({ error: "cancel_failed" }, 500);
  }

  // 3. Rembourser les billets encore valides.
  const { data: rows, error: listErr } = await admin.rpc(
    "event_tickets_to_refund",
    { p_event: eventId },
  );
  if (listErr) {
    console.error("cancel-event: liste des billets illisible:", listErr.message);
    // L'événement EST annulé : on le dit, et on signale que les
    // remboursements n'ont pas pu être lancés. Mentir ici serait pire.
    return json({ error: "refunds_not_started", cancelled: true }, 500);
  }

  const tickets = (rows ?? []) as Refundable[];
  let refunded = 0;
  let failed = 0;

  for (const ticket of tickets) {
    const amount = Number(ticket.amount ?? 0);
    let refundId: string | null = null;

    if (stripeKey && ticket.payment_intent_id && amount > 0) {
      const form = new URLSearchParams({
        payment_intent: ticket.payment_intent_id,
        // Montant du SEUL billet : un paiement couvre souvent plusieurs
        // billets, et d'autres peuvent déjà avoir été remboursés.
        amount: String(Math.round(amount * 100)),
        reason: "requested_by_customer",
      });

      try {
        const res = await fetch("https://api.stripe.com/v1/refunds", {
          method: "POST",
          headers: {
            Authorization: `Bearer ${stripeKey}`,
            "Content-Type": "application/x-www-form-urlencoded",
            // Dérivée du billet : un appel rejoué ne rembourse pas deux fois.
            "Idempotency-Key": `event-cancel-${ticket.ticket_id}`,
          },
          body: form.toString(),
        });
        const payload = await res.json().catch(() => null);
        if (!res.ok) {
          // Le message de Stripe, pas seulement le code : deux diagnostics de
          // ce projet ont été retardés faute de l'avoir journalisé.
          console.error(
            "cancel-event: remboursement refuse",
            ticket.ticket_id,
            res.status,
            payload?.error?.message ?? "",
          );
          failed++;
          continue; // Le billet reste valide : il sera repris au prochain appel.
        }
        refundId = payload?.id ?? null;
      } catch (e) {
        console.error("cancel-event: Stripe injoignable", String(e));
        failed++;
        continue;
      }
    }

    const { error: markErr } = await admin.rpc("cancel_ticket_for_event", {
      p_ticket: ticket.ticket_id,
      p_refund_id: refundId,
    });
    if (markErr) {
      // Cas le plus grave : l'argent est parti, la base l'ignore. Repasser
      // rembourserait... non : la clé d'idempotence protège, Stripe renverra
      // le même remboursement. C'est pourquoi elle dérive du billet.
      console.error(
        "cancel-event: REMBOURSE MAIS NON ANNULE —",
        ticket.ticket_id,
        refundId,
        markErr.message,
      );
      failed++;
      continue;
    }
    refunded++;
  }

  return json({
    ok: failed === 0,
    cancelled: true,
    tickets: tickets.length,
    refunded,
    failed,
  });
});
