// =============================================================================
// HAPPYN Web — Page de suppression de compte
// =============================================================================
// Aucune logique métier ici : la suppression se fait dans l'app, ou à la main
// sur demande par courriel. La page ne fait que pointer vers l'adresse de
// support, lue depuis `config.js` pour qu'elle ne puisse pas diverger du reste
// du site. Mêmes six lignes que `connect.js`, pour la même raison : pas de
// build, pas de module partagé pour si peu.
// =============================================================================

(function () {
  'use strict';

  document.querySelectorAll('[data-current-year]').forEach((node) => {
    node.textContent = String(new Date().getFullYear());
  });

  document.querySelectorAll('[data-support-link]').forEach((node) => {
    // L'objet pré-rempli permet de trier ces demandes sans ouvrir chaque
    // message : elles ont un délai légal, les autres non.
    const subject = node.getAttribute('data-support-subject');
    const query = subject ? `?subject=${encodeURIComponent(subject)}` : '';
    node.setAttribute('href', `mailto:${HAPPYN.supportEmail}${query}`);
  });

  document.querySelectorAll('[data-support-email]').forEach((node) => {
    node.textContent = HAPPYN.supportEmail;
  });
})();
