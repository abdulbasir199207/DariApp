/* ============================================================
   80-ui-core: Rendering, Navigation, Dialoge, Ereignis-Delegation.
   Alle Klicks laufen über data-a="aktion" data-v="wert" – es gibt
   keine Inline-Handler mehr (so können Tag-Namen mit Apostroph o. ä.
   nichts mehr zerbrechen).
   ============================================================ */

const $ = id => document.getElementById(id);
const App = { tab: 'today', sub: null, session: false, viewKey: '' };
const A = Object.create(null);     // Klick-Aktionen
const IN = Object.create(null);    // Eingabe-Handler
const Views = Object.create(null); // Tab- und Unterseiten

function toast(msg, ms = 2200) {
  const t = $('toast'); if (!t) return;
  t.textContent = msg; t.classList.add('show');
  clearTimeout(t._t); t._t = setTimeout(() => t.classList.remove('show'), ms);
}

/** Text mit automatischer Schreibrichtung und passender Schrift. */
function txt(s, extra = '') {
  return `<span dir="auto" class="${isFaText(s) ? 'pfont ' : ''}${extra}">${esc(s)}</span>`;
}
const faSpan = (s, extra = '') => `<span class="persian ${extra}">${esc(s)}</span>`;

function applyTheme() {
  const st = DB.data.settings, root = document.documentElement;
  let theme = st.appearance;
  if (theme === 'system') theme = matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  root.setAttribute('data-theme', theme);
  if (st.animations === false) root.setAttribute('data-noanim', ''); else root.removeAttribute('data-noanim');
  const m = document.querySelector('meta[name=theme-color]');
  if (m) m.setAttribute('content', theme === 'dark' ? '#0F151B' : '#F7F3EC');
}

const ICONS = {
  today: '<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="4"/><path d="M12 3v2M12 19v2M3 12h2M19 12h2M5.6 5.6l1.4 1.4M17 17l1.4 1.4M18.4 5.6L17 7M7 17l-1.4 1.4"/></svg>',
  learn: '<svg viewBox="0 0 24 24"><path d="M12 3C8 3 5 6 5 10c0 2 1 3 1 5v3h12v-3c0-2 1-3 1-5 0-4-3-7-7-7z"/></svg>',
  cards: '<svg viewBox="0 0 24 24"><rect x="4" y="6" width="16" height="12" rx="2"/><path d="M8 3h10a2 2 0 0 1 2 2v9"/></svg>',
  stats: '<svg viewBox="0 0 24 24"><path d="M5 20V10M12 20V4M19 20v-7"/></svg>',
  more: '<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="3"/><path d="M12 3v3M12 18v3M3 12h3M18 12h3M6 6l2 2M16 16l2 2M18 6l-2 2M8 16l-2 2"/></svg>'
};
const TABS = [['today', 'Heute'], ['learn', 'Üben'], ['cards', 'Karten'], ['stats', 'Statistik'], ['more', 'Mehr']];

function renderTabs() {
  $('tabbar').innerHTML = TABS.map(([k, l]) =>
    `<button class="tab ${App.tab === k && !App.session ? 'active' : ''}" data-a="go" data-v="${k}">${ICONS[k]}<span>${l}</span></button>`).join('');
}

function currentViewKey() {
  if (App.session) return 'session:' + (typeof Session !== 'undefined' && Session.s ? Session.s.i + ':' + Session.s.steps.length : '');
  return App.sub || App.tab;
}

function render() {
  if (Store.mode === 'recovery') return renderRecovery();
  renderTabs();
  const s = $('screen');
  const key = currentViewKey();
  s.className = 'screen' + (key !== App.viewKey ? ' fadein' : '');
  App.viewKey = key;
  let html;
  if (App.session) html = Session.view();
  else if (App.sub && Views[App.sub]) html = Views[App.sub]();
  else html = (Views[App.tab] || Views.today)();
  s.innerHTML = html;
  if (App.session) Session.afterRender();
}

A.go = tab => { Session.abort(); App.tab = tab; App.sub = null; render(); $('screen').scrollTop = 0; };
A.sub = name => { App.sub = name; render(); $('screen').scrollTop = 0; };
A.back = () => { App.sub = null; render(); };

/* ---------- Dialoge ---------- */
const Dlg = { cb: null };
function openDialog(html, wide = false) {
  $('dialogRoot').innerHTML = `<div class="dlg-back" data-a="dlgBack"><div class="dlg" style="${wide ? 'max-width:440px;' : ''}">
    <button class="dlg-x" data-a="closeDialog" aria-label="Schließen">✕</button>${html}</div></div>`;
}
function closeDialog() { const d = $('dialogRoot'); if (d) d.innerHTML = ''; Dlg.cb = null; }
A.closeDialog = () => closeDialog();
A.dlgBack = (v, el, e) => { if (e.target === el) closeDialog(); };
A.dlgOk = () => { const cb = Dlg.cb; closeDialog(); if (cb) cb(); };

function confirmDialog({ icon = '⚠︎', iconColor = 'var(--warn)', title, body, ok = 'OK', danger = false, onOk }) {
  Dlg.cb = onOk;
  openDialog(`<div class="dlg-ic" style="color:${iconColor}">${icon}</div><h3>${esc(title)}</h3><p>${body}</p>
    <div class="dlg-actions"><button class="pillbtn" ${danger ? 'style="background:var(--terra)"' : ''} data-a="dlgOk">${esc(ok)}</button>
    <button class="pillbtn secondary" data-a="closeDialog">Abbrechen</button></div>`);
}

/* ---------- Fehler ---------- */
function reportError(err) {
  try { console.error(err); } catch (e) {}
  toast('Das hat nicht geklappt. Deine Daten sind sicher.', 3000);
}

/* ---------- Ereignis-Delegation ---------- */
document.addEventListener('click', e => {
  const el = e.target.closest('[data-a]');
  if (!el || el.disabled) return;
  const fn = A[el.dataset.a];
  if (!fn) return;
  try {
    const r = fn(el.dataset.v, el, e);
    if (r && typeof r.catch === 'function') r.catch(reportError);
  } catch (err) { reportError(err); }
});
document.addEventListener('input', e => {
  const el = e.target.closest('[data-i]');
  if (!el) return;
  const fn = IN[el.dataset.i];
  if (fn) try { fn(el.value, el, e); } catch (err) { reportError(err); }
});
document.addEventListener('keydown', e => {
  if (e.key !== 'Enter') return;
  const el = e.target.closest('[data-enter]');
  if (!el) return;
  e.preventDefault();
  const fn = A[el.dataset.enter];
  if (fn) try { const r = fn(el.dataset.v, el, e); if (r && r.catch) r.catch(reportError); } catch (err) { reportError(err); }
});
/* Langer Druck (z. B. Tag löschen) */
(function () {
  let timer = null, fired = false;
  document.addEventListener('pointerdown', e => {
    const el = e.target.closest('[data-lp]');
    fired = false; clearTimeout(timer);
    if (!el) return;
    timer = setTimeout(() => { fired = true; const fn = A[el.dataset.lp]; if (fn) try { fn(el.dataset.v, el, e); } catch (err) { reportError(err); } }, 550);
  });
  ['pointerup', 'pointercancel', 'pointermove', 'scroll'].forEach(ev => document.addEventListener(ev, () => clearTimeout(timer), true));
  document.addEventListener('contextmenu', e => { if (e.target.closest('[data-lp]')) e.preventDefault(); });
  document.addEventListener('click', e => { if (fired && e.target.closest('[data-lp]')) { e.stopPropagation(); e.preventDefault(); fired = false; } }, true);
})();
window.addEventListener('error', e => { try { console.error(e.error || e.message); } catch (_) {} });
window.addEventListener('unhandledrejection', e => { try { console.error(e.reason); } catch (_) {} });
