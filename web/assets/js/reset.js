// =============================================================================
// HAPPYN Web — Réinitialisation du mot de passe
// =============================================================================
// Page d'atterrissage du lien reçu par courriel. Elle échange le jeton contre
// une session, puis écrit le nouveau mot de passe via l'API REST de Supabase.
//
// Aucun secret ici : le jeton vient du lien, il est à usage unique et de courte
// durée, et la clé utilisée est la clé publiable — la même que partout ailleurs.
//
// Supabase peut faire arriver le lien sous trois formes selon la configuration.
// On gère les deux qui se suffisent à elles-mêmes :
//
//   1. `#access_token=…`      — flux implicite : la session est déjà là.
//   2. `?token_hash=…&type=recovery` — on l'échange contre une session.
//   3. `?code=…`              — flux PKCE : l'échange exige le « code verifier »
//                               généré sur le TÉLÉPHONE au moment de la
//                               demande. Une page web ne l'a pas et ne peut
//                               structurellement pas l'obtenir. On l'explique
//                               au lieu d'échouer sans raison visible.
// =============================================================================

(function () {
  'use strict';

  const el = {
    loading: document.querySelector('[data-reset-loading]'),
    form: document.querySelector('[data-reset-form]'),
    done: document.querySelector('[data-reset-done]'),
    invalid: document.querySelector('[data-reset-invalid]'),
    error: document.querySelector('[data-reset-error]'),
    submit: document.querySelector('[data-reset-submit]'),
  };

  const MIN_LENGTH = 8;
  let accessToken = null;

  // ── Affichage ──────────────────────────────────────────────────────────────

  function show(target) {
    [el.loading, el.form, el.done, el.invalid].forEach((node) => {
      if (node) node.hidden = node !== target;
    });
  }

  function showError(message) {
    if (!el.error) return;
    el.error.textContent = message;
    el.error.hidden = false;
  }

  function clearError() {
    if (el.error) el.error.hidden = true;
  }

  function applyCommonBits() {
    document.querySelectorAll('[data-current-year]').forEach((node) => {
      node.textContent = String(new Date().getFullYear());
    });
    document.querySelectorAll('[data-support-link]').forEach((node) => {
      node.setAttribute('href', `mailto:${HAPPYN.supportEmail}`);
    });
  }

  // ── Récupération de la session ─────────────────────────────────────────────

  function readHashParams() {
    // Le fragment (#) n'est jamais envoyé au serveur : c'est précisément pour
    // ça que Supabase y place les jetons.
    return new URLSearchParams(location.hash.replace(/^#/, ''));
  }

  async function exchangeTokenHash(tokenHash) {
    const response = await fetch(`${HAPPYN.supabaseUrl}/auth/v1/verify`, {
      method: 'POST',
      headers: {
        apikey: HAPPYN.supabaseAnonKey,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ type: 'recovery', token_hash: tokenHash }),
    });
    if (!response.ok) return null;
    const data = await response.json();
    return data.access_token || null;
  }

  async function resolveSession() {
    const hash = readHashParams();
    const query = new URLSearchParams(location.search);

    // Lien déjà expiré : Supabase le dit dans le fragment plutôt que de nous
    // laisser deviner.
    if (hash.get('error') || query.get('error')) return null;

    const fromHash = hash.get('access_token');
    if (fromHash) {
      // Retirer les jetons de la barre d'adresse : ils n'ont plus à traîner
      // dans l'historique ni dans une capture d'écran.
      history.replaceState(null, '', location.pathname);
      return fromHash;
    }

    const tokenHash = query.get('token_hash') || query.get('token');
    if (tokenHash) {
      const token = await exchangeTokenHash(tokenHash);
      if (token) history.replaceState(null, '', location.pathname);
      return token;
    }

    return null;
  }

  // ── Écriture du nouveau mot de passe ───────────────────────────────────────

  async function updatePassword(password) {
    const response = await fetch(`${HAPPYN.supabaseUrl}/auth/v1/user`, {
      method: 'PUT',
      headers: {
        apikey: HAPPYN.supabaseAnonKey,
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ password }),
    });

    if (response.ok) return { ok: true };

    let message = 'Something went wrong. Please try again.';
    try {
      const body = await response.json();
      // On remonte le message de Supabase quand il en donne un : « password
      // too short », « same as the old password »… Un message générique
      // laisserait l'utilisateur réessayer la même chose indéfiniment.
      message = body.msg || body.error_description || body.message || message;
    } catch (_) {
      /* corps illisible : on garde le message générique */
    }
    return { ok: false, message };
  }

  function onSubmit(event) {
    event.preventDefault();
    clearError();

    const password = document.getElementById('password').value;
    const confirm = document.getElementById('confirm').value;

    if (password.length < MIN_LENGTH) {
      showError(`Password must be at least ${MIN_LENGTH} characters.`);
      return;
    }
    if (password !== confirm) {
      showError("Both passwords must match.");
      return;
    }

    el.submit.disabled = true;
    el.submit.textContent = 'Updating…';

    updatePassword(password).then((result) => {
      if (result.ok) {
        show(el.done);
        return;
      }
      el.submit.disabled = false;
      el.submit.textContent = 'Update password';
      showError(result.message);
    });
  }

  // ── Point d'entrée ─────────────────────────────────────────────────────────

  async function init() {
    applyCommonBits();
    if (!el.form) return;

    if (new URLSearchParams(location.search).get('code')) {
      // Flux PKCE : impossible depuis une page web (voir l'en-tête).
      show(el.invalid);
      console.warn(
        '[happyn] Lien PKCE (?code=) : la page web ne peut pas le résoudre. ' +
          'Basculer le gabarit de courriel sur {{ .TokenHash }}.',
      );
      return;
    }

    accessToken = await resolveSession();
    if (!accessToken) {
      show(el.invalid);
      return;
    }

    show(el.form);
    el.form.addEventListener('submit', onSubmit);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
