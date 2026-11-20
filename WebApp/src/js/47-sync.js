/* ============================================================
   47-sync: Abgleich mit dem eigenen Server (NUC, „ZARA-Sync").
   - Nach jeder Änderung wird der aktuelle Stand (Format „zara-backup")
     an den Server geschickt. Der Server bewahrt JEDEN Stand auf und löscht nie.
   - Beim Start und beim Zurückkehren in die App wird der neueste Stand
     vom Server geholt und ZUSAMMENGEFÜHRT (Backup.merge – es geht nichts verloren,
     vorher legt Backup.apply automatisch eine Sicherheitskopie an).
   - Aus, solange kein Server-Schlüssel hinterlegt ist. Offline bleibt alles wie bisher.
   ============================================================ */

const Sync = {
  CFG_KEY: 'zara.sync',
  DELAY: 8000,                 // nach der letzten Änderung so lange warten, dann senden
  ls: null,                    // Speicher für die Einstellungen (Browser: localStorage)
  http: null,                  // fetch-Funktion (Browser: window.fetch) – in Tests ersetzbar
  timer: null,
  busy: false,
  applying: false,
  lastError: null,

  cfg() {
    try { return JSON.parse((this.ls && this.ls.getItem(this.CFG_KEY)) || 'null') || {}; } catch (e) { return {}; }
  },
  saveCfg(c) { try { if (this.ls) this.ls.setItem(this.CFG_KEY, JSON.stringify(c)); } catch (e) {} },
  ready() { const c = this.cfg(); return !!(c.enabled && c.url && c.key && this.http); },

  /** Einrichtung über den Link vom Server: …/?key=SCHLÜSSEL (Adresse = Herkunft der Seite). */
  setup({ ls, http, origin, search } = {}) {
    this.ls = ls || null; this.http = http || null;
    const c = this.cfg();
    let key = null;
    try { key = new URLSearchParams(search || '').get('key'); } catch (e) {}
    if (key) { c.key = key; c.enabled = true; if (origin && /^https?:\/\//.test(origin)) c.url = origin; this.saveCfg(c); return true; }
    return false;
  },
  configure(url, key) {
    const c = this.cfg();
    c.url = String(url || '').trim().replace(/\/+$/, ''); c.key = String(key || '').trim(); c.enabled = !!(c.url && c.key);
    this.saveCfg(c);
    return c.enabled;
  },
  notify() { try { if (typeof onSyncChange === 'function') setTimeout(onSyncChange, 0); } catch (e) {} },
  disable() { const c = this.cfg(); c.enabled = false; this.saveCfg(c); },

  async req(method, path, body, { keepalive = false } = {}) {
    const c = this.cfg();
    const opts = { method, headers: { Authorization: 'Bearer ' + c.key }, keepalive };
    if (body != null) { opts.headers['Content-Type'] = 'application/json'; opts.body = body; }
    const res = await this.http(c.url + path, opts);
    return res;
  },

  /** Aktuellen Stand senden (ohne Audio – Aufnahmen bleiben auf dem Gerät). */
  async push({ keepalive = false } = {}) {
    if (!this.ready() || this.applying || Store.mode !== 'ok') return { ok: false, skipped: true };
    try {
      const b = await Backup.build({ includeAudio: false });
      const createdAt = JSON.parse(b.json).createdAt;
      const res = await this.req('PUT', '/api/backup', b.json, { keepalive });
      if (!res.ok) throw new Error('Server antwortet ' + res.status);
      const c = this.cfg(); c.lastPushAt = createdAt; c.lastOkAt = now(); this.saveCfg(c);
      this.lastError = null; this.notify();
      return { ok: true };
    } catch (e) { this.lastError = e.message || String(e); this.notify(); return { ok: false, error: this.lastError }; }
  },

  /** Neuesten Server-Stand holen und zusammenführen, falls er von einem anderen Gerät stammt. */
  async pull() {
    if (!this.ready() || this.busy || Store.mode !== 'ok') return { ok: false, skipped: true };
    this.busy = true;
    try {
      const res = await this.req('GET', '/api/backup/latest');
      if (res.status === 404) { this.busy = false; return this.push(); }   // Server leer: ersten Stand hochladen
      if (!res.ok) throw new Error('Server antwortet ' + res.status);
      const text = await res.text();
      const parsed = Backup.parse(text);
      if (!parsed.ok) throw new Error(parsed.error);
      const c = this.cfg();
      const seen = Math.max(c.lastPushAt || 0, c.lastPullAt || 0);
      let merged = null;
      if (!parsed.createdAt || parsed.createdAt > seen) {
        this.applying = true;
        try { merged = await Backup.apply(parsed, 'merge'); } finally { this.applying = false; }
        if (!merged.ok) throw new Error(merged.error);
        const c2 = this.cfg(); c2.lastPullAt = parsed.createdAt || now(); c2.lastOkAt = now(); this.saveCfg(c2);
        await this.push();          // zusammengeführten Stand zurückschicken
      } else {
        const c2 = this.cfg(); c2.lastOkAt = now(); this.saveCfg(c2);
      }
      this.lastError = null;
      return { ok: true, merged };
    } catch (e) { this.lastError = e.message || String(e); return { ok: false, error: this.lastError }; }
    finally { this.busy = false; }
  },

  /** Nach einer Änderung: Senden verzögert einplanen. */
  schedule() {
    if (!this.ready() || this.applying) return;
    if (this.timer) clearTimeout(this.timer);
    this.timer = setTimeout(() => { this.timer = null; this.push(); }, this.DELAY);
    this.notify();
  },
  /** App geht in den Hintergrund: sofort senden. */
  flush() {
    if (this.timer) { clearTimeout(this.timer); this.timer = null; return this.push({ keepalive: true }); }
    return Promise.resolve({ ok: true, skipped: true });
  }
};

/* Jede erfolgreiche Speicherung plant das Senden ein (nur wenn der Abgleich eingerichtet ist). */
{
  const origSave = Store.save;
  Store.save = function () { const ok = origSave.apply(this, arguments); if (ok) Sync.schedule(); return ok; };
}
