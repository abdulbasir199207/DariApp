/* ============================================================
   50-scheduler: Fälligkeit, „schwierige Wörter", Warteschlangen.
   Adaptives Lernen: Je öfter ein Wort falsch war (oder je schwieriger
   FSRS es einstuft), desto früher und häufiger kommt es wieder.
   ============================================================ */

function isDue(c, t = now()) { if (!c.active) return false; if (!c.nextReview) return true; return c.nextReview <= t; }

/** 0 = sicher beherrscht … >1,2 = schwierig. Kombiniert Fehlerquote, FSRS-Schwierigkeit, Rückfälle, Spiel-Fehler, Vergessenswahrscheinlichkeit. */
function weakScore(c, t = now()) {
  const reps = c.reps || 0;
  if (!reps) return 0;
  const wrongRate = clamp((c.wrong || 0) / reps, 0, 1);
  const dNorm = (clamp(c.d || 5, 1, 10) - 1) / 9;
  const lapse = Math.min(c.lapses || 0, 5) / 5;
  const miss = Math.min(c.miss || 0, 5) / 5;
  const retr = (c.s > 0 && c.lastReview) ? FSRS.R(Math.max(t - c.lastReview, 0) / DAY, c.s) : 1;
  return wrongRate * 2 + dNorm * 1.2 + lapse + miss * 0.5 + (1 - retr) * 0.8;
}
const WEAK_THRESHOLD = 1.2;
function isWeak(c, t = now()) { return c.active && (c.reps || 0) >= 1 && weakScore(c, t) >= WEAK_THRESHOLD; }
function weakCards(cards, t = now()) {
  return cards.filter(c => isWeak(c, t)).sort((a, b) => weakScore(b, t) - weakScore(a, t));
}

/** Lern-Warteschlange: Fälligkeit dominiert, Schwierigkeit erhöht die Häufigkeit, Rauschen sorgt für Abwechslung. */
function buildQueue(cards, limit, rng = Math.random, t = now()) {
  const active = cards.filter(c => c.active);
  const due = active.filter(c => isDue(c, t));
  const pool = due.length ? due : active;
  const scored = pool.map(c => {
    const overdue = c.nextReview ? Math.max((t - c.nextReview) / DAY, 0) : 2.0;
    return { c, p: overdue * 2 + weakScore(c, t) * 0.8 + rng() };
  }).sort((a, b) => b.p - a.p).map(x => x.c);
  // Tag-Interleaving: nicht zwei Karten desselben (ersten) Tags direkt nacheinander.
  const res = []; const rem = scored.slice();
  while (rem.length) {
    const last = res.length ? (res[res.length - 1].tags[0] || null) : null;
    let i = rem.findIndex(c => (c.tags[0] || null) !== last);
    if (i < 0) i = 0;
    res.push(rem.splice(i, 1)[0]);
  }
  return limit ? res.slice(0, limit) : res;
}

/* ----- Sätze & Grammatik: einfaches Leitner-System (Kästen 0…5) ----- */
const SENT_DAYS = [0, 1, 2, 4, 8, 16];

function sentUpdate(sent, id, ok, t = now()) {
  const s = sent[id] || (sent[id] = { box: 0, due: 0, ok: 0, bad: 0, last: 0 });
  if (ok) { s.ok++; s.box = Math.min(s.box + 1, 5); } else { s.bad++; s.box = 0; }
  s.due = t + SENT_DAYS[s.box] * DAY; s.last = t;
  return s;
}

/** Wählt n Elemente: erst fällige/schwache, dann neue, dann der Rest. */
function pickItems(items, sent, n, rng = Math.random, t = now()) {
  const scored = items.map(it => {
    const s = sent[it.id];
    let p;
    if (!s) p = 1.5 + rng() * 0.5;                       // neu
    else if (s.due <= t) p = 2 + (6 - s.box) * 0.3 + (s.bad / Math.max(s.ok + s.bad, 1)) + rng() * 0.3;  // fällig
    else p = rng() * 0.4;                                 // noch nicht fällig
    return { it, p };
  });
  return scored.sort((a, b) => b.p - a.p).slice(0, n).map(x => x.it);
}
