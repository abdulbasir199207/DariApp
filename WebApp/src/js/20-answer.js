/* ---------- Antwortprüfung ----------
   Ergebnis: 'perfect' | 'typo' | 'wrong'.
   Regeln: Groß-/Kleinschreibung, Leerzeichen und Satzzeichen am Rand zählen
   nicht. Persisch: Zeichenvarianten (arabisches Ya/Kaf), Diakritika und
   Halbleerzeichen (ZWNJ) werden vereinheitlicht, Ziffern ۱۲۳ = 123.
   Das „آ" (Alef mit Madda) bleibt unterscheidbar: „اب" statt „آب" ist nur
   ein Tippfehler. Deutsch: ä/ö/ü/ß dürfen als ae/oe/ue/ss getippt werden;
   ein fehlender Artikel zählt als Tippfehler. */
const Answer = {
  persianMap: { 'ي': 'ی', 'ك': 'ک', 'ۀ': 'ه', 'ة': 'ه', 'أ': 'ا', 'إ': 'ا', 'ؤ': 'و', 'ى': 'ی' },
  strip: new Set(['ً', 'ٌ', 'ٍ', 'َ', 'ُ', 'ِ', 'ّ',
    'ْ', 'ٰ', 'ـ', '‌', '‍', '﻿']),
  edgePunct: /^[\s.,;:!?'"“”„‚‘’«»()\[\]\-–—…،؛؟]+|[\s.,;:!?'"“”„‚‘’«»()\[\]\-–—…،؛؟]+$/g,
  articles: ['der', 'die', 'das', 'ein', 'eine', 'einen', 'einem', 'einer', 'den', 'dem', 'des'],

  digits(s) {
    return s.replace(/[٠-٩]/g, c => String(c.charCodeAt(0) - 0x0660))
            .replace(/[۰-۹]/g, c => String(c.charCodeAt(0) - 0x06F0));
  },
  normalize(t, fa) {
    let s = String(t == null ? '' : t).normalize('NFC').trim().toLowerCase();
    s = this.digits(s).replace(this.edgePunct, '');
    s = s.split(/\s+/).filter(Boolean).join(' ');
    if (fa) s = [...s].map(c => this.persianMap[c] || c).filter(c => !this.strip.has(c)).join('');
    return s;
  },
  /** Gröbere Faltung: nur für den „zählt als Variante"-Vergleich. */
  fold(s, fa) {
    if (fa) return s.replace(/آ/g, 'ا');
    return s.replace(/ä/g, 'ae').replace(/ö/g, 'oe').replace(/ü/g, 'ue').replace(/ß/g, 'ss');
  },
  lev(a, b) {
    a = [...a]; b = [...b];
    if (!a.length) return b.length;
    if (!b.length) return a.length;
    let prev = Array.from({ length: b.length + 1 }, (_, i) => i), cur = new Array(b.length + 1);
    for (let i = 1; i <= a.length; i++) {
      cur[0] = i;
      for (let j = 1; j <= b.length; j++) {
        const cost = a[i - 1] === b[j - 1] ? 0 : 1;
        cur[j] = Math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost);
      }
      [prev, cur] = [cur, prev];
    }
    return prev[b.length];
  },
  stripArticle(s) {
    const i = s.indexOf(' ');
    if (i > 0 && this.articles.includes(s.slice(0, i))) return s.slice(i + 1);
    return s;
  },
  evaluate(input, solutions, fa) {
    const ni = this.normalize(input, fa);
    if (!ni) return 'wrong';
    const sols = (solutions || []).map(s => this.normalize(s, fa)).filter(Boolean);
    if (sols.includes(ni)) return 'perfect';
    const fi = this.fold(ni, fa);
    let best = 'wrong';
    for (const s of sols) {
      const fs = this.fold(s, fa);
      if (fi === fs) {
        if (!fa) return 'perfect';          // ae/oe/ue/ss-Schreibweise ist korrekt
        best = 'typo'; continue;            // آ/ا-Verwechslung
      }
      if (!fa && this.stripArticle(s) === ni && s !== ni) { best = 'typo'; continue; }
      const d = this.lev(fi, fs);
      const tol = fs.length >= 4 ? 1 : 0;
      if (d > 0 && d <= tol) best = 'typo';
    }
    return best;
  },
  /** Satzbewertung: Toleranz wächst mit der Länge (max. ~8 %). */
  evaluateSentence(input, solutions, fa) {
    const ni = this.fold(this.normalize(input, fa), fa);
    if (!ni) return 'wrong';
    let best = 'wrong';
    for (const sol of solutions) {
      const ns = this.fold(this.normalize(sol, fa), fa);
      if (ni === ns) return 'perfect';
      const tol = Math.max(1, Math.floor(ns.length * 0.08));
      if (this.lev(ni, ns) <= tol) best = 'typo';
    }
    return best;
  }
};
function ratingFromQuality(q, fast) { if (q === 'perfect') return fast ? 4 : 3; if (q === 'typo') return 2; return 1; }
