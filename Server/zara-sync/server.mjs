// ZARA-Sync: speichert jeden Stand der ZARA-App (Format "zara-backup") auf dem NUC.
// Regel: Jeder Upload wird als NEUE Datei aufbewahrt. Nichts wird überschrieben oder gelöscht.
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

const DATA = process.env.ZARA_DATA || '/data';
const HIST = path.join(DATA, 'history');
const LATEST = path.join(DATA, 'latest.json');
const TOKEN_FILE = path.join(DATA, 'token');
const SAETZE = path.join(DATA, 'saetze.json');            // „Meine Sätze“ – wird nur ergänzt, nie gelöscht
const SAETZE_HIST = path.join(DATA, 'saetze-history');
const WEB = process.env.ZARA_WEB || '/app/web/ZARA.html';
const PORT = Number(process.env.PORT || 8090);
const MAX = 100 * 1024 * 1024; // 100 MB (Audio-Aufnahmen können im Backup stecken)

fs.mkdirSync(HIST, { recursive: true });
fs.mkdirSync(SAETZE_HIST, { recursive: true });
const readSaetze = () => { try { return JSON.parse(fs.readFileSync(SAETZE, 'utf8')); } catch { return []; } };
const writeSaetze = (list) => {
  const raw = JSON.stringify(list);
  fs.writeFileSync(path.join(SAETZE_HIST, new Date().toISOString().replace(/[:.]/g, '-') + '_' + crypto.randomBytes(3).toString('hex') + '.json'), raw, { flag: 'wx', mode: 0o600 });
  const tmp = SAETZE + '.tmp'; fs.writeFileSync(tmp, raw, { mode: 0o600 }); fs.renameSync(tmp, SAETZE);
};
const str = (v, n) => typeof v === 'string' && v.trim() && v.length <= n;
if (!fs.existsSync(TOKEN_FILE)) fs.writeFileSync(TOKEN_FILE, crypto.randomBytes(24).toString('hex') + '\n', { mode: 0o600 });
const TOKEN = fs.readFileSync(TOKEN_FILE, 'utf8').trim();

const log = (...a) => console.log(new Date().toISOString(), ...a);
const send = (res, code, body, type = 'application/json; charset=utf-8') => {
  res.writeHead(code, { 'Content-Type': type, 'Cache-Control': 'no-store',
    'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'Authorization, Content-Type',
    'Access-Control-Allow-Methods': 'GET, PUT, POST, OPTIONS' });
  res.end(typeof body === 'string' || Buffer.isBuffer(body) ? body : JSON.stringify(body));
};
const authorized = (req, url) => {
  const h = req.headers.authorization || '';
  const given = h.startsWith('Bearer ') ? h.slice(7) : (url.searchParams.get('key') || '');
  const a = Buffer.from(given), b = Buffer.from(TOKEN);
  return a.length === b.length && crypto.timingSafeEqual(a, b);
};
const readBody = (req) => new Promise((ok, fail) => {
  const chunks = []; let n = 0;
  req.on('data', (c) => { n += c.length; if (n > MAX) { fail(new Error('zu groß')); req.destroy(); } else chunks.push(c); });
  req.on('end', () => ok(Buffer.concat(chunks)));
  req.on('error', fail);
});
const history = () => fs.readdirSync(HIST).filter((f) => f.endsWith('.json')).sort().reverse();

http.createServer(async (req, res) => {
  const url = new URL(req.url, 'http://x');
  try {
    if (req.method === 'OPTIONS') return send(res, 204, '');
    if (url.pathname === '/api/health') return send(res, 200, { ok: true, staende: history().length, saetze: readSaetze().length });
    if (req.method === 'GET' && (url.pathname === '/' || url.pathname === '/ZARA.html')) {
      return fs.existsSync(WEB) ? send(res, 200, fs.readFileSync(WEB), 'text/html; charset=utf-8') : send(res, 404, { error: 'Web-App fehlt' });
    }
    if (!url.pathname.startsWith('/api/')) return send(res, 404, { error: 'nicht gefunden' });
    if (!authorized(req, url)) return send(res, 401, { error: 'Schlüssel fehlt oder falsch' });

    if ((req.method === 'PUT' || req.method === 'POST') && url.pathname === '/api/backup') {
      const raw = await readBody(req);
      let obj; try { obj = JSON.parse(raw.toString('utf8')); } catch { return send(res, 400, { error: 'kein gültiges JSON' }); }
      if (obj.format !== 'zara-backup' || typeof obj.formatVersion !== 'number') return send(res, 400, { error: 'kein zara-backup' });
      const quelle = String(obj.source || 'unbekannt').replace(/[^a-z0-9-]/gi, '').slice(0, 20) || 'unbekannt';
      const name = new Date().toISOString().replace(/[:.]/g, '-') + '_' + quelle + '_' + crypto.randomBytes(3).toString('hex') + '.json';
      const ziel = path.join(HIST, name);
      fs.writeFileSync(ziel, raw, { flag: 'wx', mode: 0o600 });           // nie überschreiben
      const tmp = LATEST + '.tmp'; fs.writeFileSync(tmp, raw, { mode: 0o600 }); fs.renameSync(tmp, LATEST);
      log('gespeichert', name, raw.length, 'Bytes');
      return send(res, 201, { ok: true, gespeichert: name, bytes: raw.length });
    }
    if (req.method === 'GET' && url.pathname === '/api/backup/latest') {
      return fs.existsSync(LATEST) ? send(res, 200, fs.readFileSync(LATEST)) : send(res, 404, { error: 'noch kein Stand' });
    }
    if (req.method === 'GET' && url.pathname === '/api/saetze') return send(res, 200, readSaetze());
    if (req.method === 'POST' && url.pathname === '/api/saetze') {
      let obj; try { obj = JSON.parse((await readBody(req)).toString('utf8')); } catch { return send(res, 400, { error: 'kein gültiges JSON' }); }
      const neu = Array.isArray(obj && obj.saetze) ? obj.saetze : [];
      const list = readSaetze(), seen = new Set(list.map((x) => x.fa));
      let n = 0;
      for (const x of neu) {
        if (!x || !str(x.de, 300) || !str(x.fa, 300) || !str(x.pd, 200) || !str(x.pf, 200) || seen.has(x.fa)) continue;
        if (x.de.split(' ').length !== x.pd.split(' ').length || x.fa.split(' ').length !== x.pf.split(' ').length) continue;
        list.push({ id: 'u_' + Date.now().toString(36) + '_' + n, de: x.de.trim(), fa: x.fa.trim(), tr: String(x.tr || '').trim(),
          pd: x.pd.trim(), pf: x.pf.trim(), q: !!x.q, woerter: Array.isArray(x.woerter) ? x.woerter.slice(0, 10).map(String) : [], erstellt: new Date().toISOString() });
        seen.add(x.fa); n++;
      }
      if (n) writeSaetze(list);
      log('Sätze ergänzt', n);
      return send(res, 201, { ok: true, neu: n, gesamt: list.length });
    }
    if (req.method === 'POST' && url.pathname === '/api/saetze/falsch') {
      let obj; try { obj = JSON.parse((await readBody(req)).toString('utf8')); } catch { return send(res, 400, { error: 'kein gültiges JSON' }); }
      const list = readSaetze(), x = list.find((y) => y.id === (obj && obj.id));
      if (!x) return send(res, 404, { error: 'nicht gefunden' });
      x.falsch = true; writeSaetze(list);                      // nur markiert, nicht gelöscht
      return send(res, 200, { ok: true });
    }
    if (req.method === 'GET' && url.pathname === '/api/history') {
      return send(res, 200, history().map((f) => ({ name: f, bytes: fs.statSync(path.join(HIST, f)).size })));
    }
    const m = url.pathname.match(/^\/api\/history\/([\w.-]+\.json)$/);
    if (req.method === 'GET' && m && fs.existsSync(path.join(HIST, m[1]))) return send(res, 200, fs.readFileSync(path.join(HIST, m[1])));
    return send(res, 404, { error: 'nicht gefunden' });
  } catch (e) {
    log('Fehler', e.message);
    return send(res, 500, { error: e.message });
  }
}).listen(PORT, () => log('ZARA-Sync läuft auf Port', PORT, '· Stände:', history().length));
