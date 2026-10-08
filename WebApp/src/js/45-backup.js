/* ============================================================
   45-backup: Export, Prüfung, Wiederherstellung, Zusammenführen.
   Das Format „zara-backup" ist plattformübergreifend (PWA ↔ iOS-App).
   Auch alte Backups der Version 2.0 (nackte Datenstruktur) werden gelesen.
   ============================================================ */

async function blobToB64(blob) {
  const buf = new Uint8Array(await blob.arrayBuffer());
  let bin = '';
  for (let i = 0; i < buf.length; i += 0x8000) bin += String.fromCharCode.apply(null, buf.subarray(i, i + 0x8000));
  return btoa(bin);
}
function b64ToBlob(b64, type) {
  const bin = atob(b64), buf = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) buf[i] = bin.charCodeAt(i);
  return new Blob([buf], { type: type || 'audio/mp4' });
}

const Backup = {
  FORMAT: 'zara-backup',
  VERSION: 3,
  lastUndo: null,

  fileName() { return 'zara-backup-' + dayKey() + '.json'; },

  /** Baut den Backup-Text. includeAudio: Aufnahmen als Base64 anhängen. */
  async build({ includeAudio = false } = {}) {
    const data = clone(Store.data);
    const dataJson = JSON.stringify(data);
    const out = {
      format: this.FORMAT, formatVersion: this.VERSION, source: 'zara-web',
      appVersion: APP_VERSION, createdAt: now(),
      counts: { cards: data.cards.length, logs: data.logs.length },
      checksum: checksum(dataJson), data
    };
    let audioCount = 0;
    if (includeAudio) {
      out.audio = {};
      for (const c of data.cards) {
        if (!c.audio) continue;
        const blob = await AudioStore.get(c.id);
        if (blob) { out.audio[c.id] = { type: blob.type || 'audio/mp4', b64: await blobToB64(blob) }; audioCount++; }
      }
    }
    return { json: JSON.stringify(out), cards: data.cards.length, audioCount };
  },

  /** Liest und prüft Backup-Text. Verändert noch nichts. */
  parse(text) {
    let obj;
    try { obj = JSON.parse(String(text == null ? '' : text).replace(/^﻿/, '').trim()); }
    catch (e) { return { ok: false, error: 'Das ist kein gültiges Backup (Text unvollständig oder beschädigt).' }; }
    if (!obj || typeof obj !== 'object' || Array.isArray(obj)) return { ok: false, error: 'Das ist kein gültiges Backup.' };

    let payload, createdAt = null, checksumOk = null, audio = {}, kind = 'legacy', source = 'zara-web';
    if (obj.format === this.FORMAT) {
      kind = 'zara'; payload = obj.data; createdAt = obj.createdAt || null; source = obj.source || source;
      if (obj.formatVersion > this.VERSION) return { ok: false, error: 'Dieses Backup stammt aus einer neueren ZARA-Version. Bitte ZARA aktualisieren.' };
      if (obj.checksum) {
        try { checksumOk = (checksum(JSON.stringify(payload)) === obj.checksum); } catch (e) { checksumOk = false; }
      }
      if (obj.audio && typeof obj.audio === 'object') audio = obj.audio;
    } else {
      payload = obj;      // Backup der Version 2.0: die Datenstruktur selbst
    }
    if (!payload || !Array.isArray(payload.cards)) return { ok: false, error: 'Im Backup wurden keine Karten gefunden.' };

    const { data, issues } = Schema.sanitize(payload);
    if (data.schemaVersion > SCHEMA) return { ok: false, error: 'Dieses Backup stammt aus einer neueren ZARA-Version. Bitte ZARA aktualisieren.' };
    const from = data.schemaVersion;
    if (from < SCHEMA) Schema.migrate(data);
    return { ok: true, kind, source, data, issues, createdAt, checksumOk, audio,
      migratedFrom: from < SCHEMA ? from : null,
      summary: { cards: data.cards.length, logs: data.logs.length,
        tags: new Set(data.cards.flatMap(c => c.tags)).size, audio: Object.keys(audio).length } };
  },

  /** Führt zwei Datenstände zusammen (ohne etwas zu verlieren). */
  merge(cur, inc) {
    const out = clone(cur);
    const byId = new Map(out.cards.map(c => [c.id, c]));
    const LEARN = ['state', 's', 'd', 'interval', 'reps', 'lapses', 'correct', 'wrong', 'miss', 'lastReview', 'nextReview', 'lastTime'];
    let added = 0, updated = 0;
    for (const ic of inc.cards) {
      const c = byId.get(ic.id);
      if (!c) { out.cards.push(clone(ic)); added++; continue; }
      const newerContent = (ic.updatedAt || 0) > (c.updatedAt || 0);
      const newerLearning = (ic.lastReview || 0) > (c.lastReview || 0);
      if (newerContent) { for (const k of ['de', 'fa', 'translit', 'tags', 'audio', 'active', 'fav', 'exDe', 'exFa', 'updatedAt']) c[k] = clone(ic[k]); updated++; }
      if (newerLearning) for (const k of LEARN) c[k] = ic[k];
    }
    const key = l => [l.date, l.cardId || '', l.itemId || '', l.rating, l.mode].join('|');
    const seen = new Set(out.logs.map(key));
    for (const l of inc.logs) if (!seen.has(key(l))) { out.logs.push(clone(l)); seen.add(key(l)); }
    out.logs.sort((a, b) => a.date - b.date);
    for (const [k, v] of Object.entries(inc.logArchive || {})) {
      if (!out.logArchive[k] || out.logArchive[k].n < v.n) out.logArchive[k] = clone(v);
    }
    for (const [k, v] of Object.entries(inc.sent || {})) {
      if (!out.sent[k] || (out.sent[k].last || 0) < (v.last || 0)) out.sent[k] = clone(v);
    }
    return { data: out, added, updated };
  },

  /**
   * Wendet ein geprüftes Backup an. mode: 'replace' | 'merge'.
   * Legt vorher IMMER eine Sicherheitskopie an und rollt bei Fehlern zurück.
   */
  async apply(parsed, mode = 'replace') {
    const wasRecovery = Store.mode === 'recovery';
    const before = Store.data;
    let undoId = null;
    if (!wasRecovery) {
      const rawNow = Store._get(Store.KEY);
      if (rawNow) Store._set(Store.PREV + '.prerestore', rawNow);
      const rec = await Store.snapshot('pre-restore');
      undoId = rec ? rec.id : null;
    }
    let next, extra = {};
    if (mode === 'merge' && !wasRecovery) {
      const m = this.merge(Store.data, parsed.data);
      next = m.data; extra = { added: m.added, updated: m.updated };
    } else {
      next = clone(parsed.data);
      next.settings = Schema.fixSettings(next.settings);
    }
    next.schemaVersion = SCHEMA;
    next.meta = Object.assign({}, next.meta, { restoredAt: now() });
    Store.data = next;
    Store.mode = 'ok';
    if (!Store.save()) {
      Store.data = before;            // Rollback im Speicher – Hauptdatensatz blieb unverändert
      Store.mode = wasRecovery ? 'recovery' : 'ok';
      return { ok: false, error: 'Speichern nicht möglich (Speicher voll?). Es wurde nichts verändert.' };
    }
    let audioRestored = 0;
    for (const [id, a] of Object.entries(parsed.audio || {})) {
      if (a && a.b64 && next.cards.some(c => c.id === id)) {
        try { if (await AudioStore.put(id, b64ToBlob(a.b64, a.type))) audioRestored++; } catch (e) {}
      }
    }
    Store.recovery = null;
    this.lastUndo = undoId;
    return Object.assign({ ok: true, undoId, audioRestored, cards: next.cards.length }, extra);
  },

  /** Stellt den Stand vor der letzten Wiederherstellung wieder her. */
  async undo() {
    if (!this.lastUndo) return { ok: false, error: 'Nichts zum Rückgängigmachen.' };
    const snap = await Store.getSnapshot(this.lastUndo);
    if (!snap) return { ok: false, error: 'Die Sicherheitskopie wurde nicht gefunden.' };
    const parsed = this.parse(snap.json);
    if (!parsed.ok) return parsed;
    this.lastUndo = null;
    return this.apply(parsed, 'replace');
  },

  /** Aus einem Schnappschuss wiederherstellen. */
  async restoreSnapshot(id) {
    const snap = await Store.getSnapshot(id);
    if (!snap) return { ok: false, error: 'Schnappschuss nicht gefunden.' };
    const parsed = this.parse(snap.json);
    if (!parsed.ok) return parsed;
    return this.apply(parsed, 'replace');
  },

  /** Wiederherstellungsmodus verlassen: bewusst bei null beginnen (Rohtext bleibt in der Quarantäne). */
  startFresh() {
    Store.data = emptyData();
    Store.mode = 'ok'; Store.recovery = null;
    return Store.save();
  }
};
