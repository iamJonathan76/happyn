const original = document.querySelector('#original');
const alternate = document.querySelector('#alternate');
const slideImage = document.querySelector('#slide-image');
const slideName = document.querySelector('#slide-name');
const carousel = document.querySelector('#app');
const slides = [
  [null, 'Home', 'Accueil'],
  ['discover', 'Discover', 'Découvrir'],
  ['profile', 'Profile', 'Profil'],
  ['create', 'Create Event', 'Créer un événement'],
  ['ticket', 'My Ticket', 'Mon billet']
];
let active = 0;
let language = window.HappynI18n.lang;
const translations = [...document.querySelectorAll('[data-fr]')].map(node => [node, node.textContent]);
const legalLinks = [...document.querySelectorAll('[data-legal]')].map(link => [link, new URL(link.href)]);
function showSlide(index) {
  active = (index + slides.length) % slides.length;
  const [file, en, fr] = slides[active];
  const label = language === 'fr' ? fr : en;
  document.querySelector('#carousel-qr').hidden = file !== 'ticket';
  document.querySelector('#carousel-countdown').hidden = file !== 'ticket';
  original.hidden = Boolean(file);
  alternate.hidden = !file;
  if (file) {
    const source = 'assets/img/landing/' + file + '-series.png';
    if (slideImage.getAttribute('src') !== source) {
      slideImage.src = source;
    }
    slideImage.alt = 'HAPPYN — ' + label;
  }
  slideName.textContent = label;
}
function translate() {
  const fr = language === 'fr';
  document.documentElement.lang = language;
  document.querySelector('#language').textContent = fr ? 'FR ⌄' : 'EN ⌄';
  document.querySelector('#language').setAttribute('aria-label', fr ? 'Switch to English' : 'Afficher en français');
  document.querySelector('#prev').setAttribute('aria-label', fr ? 'Capture précédente' : 'Previous screenshot');
  document.querySelector('#next').setAttribute('aria-label', fr ? 'Capture suivante' : 'Next screenshot');
  for (const [node, en] of translations) node.textContent = fr ? node.dataset.fr : en;
  for (const [link, target] of legalLinks) {
    target.searchParams.set('lang', language);
    link.href = target.href;
  }
  showSlide(active);
}
document.querySelector('#language').addEventListener('click', () => {
  language = language === 'en' ? 'fr' : 'en';
  const url = new URL(location.href);
  url.searchParams.set('lang', language);
  history.replaceState(null, '', url);
  window.HappynI18n.set(language);
  translate();
});
document.querySelector('#prev').addEventListener('click', () => showSlide(active - 1));
document.querySelector('#next').addEventListener('click', () => showSlide(active + 1));
carousel.addEventListener('keydown', event => {
  if (event.key === 'ArrowLeft' || event.key === 'ArrowRight') {
    event.preventDefault();
    showSlide(active + (event.key === 'ArrowLeft' ? -1 : 1));
  }
});
function jumpToSlide(index) {
  showSlide(index);
  carousel.scrollIntoView({block: 'center'});
  document.querySelector('#next').focus({preventScroll: true});
}
for (const button of document.querySelectorAll('[data-slide]')) {
  button.addEventListener('click', () => jumpToSlide(Number(button.dataset.slide)));
}
document.querySelector('#connect').addEventListener('click', event => {
  event.preventDefault();
  jumpToSlide(2);
});
for (const button of document.querySelectorAll('[data-updates]')) {
  button.addEventListener('click', () => document.querySelector('#launch-dialog').showModal());
}
translate();
const helpMenu = document.querySelector('#help-menu');
helpMenu.addEventListener('click', event => {
  if (event.target.closest('a')) helpMenu.open = false;
});
document.addEventListener('click', event => {
  if (!helpMenu.contains(event.target)) helpMenu.open = false;
});
helpMenu.addEventListener('keydown', event => {
  if (event.key === 'Escape' && helpMenu.open) {
    helpMenu.open = false;
    helpMenu.querySelector('summary').focus();
  }
});


// Un lien vers un accordéon (p. ex. « Read the guide » ou le menu Aide → #guide)
// l'ouvre, sinon on atterrit sur un bloc replié. Externe pour respecter la CSP.
function openHashDetails() {
  const el = location.hash && document.getElementById(location.hash.slice(1));
  if (el && el.tagName === 'DETAILS') el.open = true;
}
addEventListener('hashchange', openHashDetails);
openHashDetails();
document.addEventListener('click', event => {
  const link = event.target.closest('a[href^="#"]');
  if (!link) return;
  const el = document.getElementById(link.getAttribute('href').slice(1));
  if (el && el.tagName === 'DETAILS') el.open = true;
});

// La demonstration dessine uniquement un motif visuel : aucun jeton d'entree n'est expose.
const qrCanvases = [...document.querySelectorAll('.demo-qr')];
const qrCountdowns = document.querySelectorAll('.qr-countdown');
const qrProgressBars = document.querySelectorAll('.qr-progress');
const qrPauseButtons = document.querySelectorAll('.qr-pause');
const qrCycleDuration = 5000;
const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)');
let qrPaused = reducedMotion.matches;
let qrElapsed = 0;
let qrLastTime = performance.now();
let qrSeed = 1;

function drawDemoCodes() {
  let random = ++qrSeed * 9749;
  const cells = 29;
  const cellSize = 12;
  const offset = 30;
  const modules = [];
  for (let y = 0; y < cells; y++) {
    for (let x = 0; x < cells; x++) {
      const reserved = (x < 8 && y < 8) ||
        (x >= cells - 8 && y < 8) ||
        (x < 8 && y >= cells - 8);
      random = (Math.imul(random, 1664525) + 1013904223) >>> 0;
      if (!reserved && random >>> 31) modules.push([x, y]);
    }
  }
  for (const canvas of qrCanvases) {
    const context = canvas.getContext('2d');
    context.fillStyle = '#fff';
    context.fillRect(0, 0, 408, 408);
    context.fillStyle = '#08080f';
    for (const [x, y] of modules) {
      context.fillRect(offset + x * cellSize, offset + y * cellSize, cellSize, cellSize);
    }
    for (const [x, y] of [[0, 0], [cells - 7, 0], [0, cells - 7]]) {
      context.fillStyle = '#08080f';
      context.fillRect(offset + x * cellSize, offset + y * cellSize, 7 * cellSize, 7 * cellSize);
      context.fillStyle = '#fff';
      context.fillRect(offset + (x + 1) * cellSize, offset + (y + 1) * cellSize, 5 * cellSize, 5 * cellSize);
      context.fillStyle = '#08080f';
      context.fillRect(offset + (x + 2) * cellSize, offset + (y + 2) * cellSize, 3 * cellSize, 3 * cellSize);
    }
  }
}

function updateQrControls() {
  const french = window.HappynI18n.lang === 'fr';
  const seconds = Math.ceil((qrCycleDuration - qrElapsed) / 1000);
  for (const countdown of qrCountdowns) {
    countdown.textContent = french ? 'Nouveau QR dans ' + seconds + ' s' : 'New QR in ' + seconds + ' s';
  }
  for (const button of qrPauseButtons) {
    button.textContent = qrPaused ? (french ? 'Reprendre' : 'Resume') : 'Pause';
    button.setAttribute('aria-pressed', String(qrPaused));
  }
  for (const progress of qrProgressBars) {
    progress.value = qrCycleDuration - qrElapsed;
    progress.setAttribute('aria-label', french ? 'Temps avant le prochain code de démonstration' : 'Time until the next demonstration code');
  }
}

for (const button of qrPauseButtons) {
  button.addEventListener('click', () => {
    qrPaused = !qrPaused;
    qrLastTime = performance.now();
    updateQrControls();
  });
}
reducedMotion.addEventListener('change', event => {
  qrPaused = event.matches;
  qrLastTime = performance.now();
  updateQrControls();
});
document.addEventListener('happyn:lang', updateQrControls);
document.addEventListener('visibilitychange', () => {
  qrLastTime = performance.now();
});
drawDemoCodes();
updateQrControls();
setInterval(() => {
  const now = performance.now();
  const delta = now - qrLastTime;
  qrLastTime = now;
  if (qrPaused || document.hidden) return;
  qrElapsed += delta;
  if (qrElapsed >= qrCycleDuration) {
    qrElapsed %= qrCycleDuration;
    drawDemoCodes();
  }
  updateQrControls();
}, 100);
