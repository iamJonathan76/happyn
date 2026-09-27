// =============================================================================
// HAPPYN — Edge Function `connect-onboard`
// =============================================================================
// Ouvre le formulaire Stripe qui permet à un organisateur de recevoir son
// argent, et rend le lien à l'app.
//
// Deux modes, une seule fonction parce qu'ils partagent tout le reste
// (authentification, recherche du compte, appels Stripe) :
//
//   mode = "onboarding" → lien vers le formulaire d'inscription (Account Link).
//   mode = "dashboard"  → lien vers le tableau de bord Express, pour changer de
//                         compte bancaire ou consulter ses virements.
//
// Les DEUX liens sont à usage unique et expirent en quelques minutes : c'est
// voulu côté Stripe, et c'est pourquoi on les génère à la demande au lieu de les
// stocker.
//
// ── Pourquoi `transfers` et pas `card_payments` ──────────────────────────────
// HAPPYN encaisse sur son propre compte puis vire à l'organisateur (« separate
// charges and transfers », cf. la migration `stripe_connect`). L'organisateur ne
// traite donc jamais de carte : il n'a besoin que de RECEVOIR. Demander
// `card_payments` en plus lui ferait remplir un dossier de marchand complet
// pour rien — et ferait échouer l'inscription de la plupart des particuliers.
//
// ── L'âge ────────────────────────────────────────────────────────────────────
// Le seuil de 18 ans pour recevoir des paiements n'est pas revérifié ici : la
// vérification d'identité de Stripe le fait pour de vrai, avec pièce à l'appui,
// et n'activera pas `transfers` pour un mineur. Le contrôle côté app reste utile
// pour éviter d'envoyer quelqu'un dans un formulaire qu'il ne passera pas.
// =============================================================================

import { createClient } from "jsr:@supabase/supabase-js@2";

const STRIPE_API = "https://api.stripe.com/v1";

// Le pays du compte détermine les pièces demandées et n'est pas modifiable
// ensuite. HAPPYN lance au Québec/Ontario : CA. À rendre paramétrable le jour
// où un organisateur hors Canada s'inscrit — pas avant, un choix par défaut
// silencieux serait pire qu'une limite explicite.
const ACCOUNT_COUNTRY = "CA";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}

async function stripe(
  key: string,
  path: string,
  form?: URLSearchParams,
  idempotencyKey?: string,
): Promise<{ ok: boolean; status: number; body: Record<string, unknown> }> {
  const headers: Record<string, string> = { Authorization: `Bearer ${key}` };
  if (form) headers["Content-Type"] = "application/x-www-form-urlencoded";
  if (idempotencyKey) headers["Idempotency-Key"] = idempotencyKey;

  const res = await fetch(`${STRIPE_API}${path}`, {
    method: form ? "POST" : "GET",
    headers,
    body: form?.toString(),
  });
  return { ok: res.ok, status: res.status, body: await res.json() };
}

/// Traduit la réponse Stripe en l'état qu'on garde en base.
///
/// `capabilities.transfers === "active"` est le seul signal qui autorise un
/// virement. `details_submitted` dit seulement que le formulaire a été envoyé —
/// la vérification peut encore échouer après, et se fier à lui reviendrait à
/// promettre un versement impossible.
function accountState(account: Record<string, unknown>) {
  const capabilities = (account.capabilities ?? {}) as Record<string, string>;
  const requirements = (account.requirements ?? {}) as Record<string, unknown>;
  return {
    transfers_enabled: capabilities.transfers === "active",
    payouts_enabled: account.payouts_enabled === true,
    details_submitted: account.details_submitted === true,
    disabled_reason: (requirements.disabled_reason as string | null) ?? null,
    updated_at: new Date().toISOString(),
  };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const stripeKey = Deno.env.get("STRIPE_SECRET_KEY");
  const url = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  if (!stripeKey) return json({ error: "not_configured" }, 500);

  // Stripe exige des URL https et les refuse en localhost. Ce sont des pages
  // web ordinaires : l'organisateur y arrive dans son navigateur, puis revient
  // à l'app, qui rafraîchit l'état au premier plan (`connect-refresh`).
  const returnUrl = Deno.env.get("CONNECT_RETURN_URL") ??
    "https://happynevents.com/connect-return.html";
  const refreshUrl = Deno.env.get("CONNECT_REFRESH_URL") ??
    "https://happynevents.com/connect-refresh.html";

  // ── Qui appelle ? ─────────────────────────────────────────────────────────
  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader) return json({ error: "not_authenticated" }, 401);

  const userClient = createClient(url, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData } = await userClient.auth.getUser();
  const caller = userData?.user;
  if (!caller) return json({ error: "not_authenticated" }, 401);

  let mode = "onboarding";
  try {
    const body = await req.json();
    if (body?.mode === "dashboard") mode = "dashboard";
  } catch (_) {
    // Corps absent ou illisible : on reste sur l'inscription, qui est le cas
    // d'usage de loin le plus fréquent.
  }

  const admin = createClient(url, serviceKey);

  // Un compte suspendu ne doit pas pouvoir se brancher un moyen d'encaisser.
  const { data: profile } = await admin
    .from("profiles")
    .select("is_suspended")
    .eq("id", caller.id)
    .maybeSingle();
  if (profile?.is_suspended === true) {
    return json({ error: "suspended" }, 403);
  }

  // ── Le compte connecté ────────────────────────────────────────────────────
  const { data: existing } = await admin
    .from("stripe_accounts")
    .select("account_id")
    .eq("user_id", caller.id)
    .maybeSingle();

  let accountId = existing?.account_id as string | undefined;

  if (!accountId) {
    if (mode === "dashboard") {
      // Pas de compte : il n'y a pas de tableau de bord à ouvrir. L'app doit
      // proposer l'inscription, pas afficher une erreur technique.
      return json({ error: "no_account" }, 409);
    }

    const form = new URLSearchParams();
    form.append("type", "express");
    form.append("country", ACCOUNT_COUNTRY);
    if (caller.email) form.append("email", caller.email);
    form.append("capabilities[transfers][requested]", "true");
    form.append(
      "business_profile[product_description]",
      "Vente de billets d'evenements via HAPPYN",
    );
    // Permet de retrouver l'utilisateur depuis le tableau de bord Stripe quand
    // un virement pose question.
    form.append("metadata[user_id]", caller.id);

    // Clé d'idempotence liée à l'utilisateur : deux appuis sur le bouton ne
    // créent pas deux comptes Stripe. Sans elle, le doublon serait invisible
    // (la contrainte en base arrive trop tard, le compte existe déjà chez
    // Stripe) et impossible à supprimer proprement.
    const created = await stripe(
      stripeKey,
      "/accounts",
      form,
      `connect-account-${caller.id}`,
    );
    if (!created.ok) {
      console.error(
        "connect-onboard: creation refusee",
        created.status,
        (created.body as { error?: { code?: string } })?.error?.code,
      );
      return json({ error: "stripe_error" }, 502);
    }

    const newId = created.body.id as string;
    const state = accountState(created.body);

    // `ignoreDuplicates` : si un appel concurrent a déjà posé la ligne, c'est
    // SON compte qui fait foi. On relit ensuite plutôt que de supposer.
    const { error: insertErr } = await admin
      .from("stripe_accounts")
      .upsert({ user_id: caller.id, account_id: newId, ...state },
        { onConflict: "user_id", ignoreDuplicates: true });
    if (insertErr) {
      console.error("connect-onboard: ecriture echouee", insertErr.message);
      return json({ error: "save_failed" }, 500);
    }

    const { data: row } = await admin
      .from("stripe_accounts")
      .select("account_id")
      .eq("user_id", caller.id)
      .maybeSingle();
    accountId = (row?.account_id as string | undefined) ?? newId;

    if (accountId !== newId) {
      // Un compte Stripe orphelin vient d'être créé. Sans conséquence pour
      // l'organisateur, mais à nettoyer à la main : un compte vide dans le
      // tableau de bord finit par brouiller la lecture des vrais.
      console.warn(
        "connect-onboard: compte orphelin", newId,
        "— la ligne portait deja", accountId,
      );
    }
  }

  // ── Le lien ───────────────────────────────────────────────────────────────
  if (mode === "dashboard") {
    const link = await stripe(stripeKey, `/accounts/${accountId}/login_links`, new URLSearchParams());
    if (!link.ok) {
      console.error("connect-onboard: login_link refuse", link.status);
      return json({ error: "stripe_error" }, 502);
    }
    return json({ url: link.body.url, account_id: accountId });
  }

  const linkForm = new URLSearchParams();
  linkForm.append("account", accountId!);
  // `refresh_url` est appelée par Stripe quand le lien a expiré avant que la
  // personne ne l'ouvre. La page doit simplement la renvoyer vers l'app, qui
  // redemandera un lien frais.
  linkForm.append("refresh_url", refreshUrl);
  linkForm.append("return_url", returnUrl);
  linkForm.append("type", "account_onboarding");

  const link = await stripe(stripeKey, "/account_links", linkForm);
  if (!link.ok) {
    console.error(
      "connect-onboard: account_link refuse",
      link.status,
      (link.body as { error?: { code?: string } })?.error?.code,
    );
    return json({ error: "stripe_error" }, 502);
  }

  return json({ url: link.body.url, account_id: accountId });
});
