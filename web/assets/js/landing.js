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
  ['messages', 'Messages', 'Messages']
];
let active = 0;
let language = window.HappynI18n.lang;
const translations = [...document.querySelectorAll('[data-fr]')].map(node => [node, node.textContent]);
const legalLinks = [...document.querySelectorAll('[data-legal]')].map(link => [link, new URL(link.href)]);
function showSlide(index) {
  active = (index + slides.length) % slides.length;
  const [file, en, fr] = slides[active];
  const label = language === 'fr' ? fr : en;
  original.hidden = Boolean(file);
  alternate.hidden = !file;
  if (file) {
    const source = 'assets/img/landing/' + file + '.jpg';
    if (slideImage.getAttribute('src') !== source) slideImage.src = source;
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
