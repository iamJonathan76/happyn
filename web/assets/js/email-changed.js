// =============================================================================
// HAPPYN Web — Atterrissage d'un lien de changement d'adresse
// =============================================================================
// Supabase renvoie ici après avoir traité un lien de confirmation. La page ne
// vérifie rien elle-même — le lien a déjà été consommé côté serveur quand on
// arrive — mais elle doit distinguer deux arrivées très différentes :
//
//   1. Le lien a été accepté. On le dit, en rappelant qu'il en reste
//      peut-être un second à ouvrir depuis l'autre adresse : avec
//      `secure_email_change`, un seul lien ne change rien, et quelqu'un qui
//      lit « c'est fait » après le premier s'arrêterait là.
//
//   2. Le lien a expiré, ou a déjà servi. Supabase l'annonce dans l'adresse
//      (`#error=…` ou `?error=…`). Afficher « adresse confirmée » dans ce cas
//      serait un mensonge, et un mensonge coûteux : la personne croirait son
//      adresse changée alors qu'elle ne peut plus se connecter avec.
//
// On ne sait PAS lequel des deux liens vient d'être ouvert, ni s'il reste le
// second : cette information n'est pas dans la redirection. Le texte est donc
// écrit pour être vrai dans les deux cas, et renvoie à l'app — la seule qui
// puisse dire quelle adresse le compte porte maintenant.
// =============================================================================

(function () {
  'use strict';

  // ── L'erreur, si le lien n'a pas été accepté ───────────────────────────────
  // Deux emplacements selon le flux : le fragment (flux implicite) ou la query
  // (flux PKCE / lien vérifié côté serveur). On regarde les deux plutôt que de
  // parier sur la configuration du projet, qui peut changer sans toucher à
  // cette page.
  function errorFromUrl() {
    const places = [
      new URLSearchParams(window.location.search),
      new URLSearchParams(window.location.hash.replace(/^#/, '')),
    ];
    for (const params of places) {
      const code = params.get('error') || params.get('error_code');
      if (code) return code;
    }
    return null;
  }

  const failed = errorFromUrl();

  document.querySelectorAll('[data-email-ok]').forEach((node) => {
    node.hidden = Boolean(failed);
  });
  document.querySelectorAll('[data-email-error]').forEach((node) => {
    node.hidden = !failed;
  });

  // Le fragment est retiré de l'adresse une fois lu : il peut contenir des
  // jetons quand Supabase est en flux implicite, et ceux-là n'ont pas à rester
  // dans l'historique ni dans une capture d'écran. `replaceState` plutôt que
  // de toucher `location.hash`, qui rechargerait l'ancre.
  if (window.location.hash && window.history.replaceState) {
    window.history.replaceState(
      null,
      '',
      window.location.pathname + window.location.search
    );
  }

  // ── Pied de page ───────────────────────────────────────────────────────────
  // Recopié depuis `connect.js` / `reset.js`, pour la même raison qu'eux : le
  // site est sans build, et un module partagé pour six lignes coûterait une
  // requête de plus sur chaque page.
  document.querySelectorAll('[data-current-year]').forEach((node) => {
    node.textContent = String(new Date().getFullYear());
  });

  document.querySelectorAll('[data-support-link]').forEach((node) => {
    node.setAttribute('href', `mailto:${HAPPYN.supportEmail}`);
  });
})();
