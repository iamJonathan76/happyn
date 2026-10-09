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

import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const webRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const outputPath = resolve(webRoot, 'assets/data/legal-fallback.json');
// La même copie pour l'app : hors connexion, elle affichait un texte écrit à
// la main, déjà différent de la base. Un seul instantané, deux destinations.
const appOutputPath = resolve(webRoot, '../assets/legal/legal-fallback.json');
// Les traductions, à part : le site en ligne (avant redéploiement) lit
// legal-fallback.json comme une liste de documents, une par slug.
const translationsPath = resolve(webRoot, 'assets/data/legal-translations.json');
const appTranslationsPath = resolve(webRoot, '../assets/legal/legal-translations.json');

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

  const translationsResponse = await fetch(
    `${url}/rest/v1/legal_document_translations` +
      `?select=slug,locale,title,content,version&order=slug.asc,locale.asc`,
    { headers: { apikey: anonKey, Authorization: `Bearer ${anonKey}` } },
  );
  if (!translationsResponse.ok) {
    throw new Error(
      `Traductions : Supabase a répondu ${translationsResponse.status}.`,
    );
  }
  const translations = await translationsResponse.json();

  const json = `${JSON.stringify(documents, null, 2)}\n`;
  const translationsJson = `${JSON.stringify(translations, null, 2)}\n`;
  await mkdir(dirname(appOutputPath), { recursive: true });
  await writeFile(outputPath, json, 'utf8');
  await writeFile(appOutputPath, json, 'utf8');
  await writeFile(translationsPath, translationsJson, 'utf8');
  await writeFile(appTranslationsPath, translationsJson, 'utf8');
  console.log(
    `✓ ${documents.length} documents et ${translations.length} traductions ` +
      `écrits dans web/assets/data/ et assets/legal/`,
  );
}

main().catch((error) => {
  console.error(`✗ ${error.message}`);
  process.exit(1);
});
