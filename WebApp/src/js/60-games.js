/* ============================================================
   60-games: Aufgaben-Generatoren (rein, ohne DOM, mit injizierbarem
   Zufall). Jede Funktion liefert alles, was die Oberfläche braucht.
   ============================================================ */

const isFaText = s => /[؀-ۿ]/.test(s || '');
const normKey = s => Answer.normalize(s, true);

/** Vorkommende Wörter der Satzbibliothek (Reserve für Ablenker bei wenigen Karten). */
function libraryWords(lang, pos) {
  const out = new Set();
  for (const s of SENTENCES) {
    const toks = lang === 'fa' ? s.faT : s.deT, ps = lang === 'fa' ? s.pf : s.pd;
    toks.forEach((t, i) => { if (!pos || pos.includes(ps[i])) out.add(t); });
  }
  return [...out];
}

/** Auswahlmöglichkeiten: richtige Antwort + bis zu n-1 Ablenker aus `pool` (ohne Duplikate/Synonyme). */
function makeChoices(correct, pool, exclude = [], n = 4, rng = Math.random) {
  const ex = new Set([correct, ...exclude].map(normKey));
  const seen = new Set();
  const dis = [];
  for (const p of shuffle(pool, rng)) {
    const k = normKey(p);
    if (!p || ex.has(k) || seen.has(k)) continue;
    seen.add(k); dis.push(p);
    if (dis.length >= n - 1) break;
  }
  const options = shuffle([correct, ...dis], rng);
  return { options, correctIdx: options.indexOf(correct) };
}

/** Multiple-Choice für eine Karte. answerIsFa: Antwort ist persisch. */
function makeCardChoices(card, answerIsFa, cards, rng = Math.random) {
  const key = answerIsFa ? 'fa' : 'de';
  const correct = card[key][0] || '';
  const tagSet = new Set(card.tags);
  const others = cards.filter(o => o.id !== card.id);
  const sameTag = shuffle(others.filter(o => o.tags.some(t => tagSet.has(t))), rng);
  const rest = shuffle(others.filter(o => !o.tags.some(t => tagSet.has(t))), rng);
  let pool = sameTag.concat(rest).map(o => o[key][0]).filter(Boolean);
  const exclude = card[key];
  const base = makeChoices(correct, pool, exclude, 4, rng);
  if (base.options.length < 4) {      // zu wenige Karten: Reserve aus der Satzbibliothek
    return makeChoices(correct, pool.concat(libraryWords(key, 'N')), exclude, 4, rng);
  }
  return base;
}

/** Zuordnungsspiel: wählt n Karten mit eindeutigen Wörtern. */
function makeMatchRound(candidates, n = 5) {
  const picked = [], sd = new Set(), sf = new Set();
  for (const c of candidates) {
    const de = c.de[0], fa = c.fa[0];
    if (!de || !fa) continue;
    const kd = Answer.normalize(de, false), kf = normKey(fa);
    if (sd.has(kd) || sf.has(kf)) continue;
    sd.add(kd); sf.add(kf); picked.push(c);
    if (picked.length >= n) break;
  }
  return picked;
}

/** Fügt die Groß-/Kleinschreibung des ersten Buchstabens von `ref` auf `tok` an. */
function matchCase(tok, ref) {
  if (!tok || !ref) return tok;
  const up = ref[0] !== ref[0].toLowerCase();
  return (up ? tok[0].toUpperCase() : tok[0].toLowerCase()) + tok.slice(1);
}

/** Lückentext. lang: Sprache des Satzes mit Lücke ('fa'|'de'). */
function makeCloze(sent, lang, rng = Math.random, library = SENTENCES) {
  const toks = lang === 'fa' ? sent.faT : sent.deT;
  const pos = lang === 'fa' ? sent.pf : sent.pd;
  let allowed = (lang === 'fa' ? sent.bf : sent.bd);
  if (!allowed) allowed = toks.map((_, i) => i).filter(i => BLANK_POS.includes(pos[i]));
  const idx = allowed[Math.floor(rng() * allowed.length)];
  const answer = toks[idx];
  const wantPos = pos[idx];
  const fromSame = [], fromAny = [];
  for (const o of library) {
    if (o.id === sent.id) continue;
    const ot = lang === 'fa' ? o.faT : o.deT, op = lang === 'fa' ? o.pf : o.pd;
    ot.forEach((t, i) => {
      if (!BLANK_POS.includes(op[i])) return;
      const cand = lang === 'de' ? matchCase(t, answer) : t;
      (op[i] === wantPos ? fromSame : fromAny).push(cand);
    });
  }
  let ch = makeChoices(answer, fromSame, [], 4, rng);
  if (ch.options.length < 4) ch = makeChoices(answer, fromSame.concat(fromAny), [], 4, rng);
  return {
    sentId: sent.id, lang, idx, answer,
    tokens: toks.map((t, i) => i === idx ? null : t),
    options: ch.options, correctIdx: ch.correctIdx,
    hint: lang === 'fa' ? sent.de : sent.fa, hintIsFa: lang !== 'fa',
    full: lang === 'fa' ? sent.fa : sent.de, tr: sent.tr, end: lang === 'fa' ? (sent.q ? '؟' : '.') : (sent.q ? '?' : '.')
  };
}

/** Satzbildung: Wörter in die richtige Reihenfolge bringen. dir: 'g2p' (→ Persisch) | 'p2g' (→ Deutsch). */
function makeBuild(sent, dir, rng = Math.random) {
  const toFa = dir === 'g2p';
  const solution = toFa ? sent.faT : sent.deT;
  const items = solution.map((t, i) => ({ id: i, t }));
  let sh = shuffle(items, rng);
  if (solution.length > 1 && sh.every((x, i) => x.id === i)) sh = sh.slice().reverse();
  return {
    sentId: sent.id, dir, tokens: sh, solution,
    alts: toFa ? sent.alts.map(a => a.split(' ')) : [],
    prompt: toFa ? sent.de : sent.fa, promptIsFa: !toFa, answerIsFa: toFa,
    full: toFa ? sent.fa : sent.de, tr: sent.tr, end: toFa ? (sent.q ? '؟' : '.') : (sent.q ? '?' : '.')
  };
}
function checkBuild(b, chosen) {
  const norm = a => a.map(t => Answer.normalize(t, b.answerIsFa)).join(' ');
  const c = norm(chosen);
  return [b.solution, ...b.alts].some(s => norm(s) === c);
}

/** Übersetzungsübung (Tippen). */
function makeTranslate(sent, dir) {
  const toFa = dir === 'g2p';
  return {
    sentId: sent.id, dir, prompt: toFa ? sent.de : sent.fa, promptIsFa: !toFa, answerIsFa: toFa,
    solutions: [toFa ? sent.fa : sent.de, ...(toFa ? sent.alts.map(a => a + (sent.q ? '؟' : '.')) : [])],
    tr: sent.tr
  };
}

/** Grammatikfrage mit gemischten Antworten. */
function makeGrammar(item, rng = Math.random) {
  const options = shuffle(item.a, rng);
  return { itemId: item.id, lang: item.lang, topic: item.topic, q: item.q, options,
    correctIdx: options.indexOf(item.a[0]), e: item.e, x: item.x || '' };
}

/** Hörverständnis. spoken: 'de' (Deutsch hören, Persisch wählen) | 'fa' (Persisch hören, Deutsch wählen). */
function makeListen(card, spoken, cards, rng = Math.random) {
  const answerIsFa = spoken === 'de';
  const speakText = spoken === 'fa' ? card.fa[0] : card.de[0];
  const ch = makeCardChoices(card, answerIsFa, cards, rng);
  return { cardId: card.id, spoken, speakText, options: ch.options, correctIdx: ch.correctIdx, answerIsFa };
}

/* ---------- Aufgabenfolgen ("Pläne") ---------- */
function resolveDir(direction, rng = Math.random) {
  return direction === 'mixed' ? (rng() < 0.5 ? 'g2p' : 'p2g') : direction;
}

/** Vokabel-Lektion (Umdrehen / Multiple Choice / Schreiben). */
function planVocab(cards, { mode, direction, limit, weak = false }, rng = Math.random) {
  const queue = buildQueue(cards, limit, rng);
  return queue.map(c => ({ type: mode, cardId: c.id, dir: resolveDir(direction, rng), weak: weak || isWeak(c) }));
}

/** Schwierige Wörter üben: nur schwache Karten, abwechselnd Auswahl und Schreiben. */
function planWeak(cards, { direction, limit = 12 }, rng = Math.random) {
  const list = weakCards(cards).slice(0, limit);
  const useMc = cards.length >= 4;
  return list.map((c, i) => ({ type: (useMc && i % 2 === 0) ? 'mc' : 'write', cardId: c.id, dir: resolveDir(direction, rng), weak: true }));
}

/** Kandidaten für Zuordnung/Hören: schwache zuerst, dann fällige, dann der Rest (jeweils gemischt). */
function gameCandidates(cards, rng = Math.random) {
  const active = cards.filter(c => c.active);
  const w = shuffle(weakCards(active), rng);
  const d = shuffle(active.filter(c => isDue(c) && !w.includes(c)), rng);
  const rest = shuffle(active.filter(c => !w.includes(c) && !d.includes(c)), rng);
  return w.concat(d, rest);
}

function planMatch(cards, rounds = 3, rng = Math.random, direction = 'g2p') {
  const steps = [];
  let pool = gameCandidates(cards, rng);
  for (let r = 0; r < rounds; r++) {
    const pick = makeMatchRound(pool, 5);
    if (pick.length < 3) break;
    steps.push({ type: 'match', dir: resolveDir(direction, rng), cardIds: pick.map(c => c.id), left: shuffle(pick.map(c => c.id), rng), right: shuffle(pick.map(c => c.id), rng) });
    pool = pool.filter(c => !pick.includes(c)).concat(pick);   // verbrauchte Karten ans Ende
  }
  return steps;
}

function planListen(cards, { direction, count = 10, canSpeakFa, canSpeakDe }, rng = Math.random) {
  const out = [];
  for (const c of gameCandidates(cards, rng)) {
    if (out.length >= count) break;
    let spoken = direction === 'g2p' ? 'de' : direction === 'p2g' ? 'fa' : (rng() < 0.5 ? 'de' : 'fa');
    const okFa = canSpeakFa || c.audio, okDe = canSpeakDe;
    if (spoken === 'fa' && !okFa) spoken = 'de';
    if (spoken === 'de' && !okDe) { if (okFa) spoken = 'fa'; else continue; }
    out.push({ type: 'listen', cardId: c.id, spoken });
  }
  return out;
}

function planSentences(type, sent, { count = 8, direction = 'mixed', lang = null }, rng = Math.random) {
  const picked = pickItems(SENTENCES, sent, count, rng);
  return picked.map(s => {
    const dir = resolveDir(direction, rng);
    const step = { type, sentId: s.id, dir };
    if (type === 'cloze') step.lang = lang || (dir === 'g2p' ? 'fa' : 'de');
    return step;
  });
}

function planGrammar(sent, { lang, topic = null, count = 10 }, rng = Math.random) {
  const pool = GRAMMAR.filter(g => g.lang === lang && (!topic || g.topic === topic));
  return pickItems(pool, sent, count, rng).map(g => ({ type: 'grammar', itemId: g.id }));
}

function planSpeak(cards, count = 8, rng = Math.random) {
  return gameCandidates(cards, rng).slice(0, count).map(c => ({ type: 'speak', cardId: c.id }));
}

/** „5-Minuten-Spiel": abwechslungsreiche Mischung (~12 Aufgaben). */
function planMix(data, { direction, canSpeakFa, canSpeakDe }, rng = Math.random) {
  const cards = data.cards.filter(c => c.active);
  const steps = [];
  if (cards.length >= 3) steps.push(...planMatch(cards, 1, rng, direction));
  const vocab = gameCandidates(cards, rng).slice(0, 6);
  vocab.forEach((c, i) => {
    const dir = resolveDir(direction, rng);
    steps.push({ type: i % 3 === 2 ? 'write' : 'mc', cardId: c.id, dir, weak: isWeak(c) });
  });
  steps.push(...planListen(cards, { direction, count: 2, canSpeakFa, canSpeakDe }, rng));
  steps.push(...planCloze(data, { count: 2, direction }, rng));
  steps.push(...planSentences('build', data.sent, { count: 1, direction }, rng));
  steps.push(...planGrammar(data.sent, { lang: 'fa', count: 2 }, rng));
  return steps;
}

/** Nach einem Fehler: dieselbe Aufgabe wenige Positionen später als Übung wiederholen. */
function requeueStep(steps, index, gap = 3) {
  const step = Object.assign({}, steps[index], { practice: true, retry: true });
  const at = Math.min(index + 1 + gap, steps.length);
  steps.splice(at, 0, step);
  return step;
}

/* ---------- Lückentext aus eigenen Karten (Beispielsatz auf der Karte) ---------- */
const EDGE_PUNCT = /^[\s.,;:!?…«»()"'،؛؟]+|[\s.,;:!?…«»()"'،؛؟]+$/g;

/** Persischer Beispielsatz der Karte mit Lücke beim Kartenwort; null, wenn das Wort im Satz nicht vorkommt. */
function makeCardCloze(card, cards, rng = Math.random) {
  if (!card.exFa || !card.exFa.trim()) return null;
  const toks = card.exFa.trim().split(/\s+/);
  const keys = card.fa.map(normKey);
  const idx = toks.findIndex(t => keys.includes(normKey(t)));
  if (idx < 0) return null;
  const raw = toks[idx], answer = raw.replace(EDGE_PUNCT, '');
  const trail = raw.slice(raw.indexOf(answer) + answer.length);
  const pool = cards.filter(o => o.id !== card.id).map(o => o.fa[0]).filter(Boolean);
  let ch = makeChoices(answer, pool, card.fa, 4, rng);
  if (ch.options.length < 4) ch = makeChoices(answer, pool.concat(libraryWords('fa', 'N')), card.fa, 4, rng);
  return {
    sentId: null, cardId: card.id, lang: 'fa', idx, answer, trail,
    tokens: toks.map((t, i) => i === idx ? null : t),
    options: ch.options, correctIdx: ch.correctIdx,
    hint: card.exDe || card.de[0], hintIsFa: false, full: card.exFa, tr: '', end: ''
  };
}

/** Lückentext-Folge: bis zu 1/3 aus eigenen Beispielsätzen, Rest aus der Satzbibliothek. */
function planCloze(data, { count = 10, direction = 'mixed' }, rng = Math.random) {
  const mine = shuffle(data.cards.filter(c => c.active && c.exFa && makeCardCloze(c, data.cards, rng)), rng)
    .slice(0, Math.floor(count / 3)).map(c => ({ type: 'ccloze', cardId: c.id, lang: 'fa' }));
  const lib = planSentences('cloze', data.sent, { count: count - mine.length, direction }, rng);
  return shuffle(lib.concat(mine), rng);
}
