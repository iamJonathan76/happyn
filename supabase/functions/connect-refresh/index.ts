// =============================================================================
// HAPPYN — Edge Function `connect-refresh`
// =============================================================================
// Relit l'état du compte connecté chez Stripe et met à jour `stripe_accounts`.
//
// Pourquoi une fonction à part et pas un webhook `account.updated` : les deux se
// complètent, mais celle-ci répond à un besoin immédiat. Quand l'organisateur
// revient du formulaire Stripe, il s'attend à voir « c'est bon » tout de suite ;
// un webhook peut mettre quelques secondes, et l'écran afficherait encore
// « inscription à terminer » sur un compte déjà valide.
//
// Elle est donc appelée par l'app au retour du formulaire et à chaque ouverture
// de l'écran paiements. C'est un appel Stripe par ouverture d'écran, ce qui est
// acceptable : l'écran est rare, et une information fausse ici coûte plus cher
// qu'un appel réseau.
//
// ⚠️ Le miroir en base n'est jamais l'autorité. `run-payouts` relit Stripe avant
//    de virer quoi que ce soit — une ligne périmée ne doit pas pouvoir provoquer
//    un virement vers un compte entre-temps bloqué.
//
// `accountState` est recopié depuis `connect-onboard` au lieu d'être partagé
// dans `_shared/` : ces fonctions sont déployées une par une depuis le tableau
// de bord Supabase (pas de CLI sur le poste), et un import relatif casserait ce
// mode de déploiement. Si l'une des deux change, changer l'autre.
// =============================================================================

import { createClient } from "jsr:@supabase/supabase-js@2";

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

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader) return json({ error: "not_authenticated" }, 401);

  const userClient = createClient(url, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData } = await userClient.auth.getUser();
  const caller = userData?.user;
  if (!caller) return json({ error: "not_authenticated" }, 401);

  const admin = createClient(url, serviceKey);

  // On ne prend JAMAIS l'identifiant de compte dans le corps de la requête :
  // il servirait à lire l'état du compte de n'importe qui. Il vient de la ligne
  // de l'appelant, et de nulle part ailleurs.
  const { data: row } = await admin
    .from("stripe_accounts")
    .select("account_id")
    .eq("user_id", caller.id)
    .maybeSingle();

  const accountId = row?.account_id as string | undefined;
  if (!accountId) {
    // Jamais inscrit : ce n'est pas une erreur, c'est un état. L'app affiche
    // l'invitation à commencer.
    return json({ has_account: false });
  }

  const res = await fetch(`https://api.stripe.com/v1/accounts/${accountId}`, {
    headers: { Authorization: `Bearer ${stripeKey}` },
  });
  const account = await res.json();
  if (!res.ok) {
    console.error("connect-refresh: lecture refusee", res.status, account?.error?.code);
    return json({ error: "stripe_error" }, 502);
  }

  const state = accountState(account);
  const { error: updateErr } = await admin
    .from("stripe_accounts")
    .update(state)
    .eq("user_id", caller.id);
  if (updateErr) {
    console.error("connect-refresh: ecriture echouee", updateErr.message);
    return json({ error: "save_failed" }, 500);
  }

  return json({ has_account: true, ...state });
});
