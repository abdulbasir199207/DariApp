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
const GEMINI_KEY_FILE = path.join(DATA, 'gemini-key');
const GEMINI_MODEL = process.env.GEMINI_MODEL || 'gemini-flash-latest';
const geminiKey = () => { try { return fs.readFileSync(GEMINI_KEY_FILE, 'utf8').trim(); } catch { return ''; } };
let genBusy = false, genLast = 0;
const latestCards = () => { try { const b = JSON.parse(fs.readFileSync(LATEST, 'utf8')); return (b.data && b.data.cards) || b.cards || []; } catch { return []; } };
// Prüft und ergänzt Sätze (gemeinsam für manuelles Senden und Gemini). Gibt die Zahl der neuen Sätze zurück.
const addSaetze = (neu) => {
  const list = readSaetze(), seen = new Set(list.map((x) => x.fa));
  let n = 0;
  for (const x of Array.isArray(neu) ? neu : []) {
    if (!x || !str(x.de, 300) || !str(x.fa, 300) || !str(x.pd, 200) || !str(x.pf, 200)) continue;
    const de = x.de.trim().replace(/[.?!]+$/, ''), fa = x.fa.trim().replace(/[.؟?!]+$/, '');
    if (seen.has(fa)) continue;
    if (de.split(/ +/).length !== x.pd.trim().split(/ +/).length || fa.split(/ +/).length !== x.pf.trim().split(/ +/).length) continue;
    if (!/^[PNVADRX]( [PNVADRX])*$/.test(x.pd.trim()) || !/^[PNVADRX]( [PNVADRX])*$/.test(x.pf.trim())) continue;
    list.push({ id: 'u_' + Date.now().toString(36) + '_' + n, de: de.replace(/ +/g, ' '), fa: fa.replace(/ +/g, ' '), tr: String(x.tr || '').trim(),
      pd: x.pd.trim().replace(/ +/g, ' '), pf: x.pf.trim().replace(/ +/g, ' '), q: !!x.q,
      woerter: Array.isArray(x.woerter) ? x.woerter.slice(0, 10).map(String) : [], erstellt: new Date().toISOString() });
    seen.add(fa); n++;
  }
  if (n) writeSaetze(list);
  return { neu: n, gesamt: list.length };
};
const PROMPT = (neue, bekannt) => `Du bist Persischlehrer (Farsi, Iran). Bilde 10 kurze, natürliche, grammatisch korrekte Übungssätze für Anfänger (3–8 Wörter).
Verwende vor allem diese NEUEN Wörter (jedes in 1–2 Sätzen): ${JSON.stringify(neue)}
Erlaubt sind zusätzlich diese bekannten Wörter und einfache Grundwörter: ${JSON.stringify(bekannt)}
Antworte NUR mit einem JSON-Array. Jedes Element:
{"de":"Ich esse Brot","fa":"من نان می‌خورم","tr":"man nân mi-khoram","pd":"P V N","pf":"P N V","woerter":["Brot"],"q":false}
Regeln: de und fa ohne Satzzeichen am Ende; Fragen mit "q":true. Persisch in persischer Schrift, Halbleerzeichen (ZWNJ) bei می‌ und ‌ها.
pd/pf: für JEDES durch Leerzeichen getrennte Wort GENAU ein Buchstabe – P Pronomen, N Nomen, V Verb, A Adjektiv, D Adverb/Fragewort, R Präposition, X Sonstiges (Artikel, Hilfswörter). Die Anzahl der Buchstaben muss exakt der Wortanzahl von de bzw. fa entsprechen. Ein mit ZWNJ verbundenes Wort ist EIN Wort.
tr: Lautschrift (â für langes a, kh, sh, gh, ch). woerter: die deutschen Wörter aus der Liste, die im Satz vorkommen.`;
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
      const r = addSaetze(obj && obj.saetze);
      log('Sätze ergänzt', r.neu);
      return send(res, 201, { ok: true, ...r });
    }
    if (req.method === 'GET' && url.pathname === '/api/einstellungen') return send(res, 200, { gemini: !!geminiKey() });
    if (req.method === 'POST' && url.pathname === '/api/einstellungen/gemini') {
      let obj; try { obj = JSON.parse((await readBody(req)).toString('utf8')); } catch { return send(res, 400, { error: 'kein gültiges JSON' }); }
      const k = String((obj && obj.key) || '').trim();
      if (k && !/^[A-Za-z0-9_-]{20,100}$/.test(k)) return send(res, 400, { error: 'Schlüssel sieht ungültig aus' });
      if (k) fs.writeFileSync(GEMINI_KEY_FILE, k + '\n', { mode: 0o600 }); else if (fs.existsSync(GEMINI_KEY_FILE)) fs.renameSync(GEMINI_KEY_FILE, GEMINI_KEY_FILE + '.alt');
      return send(res, 200, { ok: true, gemini: !!k });
    }
    if (req.method === 'POST' && url.pathname === '/api/saetze/generieren') {
      const key = geminiKey();
      if (!key) return send(res, 409, { error: 'Kein Gemini-Schlüssel hinterlegt' });
      if (genBusy || Date.now() - genLast < 60_000) return send(res, 429, { error: 'Bitte kurz warten – es werden gerade Sätze gebildet' });
      const cards = latestCards().filter((c) => c && Array.isArray(c.de) && c.de[0]);
      if (!cards.length) return send(res, 409, { error: 'Noch keine Wörter auf dem NUC' });
      const used = new Set(readSaetze().flatMap((x) => x.woerter || []));
      const wort = (c) => ({ de: c.de[0], fa: (c.fa || [])[0] || '' });
      let neue = cards.filter((c) => !used.has(c.de[0])).map(wort);
      const nurNeue = neue.length > 0;
      if (!neue.length) neue = cards.slice().sort(() => Math.random() - 0.5).map(wort);   // keine neuen: zufällige Auswahl
      neue = neue.slice(0, 12);
      const bekannt = cards.map(wort).filter((w) => !neue.some((x) => x.de === w.de)).slice(0, 60);
      genBusy = true; genLast = Date.now();
      try {
        const r = await fetch(`${process.env.GEMINI_BASE || 'https://generativelanguage.googleapis.com'}/v1beta/models/${GEMINI_MODEL}:generateContent`, {
          method: 'POST', headers: { 'Content-Type': 'application/json', 'x-goog-api-key': key },
          body: JSON.stringify({ contents: [{ parts: [{ text: PROMPT(neue, bekannt) }] }], generationConfig: { responseMimeType: 'application/json', temperature: 0.7 } }),
          signal: AbortSignal.timeout(90_000) });
        const j = await r.json().catch(() => ({}));
        if (!r.ok) { log('Gemini-Fehler', r.status, JSON.stringify(j).slice(0, 300)); return send(res, 502, { error: r.status === 429 ? 'Gemini-Tageslimit erreicht – später nochmal' : 'Gemini antwortet ' + r.status }); }
        const text = (((j.candidates || [])[0] || {}).content || {}).parts?.map((p) => p.text || '').join('') || '[]';
        let arr; try { arr = JSON.parse(text.replace(/^```(json)?|```$/g, '').trim()); } catch { arr = []; }
        const out = addSaetze(arr);
        log('Gemini-Sätze', out.neu, 'von', Array.isArray(arr) ? arr.length : 0);
        return send(res, 201, { ok: true, ...out, nurNeue });
      } catch (e) { log('Gemini-Fehler', e.message); return send(res, 502, { error: 'Gemini nicht erreichbar' }); }
      finally { genBusy = false; }
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
