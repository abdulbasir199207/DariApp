// Abgleich mit dem eigenen Server: zwei Geräte, ein echter ZARA-Sync-Server (zara-sync/server.mjs) im Testprozess.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { mkdtempSync, readFileSync, existsSync, readdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { loadApi, FakeStorage } from './helpers.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const SERVER = process.env.ZARA_SYNC_SERVER || join(here, '..', '..', 'Server', 'zara-sync', 'server.mjs');

async function startServer() {
  const dir = mkdtempSync(join(tmpdir(), 'zara-sync-'));
  const port = 20000 + Math.floor(Math.random() * 20000);
  const p = spawn(process.execPath, [SERVER], { env: { ...process.env, ZARA_DATA: dir, PORT: String(port), ZARA_WEB: '/nicht/da' }, stdio: 'pipe' });
  for (let i = 0; i < 50; i++) {
    try { const r = await fetch(`http://127.0.0.1:${port}/api/health`); if (r.ok) break; } catch (e) {}
    await new Promise(r => setTimeout(r, 100));
  }
  return { url: `http://127.0.0.1:${port}`, key: readFileSync(join(dir, 'token'), 'utf8').trim(), dir, stop: () => p.kill() };
}

function device(srv, name) {
  const { api } = loadApi();
  const ls = new FakeStorage();
  api.Store.load(); api.Store.mode = 'ok';
  api.Sync.setup({ ls, http: fetch });
  assert.ok(api.Sync.configure(srv.url, srv.key));
  return { api, name };
}
const addCard = (d, de, fa) => {
  d.api.Store.data.cards.push(d.api.Schema.fixCard({ id: d.api.uid(), de: [de], fa: [fa], translit: '', tags: [], createdAt: Date.now(), updatedAt: Date.now() }, []));
  assert.ok(d.api.Store.save());
};
const words = d => JSON.parse(JSON.stringify(d.api.Store.data.cards.map(c => c.de[0]).sort()));

test('Sync: ohne Schlüssel passiert nichts', async () => {
  const { api } = loadApi();
  api.Sync.setup({ ls: new FakeStorage(), http: fetch });
  assert.equal(api.Sync.ready(), false);
  assert.equal((await api.Sync.push()).skipped, true);
});

test('Sync: zwei Geräte gleichen Wörter ab, nichts geht verloren, Server bewahrt jeden Stand', { skip: !existsSync(SERVER) }, async () => {
  const srv = await startServer();
  try {
    const handy = device(srv, 'handy'), pc = device(srv, 'pc');
    addCard(handy, 'Haus', 'خانه');
    assert.ok((await handy.api.Sync.push()).ok);
    const r1 = await pc.api.Sync.pull();
    assert.ok(r1.ok && r1.merged, JSON.stringify(r1));
    assert.deepEqual(words(pc), ['Haus']);

    addCard(pc, 'Wasser', 'آب');
    assert.ok((await pc.api.Sync.push()).ok);
    addCard(handy, 'Brot', 'نان');                       // gleichzeitig auf dem Handy
    const r2 = await handy.api.Sync.pull();             // holt „Wasser", behält „Brot"
    assert.ok(r2.ok && r2.merged);
    assert.deepEqual(words(handy), ['Brot', 'Haus', 'Wasser']);
    const r3 = await pc.api.Sync.pull();
    assert.ok(r3.ok);
    assert.deepEqual(words(pc), ['Brot', 'Haus', 'Wasser']);

    const r4 = await pc.api.Sync.pull();                 // nichts Neues: kein erneutes Zusammenführen
    assert.ok(r4.ok && !r4.merged);
    assert.ok(readdirSync(join(srv.dir, 'history')).length >= 4, 'jeder Stand bleibt auf dem Server');
  } finally { srv.stop(); }
});

test('Sync: falscher Schlüssel wird abgewiesen und ändert nichts', { skip: !existsSync(SERVER) }, async () => {
  const srv = await startServer();
  try {
    const d = device(srv, 'x');
    d.api.Sync.configure(srv.url, 'falsch');
    addCard(d, 'Mutter', 'مادر');
    const r = await d.api.Sync.push();
    assert.equal(r.ok, false);
    assert.match(r.error, /401/);
    assert.deepEqual(words(d), ['Mutter']);
  } finally { srv.stop(); }
});
