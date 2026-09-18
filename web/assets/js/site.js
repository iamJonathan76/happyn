// =============================================================================
// HAPPYN Web — Page d'accueil : billet animé, galerie, liste d'attente
// =============================================================================
// Trois comportements, indépendants les uns des autres : si l'un échoue, les
// deux autres continuent de fonctionner.
// =============================================================================

(function () {
  'use strict';

  const t = (key, vars) =>
    window.HappynI18n ? window.HappynI18n.t(key, vars) : key;
  const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');

  // ── 1. Le billet dont le QR change ─────────────────────────────────────────
  //
  // Ce n'est PAS un vrai QR code : un motif qui en a l'allure (trois repères
  // d'angle, des modules au hasard), impossible à scanner. Un vrai code
  // renverrait quelque part ; une illustration ne doit renvoyer nulle part.
  //
  // Dans l'app, le code dure 5 minutes et se renouvelle une minute avant
  // d'expirer. Ici il change toutes les 6 secondes pour qu'on le VOIE — la page
  // l'indique (« démonstration accélérée ») pour ne rien promettre de faux.

  const QR_SIZE = 25;
  const QR_PERIOD = 6;

  function drawQr(canvas) {
    const ratio = window.devicePixelRatio || 1;
    const cssSize = canvas.clientWidth || 200;
    canvas.width = Math.round(cssSize * ratio);
    canvas.height = Math.round(cssSize * ratio);

    const ctx = canvas.getContext('2d');
    const cell = canvas.width / QR_SIZE;
    ctx.fillStyle = '#ffffff';
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    ctx.fillStyle = '#120f24';

    const inFinder = (x, y) =>
      (x < 8 && y < 8) || (x > QR_SIZE - 9 && y < 8) || (x < 8 && y > QR_SIZE - 9);

    for (let y = 0; y < QR_SIZE; y++) {
      for (let x = 0; x < QR_SIZE; x++) {
        if (inFinder(x, y)) continue;
        if (Math.random() < 0.46) {
          ctx.fillRect(x * cell, y * cell, Math.ceil(cell), Math.ceil(cell));
        }
      }
    }

    // Les trois repères d'angle, qui font reconnaître un QR au premier coup
    // d'œil.
    const finder = (fx, fy) => {
      ctx.fillStyle = '#120f24';
      ctx.fillRect(fx * cell, fy * cell, 7 * cell, 7 * cell);
      ctx.fillStyle = '#ffffff';
      ctx.fillRect((fx + 1) * cell, (fy + 1) * cell, 5 * cell, 5 * cell);
      ctx.fillStyle = '#7c3aed';
      ctx.fillRect((fx + 2) * cell, (fy + 2) * cell, 3 * cell, 3 * cell);
    };
    finder(0, 0);
    finder(QR_SIZE - 7, 0);
    finder(0, QR_SIZE - 7);
  }

  function initTicket() {
    const canvas = document.querySelector('[data-qr]');
    if (!canvas) return;
    const seconds = document.querySelector('[data-qr-seconds]');
    const bar = document.querySelector('[data-qr-bar]');
    const countdown = document.querySelector('[data-qr-countdown]');

    drawQr(canvas);

    // Animations désactivées par le système : un code fixe, pas de compte à
    // rebours qui ne décompterait rien.
    if (reducedMotion.matches) {
      if (countdown) countdown.hidden = true;
      return;
    }

    let left = QR_PERIOD;
    let visible = true;

    const restartBar = () => {
      if (!bar) return;
      bar.classList.remove('is-running');
      // Force le navigateur à constater le retrait avant de relancer.
      void bar.offsetWidth;
      bar.classList.add('is-running');
    };
    restartBar();

    // Inutile de tourner quand personne ne regarde : ni le billet hors écran,
    // ni l'onglet en arrière-plan.
    if ('IntersectionObserver' in window) {
      new IntersectionObserver((entries) => {
        visible = entries[0].isIntersecting;
      }).observe(canvas);
    }

    setInterval(() => {
      if (!visible || document.hidden) return;
      left -= 1;
      if (left <= 0) {
        left = QR_PERIOD;
        canvas.classList.add('is-swapping');
        setTimeout(() => {
          drawQr(canvas);
          canvas.classList.remove('is-swapping');
        }, 180);
        restartBar();
      }
      if (seconds) seconds.textContent = String(left);
    }, 1000);

    window.addEventListener('resize', () => drawQr(canvas));
  }

  // ── 2. La galerie de captures ──────────────────────────────────────────────

  function initShots() {
    // Une capture absente laisse voir l'écran squelette placé dessous. On ne
    // montre l'image qu'une fois chargée : jamais d'icône d'image cassée.
    document.querySelectorAll('[data-shot]').forEach((img) => {
      const shot = img.closest('.shot');
      const loaded = () => shot && shot.classList.add('is-loaded');
      const missing = () => shot && shot.classList.add('is-missing');

      if (img.complete) {
        img.naturalWidth > 0 ? loaded() : missing();
      } else {
        img.addEventListener('load', loaded, { once: true });
        img.addEventListener('error', missing, { once: true });
      }
    });

    // Le texte alternatif suit la légende — et donc la langue.
    const syncAlt = () => {
      document.querySelectorAll('.shot').forEach((shot) => {
        const img = shot.querySelector('[data-shot]');
        const caption = shot.querySelector('.shot-caption');
        if (img && caption) img.alt = caption.textContent.trim();
      });
    };
    syncAlt();
    document.addEventListener('happyn:lang', syncAlt);
  }

  function initGallery() {
    const gallery = document.querySelector('[data-gallery]');
    const track = document.querySelector('[data-gallery-track]');
    const prev = document.querySelector('[data-gallery-prev]');
    const next = document.querySelector('[data-gallery-next]');
    if (!gallery || !track) return;

    // Un « pas » = la largeur d'une capture plus l'espace entre deux.
    const step = () => {
      const first = track.querySelector('.shot');
      if (!first) return gallery.clientWidth * 0.8;
      const gap = parseFloat(getComputedStyle(track).columnGap) || 0;
      return first.getBoundingClientRect().width + gap;
    };

    const scrollByStep = (direction) => {
      gallery.scrollBy({
        left: direction * step(),
        behavior: reducedMotion.matches ? 'auto' : 'smooth',
      });
    };

    // Les flèches se grisent aux extrémités : une flèche qui ne fait rien
    // ressemble à un bug.
    const update = () => {
      const max = gallery.scrollWidth - gallery.clientWidth - 2;
      if (prev) prev.disabled = gallery.scrollLeft <= 2;
      if (next) next.disabled = gallery.scrollLeft >= max;
    };

    let frame = 0;
    gallery.addEventListener('scroll', () => {
      cancelAnimationFrame(frame);
      frame = requestAnimationFrame(update);
    });
    window.addEventListener('resize', update);

    if (prev) prev.addEventListener('click', () => scrollByStep(-1));
    if (next) next.addEventListener('click', () => scrollByStep(1));

    // Glisser à la souris, comme au doigt. Le défilement natif marche déjà au
    // trackpad et au tactile ; la souris seule ne sait pas défiler en largeur.
    let dragging = false;
    let startX = 0;
    let startLeft = 0;
    let moved = false;

    gallery.addEventListener('pointerdown', (event) => {
      if (event.pointerType !== 'mouse' || event.button !== 0) return;
      dragging = true;
      moved = false;
      startX = event.clientX;
      startLeft = gallery.scrollLeft;
      gallery.classList.add('is-dragging');
    });
    window.addEventListener('pointermove', (event) => {
      if (!dragging) return;
      const dx = event.clientX - startX;
      if (Math.abs(dx) > 3) moved = true;
      gallery.scrollLeft = startLeft - dx;
    });
    window.addEventListener('pointerup', () => {
      if (!dragging) return;
      dragging = false;
      gallery.classList.remove('is-dragging');
    });
    // Un glisser ne doit pas se terminer en clic sur une capture.
    gallery.addEventListener(
      'click',
      (event) => {
        if (moved) {
          event.preventDefault();
          event.stopPropagation();
          moved = false;
        }
      },
      true,
    );

    update();
  }

  // ── 3. La liste d'attente ──────────────────────────────────────────────────
  //
  // Envoyée à Netlify Forms. La loi canadienne anti-pourriel (LCAP) exige un
  // consentement exprès et de pouvoir le prouver : on joint donc au formulaire
  // la phrase EXACTE que la personne a acceptée, dans sa langue. Netlify
  // horodate l'envoi.

  const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;

  function initWaitlists() {
    document.querySelectorAll('[data-waitlist]').forEach((form) => {
      const status = form.querySelector('[data-waitlist-status]');
      const email = form.querySelector('input[type="email"]');
      const consent = form.querySelector('input[name="consent"]');
      const button = form.querySelector('button[type="submit"]');

      const say = (key, kind) => {
        if (!status) return;
        status.textContent = key ? t(key) : '';
        status.dataset.kind = kind || '';
      };

      form.addEventListener('submit', async (event) => {
        event.preventDefault();
        say('', '');

        if (!EMAIL.test((email.value || '').trim())) {
          say('waitlist.errEmail', 'error');
          email.focus();
          return;
        }
        if (!consent.checked) {
          say('waitlist.errConsent', 'error');
          consent.focus();
          return;
        }

        const lang = window.HappynI18n ? window.HappynI18n.lang : 'en';
        form.querySelector('[data-waitlist-lang]').value = lang;
        form.querySelector('[data-waitlist-consent-text]').value = t(
          'waitlist.consent',
        );

        button.disabled = true;
        button.textContent = t('waitlist.sending');

        try {
          const response = await fetch('/', {
            method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body: new URLSearchParams(new FormData(form)).toString(),
          });
          if (!response.ok) throw new Error(`HTTP ${response.status}`);
          form.classList.add('is-done');
          say('waitlist.success', 'success');
        } catch (error) {
          console.warn('[happyn] liste d’attente :', error);
          say('waitlist.errNetwork', 'error');
          button.disabled = false;
          button.textContent = t('waitlist.submit');
        }
      });

      // Un message affiché avant un changement de langue suit la langue.
      document.addEventListener('happyn:lang', () => {
        if (!status || !status.textContent) return;
        const kind = status.dataset.kind;
        if (kind === 'success') say('waitlist.success', kind);
      });
    });
  }

  function init() {
    [initTicket, initShots, initGallery, initWaitlists].forEach((fn) => {
      try {
        fn();
      } catch (error) {
        console.warn('[happyn]', fn.name, error);
      }
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
