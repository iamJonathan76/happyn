// =============================================================================
// HAPPYN — Edge Function `send-push`
// =============================================================================
// Pousse une notification vers les appareils d'un utilisateur.
//
// Appelée par un Database Webhook sur INSERT dans `public.notifications`. Cette
// table se remplit déjà pour l'achat confirmé, l'annulation d'un événement et
// l'annulation d'un billet — brancher l'envoi ICI plutôt qu'à chaque endroit du
// code signifie que tout nouveau type de notification sera poussé sans une
// ligne de plus.
//
// ⚠️ N'exige pas de JWT : l'appelant est la base. Protégée par le même schéma
//    de secret partagé que `notify-report`, comparé en temps constant.
//    Déployer avec --no-verify-jwt.
//
// FCM HTTP v1 exige un jeton OAuth2 obtenu en signant un JWT avec la clé privée
// du compte de service. L'ancienne « server key » est supprimée par Google, il
// n'y a pas de raccourci.
// =============================================================================

import { createClient } from "jsr:@supabase/supabase-js@2";

interface ServiceAccount {
  client_email: string;
  private_key: string;
  project_id: string;
}

/// Jeton d'accès mis en cache pour la durée de vie de l'instance : il vaut une
/// heure, et le redemander à chaque notification ajouterait un aller-retour
/// inutile à chaque envoi.
let cachedToken: { value: string; expiresAt: number } | null = null;

function secretsMatch(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

function base64url(input: ArrayBuffer | string): string {
  const bytes = typeof input === "string"
    ? new TextEncoder().encode(input)
    : new Uint8Array(input);
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

/// Convertit la clé privée PEM du compte de service en clé utilisable.
async function importPrivateKey(pem: string): Promise<CryptoKey> {
  // La clé arrive avec des \n littéraux quand elle transite par une variable
  // d'environnement : il faut les rétablir avant de décoder.
  const body = pem
    .replace(/\\n/g, "\n")
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s/g, "");
  const raw = Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey(
    "pkcs8",
    raw.buffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

async function getAccessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  // 60 s de marge : un jeton qui expire pendant l'envoi ferait échouer la
  // notification pour une raison impossible à diagnostiquer.
  if (cachedToken && cachedToken.expiresAt > now + 60) return cachedToken.value;

  const header = base64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = base64url(JSON.stringify({
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));

  const key = await importPrivateKey(sa.private_key);
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(`${header}.${claims}`),
  );
  const jwt = `${header}.${claims}.${base64url(signature)}`;

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  if (!res.ok) {
    throw new Error(`oauth ${res.status}`);
  }
  const data = await res.json();
  cachedToken = {
    value: data.access_token,
    expiresAt: now + (data.expires_in ?? 3600),
  };
  return cachedToken.value;
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return new Response("method_not_allowed", { status: 405 });

  const expected = Deno.env.get("PUSH_HOOK_SECRET");
  const saRaw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
  const url = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  if (!expected || !saRaw) {
    console.error("send-push: configuration incomplete");
    return new Response("not_configured", { status: 500 });
  }
  const provided = req.headers.get("x-happyn-secret") ?? "";
  if (!secretsMatch(provided, expected)) {
    // On journalise les LONGUEURS, jamais les valeurs : c'est suffisant pour
    // distinguer les trois causes reelles d'un 403 — en-tete absent (0),
    // valeur tronquee au collage (longueurs differentes), ou caractere
    // invisible comme un espace ou un retour a la ligne (longueurs proches).
    console.error(
      `403 : en-tete recu ${provided.length} car., secret attendu ${expected.length} car.`,
    );
    return new Response("forbidden", { status: 403 });
  }

  let record: Record<string, unknown>;
  try {
    const body = await req.json();
    record = (body.record ?? body) as Record<string, unknown>;
  } catch (_) {
    return new Response("bad_request", { status: 400 });
  }

  const userId = String(record.user_id ?? "");
  const title = String(record.title ?? "HAPPYN");
  const body = String(record.body ?? "");
  if (!userId) return new Response("bad_request", { status: 400 });

  const admin = createClient(url, serviceKey);
  const { data: tokens, error } = await admin
    .from("device_tokens")
    .select("token")
    .eq("user_id", userId);

  if (error) {
    console.error("device_tokens:", error.message);
    return new Response("lookup_failed", { status: 500 });
  }
  // Personne n'a installé l'app, ou personne n'a accepté les notifications.
  // Ce n'est pas une erreur : la notification reste lisible dans l'app.
  if (!tokens || tokens.length === 0) {
    return new Response(JSON.stringify({ sent: 0 }), { status: 200 });
  }

  let sa: ServiceAccount;
  try {
    sa = JSON.parse(saRaw);
  } catch (_) {
    console.error("send-push: FIREBASE_SERVICE_ACCOUNT n'est pas du JSON");
    return new Response("not_configured", { status: 500 });
  }

  let accessToken: string;
  try {
    accessToken = await getAccessToken(sa);
  } catch (e) {
    console.error("send-push: jeton OAuth impossible :", e);
    return new Response("auth_failed", { status: 502 });
  }

  const endpoint =
    `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`;

  let sent = 0;
  const stale: string[] = [];

  for (const row of tokens) {
    const token = row.token as string;
    const res = await fetch(endpoint, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title, body },
          // Transporté à l'app pour ouvrir le bon écran au toucher. FCM
          // n'accepte que des chaînes dans `data`.
          data: {
            type: String(record.type ?? ""),
            event_id: String(record.event_id ?? ""),
          },
          android: { priority: "high" },
        },
      }),
    });

    if (res.ok) {
      sent++;
      continue;
    }

    const payload = await res.json().catch(() => null);
    const status = payload?.error?.status;
    // App désinstallée, ou jeton remplacé : la ligne ne servira plus jamais.
    // La laisser ferait échouer un envoi sur deux indéfiniment.
    if (status === "NOT_FOUND" || status === "UNREGISTERED" || res.status === 404) {
      stale.push(token);
    } else {
      console.error("fcm:", res.status, status);
    }
  }

  if (stale.length > 0) {
    await admin.from("device_tokens").delete().in("token", stale);
  }

  return new Response(
    JSON.stringify({ sent, removed: stale.length }),
    { status: 200, headers: { "Content-Type": "application/json" } },
  );
});
