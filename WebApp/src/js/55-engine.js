/* ============================================================
   55-engine: Antworten verbuchen (FSRS, Verlauf, Sätze) und
   Statistik/Spielelemente berechnen. Keine DOM-Zugriffe.
   ============================================================ */

const Engine = {
  /**
   * Verbucht die Antwort auf eine Vokabelkarte.
   * opts: {mode, time, practice (nur Übung, ändert FSRS nicht), fsrs (default true)}
   */
  recordCard(card, rating, opts = {}) {
    const t = now();
    const mode = opts.mode || 'flip';
    const wasWeak = isWeak(card, t);
    const useFsrs = opts.fsrs !== false && !opts.practice;
    if (useFsrs) {
      const r = FSRS.schedule({ state: card.state, s: card.s, d: card.d, lastReview: card.lastReview }, rating, t);
      card.s = r.s; card.d = r.d; card.state = r.state; card.interval = r.interval;
      card.lastReview = t; card.nextReview = r.due; card.lastTime = opts.time || 0;
      card.reps = (card.reps || 0) + 1;
      if (rating === 1) { card.wrong = (card.wrong || 0) + 1; if (card.state === 'relearning') card.lapses = (card.lapses || 0) + 1; }
      else card.correct = (card.correct || 0) + 1;
    } else if (rating === 1) {
      card.miss = (card.miss || 0) + 1;      // Fehler in Spielen/Übungswiederholung fließt in die Schwäche-Bewertung ein
    }
    const log = { date: t, rating, time: opts.time || 0, mode, cardId: card.id };
    if (opts.practice) log.p = 1;
    if (wasWeak) log.wk = 1;
    DB.data.logs.push(log);
    return log;
  },

  /** Verbucht eine Satz-/Grammatikaufgabe. */
  recordItem(itemId, ok, opts = {}) {
    const t = now();
    if (!opts.practice) sentUpdate(DB.data.sent, itemId, ok, t);   // Übungswiederholungen ändern den Leitner-Kasten nicht
    const log = { date: t, rating: ok ? (opts.rating || 3) : 1, time: opts.time || 0, mode: opts.mode || 'sent', itemId };
    if (opts.practice) log.p = 1;
    DB.data.logs.push(log);
    return log;
  }
};

/* ---------- Statistik, Level, Erfolge ---------- */
function levelInfo(xp) {
  const level = Math.floor(Math.sqrt(Math.max(xp, 0) / 50)) + 1;
  const base = 50 * (level - 1) * (level - 1), next = 50 * level * level;
  return { level, xp, base, next, pct: Math.round((xp - base) / (next - base) * 100) };
}

function shiftDay(key, delta) {
  const [y, m, d] = key.split('-').map(Number);
  const dt = new Date(y, m - 1, d + delta, 12);   // 12 Uhr: unempfindlich gegen Sommerzeit
  return dayKey(dt.getTime());
}

function computeStats(data = DB.data, t = now()) {
  const cards = data.cards, logs = data.logs, arch = data.logArchive || {};
  const total = cards.length, active = cards.filter(c => c.active).length;
  const todayKey = dayKey(t);
  const todayLogs = logs.filter(l => dayKey(l.date) === todayKey);
  const today = todayLogs.filter(l => !l.p).length;

  let n = 0, ok = 0, time = 0, xp = 0;
  const days = new Set(Object.keys(arch).filter(k => arch[k].n > 0));
  for (const [, a] of Object.entries(arch)) { n += a.n; ok += a.ok; time += a.t; xp += a.xp; }
  for (const l of logs) { n++; if (l.rating !== 1) ok++; time += l.time; xp += xpForLog(l); days.add(dayKey(l.date)); }

  let streak = 0, k = todayKey;
  if (!days.has(k)) k = shiftDay(k, -1);
  while (days.has(k)) { streak++; k = shiftDay(k, -1); }

  const perDay = [];
  for (let off = 13; off >= 0; off--) {
    const key = shiftDay(todayKey, -off);
    const fromLogs = logs.filter(l => dayKey(l.date) === key).length;
    perDay.push(fromLogs || (arch[key] ? arch[key].n : 0));
  }

  const tc = {}; cards.forEach(c => c.tags.forEach(tg => tc[tg] = (tc[tg] || 0) + 1));
  const known = { neu: 0, lernend: 0, gefestigt: 0 };
  for (const c of cards) {
    if (!c.active) continue;
    if (!c.reps) known.neu++; else if (c.s >= 21) known.gefestigt++; else known.lernend++;
  }
  const weak = weakCards(cards, t);
  const goal = (data.settings && data.settings.dailyGoal) || 20;
  const wkRight = logs.filter(l => l.wk && l.rating >= 3).length;
  return {
    total, active, inactive: total - active, today, goal, goalPct: Math.min(100, Math.round(today / goal * 100)),
    reviews: n, rate: n ? ok / n : 0, avg: n ? time / n : 0, streak, perDay, xp, level: levelInfo(xp),
    hardest: weak.slice(0, 5), weakCount: weak.length,
    topTags: Object.entries(tc).sort((a, b) => b[1] - a[1]).slice(0, 6),
    dueCount: cards.filter(c => isDue(c, t)).length, known, learnedCards: cards.filter(c => c.reps > 0).length, wkRight
  };
}

const ACHIEVEMENTS = [
  { id: 'start', icon: '★', name: 'Erster Schritt', desc: 'Die erste Antwort gegeben.', test: s => s.reviews >= 1 },
  { id: 'streak3', icon: '🔥', name: '3 Tage in Folge', desc: 'Drei Tage hintereinander gelernt.', test: s => s.streak >= 3 },
  { id: 'streak7', icon: '🔥', name: 'Eine Woche', desc: '7 Tage Lernserie.', test: s => s.streak >= 7 },
  { id: 'streak30', icon: '🏆', name: 'Ein Monat', desc: '30 Tage Lernserie.', test: s => s.streak >= 30 },
  { id: 'goal', icon: '◎', name: 'Tagesziel', desc: 'Das Tagesziel heute erreicht.', test: s => s.today >= s.goal },
  { id: 'words50', icon: '▤', name: '50 Wörter', desc: '50 Wörter schon geübt.', test: s => s.learnedCards >= 50 },
  { id: 'words200', icon: '▤', name: '200 Wörter', desc: '200 Wörter schon geübt.', test: s => s.learnedCards >= 200 },
  { id: 'weak10', icon: '✓', name: 'Schwächen besiegt', desc: '10× ein schwieriges Wort richtig beantwortet.', test: s => s.wkRight >= 10 },
  { id: 'solid20', icon: '◆', name: 'Gefestigt', desc: '20 Wörter fest im Gedächtnis.', test: s => s.known.gefestigt >= 20 }
];
