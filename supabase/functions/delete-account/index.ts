// =============================================================================
// HAPPYN — Edge Function `delete-account`
// =============================================================================
// Rôle : supprimer définitivement le compte de l'utilisateur appelant.
// Exigé par Apple (règle 5.1.1(v)) et Google Play pour toute app permettant de
// créer un compte.
//
// Découpage volontaire :
//   • la logique métier (billets, événements, anonymisation) vit dans la
//     fonction SQL `delete_my_account_data()` — transactionnelle et testable ;
//   • cette Edge Function orchestre ce que le SQL ne peut pas faire :
//     le nettoyage du Storage et la suppression du compte auth,
//     qui exigent tous deux la clé service_role.
//
// Ordre important : on détache les données AVANT de supprimer le compte auth,
// pour qu'aucune cascade n'emporte les lignes qu'on veut conserver
// (billets passés, événements passés).
//
// Réponses d'erreur métier :
//   has_paid_sales -> l'organisateur a des ventes payantes en cours ; il doit
//                     d'abord annuler/rembourser. (Inerte tant que Stripe est
//                     en mode test — c'est le point d'accroche du futur flux.)
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

/// Supprime tous les fichiers d'un dossier utilisateur dans un bucket.
/// Best-effort : un échec de Storage ne doit pas empêcher la suppression du
/// compte (le droit à l'effacement prime sur quelques fichiers orphelins).
async function purgeBucket(
  admin: ReturnType<typeof createClient>,
  bucket: string,
  userId: string,
) {
  try {
    const { data, error } = await admin.storage.from(bucket).list(userId, {
      limit: 1000,
    });
    if (error || !data?.length) return;
    const paths = data.map((f: { name: string }) => `${userId}/${f.name}`);
    await admin.storage.from(bucket).remove(paths);
  } catch (_) {
    // ignoré volontairement
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return jsonResponse({ error: "missing_authorization" }, 401);

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  // Client « utilisateur » : hérite du JWT de l'appelant, donc auth.uid() est
  // renseigné dans les fonctions SQL. C'est lui qui identifie qui supprime quoi.
  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: userData, error: userErr } = await userClient.auth.getUser();
  const user = userData?.user;
  if (userErr || !user) return jsonResponse({ error: "not_authenticated" }, 401);

  // 1. Effacement / anonymisation des données métier (sous l'identité du user)
  const { error: rpcErr } = await userClient.rpc("delete_my_account_data");
  if (rpcErr) {
    const blocked = rpcErr.message?.includes("has_paid_sales");
    return jsonResponse(
      { error: blocked ? "has_paid_sales" : "deletion_failed" },
      blocked ? 409 : 500,
    );
  }

  // 2. Nettoyage du Storage (avatars + images d'événements)
  const admin = createClient(supabaseUrl, serviceKey);
  await purgeBucket(admin, "avatars", user.id);
  await purgeBucket(admin, "events", user.id);

  // 3. Suppression du compte auth. Emporte en cascade favorites,
  //    notifications et user_legal_acceptances — les données qu'on voulait
  //    conserver ont déjà été détachées à l'étape 1.
  const { error: delErr } = await admin.auth.admin.deleteUser(user.id);
  if (delErr) return jsonResponse({ error: "auth_delete_failed" }, 500);

  return jsonResponse({ status: "deleted" });
});
