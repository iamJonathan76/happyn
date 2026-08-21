// =============================================================================
// HAPPYN Web — Rendu des documents légaux + petits réglages de page
// =============================================================================
// Source de vérité : la table `legal_documents` dans Supabase (lecture publique).
//
// POURQUOI UN FALLBACK LOCAL
// Apple et Google auditent l'URL de politique de confidentialité pendant la
// revue. Si cette page dépendait uniquement d'un fetch réseau, une base
// momentanément indisponible = page vide = revue refusée. On sert donc une copie
// locale (assets/data/legal-fallback.json) quand la base ne répond pas.
// Cette copie est GÉNÉRÉE depuis la base, jamais éditée à la main :
//   node web/tools/sync-legal-fallback.mjs
// La base reste l'unique endroit où l'on écrit.
//
// Tout le texte est inséré via textContent : même venant de notre propre base,
// on ne construit jamais de HTML à partir de données.
// =============================================================================

(function () {
  'use strict';

  // ── Réglages communs à toutes les pages ────────────────────────────────────

  function applyCommonBits() {
    document.querySelectorAll('[data-current-year]').forEach((el) => {
      el.textContent = String(new Date().getFullYear());
    });

    // L'adresse support vit dans config.js : un seul endroit à changer.
    document.querySelectorAll('[data-support-link]').forEach((el) => {
      el.setAttribute('href', `mailto:${HAPPYN.supportEmail}`);
    });
  }

  // ── Chargement (base, puis copie locale) ───────────────────────────────────

  async function loadDocuments() {
    try {
      const documents = await fetchLegalDocuments();
      if (documents.length > 0) return documents;
      // Table vide = migration pas encore appliquée : on bascule aussi.
      throw new Error('legal_documents is empty');
    } catch (error) {
      console.warn('[happyn] Supabase unreachable, using local copy:', error);
      const response = await fetch('assets/data/legal-fallback.json');
      if (!response.ok) throw error;
      return response.json();
    }
  }

  // ── Rendu ──────────────────────────────────────────────────────────────────

  function renderSidebar(documents, activeSlug) {
    const nav = document.querySelector('[data-legal-nav]');
    if (!nav) return;

    nav.replaceChildren();
    documents.forEach((doc) => {
      const link = document.createElement('a');
      link.href = `legal.html?doc=${encodeURIComponent(doc.slug)}`;
      link.textContent = doc.title;
      if (doc.slug === activeSlug) link.classList.add('active');

      const item = document.createElement('li');
      item.appendChild(link);
      nav.appendChild(item);
    });
  }

  // Le champ `content` est du markdown volontairement pauvre : des titres
  // « ## », des puces « - », et des paragraphes. On le rend à la main plutôt
  // que d'embarquer une bibliothèque markdown — moins de code, et surtout
  // aucune conversion en HTML brut sur une page auditée par les stores.
  function renderContent(container, content) {
    const lines = String(content || '').split(/\r?\n/);

    let section = null;
    let list = null;

    const openSection = () => {
      section = document.createElement('div');
      section.className = 'legal-section';
      container.appendChild(section);
      list = null;
      return section;
    };

    const currentSection = () => section || openSection();

    lines.forEach((rawLine) => {
      const line = rawLine.trim();

      if (line === '') {
        list = null; // une ligne vide referme la liste en cours
        return;
      }

      if (line.startsWith('## ')) {
        // Un titre ouvre une nouvelle section.
        const heading = document.createElement('h2');
        heading.textContent = line.slice(3).trim();
        openSection().appendChild(heading);
        return;
      }

      if (line.startsWith('- ')) {
        if (!list) {
          list = document.createElement('ul');
          currentSection().appendChild(list);
        }
        const item = document.createElement('li');
        item.textContent = line.slice(2).trim();
        list.appendChild(item);
        return;
      }

      const paragraph = document.createElement('p');
      paragraph.textContent = line;
      currentSection().appendChild(paragraph);
      list = null;
    });
  }

  function renderDocument(container, doc) {
    document.title = `${doc.title} — HAPPYN`;
    container.replaceChildren();

    const title = document.createElement('h1');
    title.textContent = doc.title;
    container.appendChild(title);

    // La date d'entrée en vigueur prime sur la date de modification : c'est
    // celle qui engage juridiquement, et celle que les stores regardent.
    const meta = document.createElement('p');
    meta.className = 'legal-meta';
    const stamp = doc.effective_date
      ? `Effective ${formatDate(doc.effective_date)}`
      : doc.updated_at
        ? `Last updated ${formatDate(doc.updated_at)}`
        : '';
    meta.textContent = [doc.version, stamp].filter(Boolean).join(' · ');
    container.appendChild(meta);

    renderContent(container, doc.content);
  }

  // Index quand aucun ?doc= n'est demandé : la liste de toutes les politiques.
  function renderIndex(container, documents) {
    container.replaceChildren();

    const title = document.createElement('h1');
    title.textContent = 'Legal';
    container.appendChild(title);

    const meta = document.createElement('p');
    meta.className = 'legal-meta';
    meta.textContent =
      'The policies that govern the use of HAPPYN, for attendees and organizers alike.';
    container.appendChild(meta);

    const grid = document.createElement('div');
    grid.className = 'legal-index';

    documents.forEach((doc) => {
      const link = document.createElement('a');
      link.href = `legal.html?doc=${encodeURIComponent(doc.slug)}`;

      const name = document.createElement('strong');
      name.textContent = doc.title;
      link.appendChild(name);

      const version = document.createElement('span');
      version.textContent = doc.version;
      link.appendChild(version);

      grid.appendChild(link);
    });

    container.appendChild(grid);
  }

  function renderError(container) {
    container.replaceChildren();

    const box = document.createElement('div');
    box.className = 'state-message error';

    const title = document.createElement('strong');
    title.textContent = 'These policies are temporarily unavailable.';
    box.appendChild(title);

    const text = document.createElement('span');
    text.textContent = `Please try again in a moment, or email us at ${HAPPYN.supportEmail} and we'll send them to you directly.`;
    box.appendChild(text);

    container.appendChild(box);
  }

  function formatDate(isoString) {
    const value = String(isoString || '');
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return '';

    // Une date seule (« 2026-07-23 ») est parsée à minuit UTC. La rendre en
    // heure locale la ferait reculer d'un jour à l'ouest de Greenwich — et une
    // date d'entrée en vigueur affichée de travers, sur une page légale, n'est
    // pas un détail. On la formate donc en UTC.
    const dateOnly = /^\d{4}-\d{2}-\d{2}$/.test(value);

    return date.toLocaleDateString('en-GB', {
      year: 'numeric',
      month: 'long',
      day: 'numeric',
      ...(dateOnly ? { timeZone: 'UTC' } : {}),
    });
  }

  // ── Liens légaux du pied de page (page d'accueil) ──────────────────────────
  // Le HTML contient déjà Privacy et Terms en dur ; on complète avec le reste
  // une fois la base lue, sans jamais retirer ce qui est déjà affiché.

  function renderFooterLinks(documents) {
    const list = document.querySelector('[data-legal-links]');
    if (!list) return;

    const alreadyListed = new Set(
      Array.from(list.querySelectorAll('a')).map((a) =>
        new URL(a.href, location.href).searchParams.get('doc'),
      ),
    );

    documents.forEach((doc) => {
      if (alreadyListed.has(doc.slug)) return;

      const link = document.createElement('a');
      link.href = `legal.html?doc=${encodeURIComponent(doc.slug)}`;
      link.textContent = doc.title;

      const item = document.createElement('li');
      item.appendChild(link);
      list.appendChild(item);
    });
  }

  // ── Amener le lecteur au texte ─────────────────────────────────────────────
  // Sous 900 px la barre latérale passe AU-DESSUS du contenu (voir la média
  // query du CSS). Ouvrir un document est un changement de page : le navigateur
  // atterrit donc en haut, sur la liste des politiques, et le texte demandé se
  // trouve hors écran. On a l'impression que le clic n'a rien fait, et il faut
  // faire défiler pour découvrir que si.
  //
  // Sur grand écran on ne touche à rien : la barre latérale est À CÔTÉ du
  // contenu, qui est donc déjà visible — faire défiler la page serait gratuit
  // et désorientant.

  function revealContent(container) {
    if (!window.matchMedia('(max-width: 900px)').matches) return;

    const reducedMotion = window.matchMedia(
      '(prefers-reduced-motion: reduce)',
    ).matches;

    // Après le rendu, pour que la position soit calculée sur la hauteur réelle.
    requestAnimationFrame(() => {
      container.scrollIntoView({
        behavior: reducedMotion ? 'auto' : 'smooth',
        block: 'start',
      });
    });
  }

  // ── Point d'entrée ─────────────────────────────────────────────────────────

  async function init() {
    applyCommonBits();

    const container = document.querySelector('[data-legal-content]');
    const footerList = document.querySelector('[data-legal-links]');
    if (!container && !footerList) return; // page sans contenu légal

    let documents;
    try {
      documents = await loadDocuments();
    } catch (error) {
      console.error('[happyn] Unable to load legal documents:', error);
      if (container) renderError(container);
      return;
    }

    renderFooterLinks(documents);
    if (!container) return;

    const requestedSlug = new URLSearchParams(location.search).get('doc');
    renderSidebar(documents, requestedSlug);

    if (!requestedSlug) {
      renderIndex(container, documents);
      return;
    }

    const doc = documents.find((entry) => entry.slug === requestedSlug);
    if (doc) {
      renderDocument(container, doc);
      revealContent(container);
    } else {
      // Slug inconnu (lien obsolète) : on retombe sur l'index plutôt que sur
      // une page vide.
      renderIndex(container, documents);
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
