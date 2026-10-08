import { test } from 'node:test';
import assert from 'node:assert/strict';
import { loadApi, seeded } from './helpers.mjs';

const { api } = loadApi();
const { FSRS, Answer } = api;
const plain = x => JSON.parse(JSON.stringify(x));   // VM-Objekte → Hauptrealm (für deepEqual)

/* ---------- FSRS ---------- */
test('FSRS-4.5: Anfangsschwierigkeit D0 (Nochmal/Schwer/Gut/Leicht)', () => {
  const d = [1, 2, 3, 4].map(g => FSRS.initD(g));
  assert.ok(Math.abs(d[0] - 7.6214) < 1e-3);
  assert.ok(Math.abs(d[1] - 6.3916) < 1e-3);
  assert.ok(Math.abs(d[2] - 5.1618) < 1e-3);
  assert.ok(Math.abs(d[3] - 3.9320) < 1e-3);
  assert.ok(d[0] > d[1] && d[1] > d[2] && d[2] > d[3], 'schwerer bewertet = schwieriger');
});

test('FSRS: neue Karte mit „Gut" startet NICHT bei Schwierigkeit 1', () => {
  const r = FSRS.schedule({ state: 'new', s: 0, d: 0, lastReview: null }, 3, Date.now());
  assert.ok(r.d > 4, 'D=' + r.d);
  assert.equal(r.state, 'review');
  assert.ok(r.interval >= 1);
});

test('FSRS: Mittelwert-Rückkehr hält die Schwierigkeit in 1…10, „Nochmal" erhöht, „Leicht" senkt', () => {
  let d = 5;
  for (let i = 0; i < 40; i++) d = FSRS.nextD(d, 1);
  assert.ok(d <= 10 && d > 5);
  let e = 5;
  for (let i = 0; i < 40; i++) e = FSRS.nextD(e, 4);
  assert.ok(e >= 1 && e < 5);
  assert.ok(FSRS.nextD(5, 1) > 5 && FSRS.nextD(5, 4) < 5);
});

test('FSRS: Intervalle wachsen, Obergrenze 365, Vergessen verkleinert die Stabilität', () => {
  const t0 = Date.UTC(2026, 0, 1);
  let card = { state: 'new', s: 0, d: 0, lastReview: null };
  let last = 0, t = t0;
  for (let i = 0; i < 12; i++) {
    const r = FSRS.schedule(card, 3, t);
    assert.ok(r.interval >= last || r.interval === 365);
    assert.ok(r.interval <= 365);
    card = { state: r.state, s: r.s, d: r.d, lastReview: t };
    last = r.interval; t = r.due;
  }
  const f = FSRS.schedule(card, 1, t);
  assert.equal(f.state, 'relearning');
  assert.ok(f.s < card.s);
});

test('FSRS.replayD ist deterministisch und leer → null', () => {
  assert.equal(FSRS.replayD([]), null);
  assert.equal(FSRS.replayD([3]), FSRS.initD(3));
  assert.equal(FSRS.replayD([3, 1, 3]), FSRS.nextD(FSRS.nextD(FSRS.initD(3), 1), 3));
});

/* ---------- Antwortprüfung ---------- */
test('Antwort: Deutsch – Groß/Klein, Leerzeichen, Satzzeichen, Umlaut-Umschrift', () => {
  const ev = (i, s) => Answer.evaluate(i, s, false);
  assert.equal(ev('  hAuS ', ['Haus']), 'perfect');
  assert.equal(ev('Haus.', ['Haus']), 'perfect');
  assert.equal(ev('Gebaeude', ['Gebäude']), 'perfect');
  assert.equal(ev('Strasse', ['Straße']), 'perfect');
  assert.equal(ev('Haos', ['Haus']), 'typo');
  assert.equal(ev('Auto', ['Haus']), 'wrong');
  assert.equal(ev('Tag', ['Tor']), 'wrong');
  assert.equal(ev('   ', ['Haus']), 'wrong');
  assert.equal(ev('Gebäude', ['Haus', 'Gebäude']), 'perfect');
});

test('Antwort: fehlender Artikel ist nur ein Tippfehler', () => {
  assert.equal(Answer.evaluate('Haus', ['das Haus'], false), 'typo');
  assert.equal(Answer.evaluate('das Haus', ['das Haus'], false), 'perfect');
});

test('Antwort: Persisch – arabisches Ya/Kaf, ZWNJ, Diakritika, Ziffern', () => {
  const ev = (i, s) => Answer.evaluate(i, s, true);
  assert.equal(ev('كتاب', ['کتاب']), 'perfect');
  assert.equal(ev('میخورم', ['می‌خورم']), 'perfect');        // ohne Halbleerzeichen
  assert.equal(ev('می‌خورم', ['میخورم']), 'perfect');
  assert.equal(ev('کِتاب', ['کتاب']), 'perfect');           // mit Kasra
  assert.equal(ev('خانه.', ['خانه']), 'perfect');
  assert.equal(ev('۱۲۳', ['123']), 'perfect');
  assert.equal(ev('١٢٣', ['۱۲۳']), 'perfect');
});

test('Antwort: „اب" statt „آب" ist nur ein Tippfehler (nicht mehr „perfekt")', () => {
  assert.equal(Answer.evaluate('اب', ['آب'], true), 'typo');
  assert.equal(Answer.evaluate('آب', ['آب'], true), 'perfect');
  assert.equal(Answer.evaluate('آب', ['اب'], true), 'typo');
});

test('Antwort: Sätze mit Toleranz nach Länge', () => {
  const s = 'من فارسی یاد می‌گیرم.';
  assert.equal(Answer.evaluateSentence('من فارسی یاد میگیرم', [s], true), 'perfect');
  assert.equal(Answer.evaluateSentence('من فارسی یاد میگیریم', [s], true), 'typo');
  assert.equal(Answer.evaluateSentence('تو چای می‌نوشی', [s], true), 'wrong');
  assert.equal(Answer.evaluateSentence('ich lerne persisch', ['Ich lerne Persisch.'], false), 'perfect');
  assert.equal(Answer.evaluateSentence('Ich laerne Persisch', ['Ich lerne Persisch.'], false), 'typo');
});

/* ---------- Inhalte ---------- */
test('Inhalte: Sätze – IDs eindeutig, Wortarten passen zu den Tokens, Lücken sinnvoll', () => {
  const ids = new Set();
  for (const s of api.SENTENCES) {
    assert.ok(!ids.has(s.id), 'doppelte ID ' + s.id); ids.add(s.id);
    assert.equal(s.pd.length, s.deT.length, `${s.id}: Wortarten Deutsch (${s.pd.length}) ≠ Wörter (${s.deT.length})`);
    assert.equal(s.pf.length, s.faT.length, `${s.id}: Wortarten Persisch (${s.pf.length}) ≠ Wörter (${s.faT.length})`);
    assert.ok(s.tr && s.tr.length > 2);
    assert.ok(s.faT.every(t => /[؀-ۿ]/.test(t)), s.id + ': persisches Token ohne persische Zeichen');
    assert.ok(!/[.؟?]/.test(s.faT.join('')), s.id + ': Satzzeichen im Token');
    for (const [list, toks, pos] of [[s.bd, s.deT, s.pd], [s.bf, s.faT, s.pf]]) {
      if (list) for (const i of list) { assert.ok(i >= 0 && i < toks.length, s.id + ' Lückenindex'); assert.ok(api.BLANK_POS.includes(pos[i]), `${s.id}: Lücke bei Wortart ${pos[i]}`); }
      else assert.ok(pos.some(p => api.BLANK_POS.includes(p)), s.id + ': keine mögliche Lücke');
    }
  }
  assert.ok(api.SENTENCES.length >= 50);
});

test('Inhalte: Grammatik – richtige Antwort steht in den Optionen, keine doppelten Optionen', () => {
  const ids = new Set();
  for (const g of api.GRAMMAR) {
    assert.ok(!ids.has(g.id)); ids.add(g.id);
    assert.ok(g.a.length >= 3 && g.a.length <= 4, g.id);
    assert.equal(new Set(g.a.map(x => Answer.normalize(x, true))).size, g.a.length, g.id + ': doppelte Optionen');
    assert.ok(g.e && g.e.length > 5);
    if (g.lang === 'de') assert.ok(g.x, g.id + ': persische Erklärung fehlt');
  }
  assert.ok(api.GRAMMAR_TOPICS.fa.length >= 8 && api.GRAMMAR_TOPICS.de.length >= 5);
});

/* ---------- Generatoren ---------- */
test('Lückentext: Lücke korrekt, Antwort in Optionen, genau eine richtige, Casing verrät nichts', () => {
  const rng = seeded(7);
  for (const s of api.SENTENCES) for (const lang of ['fa', 'de']) for (let k = 0; k < 5; k++) {
    const c = api.makeCloze(s, lang, rng);
    assert.equal(c.options[c.correctIdx], c.answer);
    assert.equal(c.tokens[c.idx], null);
    assert.equal(c.tokens.filter(t => t === null).length, 1);
    assert.equal(new Set(c.options.map(o => Answer.normalize(o, true))).size, c.options.length, s.id + ': doppelte Option');
    assert.ok(c.options.length >= 3, `${s.id}/${lang}: nur ${c.options.length} Optionen`);
    if (lang === 'de') {
      const up = c.answer[0] !== c.answer[0].toLowerCase();
      assert.ok(c.options.every(o => (o[0] !== o[0].toLowerCase()) === up), s.id + ': Groß-/Kleinschreibung verrät die Antwort ' + c.options.join(','));
    }
  }
});

test('Satzbildung: Lösung wird akzeptiert, falsche Reihenfolge nicht, gemischt ≠ Lösung', () => {
  const rng = seeded(3);
  for (const s of api.SENTENCES) for (const dir of ['g2p', 'p2g']) {
    const b = api.makeBuild(s, dir, rng);
    assert.ok(api.checkBuild(b, b.solution));
    const ordered = b.tokens.map(t => t.t);
    if (b.solution.length > 1) assert.notDeepEqual(ordered, b.solution, s.id + ': Tokens bereits in Lösungsreihenfolge');
    assert.equal(ordered.slice().sort().join('|'), b.solution.slice().sort().join('|'));
    if (b.solution.length > 1) {
      const wrong = b.solution.slice().reverse();
      if (wrong.join(' ') !== b.solution.join(' ')) assert.equal(api.checkBuild(b, wrong), false);
    }
  }
});

test('Übersetzen: die Musterlösung wird als perfekt gewertet', () => {
  for (const s of api.SENTENCES) for (const dir of ['g2p', 'p2g']) {
    const t = api.makeTranslate(s, dir);
    assert.equal(Answer.evaluateSentence(t.solutions[0], t.solutions, t.answerIsFa), 'perfect');
  }
});

test('Grammatik: Optionen gemischt, Index zeigt auf die richtige Antwort', () => {
  const rng = seeded(11);
  for (const g of api.GRAMMAR) {
    const q = api.makeGrammar(g, rng);
    assert.equal(q.options[q.correctIdx], g.a[0]);
    assert.equal(q.options.length, g.a.length);
  }
});

function mkCards(n) {
  return Array.from({ length: n }, (_, i) => api.Schema.fixCard({ id: 'c' + i, de: ['Wort' + i], fa: ['واژه' + 'ابپتثجچحخدذر'[i % 12] + i], tags: [i % 2 ? 'A' : 'B'] }, []));
}

test('Multiple Choice: richtige Antwort enthalten, ohne Synonyme, auch bei sehr wenigen Karten', () => {
  const rng = seeded(5);
  for (const n of [1, 2, 3, 4, 10]) {
    const cards = mkCards(n);
    cards[0].fa.push('همنام');
    for (const c of cards) for (const isFa of [true, false]) {
      const ch = api.makeCardChoices(c, isFa, cards, rng);
      const key = isFa ? 'fa' : 'de';
      assert.equal(ch.options[ch.correctIdx], c[key][0]);
      assert.equal(ch.options.filter(o => c[key].includes(o)).length, 1, 'nur die richtige Antwort bzw. ein Synonym');
      if (n >= 4) assert.equal(ch.options.length, 4);
      else assert.ok(ch.options.length >= 3, `n=${n}: Optionen ${ch.options.length}`);
    }
  }
});

test('Zuordnung: nur eindeutige Paare, mindestens 3, höchstens 5', () => {
  const cards = mkCards(8);
  cards.push(Object.assign({}, cards[0], { id: 'dup' }));
  const round = api.makeMatchRound(cards, 5);
  assert.equal(round.length, 5);
  assert.equal(new Set(round.map(c => c.de[0])).size, 5);
});

test('Hören: nur Aufgaben, die technisch möglich sind', () => {
  const cards = mkCards(6); cards[2].audio = true;
  const none = api.planListen(cards, { direction: 'p2g', count: 6, canSpeakFa: false, canSpeakDe: false }, seeded(1));
  assert.deepEqual(plain(none.map(s => s.cardId)), ['c2']);        // nur die Karte mit eigener Aufnahme
  const de = api.planListen(cards, { direction: 'p2g', count: 6, canSpeakFa: false, canSpeakDe: true }, seeded(1));
  assert.equal(de.length, 6);
  assert.ok(de.every(s => s.spoken === 'de' || s.cardId === 'c2'));
});

test('Adaptiv: schwierige Wörter werden erkannt und bevorzugt', () => {
  const t = Date.now();
  const good = { id: 'g', active: true, reps: 6, wrong: 0, d: 3, lapses: 0, miss: 0, s: 30, lastReview: t - 2 * api.DAY, nextReview: t + 20 * api.DAY, tags: [] };
  const bad = { id: 'b', active: true, reps: 5, wrong: 3, d: 8, lapses: 2, miss: 1, s: 2, lastReview: t - 3 * api.DAY, nextReview: t - api.DAY, tags: [] };
  const fresh = { id: 'n', active: true, reps: 0, wrong: 0, d: 0, lapses: 0, miss: 0, s: 0, lastReview: null, nextReview: null, tags: [] };
  assert.ok(api.weakScore(bad, t) > api.weakScore(good, t));
  assert.equal(api.isWeak(good, t), false);
  assert.equal(api.isWeak(bad, t), true);
  assert.equal(api.isWeak(fresh, t), false);
  assert.deepEqual(plain(api.weakCards([good, bad, fresh], t).map(c => c.id)), ['b']);
  // Warteschlange: fällige schwache Karte kommt vor fälliger leichter
  const easyDue = Object.assign({}, good, { id: 'e', nextReview: t - 1000 });
  const q = api.buildQueue([easyDue, bad], null, () => 0.5, t);
  assert.equal(q[0].id, 'b');
});

test('Wiederholung nach Fehler: dieselbe Aufgabe kommt als Übung später wieder', () => {
  const steps = [{ type: 'mc', cardId: 'a' }, { type: 'mc', cardId: 'b' }, { type: 'mc', cardId: 'c' }, { type: 'mc', cardId: 'd' }, { type: 'mc', cardId: 'e' }];
  const s = api.requeueStep(steps, 0, 3);
  assert.equal(steps.length, 6);
  assert.equal(steps[4], s);
  assert.equal(s.practice, true);
  assert.equal(s.cardId, 'a');
  const t = api.requeueStep(steps, 5, 3);
  assert.equal(steps[steps.length - 1], t);
});

test('Engine: Karte verbuchen (FSRS), Übungswiederholung ändert FSRS nicht', () => {
  const { api: a } = loadApi();
  a.Store.load();
  const card = a.Schema.fixCard({ id: 'x', de: ['a'], fa: ['ب'] }, []);
  a.Store.data.cards.push(card);
  a.Engine.recordCard(card, 3, { mode: 'mc', time: 2 });
  assert.equal(card.reps, 1); assert.equal(card.state, 'review'); assert.ok(card.nextReview > Date.now());
  const snap = JSON.stringify(card);
  a.Engine.recordCard(card, 1, { mode: 'mc', time: 2, practice: true });
  const after = JSON.parse(JSON.stringify(card));
  assert.equal(after.reps, 1); assert.equal(after.miss, 1);
  assert.equal(a.Store.data.logs.length, 2);
  assert.equal(a.Store.data.logs[1].p, 1);
  assert.notEqual(JSON.stringify(card), snap);
});

test('Statistik: Tagesziel zählt keine Übungswiederholungen, Serie, XP, Level', () => {
  const { api: a } = loadApi();
  a.Store.load();
  const t = a.now();
  const d = a.Store.data;
  d.logs.push({ date: t, rating: 3, time: 1, mode: 'mc', cardId: 'x' }, { date: t, rating: 1, time: 1, mode: 'mc', cardId: 'x', p: 1 },
    { date: t - a.DAY, rating: 4, time: 1, mode: 'mc', cardId: 'x' }, { date: t - 2 * a.DAY, rating: 3, time: 1, mode: 'mc', cardId: 'x' });
  const s = a.computeStats(d, t);
  assert.equal(s.today, 1);
  assert.equal(s.streak, 3);
  assert.equal(s.xp, 10 + 1 + 12 + 10);
  assert.equal(s.level.level, 1);
  assert.equal(a.levelInfo(50).level, 2);
  assert.equal(a.levelInfo(200).level, 3);
});

test('Serie überlebt Sommerzeit-Wechsel', () => {
  const { api: a } = loadApi();
  a.Store.load();
  // 7 aufeinanderfolgende Tage um den Wechsel 29.03.2026 (Europa) – jeweils 12 Uhr Ortszeit
  const base = new Date(2026, 2, 25, 12).getTime();
  a.Store.data.logs = Array.from({ length: 7 }, (_, i) => ({ date: new Date(2026, 2, 25 + i, 12).getTime(), rating: 3, time: 1, mode: 'flip' }));
  const s = a.computeStats(a.Store.data, new Date(2026, 2, 31, 15).getTime());
  assert.equal(s.streak, 7);
  void base;
});

test('esc() maskiert auch Apostroph und Anführungszeichen (Tag-Fehler aus v2.0)', () => {
  assert.equal(api.esc(`Tag's "x" <b>&`), 'Tag&#39;s &quot;x&quot; &lt;b&gt;&amp;');
});

test('Sentence-Leitner: richtig steigt, falsch fällt zurück; fällige Items zuerst', () => {
  const sent = {};
  api.sentUpdate(sent, 's01', true, 1000); api.sentUpdate(sent, 's01', true, 1000);
  assert.equal(sent.s01.box, 2);
  api.sentUpdate(sent, 's01', false, 1000);
  assert.equal(sent.s01.box, 0);
  const picked = api.pickItems(api.SENTENCES, { s02: { box: 5, due: Date.now() + 99 * api.DAY, ok: 5, bad: 0, last: 1 }, s03: { box: 0, due: 0, ok: 0, bad: 3, last: 1 } }, 3, () => 0.5);
  assert.ok(picked.some(p => p.id === 's03'));
  assert.ok(!picked.some(p => p.id === 's02'));
});
