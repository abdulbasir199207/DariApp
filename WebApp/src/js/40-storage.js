/* ============================================================
   40-storage: Persistenz mit Schema-Versionen, Migration,
   Schnappschüssen und Wiederherstellung.

   Grundregeln (Datensicherheit hat Vorrang vor allem anderen):
   1. Der Hauptdatensatz (localStorage „dariapp.v1") wird NIE überschrieben,
      solange er nicht erfolgreich gelesen und geprüft wurde.
   2. Ist er defekt, wird der Rohtext in einen Quarantäne-Schlüssel kopiert,
      und die App startet im Wiederherstellungsmodus (Speichern gesperrt).
   3. Vor jeder Migration und vor jeder Wiederherstellung entsteht eine
      Sicherheitskopie (synchron in localStorage + Schnappschuss in IndexedDB).
   4. Jeder Schreibvorgang wird zurückgelesen und verglichen.
   ============================================================ */

const SCHEMA = 3;

const DEFAULT_SETTINGS = () => ({
  appearance: 'light', defaultMode: 'flip', defaultDirection: 'mixed',
  dailyGoal: 20, animations: true, haptics: true
});

function emptyData() {
  return { schemaVersion: SCHEMA, cards: [], logs: [], logArchive: {}, sent: {},
    settings: DEFAULT_SETTINGS(), meta: { createdAt: now() } };
}

/* ---------- Prüfen, Reparieren, Migrieren ---------- */
const Schema = {
  STATES: ['new', 'learning', 'review', 'relearning'],
  MODES: ['flip', 'mc', 'write'],
  DIRS: ['g2p', 'p2g', 'mixed'],
  APPEARANCE: ['system', 'light', 'dark'],

  num(v, d = 0) { return (typeof v === 'number' && isFinite(v)) ? v : d; },
  numOrNull(v) { return (typeof v === 'number' && isFinite(v)) ? v : null; },
  strList(v) {
    if (typeof v === 'string') v = [v];
    if (!Array.isArray(v)) return [];
    return v.filter(x => typeof x === 'string').map(x => x.trim()).filter(Boolean);
  },

  /** Repariert eine Karte (oder gibt null zurück, wenn sie keinerlei Inhalt hat). */
  fixCard(c, issues) {
    if (!c || typeof c !== 'object' || Array.isArray(c)) { issues.push('Ungültiger Karteneintrag'); return null; }
    const de = this.strList(c.de), fa = this.strList(c.fa);
    if (!de.length && !fa.length) { issues.push('Leere Karte entfernt'); return null; }
    const t = now();
    const out = {
      id: (typeof c.id === 'string' && c.id) ? c.id : uid(),
      de, fa,
      translit: typeof c.translit === 'string' ? c.translit : '',
      tags: this.strList(c.tags),
      audio: !!c.audio,
      active: c.active !== false,
      fav: !!c.fav,
      state: this.STATES.includes(c.state) ? c.state : 'new',
      s: Math.max(this.num(c.s), 0), d: this.num(c.d),
      interval: Math.max(Math.round(this.num(c.interval)), 0),
      reps: Math.max(Math.round(this.num(c.reps)), 0),
      lapses: Math.max(Math.round(this.num(c.lapses)), 0),
      correct: Math.max(Math.round(this.num(c.correct)), 0),
      wrong: Math.max(Math.round(this.num(c.wrong)), 0),
      miss: Math.max(Math.round(this.num(c.miss)), 0),
      lastReview: this.numOrNull(c.lastReview),
      nextReview: this.numOrNull(c.nextReview),
      lastTime: Math.max(this.num(c.lastTime), 0),
      createdAt: this.num(c.createdAt, t),
      updatedAt: this.num(c.updatedAt, this.num(c.createdAt, t)),
      exDe: typeof c.exDe === 'string' ? c.exDe : '',
      exFa: typeof c.exFa === 'string' ? c.exFa : ''
    };
    // Unbekannte Zusatzfelder bleiben erhalten (Vorwärtskompatibilität).
    for (const k of Object.keys(c)) if (!(k in out)) out[k] = c[k];
    if (out.state === 'new' && out.reps === 0) { out.s = 0; out.d = 0; }
    return out;
  },

  fixLog(l) {
    if (!l || typeof l !== 'object') return null;
    const date = this.numOrNull(l.date);
    if (date == null) return null;
    const out = {
      date, rating: clamp(Math.round(this.num(l.rating, 3)), 1, 4),
      time: Math.max(this.num(l.time), 0),
      mode: typeof l.mode === 'string' ? l.mode : 'flip'
    };
    if (typeof l.cardId === 'string') out.cardId = l.cardId;
    if (typeof l.itemId === 'string') out.itemId = l.itemId;
    if (l.p) out.p = 1;      // Übungswiederholung (zählt nicht fürs Tagesziel)
    if (l.wk) out.wk = 1;    // schwieriges Wort richtig beantwortet
    return out;
  },

  fixSettings(s) {
    const d = DEFAULT_SETTINGS();
    s = (s && typeof s === 'object') ? s : {};
    return {
      appearance: this.APPEARANCE.includes(s.appearance) ? s.appearance : d.appearance,
      defaultMode: this.MODES.includes(s.defaultMode) ? s.defaultMode : d.defaultMode,
      defaultDirection: this.DIRS.includes(s.defaultDirection) ? s.defaultDirection : d.defaultDirection,
      dailyGoal: clamp(Math.round(this.num(s.dailyGoal, d.dailyGoal)), 5, 200),
      animations: s.animations !== false,
      haptics: s.haptics !== false
    };
  },

  /** Vollständige Prüfung + Reparatur. Mutiert die Eingabe nicht. */
  sanitize(input) {
    const issues = [];
    const d = (input && typeof input === 'object' && !Array.isArray(input)) ? input : {};
    const seen = new Set();
    const cards = [];
    for (const raw of (Array.isArray(d.cards) ? d.cards : [])) {
      const c = this.fixCard(raw, issues);
      if (!c) continue;
      if (seen.has(c.id)) { c.id = uid(); issues.push('Doppelte Karten-ID repariert'); }
      seen.add(c.id); cards.push(c);
    }
    let droppedLogs = 0;
    const logs = [];
    for (const raw of (Array.isArray(d.logs) ? d.logs : [])) {
      const l = this.fixLog(raw);
      if (l) logs.push(l); else droppedLogs++;
    }
    if (droppedLogs) issues.push(droppedLogs + ' ungültige Verlaufseinträge entfernt');
    const archive = {};
    if (d.logArchive && typeof d.logArchive === 'object') {
      for (const [k, v] of Object.entries(d.logArchive)) {
        if (/^\d{4}-\d{2}-\d{2}$/.test(k) && v && typeof v === 'object') {
          archive[k] = { n: Math.max(this.num(v.n), 0), ok: Math.max(this.num(v.ok), 0),
            t: Math.max(this.num(v.t), 0), xp: Math.max(this.num(v.xp), 0) };
        }
      }
    }
    const sent = {};
    if (d.sent && typeof d.sent === 'object') {
      for (const [k, v] of Object.entries(d.sent)) {
        if (v && typeof v === 'object') {
          sent[k] = { box: clamp(Math.round(this.num(v.box)), 0, 5), due: this.num(v.due),
            ok: Math.max(this.num(v.ok), 0), bad: Math.max(this.num(v.bad), 0), last: this.num(v.last) };
        }
      }
    }
    const meta = (d.meta && typeof d.meta === 'object') ? clone(d.meta) : {};
    if (!meta.createdAt) meta.createdAt = now();
    const out = {
      schemaVersion: this.num(d.schemaVersion, 2),
      cards, logs, logArchive: archive, sent,
      settings: this.fixSettings(d.settings), meta
    };
    // Unbekannte Top-Level-Felder erhalten
    for (const k of Object.keys(d)) if (!(k in out)) out[k] = d[k];
    return { data: out, issues };
  },

  /** Migrationsschritte. Jeder Schritt hebt schemaVersion um 1. */
  steps: {
    // v2 (PWA bis 2.0) → v3 (ZARA): Schwierigkeit mit korrigierter FSRS-Formel
    // aus dem Verlauf neu herleiten. Termine (nextReview), Stabilität und
    // Zustand bleiben UNVERÄNDERT – es geht nichts verloren.
    2(d) {
      const byCard = new Map();
      for (const l of d.logs) {
        if (!l.cardId) continue;
        if (!byCard.has(l.cardId)) byCard.set(l.cardId, []);
        byCard.get(l.cardId).push(l);
      }
      let recalculated = 0;
      for (const c of d.cards) {
        if (c.reps > 0 && byCard.has(c.id)) {
          const ratings = byCard.get(c.id).sort((a, b) => a.date - b.date).map(l => l.rating);
          const nd = FSRS.replayD(ratings);
          if (nd != null) { c.d = nd; recalculated++; }
        }
      }
      d.meta.migration = { from: 2, to: 3, at: now(), difficultyRecalculated: recalculated };
    }
  },

  migrate(d) {
    const from = d.schemaVersion;
    const applied = [];
    if (from > SCHEMA) return { data: d, from, applied, tooNew: true };
    let v = from;
    while (v < SCHEMA) {
      const step = this.steps[v];
      if (step) step(d);
      v++; applied.push(v);
    }
    d.schemaVersion = SCHEMA;
    return { data: d, from, applied, tooNew: false };
  }
};

/* ---------- Schnappschüsse (IndexedDB) ---------- */
const SnapBackend = {
  _db: null,
  open() {
    return new Promise(res => {
      if (this._db) return res(this._db);
      if (typeof indexedDB === 'undefined') return res(null);
      let r;
      try { r = indexedDB.open('zara-backups', 1); } catch (e) { return res(null); }
      r.onupgradeneeded = () => { r.result.createObjectStore('snaps', { keyPath: 'id' }); };
      r.onsuccess = () => { this._db = r.result; res(this._db); };
      r.onerror = () => res(null);
      r.onblocked = () => res(null);
    });
  },
  async put(rec) {
    const db = await this.open(); if (!db) return false;
    return new Promise(res => {
      const t = db.transaction('snaps', 'readwrite');
      t.objectStore('snaps').put(rec);
      t.oncomplete = () => res(true); t.onerror = () => res(false); t.onabort = () => res(false);
    });
  },
  async all() {
    const db = await this.open(); if (!db) return [];
    return new Promise(res => {
      const q = db.transaction('snaps', 'readonly').objectStore('snaps').getAll();
      q.onsuccess = () => res(q.result || []); q.onerror = () => res([]);
    });
  },
  async remove(id) {
    const db = await this.open(); if (!db) return false;
    return new Promise(res => {
      const t = db.transaction('snaps', 'readwrite');
      t.objectStore('snaps').delete(id);
      t.oncomplete = () => res(true); t.onerror = () => res(false);
    });
  }
};

/* ---------- Audio (IndexedDB) – gleiche DB wie in v2.0, damit Aufnahmen erhalten bleiben ---------- */
const AudioStore = {
  _db: null,
  open() {
    return new Promise(res => {
      if (this._db) return res(this._db);
      if (typeof indexedDB === 'undefined') return res(null);
      let r;
      try { r = indexedDB.open('dariapp-audio', 1); } catch (e) { return res(null); }
      r.onupgradeneeded = () => { r.result.createObjectStore('audio'); };
      r.onsuccess = () => { this._db = r.result; res(this._db); };
      r.onerror = () => res(null);
    });
  },
  async put(id, blob) {
    const db = await this.open(); if (!db) return false;
    return new Promise(r => { const t = db.transaction('audio', 'readwrite'); t.objectStore('audio').put(blob, id);
      t.oncomplete = () => r(true); t.onerror = () => r(false); });
  },
  async get(id) {
    const db = await this.open(); if (!db) return null;
    return new Promise(r => { const q = db.transaction('audio', 'readonly').objectStore('audio').get(id);
      q.onsuccess = () => r(q.result || null); q.onerror = () => r(null); });
  },
  async del(id) {
    const db = await this.open(); if (!db) return false;
    return new Promise(r => { const t = db.transaction('audio', 'readwrite'); t.objectStore('audio').delete(id);
      t.oncomplete = () => r(true); t.onerror = () => r(false); });
  }
};

/* ---------- Der Speicher ---------- */
const Store = {
  KEY: 'dariapp.v1',                 // UNVERÄNDERT: hier liegen die bestehenden Nutzerdaten
  PREV: 'dariapp.v1.prev',           // letzter bekannter guter Stand (synchron)
  QUAR: 'dariapp.v1.quarantine.',    // Rohtext defekter Datensätze
  ls: null,
  snaps: SnapBackend,
  data: emptyData(),
  mode: 'ok',                        // 'ok' | 'recovery'
  recovery: null,
  lastSaveError: null,
  onSaveError: null,
  info: null,

  attach(ls) { this.ls = ls; return this; },

  _get(k) { try { return this.ls.getItem(k); } catch (e) { return null; } },
  _set(k, v) { try { this.ls.setItem(k, v); return true; } catch (e) { return false; } },

  _parse(raw) {
    if (typeof raw !== 'string' || !raw.trim()) return null;
    try {
      const p = JSON.parse(raw);
      return (p && typeof p === 'object' && !Array.isArray(p)) ? p : null;
    } catch (e) { return null; }
  },

  _quarantine(raw) {
    const key = this.QUAR + now();
    this._set(key, raw);
    // Nur die 3 neuesten Quarantäne-Einträge behalten.
    try {
      const keys = [];
      for (let i = 0; i < this.ls.length; i++) { const k = this.ls.key(i); if (k && k.startsWith(this.QUAR)) keys.push(k); }
      keys.sort().slice(0, Math.max(0, keys.length - 3)).forEach(k => { try { this.ls.removeItem(k); } catch (e) {} });
    } catch (e) {}
    return key;
  },

  /** Synchrones Laden. Gibt Infos über den Ablauf zurück, wirft nie. */
  load() {
    const info = { fresh: false, recovered: null, migratedFrom: null, issues: [], recovery: false,
      tooNew: false, quarantineKey: null };
    this.mode = 'ok'; this.recovery = null;
    const raw = this._get(this.KEY);
    let parsed = this._parse(raw);
    let source = 'main';

    if (raw == null) {
      // Kein Hauptdatensatz. Gab es einen letzten guten Stand?
      const prevParsed = this._parse(this._get(this.PREV));
      if (prevParsed) { parsed = prevParsed; source = 'prev'; info.recovered = 'prev'; }
      else { info.fresh = true; this.data = emptyData(); this.info = info; return info; }
    } else if (!parsed) {
      // Defekt: Rohtext sichern, auf letzten guten Stand zurückgreifen – NICHT überschreiben.
      info.quarantineKey = this._quarantine(raw);
      const prevParsed = this._parse(this._get(this.PREV));
      if (prevParsed) { parsed = prevParsed; source = 'prev'; info.recovered = 'prev'; }
      else {
        this.mode = 'recovery'; info.recovery = true;
        this.recovery = { reason: 'corrupt', rawLength: raw.length, quarantineKey: info.quarantineKey };
        this.data = emptyData(); this.info = info; return info;
      }
    }

    const { data, issues } = Schema.sanitize(parsed);
    info.issues = issues;
    if (data.schemaVersion > SCHEMA) {
      // Daten stammen aus einer neueren App-Version: nichts anfassen.
      info.tooNew = true; this.mode = 'recovery'; info.recovery = true;
      this.recovery = { reason: 'tooNew', version: data.schemaVersion };
      this.data = emptyData(); this.info = info; return info;
    }
    const needsMigration = data.schemaVersion < SCHEMA;
    if (needsMigration || issues.length || source === 'prev') {
      // Vor jeder Veränderung: Original synchron sichern.
      if (raw != null) this._set(this.PREV + '.premigration', raw);
    }
    if (needsMigration) {
      info.migratedFrom = data.schemaVersion;
      Schema.migrate(data);
    }
    this.data = data;
    info.needsSave = needsMigration || issues.length > 0 || source === 'prev';
    info.preMigration = needsMigration || issues.length > 0;
    info.originalRaw = info.preMigration ? raw : null;
    this.info = info;
    return info;
  },

  save() {
    if (this.mode !== 'ok' || !this.ls) return false;
    try {
      this.data.meta.lastSaved = now();
      const json = JSON.stringify(this.data);
      this.ls.setItem(this.KEY, json);
      if (this.ls.getItem(this.KEY) !== json) throw new Error('Rücklese-Prüfung fehlgeschlagen');
      this.lastSaveError = null;
      return true;
    } catch (e) {
      this.lastSaveError = e;
      if (this.onSaveError) try { this.onSaveError(e); } catch (_) {}
      return false;
    }
  },

  /** Letzten guten Stand höchstens alle 24 h synchron festhalten. */
  rotatePrev() {
    if (this.mode !== 'ok') return;
    const m = this.data.meta;
    if (this.data.cards.length && (!m.prevAt || now() - m.prevAt > DAY)) {
      const raw = this._get(this.KEY);
      if (raw && this._parse(raw)) { if (this._set(this.PREV, raw)) m.prevAt = now(); }
    }
  },

  /* ----- Schnappschüsse ----- */
  /** `rawJson`: expliziter Text (z. B. der Originalstand VOR einer Migration). */
  async snapshot(reason, throttleMs = 0, rawJson = null) {
    if (this.mode !== 'ok' && !rawJson) return null;
    const m = this.data.meta;
    m.lastSnap = m.lastSnap || {};
    if (throttleMs && now() - (m.lastSnap[reason] || 0) < throttleMs) return null;
    const json = rawJson || JSON.stringify(this.data);
    const src = rawJson ? (this._parse(rawJson) || {}) : this.data;
    const rec = { id: now() + '-' + Math.random().toString(36).slice(2, 6), at: now(), reason,
      cards: Array.isArray(src.cards) ? src.cards.length : 0,
      logs: Array.isArray(src.logs) ? src.logs.length : 0, size: json.length, json };
    const ok = await this.snaps.put(rec);
    if (ok) { m.lastSnap[reason] = now(); await this.pruneSnapshots(); return rec; }
    return null;
  },
  async listSnapshots() {
    const all = await this.snaps.all();
    return all.map(r => ({ id: r.id, at: r.at, reason: r.reason, cards: r.cards, logs: r.logs, size: r.size }))
      .sort((a, b) => b.at - a.at);
  },
  async getSnapshot(id) {
    const all = await this.snaps.all();
    return all.find(r => r.id === id) || null;
  },
  async pruneSnapshots() {
    const all = (await this.snaps.all()).sort((a, b) => b.at - a.at);
    const auto = all.filter(r => r.reason === 'auto');
    const other = all.filter(r => r.reason !== 'auto');
    for (const r of auto.slice(7)) await this.snaps.remove(r.id);
    for (const r of other.slice(8)) await this.snaps.remove(r.id);
  },
  /** Täglicher automatischer Schnappschuss (nur wenn Daten vorhanden). */
  async autoSnapshot() {
    if (this.mode !== 'ok' || !this.data.cards.length) return null;
    const m = this.data.meta;
    if (m.lastAutoSnapshot && now() - m.lastAutoSnapshot < 20 * 3600 * 1000) return null;
    const rec = await this.snapshot('auto');
    if (rec) { m.lastAutoSnapshot = now(); this.save(); }
    return rec;
  },

  /* ----- Aufnahmen gelöschter Karten bleiben 30 Tage erhalten (Rückgängig-Schutz) ----- */
  markOrphan(cardId) {
    const m = this.data.meta; m.orphans = m.orphans || {}; m.orphans[cardId] = now();
  },
  async purgeOrphans() {
    const m = this.data.meta; if (!m.orphans) return 0;
    const live = new Set(this.data.cards.map(c => c.id));
    let n = 0;
    for (const [id, ts] of Object.entries(m.orphans)) {
      if (live.has(id)) { delete m.orphans[id]; continue; }
      if (now() - ts > 30 * DAY) { await AudioStore.del(id); delete m.orphans[id]; n++; }
    }
    return n;
  },

  /** Persistenten Speicher anfragen (verhindert Löschen durch iOS bei Platzmangel). */
  async requestPersistence() {
    try {
      if (navigator.storage && navigator.storage.persist) {
        const ok = await navigator.storage.persist();
        this.data.meta.persisted = !!ok;
        return ok;
      }
    } catch (e) {}
    return false;
  },

  /** Verlauf älter als `keepDays` zu Tageswerten verdichten (hält localStorage klein). */
  compactLogs(keepDays = 180) {
    const cutoff = startOfDay(now() - keepDays * DAY);
    const old = this.data.logs.filter(l => l.date < cutoff);
    if (old.length < 200) return 0;
    const arch = this.data.logArchive;
    for (const l of old) {
      const k = dayKey(l.date);
      const a = arch[k] || (arch[k] = { n: 0, ok: 0, t: 0, xp: 0 });
      a.n++; if (l.rating !== 1) a.ok++; a.t += l.time; a.xp += xpForLog(l);
    }
    this.data.logs = this.data.logs.filter(l => l.date >= cutoff);
    return old.length;
  }
};

const DB = Store;   // gleiche Instanz; kürzerer Name in Oberfläche und Engine

/** Erfahrungspunkte je Antwort – belohnt richtiges Abrufen, Mühe und das Üben schwieriger Wörter. */
function xpForLog(l) {
  let xp = l.rating >= 4 ? 12 : l.rating === 3 ? 10 : l.rating === 2 ? 6 : 2;
  if (l.wk && l.rating >= 3) xp += 5;
  if (l.p) xp = Math.round(xp / 2);
  return xp;
}
