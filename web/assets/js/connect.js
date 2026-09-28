// =============================================================================
// HAPPYN Web — Pages de retour du formulaire Stripe Connect
// =============================================================================
// Ces deux pages (`connect-return.html`, `connect-refresh.html`) n'ont aucune
// logique métier : Stripe y renvoie l'organisateur, et c'est l'APP qui vérifie
// ensuite l'état réel du compte auprès de Stripe.
//
// C'est délibéré. Cette page pourrait afficher « ton compte est actif », mais ce
// serait faux une fois sur dix : la vérification de Stripe peut encore échouer
// après l'envoi du formulaire. Une page qui affirme un succès que l'app
// contredira ensuite est pire qu'une page qui ne dit rien.
//
// Il ne reste donc que les deux comportements communs à tout le site, que
// `site.js` ne porte pas (il ne sert que la page d'accueil) : l'année du pied de
// page et l'adresse de contact. Recopiés depuis `reset.js` plutôt que partagés —
// le site est volontairement sans build, et un module de plus pour six lignes
// coûterait une requête à chaque page.
// =============================================================================

(function () {
  'use strict';

  document.querySelectorAll('[data-current-year]').forEach((node) => {
    node.textContent = String(new Date().getFullYear());
  });

  document.querySelectorAll('[data-support-link]').forEach((node) => {
    node.setAttribute('href', `mailto:${HAPPYN.supportEmail}`);
  });
})();
