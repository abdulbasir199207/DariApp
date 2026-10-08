/* ============================================================
   ZARA – Web-Version (PWA). Vollständig offline, lokal.
   00-util: kleine, seiteneffektfreie Hilfsfunktionen.
   ============================================================ */

const APP_NAME = 'ZARA';
const APP_VERSION = '3.0 · Okt 2026';   // zum Prüfen, ob die neueste Version geladen ist
const DAY = 86400000;

const now = () => Date.now();
const uid = () => Date.now().toString(36) + Math.random().toString(36).slice(2, 8);
const clamp = (v, lo, hi) => Math.min(Math.max(v, lo), hi);

/** HTML-Escape für Text UND Attributwerte (inkl. Apostroph). */
function esc(s) {
  return String(s == null ? '' : s).replace(/[&<>"']/g, c => (
    { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

/** Fisher-Yates; rng injizierbar (Tests). Gibt eine Kopie zurück. */
function shuffle(arr, rng = Math.random) {
  const a = arr.slice();
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(rng() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

/** Beginn des lokalen Kalendertags (ms). */
function startOfDay(ts) {
  const d = new Date(ts == null ? now() : ts);
  d.setHours(0, 0, 0, 0);
  return d.getTime();
}

/** Lokaler Tagesschlüssel „YYYY-MM-DD". */
function dayKey(ts) {
  const d = new Date(ts == null ? now() : ts);
  const p = n => String(n).padStart(2, '0');
  return d.getFullYear() + '-' + p(d.getMonth() + 1) + '-' + p(d.getDate());
}

/** Schnelle, stabile 32-Bit-Prüfsumme (FNV-1a) als Hex-String. */
function checksum(str) {
  let h = 0x811c9dc5;
  for (let i = 0; i < str.length; i++) {
    h ^= str.charCodeAt(i);
    h = Math.imul(h, 0x01000193) >>> 0;
  }
  return h.toString(16).padStart(8, '0');
}

/** Tiefe Kopie für reine JSON-Daten. */
const clone = o => JSON.parse(JSON.stringify(o));

/** Nimmt bis zu n zufällige Elemente. */
function sample(arr, n, rng = Math.random) { return shuffle(arr, rng).slice(0, n); }
