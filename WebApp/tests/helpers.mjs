// Test-Hilfen: lädt die reinen Logik-Module der PWA in eine VM (ohne DOM).
import { readFileSync, readdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';

const here = dirname(fileURLToPath(import.meta.url));
const jsDir = join(here, '..', 'src', 'js');

/** Minimaler localStorage-Ersatz. quota: maximale Gesamtzeichen (optional), failWrites: alle Schreibzugriffe schlagen fehl. */
export class FakeStorage {
  constructor({ quota = Infinity } = {}) { this.m = new Map(); this.quota = quota; this.failWrites = false; }
  get length() { return this.m.size; }
  key(i) { return [...this.m.keys()][i] ?? null; }
  getItem(k) { return this.m.has(k) ? this.m.get(k) : null; }
  setItem(k, v) {
    if (this.failWrites) throw new Error('QuotaExceededError');
    const used = [...this.m.entries()].filter(([kk]) => kk !== k).reduce((a, [, vv]) => a + vv.length, 0);
    if (used + String(v).length > this.quota) throw new Error('QuotaExceededError');
    this.m.set(k, String(v));
  }
  removeItem(k) { this.m.delete(k); }
}

/** In-Memory-Ersatz für IndexedDB-Schnappschüsse. */
export class MemSnaps {
  constructor() { this.list = []; this.fail = false; }
  async put(rec) { if (this.fail) return false; this.list.push(JSON.parse(JSON.stringify(rec))); return true; }
  async all() { return this.list.map(r => JSON.parse(JSON.stringify(r))); }
  async remove(id) { this.list = this.list.filter(r => r.id !== id); return true; }
}

const NAMES = ['APP_VERSION', 'DAY', 'now', 'uid', 'clamp', 'esc', 'shuffle', 'startOfDay', 'dayKey', 'checksum', 'clone', 'sample',
  'FSRS', 'Answer', 'ratingFromQuality', 'SENTENCES', 'GRAMMAR', 'GRAMMAR_TOPICS', 'BLANK_POS', 'SCHEMA', 'Schema', 'Store', 'DB', 'emptyData',
  'DEFAULT_SETTINGS', 'Backup', 'AudioStore', 'xpForLog', 'isDue', 'weakScore', 'isWeak', 'weakCards', 'buildQueue', 'sentUpdate', 'pickItems',
  'Engine', 'levelInfo', 'shiftDay', 'computeStats', 'ACHIEVEMENTS', 'makeChoices', 'makeCardChoices', 'makeMatchRound', 'makeCloze', 'makeBuild',
  'checkBuild', 'makeTranslate', 'makeGrammar', 'makeListen', 'planVocab', 'planWeak', 'planMatch', 'planListen', 'planSentences',
  'planGrammar', 'planSpeak', 'planMix', 'requeueStep', 'gameCandidates', 'resolveDir', 'libraryWords', 'isFaText', 'matchCase'];

/** Lädt alle Logik-Dateien (00–69) in einen frischen Kontext und gibt die Namen zurück. */
export function loadApi({ time } = {}) {
  const files = readdirSync(jsDir).filter(f => f.endsWith('.js') && parseInt(f, 10) < 70).sort();
  const code = files.map(f => readFileSync(join(jsDir, f), 'utf8')).join('\n')
    + `\n;globalThis.__api = { ${NAMES.join(', ')} };`;
  const ctx = vm.createContext({ console, setTimeout, clearTimeout, Math, JSON, Date, Blob, atob, btoa, Uint8Array, Promise, navigator: {} });
  vm.runInContext(code, ctx, { filename: 'zara-logic.js' });
  const api = ctx.__api;
  const storage = new FakeStorage();
  const snaps = new MemSnaps();
  api.Store.attach(storage);
  api.Store.snaps = snaps;
  return { api, storage, snaps, ctx };
}

/** Deterministischer Zufall (mulberry32). */
export function seeded(seed = 1) {
  let a = seed >>> 0;
  return () => { a = (a + 0x6D2B79F5) >>> 0; let t = a; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
}
