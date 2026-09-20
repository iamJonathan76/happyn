// =============================================================================
// HAPPYN — Edge Function `notify-report`
// =============================================================================
// Prévient l'équipe qu'un signalement vient d'arriver.
//
// Sans elle, la file de modération existe mais il faut penser à l'ouvrir — ce
// qui tient mal la contrainte des 24 h d'Apple (guideline 1.2). Un signalement
// déposé un vendredi soir attendrait le lundi.
//
// Appelée par un Database Webhook sur INSERT dans `public.reports`
// (configuration côté tableau de bord, voir docs/SECURITY.md § 3 bis).
//
// ⚠️ Comme `stripe-webhook`, cette fonction N'EXIGE PAS de JWT : l'appelant est
//    la base, pas un utilisateur. Elle est donc protégée par un secret partagé
//    (`REPORT_HOOK_SECRET`) comparé en temps constant. Sans lui, n'importe qui
//    connaissant l'URL pourrait déclencher des envois — donc épuiser le quota
//    de courriels et noyer la vraie alerte au milieu du bruit.
//    Déployer avec --no-verify-jwt.
// =============================================================================

const RESEND_ENDPOINT = "https://api.resend.com/emails";

/// Comparaison en temps constant : une comparaison naïve (`a === b`) s'arrête
/// au premier caractère différent, et le temps de réponse laisse deviner le
/// secret caractère par caractère.
function secretsMatch(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

function escapeHtml(value: unknown): string {
  return String(value ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response("method_not_allowed", { status: 405 });
  }

  const expected = Deno.env.get("REPORT_HOOK_SECRET");
  const apiKey = Deno.env.get("RESEND_API_KEY");
  const to = Deno.env.get("MODERATION_EMAIL");

  if (!expected || !apiKey || !to) {
    console.error("notify-report: configuration incomplete");
    return new Response("not_configured", { status: 500 });
  }

  const provided = req.headers.get("x-happyn-secret") ?? "";
  if (!secretsMatch(provided, expected)) {
    return new Response("forbidden", { status: 403 });
  }

  let record: Record<string, unknown>;
  try {
    const body = await req.json();
    // Un Database Webhook enveloppe la ligne dans `record`. On accepte aussi un
    // corps direct, ce qui rend la fonction testable à la main.
    record = (body.record ?? body) as Record<string, unknown>;
  } catch (_) {
    return new Response("bad_request", { status: 400 });
  }

  const targetType = escapeHtml(record.target_type);
  const reason = escapeHtml(record.reason);
  // Le nom de la cible, posé par trigger sur la ligne elle-même (migration
  // `report_context`). Un webhook de base transmet la ligne sans jointure : la
  // seule autre façon de nommer l'événement serait de donner une clé de
  // service à cette fonction, donc de lui ouvrir toute la base pour afficher
  // un titre.
  //
  // Tronqué : un titre à rallonge ne doit pas noyer le motif juste en dessous.
  const targetLabel = escapeHtml(
    String(record.target_label ?? "").slice(0, 120),
  );
  // Le détail est saisi par un utilisateur : il est échappé avant d'entrer dans
  // le HTML du courriel, et tronqué pour qu'un pavé ne rende pas l'alerte
  // illisible. Le texte complet reste dans la file de modération.
  const rawDetails = String(record.details ?? "").slice(0, 500);
  const details = escapeHtml(rawDetails);

  // Le sujet porte le nom de la cible : c'est la seule ligne visible depuis la
  // liste des courriels, et c'est elle qui permet de trier l'urgent du reste
  // sans ouvrir. « signalement (event) » ne le permettait pas.
  const subject = targetLabel
    ? `HAPPYN — signalement : ${targetLabel}`
    : `HAPPYN — signalement (${targetType})`;

  const html = `
    <h2>Nouveau signalement</h2>
    <p><strong>Type :</strong> ${targetType}</p>
    ${targetLabel ? `<p><strong>Cible :</strong> ${targetLabel}</p>` : ""}
    <p><strong>Motif :</strong> ${reason}</p>
    ${details ? `<p><strong>Détails :</strong> ${details}</p>` : ""}
    <p>Ouvre HAPPYN → Réglages → Modération pour le traiter.</p>
    <p style="color:#6b6280;font-size:12px">
      Rappel : Apple attend une modération effective sous 24 h.
    </p>
  `;

  const response = await fetch(RESEND_ENDPOINT, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: "HAPPYN <no-reply@happynevents.com>",
      to: [to],
      subject,
      html,
    }),
  });

  if (!response.ok) {
    // On journalise sans renvoyer le détail à l'appelant : la réponse de Resend
    // peut contenir des éléments de configuration.
    console.error("notify-report: resend a repondu", response.status);
    return new Response("send_failed", { status: 502 });
  }

  return new Response("ok", { status: 200 });
});
