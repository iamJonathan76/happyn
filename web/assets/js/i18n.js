// =============================================================================
// HAPPYN Web — Bilinguisme (français / anglais)
// =============================================================================
// Un seul dictionnaire pour les trois pages. Le HTML est écrit en anglais ; ce
// script le remplace par le français quand c'est la langue choisie.
//
// Ordre de décision de la langue :
//   1. ?lang=fr ou ?lang=en dans l'adresse (liens partagés, tests)
//   2. le choix fait avec le sélecteur, mémorisé sur cet appareil
//   3. la PREMIÈRE des langues préférées du navigateur qui soit fr ou en —
//      quelqu'un réglé « anglais, puis français » préfère l'anglais
//   4. l'anglais par défaut
//
// Chargé dans <head>, sans `defer` : il masque la page le temps de la traduire.
// Sans ça, un visiteur francophone verrait une fraction de seconde d'anglais
// avant que le texte ne change sous ses yeux.
//
// Tout passe par textContent, jamais innerHTML : aucune chaîne du dictionnaire
// n'est interprétée comme du HTML.
// =============================================================================

(function () {
  'use strict';

  const DICT = {
    en: {
      // ── Page d'accueil : méta ──────────────────────────────────────────────
      'meta.title': 'HAPPYN — Discover events worth showing up for',
      'meta.description':
        "Discover events in Ottawa–Gatineau, book in seconds, walk in with a ticket nobody can copy, and relive the night with the people who were there.",

      // ── Navigation ─────────────────────────────────────────────────────────
      'nav.how': 'How it works',
      'nav.app': 'The app',
      'nav.organizers': 'Organizers',
      'nav.legal': 'Legal',
      'nav.contact': 'Contact',
      'nav.cta': 'Get notified',
      'nav.home': 'HAPPYN home',
      'nav.skip': 'Skip to content',
      'lang.label': 'Language',

      // ── Hero ───────────────────────────────────────────────────────────────
      'hero.eyebrow': 'Ottawa–Gatineau · Coming soon to iOS & Android',
      'hero.title1': 'Discover events',
      'hero.title2': 'worth showing up for.',
      'hero.lead':
        "Find what's on around you, book in seconds, and walk straight in with a ticket nobody can copy. Then relive the night with the people who were there.",
      'store.soon': 'Coming soon on',

      // ── Billet animé (illustration) ────────────────────────────────────────
      'ticket.aria':
        'Illustration of a HAPPYN ticket whose QR code keeps changing on its own',
      'ticket.header': 'My ticket',
      'ticket.meta': 'Sat · 9:00 PM · ByWard Market',
      'ticket.tier': 'General admission',
      'ticket.door': 'Doors',
      'ticket.doorTime': '8:30 PM',
      'ticket.number': 'Ticket',
      'ticket.valid': 'Valid · 1 entry',
      'ticket.renew': 'New code in',
      'ticket.caption':
        'The code keeps changing and expires on its own — a screenshot gets you nowhere.',
      'ticket.demo': 'Demo sped up',

      // ── Liste d'attente ────────────────────────────────────────────────────
      'waitlist.email': 'Email address',
      'waitlist.placeholder': 'you@example.com',
      'waitlist.submit': 'Notify me',
      'waitlist.sending': 'Sending…',
      'waitlist.consent':
        'I agree to receive emails from HAPPYN about its launch. I can unsubscribe at any time.',
      'waitlist.privacy': 'What we do with your email',
      'waitlist.success': "You're on the list. We'll email you when HAPPYN launches.",
      'waitlist.errEmail': 'Enter a valid email address.',
      'waitlist.errConsent': 'Check the box so we have your permission to email you.',
      'waitlist.errNetwork':
        "That didn't go through. Check your connection and try again.",

      // ── Parcours ───────────────────────────────────────────────────────────
      'journey.kicker': 'How it works',
      'journey.title': 'From “what’s on tonight?” to the photos the next day',
      'journey.lead': 'Three moments, one app. You never have to leave it to go out.',
      'step1.title': 'Discover',
      'step1.body':
        'What’s happening soon near you, sorted by date. Filter by category, save what you like, and see where your connections are going — when they choose to share it.',
      'step2.title': 'Go',
      'step2.body':
        'Free or paid, book in a few taps. Payment goes through Stripe, so HAPPYN never sees your card. At the door, your QR code gets you in — once.',
      'step3.title': 'Relive',
      'step3.body':
        'Share your moments from the event, see everyone else’s, and follow the people you met there.',

      // ── Galerie ────────────────────────────────────────────────────────────
      'gallery.kicker': 'The app',
      'gallery.title': 'See it before you download it',
      'gallery.lead': 'Swipe through the screens you’ll use most.',
      'gallery.region': 'App screenshots',
      'gallery.prev': 'Previous screen',
      'gallery.next': 'Next screen',
      'gallery.soon': 'Screenshot coming soon',
      'shot.home': 'Home — what’s happening soon',
      'shot.event': 'An event, and who’s going',
      'shot.ticket': 'Your ticket at the door',
      'shot.moments': 'Moments from the night',
      'shot.people': 'Find people you know',
      'shot.dashboard': 'The organizer dashboard',

      // ── Confiance ──────────────────────────────────────────────────────────
      'trust.kicker': 'Built to be trusted',
      'trust.title': 'The details we didn’t cut corners on',
      'trust1.title': 'A ticket that can’t be copied',
      'trust1.body':
        'Every QR code is signed, expires on its own, and is accepted at the door exactly once.',
      'trust2.title': 'Your card stays with Stripe',
      'trust2.body':
        'Payments are handled by Stripe. HAPPYN never stores your card number — it never even sees it.',
      'trust3.title': 'Private addresses stay private',
      'trust3.body':
        'For a private event, the exact address is only revealed to people holding a ticket. Everyone else sees the city.',
      'trust4.title': 'You decide who sees you going',
      'trust4.body':
        'Your attendance is hidden by default. Only people you follow and who follow you back can see it — and only if you choose to show it.',

      // ── Organisateurs ──────────────────────────────────────────────────────
      'org.kicker': 'For organizers',
      'org.title': 'Run your event from your phone',
      'org.lead':
        'Create it in minutes, then follow your sales and your door from a single screen.',
      'org1.title': 'Sales at a glance',
      'org1.body': 'Gross sales, tickets sold per tier, seats left.',
      'org2.title': 'Your guest list',
      'org2.body': 'Who’s coming and who’s already in. Names only — never their email.',
      'org3.title': 'Scan at the door',
      'org3.body': 'The built-in scanner admits each ticket exactly once.',
      'org4.title': 'Stay in control',
      'org4.body':
        'Publish, unpublish or cancel whenever you need to. Cancelling notifies everyone who bought a ticket.',
      'dash.example': 'Example',
      'dash.state': 'Published',
      'dash.event': 'Rooftop Sessions',
      'dash.date': 'Saturday · 9:00 PM',
      'dash.gross': 'Gross sales',
      'dash.amount': '$1,240',
      'dash.price1': '$15',
      'dash.price2': '$29',
      'dash.sold': '62 of 100 tickets',
      'dash.checkedIn': 'Checked in',
      'dash.left': 'Seats left',
      'dash.tier1': 'Early bird',
      'dash.tier2': 'General',
      'dash.tier1Sold': '40 of 40',
      'dash.tier2Sold': '22 of 60',

      // ── Appel final + contact ──────────────────────────────────────────────
      'cta.title': 'Be there on day one',
      'cta.body':
        'HAPPYN is launching in Ottawa–Gatineau. Leave your email and we’ll let you know the moment it’s out.',
      'contact.title': 'Questions, press or partnerships?',
      'contact.body':
        'You organize events and want to launch your next one on HAPPYN? We read everything.',
      'contact.button': 'Write to us',

      // ── Pied de page (toutes les pages) ────────────────────────────────────
      'footer.about': 'Discover, book and relive the events happening around you.',
      'footer.legal': 'Legal',
      'footer.privacy': 'Privacy Policy',
      'footer.terms': 'Terms of Service',
      'footer.contact': 'Contact',
      'footer.support': 'Support',
      'footer.allPolicies': 'All policies',
      'footer.rights': 'All rights reserved.',
      'footer.made': 'Made in Ottawa, for people who go out.',
      'footer.contactSupport': 'Contact support',

      // ── Pages légales ──────────────────────────────────────────────────────
      'legal.metaTitle': 'Legal — HAPPYN',
      'legal.metaDescription':
        "HAPPYN's Terms of Service, Privacy Policy, Community Guidelines and other policies.",
      'legal.policies': 'Policies',
      'legal.loading': 'Loading…',
      'legal.indexTitle': 'Legal',
      'legal.indexLead':
        'The policies that govern the use of HAPPYN, for attendees and organizers alike.',
      'legal.effective': 'Effective {date}',
      'legal.updated': 'Last updated {date}',
      'legal.errorTitle': 'These policies are temporarily unavailable.',
      'legal.errorBody':
        "Please try again in a moment, or email us at {email} and we'll send them to you directly.",
      'legal.englishOnly': '',

      // ── Réinitialisation du mot de passe ───────────────────────────────────
      'reset.metaTitle': 'Reset your password — HAPPYN',
      'reset.metaDescription': 'Choose a new password for your HAPPYN account.',
      'reset.checking': 'Checking your link…',
      'reset.moment': 'One moment.',
      'reset.chooseTitle': 'Choose a new password',
      'reset.chooseBody':
        "Pick something you don't use anywhere else. You'll sign in to the app with this password.",
      'reset.newPassword': 'New password',
      'reset.confirm': 'Confirm password',
      'reset.hint': 'At least 8 characters.',
      'reset.submit': 'Update password',
      'reset.updating': 'Updating…',
      'reset.doneTitle': 'Password updated',
      'reset.doneBody':
        'Open HAPPYN and sign in with your new password. You can close this page.',
      'reset.invalidTitle': "This link doesn't work anymore",
      'reset.invalidBody':
        'Reset links expire, and each one can only be used once. Open HAPPYN and tap “Forgot password?” to get a fresh one.',
      'reset.stuckBefore': 'Still stuck? Write to',
      'reset.stuckLink': 'our support address',
      'reset.stuckAfter': "and we'll sort it out.",
      'reset.errTooShort': 'Password must be at least {n} characters.',
      'reset.errMismatch': 'Both passwords must match.',
      'reset.errSame': 'Choose a password different from your old one.',
      'reset.errGeneric': 'Something went wrong. Please try again.',
    },

    fr: {
      'meta.title': 'HAPPYN — Des événements qui valent le déplacement',
      'meta.description':
        "Découvre les événements d'Ottawa–Gatineau, réserve en quelques secondes, entre avec un billet que personne ne peut copier, et revis la soirée avec ceux qui y étaient.",

      'nav.how': 'Comment ça marche',
      'nav.app': "L'app",
      'nav.organizers': 'Organisateurs',
      'nav.legal': 'Légal',
      'nav.contact': 'Contact',
      'nav.cta': 'Être prévenu',
      'nav.home': 'Accueil HAPPYN',
      'nav.skip': 'Aller au contenu',
      'lang.label': 'Langue',

      'hero.eyebrow': 'Ottawa–Gatineau · Bientôt sur iOS et Android',
      'hero.title1': 'Des événements',
      'hero.title2': 'qui valent le déplacement.',
      'hero.lead':
        "Trouve ce qui se passe autour de toi, réserve en quelques secondes et entre directement avec un billet que personne ne peut copier. Puis revis la soirée avec ceux qui y étaient.",
      'store.soon': 'Bientôt sur',

      'ticket.aria':
        "Illustration d'un billet HAPPYN dont le QR code change tout seul",
      'ticket.header': 'Mon billet',
      'ticket.meta': 'Sam. · 21 h · Marché By',
      'ticket.tier': 'Admission générale',
      'ticket.door': 'Portes',
      'ticket.doorTime': '20 h 30',
      'ticket.number': 'Billet',
      'ticket.valid': 'Valide · 1 entrée',
      'ticket.renew': 'Nouveau code dans',
      'ticket.caption':
        "Le code change sans cesse et expire tout seul : une capture d'écran ne sert à rien.",
      'ticket.demo': 'Démonstration accélérée',

      'waitlist.email': 'Adresse courriel',
      'waitlist.placeholder': 'toi@exemple.com',
      'waitlist.submit': 'Me prévenir',
      'waitlist.sending': 'Envoi…',
      'waitlist.consent':
        "J'accepte de recevoir des courriels de HAPPYN au sujet de son lancement. Je peux me désabonner en tout temps.",
      'waitlist.privacy': 'Ce que nous faisons de ton courriel',
      'waitlist.success': "C'est noté. On t'écrira au lancement de HAPPYN.",
      'waitlist.errEmail': 'Entre une adresse courriel valide.',
      'waitlist.errConsent': "Coche la case pour qu'on ait ton accord pour t'écrire.",
      'waitlist.errNetwork':
        "Ça n'a pas fonctionné. Vérifie ta connexion et réessaie.",

      'journey.kicker': 'Comment ça marche',
      'journey.title': 'De « on sort où ce soir ? » aux photos du lendemain',
      'journey.lead':
        "Trois moments, une seule app. Tu n'as jamais besoin d'en sortir pour sortir.",
      'step1.title': 'Découvrir',
      'step1.body':
        "Ce qui arrive bientôt près de chez toi, trié par date. Filtre par catégorie, garde ce qui te plaît et vois où vont tes connexions — quand elles choisissent de le montrer.",
      'step2.title': 'Y aller',
      'step2.body':
        "Gratuit ou payant, tu réserves en quelques gestes. Le paiement passe par Stripe : HAPPYN ne voit jamais ta carte. À l'entrée, ton QR code te fait entrer — une seule fois.",
      'step3.title': 'Revivre',
      'step3.body':
        "Partage tes moments de l'événement, découvre ceux des autres et suis les gens rencontrés là-bas.",

      'gallery.kicker': "L'app",
      'gallery.title': 'Vois-la avant de la télécharger',
      'gallery.lead': "Fais défiler les écrans que tu utiliseras le plus.",
      'gallery.region': "Captures d'écran de l'app",
      'gallery.prev': 'Écran précédent',
      'gallery.next': 'Écran suivant',
      'gallery.soon': 'Capture à venir',
      'shot.home': 'Accueil — ce qui arrive bientôt',
      'shot.event': 'Un événement, et qui y va',
      'shot.ticket': "Ton billet à l'entrée",
      'shot.moments': 'Les moments de la soirée',
      'shot.people': 'Retrouve les gens que tu connais',
      'shot.dashboard': 'Le tableau de bord organisateur',

      'trust.kicker': 'Pensé pour la confiance',
      'trust.title': "Là où on n'a pas pris de raccourcis",
      'trust1.title': 'Un billet impossible à copier',
      'trust1.body':
        "Chaque QR code est signé, expire de lui-même et n'est accepté qu'une seule fois à l'entrée.",
      'trust2.title': 'Ta carte reste chez Stripe',
      'trust2.body':
        'Les paiements sont traités par Stripe. HAPPYN ne stocke pas ton numéro de carte — il ne le voit même pas.',
      'trust3.title': 'Les adresses privées le restent',
      'trust3.body':
        "Pour un événement privé, l'adresse exacte n'est révélée qu'aux détenteurs d'un billet. Les autres ne voient que la ville.",
      'trust4.title': 'Tu choisis qui voit que tu y vas',
      'trust4.body':
        'Ta présence est cachée par défaut. Seules les personnes que tu suis et qui te suivent peuvent la voir — et seulement si tu choisis de la montrer.',

      'org.kicker': 'Pour les organisateurs',
      'org.title': 'Gère ton événement depuis ton téléphone',
      'org.lead':
        'Crée-le en quelques minutes, puis suis tes ventes et ton entrée depuis un seul écran.',
      'org1.title': "Tes ventes d'un coup d'œil",
      'org1.body': 'Ventes brutes, billets vendus par palier, places restantes.',
      'org2.title': "Ta liste d'invités",
      'org2.body':
        'Qui vient, qui est déjà entré. Les noms seulement — jamais les courriels.',
      'org3.title': "Scanne à l'entrée",
      'org3.body': "Le scanner intégré n'accepte chaque billet qu'une seule fois.",
      'org4.title': 'Tu gardes la main',
      'org4.body':
        "Publie, dépublie ou annule quand tu veux. Annuler prévient tous ceux qui ont acheté un billet.",
      'dash.example': 'Exemple',
      'dash.state': 'Publié',
      'dash.event': 'Rooftop Sessions',
      'dash.date': 'Samedi · 21 h',
      'dash.gross': 'Ventes brutes',
      'dash.amount': '1 240 $',
      'dash.price1': '15 $',
      'dash.price2': '29 $',
      'dash.sold': '62 billets sur 100',
      'dash.checkedIn': 'Entrées',
      'dash.left': 'Places restantes',
      'dash.tier1': 'Prévente',
      'dash.tier2': 'Général',
      'dash.tier1Sold': '40 sur 40',
      'dash.tier2Sold': '22 sur 60',

      'cta.title': 'Sois là dès le premier jour',
      'cta.body':
        "HAPPYN arrive à Ottawa–Gatineau. Laisse ton courriel et on te prévient dès sa sortie.",
      'contact.title': 'Questions, presse ou partenariats ?',
      'contact.body':
        'Tu organises des événements et tu veux lancer le prochain sur HAPPYN ? On lit tout.',
      'contact.button': 'Nous écrire',

      'footer.about': 'Découvre, réserve et revis les événements autour de toi.',
      'footer.legal': 'Légal',
      'footer.privacy': 'Politique de confidentialité',
      'footer.terms': "Conditions d'utilisation",
      'footer.contact': 'Contact',
      'footer.support': 'Support',
      'footer.allPolicies': 'Toutes les politiques',
      'footer.rights': 'Tous droits réservés.',
      'footer.made': 'Fait à Ottawa, pour ceux qui sortent.',
      'footer.contactSupport': 'Contacter le support',

      'legal.metaTitle': 'Légal — HAPPYN',
      'legal.metaDescription':
        "Conditions d'utilisation, politique de confidentialité, règles de la communauté et autres politiques de HAPPYN.",
      'legal.policies': 'Politiques',
      'legal.loading': 'Chargement…',
      'legal.indexTitle': 'Légal',
      'legal.indexLead':
        "Les politiques qui encadrent l'utilisation de HAPPYN, pour les participants comme pour les organisateurs.",
      'legal.effective': 'En vigueur le {date}',
      'legal.updated': 'Mis à jour le {date}',
      'legal.errorTitle': 'Ces politiques sont momentanément indisponibles.',
      'legal.errorBody':
        'Réessaie dans un instant, ou écris-nous à {email} et on te les enverra directement.',
      // Dit franchement plutôt que de laisser un francophone tomber sur un texte
      // anglais sans explication. À retirer quand les versions françaises
      // seront en base.
      'legal.englishOnly':
        'Nos politiques sont pour le moment disponibles en anglais seulement. La version française est en préparation.',

      'reset.metaTitle': 'Réinitialiser ton mot de passe — HAPPYN',
      'reset.metaDescription': 'Choisis un nouveau mot de passe pour ton compte HAPPYN.',
      'reset.checking': 'Vérification de ton lien…',
      'reset.moment': 'Un instant.',
      'reset.chooseTitle': 'Choisis un nouveau mot de passe',
      'reset.chooseBody':
        "Choisis-en un que tu n'utilises nulle part ailleurs. C'est avec lui que tu te connecteras dans l'app.",
      'reset.newPassword': 'Nouveau mot de passe',
      'reset.confirm': 'Confirme le mot de passe',
      'reset.hint': 'Au moins 8 caractères.',
      'reset.submit': 'Mettre à jour',
      'reset.updating': 'Mise à jour…',
      'reset.doneTitle': 'Mot de passe mis à jour',
      'reset.doneBody':
        'Ouvre HAPPYN et connecte-toi avec ton nouveau mot de passe. Tu peux fermer cette page.',
      'reset.invalidTitle': 'Ce lien ne fonctionne plus',
      'reset.invalidBody':
        "Les liens de réinitialisation expirent et ne servent qu'une fois. Ouvre HAPPYN et touche « Mot de passe oublié ? » pour en recevoir un nouveau.",
      'reset.stuckBefore': 'Toujours bloqué ? Écris à',
      'reset.stuckLink': 'notre adresse de support',
      'reset.stuckAfter': 'et on règle ça.',
      'reset.errTooShort': 'Le mot de passe doit contenir au moins {n} caractères.',
      'reset.errMismatch': 'Les deux mots de passe doivent être identiques.',
      'reset.errSame': "Choisis un mot de passe différent de l'ancien.",
      'reset.errGeneric': 'Un problème est survenu. Réessaie.',
    },
  };

  const SUPPORTED = ['en', 'fr'];
  const STORE_KEY = 'happyn.lang';

  function detect() {
    const fromUrl = new URLSearchParams(location.search).get('lang');
    if (SUPPORTED.includes(fromUrl)) return fromUrl;

    try {
      const saved = localStorage.getItem(STORE_KEY);
      if (SUPPORTED.includes(saved)) return saved;
    } catch (_) {
      /* stockage bloqué (navigation privée) : on passe à la suite */
    }

    const preferred = navigator.languages || [navigator.language || ''];
    for (const tag of preferred) {
      const base = String(tag).slice(0, 2).toLowerCase();
      if (SUPPORTED.includes(base)) return base;
    }
    return 'en';
  }

  let lang = detect();
  document.documentElement.lang = lang;

  // Le HTML est en anglais : seul un visiteur francophone a besoin d'attendre
  // la traduction. Filet de sécurité : si quoi que ce soit échoue, la page
  // réapparaît quand même au bout d'une seconde — mieux vaut de l'anglais
  // qu'une page blanche.
  if (lang !== 'en') {
    document.documentElement.classList.add('i18n-pending');
    setTimeout(reveal, 1000);
  }

  function reveal() {
    document.documentElement.classList.remove('i18n-pending');
  }

  function t(key, vars) {
    const table = DICT[lang] || DICT.en;
    let text = key in table ? table[key] : key in DICT.en ? DICT.en[key] : key;
    if (vars) {
      Object.keys(vars).forEach((name) => {
        text = text.split(`{${name}}`).join(String(vars[name]));
      });
    }
    return text;
  }

  // data-i18n="clé"                 → textContent
  // data-i18n-attr="attr:clé;attr:clé" → attributs (placeholder, aria-label…)
  function apply(root) {
    const scope = root || document;
    scope.querySelectorAll('[data-i18n]').forEach((node) => {
      node.textContent = t(node.getAttribute('data-i18n'));
    });
    scope.querySelectorAll('[data-i18n-attr]').forEach((node) => {
      node
        .getAttribute('data-i18n-attr')
        .split(';')
        .forEach((pair) => {
          const [attr, key] = pair.split(':').map((s) => s.trim());
          if (attr && key) node.setAttribute(attr, t(key));
        });
    });
    document.querySelectorAll('[data-set-lang]').forEach((button) => {
      button.setAttribute(
        'aria-pressed',
        String(button.getAttribute('data-set-lang') === lang),
      );
    });
  }

  function set(next) {
    if (!SUPPORTED.includes(next) || next === lang) return;
    lang = next;
    try {
      localStorage.setItem(STORE_KEY, lang);
    } catch (_) {
      /* le choix vaudra pour cette visite seulement */
    }
    document.documentElement.lang = lang;
    apply();
    // Les scripts qui fabriquent du texte eux-mêmes (pages légales, mot de
    // passe) écoutent cet événement pour se redessiner.
    document.dispatchEvent(new CustomEvent('happyn:lang', { detail: { lang } }));
  }

  function init() {
    try {
      apply();
      document.querySelectorAll('[data-set-lang]').forEach((button) => {
        button.addEventListener('click', () =>
          set(button.getAttribute('data-set-lang')),
        );
      });
    } finally {
      reveal();
    }
  }

  window.HappynI18n = {
    t,
    apply,
    set,
    get lang() {
      return lang;
    },
    // Pour formater les dates dans la langue affichée.
    get locale() {
      return lang === 'fr' ? 'fr-CA' : 'en-CA';
    },
  };

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
