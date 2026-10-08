// Erzeugt tests/fixtures/v2-data.json: echte Daten im Format der PWA-Version 2.0.
// Dafür wird der ORIGINAL-Code von v2.0 (Git-Tag v2.0-baseline) in einer VM ausgeführt
// und über 25 simulierte Tage benutzt – so entsteht genau das Datenformat, das auf dem
// iPhone des Nutzers liegt (inkl. der damaligen FSRS-Werte).
import { execSync } from 'node:child_process';
import { writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';
import { seeded } from './helpers.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const html = execSync('git show v2.0-baseline:WebApp/DariApp.html', { cwd: join(here, '..', '..'), encoding: 'utf8', maxBuffer: 1 << 26 });
const script = html.match(/<script>([\s\S]*)<\/script>/)[1].replace(/\nboot\(\);\s*$/, '\n');

let clock = Date.UTC(2026, 8, 1, 9, 0, 0);   // 1. Sept 2026
class FakeDate extends Date {
  constructor(...a) { if (a.length) super(...a); else super(clock); }
  static now() { return clock; }
}
const store = new Map();
const stub = () => ({ classList: { add() {}, remove() {}, toggle() {}, contains() { return false; } }, setAttribute() {}, removeAttribute() {}, style: {}, set innerHTML(v) {}, get innerHTML() { return ''; }, addEventListener() {} });
const ctx = vm.createContext({
  console, Math, JSON, Promise, setTimeout, clearTimeout, Date: FakeDate, FileReader: class {}, File: class {},
  localStorage: { getItem: k => store.has(k) ? store.get(k) : null, setItem: (k, v) => store.set(k, String(v)), removeItem: k => store.delete(k) },
  document: { getElementById: stub, querySelector: stub, documentElement: stub(), createElement: stub, body: stub() },
  navigator: {}, matchMedia: () => ({ matches: false, addEventListener() {} }), window: {}, indexedDB: undefined, alert() {}
});
vm.runInContext(script + '\n;globalThis.__v2 = { DB, FSRS, seedIfEmpty, uid, now, buildQueue };', ctx);
const { DB, FSRS, uid, now } = ctx.__v2;

DB.load();
const topics = { Alltag: ['Haus', 'Tisch', 'Stuhl', 'Fenster', 'Tür', 'Straße', 'Auto', 'Buch'], Familie: ['Mutter', 'Vater', 'Bruder', 'Schwester', 'Kind', 'Onkel'], Essen: ['Brot', 'Wasser', 'Tee', 'Reis', 'Fleisch', 'Apfel', 'Milch'], Verben: ['gehen', 'kommen', 'lesen', 'schreiben', 'sehen', 'hören', 'sprechen', 'lernen'] };
const fa = ['خانه', 'میز', 'صندلی', 'پنجره', 'در', 'خیابان', 'ماشین', 'کتاب', 'مادر', 'پدر', 'برادر', 'خواهر', 'کودک', 'دایی', 'نان', 'آب', 'چای', 'برنج', 'گوشت', 'سیب', 'شیر', 'رفتن', 'آمدن', 'خواندن', 'نوشتن', 'دیدن', 'شنیدن', 'گفتن', 'آموختن'];
let k = 0;
DB.data.cards = [];
for (const [tag, words] of Object.entries(topics)) for (const w of words) {
  DB.data.cards.push({ id: uid(), de: [w], fa: [fa[k % fa.length]].concat(k % 5 === 0 ? ['واژه' + k] : []), translit: 'tr' + k, tags: k % 4 === 0 ? [tag, 'Test'] : [tag], audio: k % 7 === 0, active: k % 11 !== 0, fav: k % 6 === 0, state: 'new', s: 0, d: 0, interval: 0, reps: 0, lapses: 0, correct: 0, wrong: 0, lastReview: null, nextReview: null, lastTime: 0, createdAt: now(), updatedAt: now() });
  k++;
}
const rnd = seeded(42);
for (let day = 0; day < 25; day++) {
  clock += 86400000;
  const due = DB.data.cards.filter(c => c.active && (!c.nextReview || c.nextReview <= clock)).slice(0, 14);
  for (const c of due) {
    clock += 15000;
    const hard = c.tags.includes('Verben') ? 0.35 : 0.12;
    const g = rnd() < hard ? 1 : (rnd() < 0.15 ? 4 : rnd() < 0.15 ? 2 : 3);
    const r = FSRS.schedule({ state: c.state, s: c.s, d: c.d, lastReview: c.lastReview }, g, now());
    c.s = r.s; c.d = r.d; c.state = r.state; c.interval = r.interval; c.lastReview = now(); c.nextReview = r.due; c.lastTime = 4.5; c.reps = (c.reps || 0) + 1;
    if (g === 1) { c.wrong = (c.wrong || 0) + 1; if (c.state === 'relearning') c.lapses = (c.lapses || 0) + 1; } else c.correct = (c.correct || 0) + 1;
    DB.data.logs.push({ date: now(), rating: g, time: 4.5, mode: ['flip', 'mc', 'write'][day % 3], cardId: c.id });
    c.updatedAt = now();
  }
}
DB.data.settings = { appearance: 'dark', defaultMode: 'mc', defaultDirection: 'g2p', dailyGoal: 30, animations: false };
DB.save();
const out = store.get('dariapp.v1');
mkdirSync(join(here, 'fixtures'), { recursive: true });
writeFileSync(join(here, 'fixtures', 'v2-data.json'), out);
const parsed = JSON.parse(out);
console.log(`Fixture: ${parsed.cards.length} Karten, ${parsed.logs.length} Verlaufseinträge, ${Math.round(out.length / 1024)} KB`);
