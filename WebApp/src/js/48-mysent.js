/* ============================================================
   48-mysent: „Meine Sätze“ – Sätze aus den eigenen Wörtern,
   die auf dem NUC gesammelt werden (Server: /api/saetze).
   Die Liste wird lokal zwischengespeichert, damit sie auch offline da ist.
   Als falsch gemeldete Sätze werden nicht mehr geübt (aber nie gelöscht).
   ============================================================ */

const MySent = {
  KEY: 'zara.mysent',
  ls: null,
  raw: [],

  /** Lokale Kopie laden und in die Satzbibliothek einhängen. */
  init(ls) { this.ls = ls || null; try { this.raw = JSON.parse((this.ls && this.ls.getItem(this.KEY)) || '[]') || []; } catch (e) { this.raw = []; } this.install(); },
  valid(x) { return x && x.id && x.de && x.fa && x.pd && x.pf && x.de.split(' ').length === x.pd.split(' ').length && x.fa.split(' ').length === x.pf.split(' ').length; },
  install() {
    for (let i = SENTENCES.length - 1; i >= 0; i--) if (SENTENCES[i].mine) SENTENCES.splice(i, 1);
    for (const x of this.raw) {
      if (x.falsch || !this.valid(x)) continue;
      const de = x.de.replace(/[.?!]+$/, ''), fa = x.fa.replace(/[.؟?!]+$/, '');
      const s = S(x.id, 'Meine Sätze', 1, de, fa, x.tr || '', x.pd, x.pf, { q: !!x.q });
      s.mine = true; SENTENCES.push(s);
    }
  },
  list() { return SENTENCES.filter(s => s.mine); },
  count() { return this.list().length; },
  isMine(id) { return typeof id === 'string' && id.startsWith('u_'); },

  /** Neueste Liste vom NUC holen (nur wenn der Abgleich eingerichtet ist). */
  async fetch() {
    if (!Sync.ready()) return { ok: false, skipped: true };
    try {
      const res = await Sync.req('GET', '/api/saetze');
      if (!res.ok) throw new Error('Server antwortet ' + res.status);
      const list = JSON.parse(await res.text());
      if (!Array.isArray(list)) throw new Error('ungültig');
      this.raw = list; try { if (this.ls) this.ls.setItem(this.KEY, JSON.stringify(list)); } catch (e) {}
      this.install();
      return { ok: true, n: this.count() };
    } catch (e) { return { ok: false, error: e.message || String(e) }; }
  },
  async flag(id) {
    const x = this.raw.find(y => y.id === id); if (x) x.falsch = true;
    try { if (this.ls) this.ls.setItem(this.KEY, JSON.stringify(this.raw)); } catch (e) {}
    this.install();
    if (Sync.ready()) { try { await Sync.req('POST', '/api/saetze/falsch', JSON.stringify({ id })); } catch (e) {} }
  }
};

/** Übungsplan nur aus „Meinen Sätzen“: gemischt Satzbildung, Übersetzen, Lückentext. */
function planMySent(sent, { count = 10, direction = 'mixed' } = {}, rng = Math.random) {
  const pool = MySent.list();
  const types = ['build', 'translate', 'cloze'];
  return pickItems(pool, sent, count, rng).map((s, i) => {
    const type = types[i % 3], dir = resolveDir(direction, rng);
    const step = { type, sentId: s.id, dir };
    if (type === 'cloze') step.lang = dir === 'g2p' ? 'fa' : 'de';
    return step;
  });
}
