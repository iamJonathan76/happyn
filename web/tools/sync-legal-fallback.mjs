// =============================================================================
// HAPPYN Web — Régénère la copie locale des documents légaux
// =============================================================================
// La table `legal_documents` de Supabase est la source unique de vérité.
// Ce script en prend un instantané dans assets/data/legal-fallback.json, servi
// uniquement quand la base est injoignable (voir l'en-tête de legal.js).
//
//   node web/tools/sync-legal-fallback.mjs
//
// À relancer après CHAQUE modification du texte légal en base, puis à committer
// le JSON obtenu. Ne pas éditer ce JSON à la main : la prochaine exécution
// écraserait la modification.
//
// Aucune dépendance : Node 18+ suffit (fetch natif). Aucun secret : la lecture
// est publique, la clé anon suffit.
// =============================================================================

import { readFile, writeFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const webRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const outputPath = resolve(webRoot, 'assets/data/legal-fallback.json');

// On relit les valeurs depuis config.js pour ne pas dupliquer l'URL et la clé.
async function readConfig() {
  const source = await readFile(resolve(webRoot, 'assets/js/config.js'), 'utf8');
  const pick = (key) => {
    const match = source.match(new RegExp(`${key}:\\s*'([^']+)'`));
    if (!match) throw new Error(`config.js: champ « ${key} » introuvable`);
    return match[1];
  };
  return { url: pick('supabaseUrl'), anonKey: pick('supabaseAnonKey') };
}

async function main() {
  const { url, anonKey } = await readConfig();

  const endpoint =
    `${url}/rest/v1/legal_documents` +
    `?select=slug,title,content,version,effective_date,sort_order,updated_at` +
    `&order=sort_order.asc`;

  const response = await fetch(endpoint, {
    headers: { apikey: anonKey, Authorization: `Bearer ${anonKey}` },
  });

  if (!response.ok) {
    throw new Error(
      `Supabase a répondu ${response.status} ${response.statusText}. ` +
        `La migration legal_documents est-elle bien appliquée ?`,
    );
  }

  const documents = await response.json();
  if (!Array.isArray(documents) || documents.length === 0) {
    throw new Error(
      'La table legal_documents est vide — rien à écrire. Vérifie la table ' +
        'dans le SQL Editor avant de régénérer la copie locale.',
    );
  }

  await writeFile(outputPath, `${JSON.stringify(documents, null, 2)}\n`, 'utf8');
  console.log(
    `✓ ${documents.length} documents écrits dans assets/data/legal-fallback.json`,
  );
}

main().catch((error) => {
  console.error(`✗ ${error.message}`);
  process.exit(1);
});
