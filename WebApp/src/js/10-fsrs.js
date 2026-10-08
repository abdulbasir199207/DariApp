/* ---------- FSRS 4.5 ----------
   Free Spaced Repetition Scheduler. Rein funktional.
   KORREKTUR gegenüber v2.0: Die Anfangsschwierigkeit D0 und die
   Mittelwert-Rückkehr nutzen jetzt die FSRS-4.5-Formeln. Zuvor wurde die
   FSRS-5-Formel mit 4.5-Gewichten kombiniert, wodurch „Gut"/„Leicht" bei der
   ersten Antwort Schwierigkeit 1,0 statt ~5,2 bzw. ~3,9 ergaben. */
const FSRS = {
  w: [0.4872, 1.4003, 3.7145, 13.8206, 5.1618, 1.2298, 0.8975, 0.0310, 1.6474,
      0.1367, 1.0461, 2.1072, 0.0793, 0.3246, 1.5870, 0.2272, 2.8755],
  retention: 0.90, maxInterval: 365, decay: -0.5, factor: 19 / 81,

  /** Abrufwahrscheinlichkeit nach t Tagen bei Stabilität S. */
  R(t, S) { if (S <= 0) return 0; return Math.pow(1 + this.factor * t / S, this.decay); },
  /** D0(G) = w4 − (G − 3)·w5 */
  initD(g) { return clamp(this.w[4] - (g - 3) * this.w[5], 1, 10); },
  initS(g) { return Math.max(this.w[g - 1], 0.1); },
  /** D' = D − w6·(G − 3), danach Mittelwert-Rückkehr zu w4. */
  nextD(d, g) {
    const nd = d - this.w[6] * (g - 3);
    return clamp(this.w[7] * this.w[4] + (1 - this.w[7]) * nd, 1, 10);
  },
  recallS(d, s, r, g) {
    const hard = (g === 2) ? this.w[15] : 1;
    const easy = (g === 4) ? this.w[16] : 1;
    const f = Math.exp(this.w[8]) * (11 - d) * Math.pow(s, -this.w[9])
      * (Math.exp(this.w[10] * (1 - r)) - 1) * hard * easy;
    return s * (1 + f);
  },
  forgetS(d, s, r) {
    return this.w[11] * Math.pow(d, -this.w[12]) * (Math.pow(s + 1, this.w[13]) - 1)
      * Math.exp(this.w[14] * (1 - r));
  },
  interval(S) {
    const raw = S / this.factor * (Math.pow(this.retention, 1 / this.decay) - 1);
    return clamp(Math.round(raw), 1, this.maxInterval);
  },
  /** card: {state,s,d,lastReview}; g: 1..4. Gibt neue Werte zurück (mutiert nicht). */
  schedule(card, g, reviewDate) {
    const elapsed = card.lastReview ? Math.max((reviewDate - card.lastReview) / DAY, 0) : 0;
    let nd, ns, nstate;
    if (card.state === 'new' || !card.state) {
      nd = this.initD(g); ns = this.initS(g); nstate = (g === 1) ? 'learning' : 'review';
    } else {
      const r = this.R(elapsed, card.s || 0);
      nd = this.nextD(card.d || 5, g);
      if (g === 1) { ns = this.forgetS(nd, card.s || 0.1, r); nstate = 'relearning'; }
      else { ns = this.recallS(nd, card.s || 0.1, r, g); nstate = 'review'; }
    }
    ns = Math.max(ns, 0.1);
    const iv = this.interval(ns);
    return { s: ns, d: clamp(nd, 1, 10), state: nstate, interval: iv, due: reviewDate + iv * DAY };
  },
  /** Schwierigkeit aus einer Bewertungsfolge neu herleiten (Migration v2→v3). */
  replayD(ratings) {
    if (!ratings.length) return null;
    let d = this.initD(ratings[0]);
    for (let i = 1; i < ratings.length; i++) d = this.nextD(d, ratings[i]);
    return d;
  }
};
