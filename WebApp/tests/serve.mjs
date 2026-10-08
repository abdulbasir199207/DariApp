// Lokaler Testserver: gleiche Origin für alte (v2.0) und neue Version → localStorage wird geteilt,
// genau wie beim Update desselben Artifacts.
//   node tests/serve.mjs <Port> <Pfad zu v2.0-HTML>
import http from 'node:http';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const port = Number(process.argv[2] || 8123);
const oldPath = process.argv[3];
const wrap = body => `<!doctype html><html lang="de"><head></head><body>${body}</body></html>`;

http.createServer((req, res) => {
  const url = req.url.split('?')[0];
  try {
    if (url === '/new.html') { res.writeHead(200, { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-store' }); res.end(wrap(readFileSync(join(here, '..', 'ZARA.html'), 'utf8'))); }
    else if (url === '/old.html' && oldPath) { res.writeHead(200, { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-store' }); res.end(wrap(readFileSync(oldPath, 'utf8'))); }
    else if (url === '/driver.js') { res.writeHead(200, { 'content-type': 'text/javascript; charset=utf-8', 'cache-control': 'no-store' }); res.end(readFileSync(join(here, 'driver.js'))); }
    else if (url === '/fixture.json') { res.writeHead(200, { 'content-type': 'application/json' }); res.end(readFileSync(join(here, 'fixtures', 'v2-data.json'))); }
    else { res.writeHead(404); res.end('nicht gefunden'); }
  } catch (e) { res.writeHead(500); res.end(String(e)); }
}).listen(port, () => console.log('Testserver auf http://localhost:' + port));
