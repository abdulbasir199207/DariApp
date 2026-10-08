import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { loadApi } from './helpers.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const plain = x => JSON.parse(JSON.stringify(x));   // VM-Objekte → Hauptrealm (für deepEqual)
const V2 = readFileSync(join(here, 'fixtures', 'v2-data.json'), 'utf8');

test('Neuinstallation: keine Daten → fresh, nichts wird geschrieben', () => {
  const { api, storage } = loadApi();
  const info = api.Store.load();
  assert.equal(info.fresh, true);
  assert.equal(api.Store.mode, 'ok');
  assert.equal(storage.getItem('dariapp.v1'), null);
});

test('Update v2.0 → v3: alle Karten, Verlauf und Termine bleiben unverändert erhalten', () => {
  const { api, storage } = loadApi();
  storage.setItem('dariapp.v1', V2);
  const before = JSON.parse(V2);
  const info = api.Store.load();
  assert.equal(info.migratedFrom, 2);
  const after = api.Store.data;
  assert.equal(after.schemaVersion, 3);
  assert.equal(after.cards.length, before.cards.length);
  assert.equal(after.logs.length, before.logs.length);
  for (const b of before.cards) {
    const a = after.cards.find(c => c.id === b.id);
    assert.ok(a, 'Karte fehlt: ' + b.id);
    for (const k of ['de', 'fa', 'translit', 'tags', 'audio', 'active', 'fav', 'state', 's', 'interval', 'reps', 'lapses', 'correct', 'wrong', 'lastReview', 'nextReview', 'createdAt', 'updatedAt']) {
      assert.deepEqual(plain(a[k]), b[k], `Feld ${k} der Karte ${b.id} wurde verändert`);
    }
    assert.ok(a.d >= 0 && a.d <= 10);
  }
  assert.deepEqual(plain(after.logs.map(l => [l.date, l.rating, l.cardId])), before.logs.map(l => [l.date, l.rating, l.cardId]));
  assert.deepEqual(after.settings.appearance, 'dark');
  assert.equal(after.settings.dailyGoal, 30);
  assert.equal(after.settings.animations, false);
  // Originalstand wurde VOR der Migration synchron gesichert
  assert.equal(storage.getItem('dariapp.v1.prev.premigration'), V2);
  assert.equal(info.originalRaw, V2);
});

test('Migration: Schwierigkeit wird aus dem Verlauf korrekt neu berechnet (Bugfix FSRS-D0)', () => {
  const { api, storage } = loadApi();
  storage.setItem('dariapp.v1', V2);
  const before = JSON.parse(V2);
  api.Store.load();
  const withLogs = api.Store.data.cards.filter(c => c.reps > 0 && before.logs.some(l => l.cardId === c.id));
  assert.ok(withLogs.length > 5);
  let changed = 0;
  for (const c of withLogs) {
    const ratings = before.logs.filter(l => l.cardId === c.id).sort((a, b) => a.date - b.date).map(l => l.rating);
    const expected = api.FSRS.replayD(ratings);
    assert.ok(Math.abs(c.d - expected) < 1e-9);
    const old = before.cards.find(x => x.id === c.id).d;
    if (Math.abs(old - c.d) > 0.01) changed++;
  }
  assert.ok(changed > 0, 'mindestens eine Schwierigkeit muss korrigiert worden sein');
});

test('Defekter Hauptdatensatz wird NIE überschrieben: Quarantäne + Wiederherstellungsmodus', () => {
  const { api, storage } = loadApi();
  const broken = V2.slice(0, V2.length - 50);
  storage.setItem('dariapp.v1', broken);
  const info = api.Store.load();
  assert.equal(info.recovery, true);
  assert.equal(api.Store.mode, 'recovery');
  assert.equal(storage.getItem('dariapp.v1'), broken, 'Hauptdatensatz darf nicht verändert werden');
  assert.equal(api.Store.save(), false, 'Speichern muss im Wiederherstellungsmodus gesperrt sein');
  assert.equal(storage.getItem('dariapp.v1'), broken);
  const qk = [...storage.m.keys()].find(k => k.startsWith('dariapp.v1.quarantine.'));
  assert.ok(qk, 'Rohtext muss in Quarantäne liegen');
  assert.equal(storage.getItem(qk), broken);
});

test('Defekter Hauptdatensatz + gültiger letzter Stand → automatische Rettung', () => {
  const { api, storage } = loadApi();
  storage.setItem('dariapp.v1.prev', V2);
  storage.setItem('dariapp.v1', '{"cards":[');
  const info = api.Store.load();
  assert.equal(info.recovered, 'prev');
  assert.equal(api.Store.mode, 'ok');
  assert.equal(api.Store.data.cards.length, JSON.parse(V2).cards.length);
  assert.ok([...storage.m.keys()].some(k => k.startsWith('dariapp.v1.quarantine.')));
});

test('Hauptdatensatz fehlt, letzter Stand vorhanden → wird verwendet', () => {
  const { api, storage } = loadApi();
  storage.setItem('dariapp.v1.prev', V2);
  const info = api.Store.load();
  assert.equal(info.recovered, 'prev');
  assert.equal(api.Store.data.cards.length, JSON.parse(V2).cards.length);
});

test('Daten aus neuerer Version werden nicht angefasst', () => {
  const { api, storage } = loadApi();
  const future = JSON.stringify({ schemaVersion: 99, cards: [{ id: 'x', de: ['a'], fa: ['b'] }], logs: [] });
  storage.setItem('dariapp.v1', future);
  const info = api.Store.load();
  assert.equal(info.tooNew, true);
  assert.equal(api.Store.mode, 'recovery');
  assert.equal(api.Store.save(), false);
  assert.equal(storage.getItem('dariapp.v1'), future);
});

test('Sanitize repariert Müll, ohne Gutes zu verlieren', () => {
  const { api } = loadApi();
  const { data, issues } = api.Schema.sanitize({
    cards: [
      { id: 'a', de: 'Haus', fa: ['خانه'], tags: 'x', state: 'kaputt', reps: -5, s: 'abc' },
      null, 'text', { de: [], fa: [] },
      { id: 'a', de: ['Doppelt'], fa: ['دوباره'] },
      { de: ['Ohne ID'], fa: ['بدون'] }
    ],
    logs: [{ date: 1, rating: 9 }, { date: 'x' }, null, { date: 5, rating: 1, cardId: 'a' }],
    settings: { dailyGoal: 9999, appearance: 'neon' }
  });
  assert.equal(data.cards.length, 3);
  assert.deepEqual(plain(data.cards[0].de), ['Haus']);
  assert.deepEqual(plain(data.cards[0].tags), ['x']);
  assert.equal(data.cards[0].state, 'new');
  assert.equal(data.cards[0].reps, 0);
  assert.equal(new Set(data.cards.map(c => c.id)).size, 3);
  assert.equal(data.logs.length, 2);
  assert.equal(data.logs[0].rating, 4);
  assert.equal(data.settings.dailyGoal, 200);
  assert.equal(data.settings.appearance, 'light');
  assert.ok(issues.length > 0);
});

test('Speichern liest zurück; Speicherfehler werden gemeldet und Daten bleiben im Speicher', () => {
  const { api, storage } = loadApi();
  api.Store.load();
  api.Store.data.cards.push(...api.Schema.sanitize(JSON.parse(V2)).data.cards);
  assert.equal(api.Store.save(), true);
  const saved = storage.getItem('dariapp.v1');
  storage.failWrites = true;
  let reported = null;
  api.Store.onSaveError = e => { reported = e; };
  assert.equal(api.Store.save(), false);
  assert.ok(reported);
  assert.equal(storage.getItem('dariapp.v1'), saved, 'alter Stand bleibt unangetastet');
  assert.ok(api.Store.data.cards.length > 0);
});

test('Backup → Wiederherstellung: Rundreise ist verlustfrei (inkl. Prüfsumme)', async () => {
  const { api, storage } = loadApi();
  storage.setItem('dariapp.v1', V2);
  api.Store.load(); api.Store.save();
  const orig = JSON.stringify(api.Store.data);
  const { json, cards } = await api.Backup.build();
  assert.equal(cards, 29);
  // Daten zerstören, dann aus dem Backup wiederherstellen
  api.Store.data.cards.length = 0;
  api.Store.data.logs.length = 0;
  const parsed = api.Backup.parse(json);
  assert.equal(parsed.ok, true);
  assert.equal(parsed.checksumOk, true);
  const res = await api.Backup.apply(parsed, 'replace');
  assert.equal(res.ok, true);
  const restored = JSON.parse(JSON.stringify(api.Store.data));
  const o = JSON.parse(orig);
  assert.deepEqual(restored.cards, o.cards);
  assert.deepEqual(restored.logs, o.logs);
  assert.deepEqual(restored.settings, o.settings);
});

test('Wiederherstellung legt vorher einen Schnappschuss an und ist rückgängig machbar', async () => {
  const { api, storage, snaps } = loadApi();
  storage.setItem('dariapp.v1', V2);
  api.Store.load(); api.Store.save();
  const before = JSON.stringify(api.Store.data.cards);
  const other = { cards: [{ id: 'n1', de: ['Neu'], fa: ['نو'] }], logs: [] };
  const parsed = api.Backup.parse(JSON.stringify(other));
  const res = await api.Backup.apply(parsed, 'replace');
  assert.equal(res.ok, true);
  assert.equal(api.Store.data.cards.length, 1);
  assert.ok(snaps.list.some(s => s.reason === 'pre-restore'));
  assert.ok(storage.getItem('dariapp.v1.prev.prerestore'));
  const undo = await api.Backup.undo();
  assert.equal(undo.ok, true);
  assert.equal(JSON.stringify(api.Store.data.cards), before);
});

test('Wiederherstellung mit Speicherfehler rollt zurück – nichts geht verloren', async () => {
  const { api, storage } = loadApi();
  storage.setItem('dariapp.v1', V2);
  api.Store.load(); api.Store.save();
  const raw = storage.getItem('dariapp.v1');
  const parsed = api.Backup.parse(JSON.stringify({ cards: [{ id: 'n', de: ['x'], fa: ['y'] }] }));
  storage.failWrites = true;
  const res = await api.Backup.apply(parsed, 'replace');
  assert.equal(res.ok, false);
  storage.failWrites = false;
  assert.equal(storage.getItem('dariapp.v1'), raw);
  assert.equal(api.Store.data.cards.length, 29);
});

test('Ungültige oder manipulierte Backups werden erkannt', async () => {
  const { api } = loadApi();
  assert.equal(api.Backup.parse('kein json').ok, false);
  assert.equal(api.Backup.parse('[]').ok, false);
  assert.equal(api.Backup.parse('{"foo":1}').ok, false);
  assert.equal(api.Backup.parse('{"format":"zara-backup","formatVersion":99,"data":{"cards":[]}}').ok, false);
  const { json } = await api.Backup.build();
  const tampered = JSON.parse(json); tampered.data.cards.push({ id: 'z', de: ['z'], fa: ['z'] });
  const p = api.Backup.parse(JSON.stringify(tampered));
  assert.equal(p.ok, true);
  assert.equal(p.checksumOk, false);
});

test('Backup der Version 2.0 (nackte Datenstruktur) wird gelesen und migriert', () => {
  const { api } = loadApi();
  const p = api.Backup.parse(V2);
  assert.equal(p.ok, true);
  assert.equal(p.kind, 'legacy');
  assert.equal(p.migratedFrom, 2);
  assert.equal(p.summary.cards, 29);
});

test('Zusammenführen: nichts geht verloren, neuere Lernstände gewinnen', () => {
  const { api } = loadApi();
  const base = api.Schema.sanitize({ cards: [
    { id: 'a', de: ['A'], fa: ['ا'], reps: 1, lastReview: 100, s: 1, updatedAt: 10 },
    { id: 'b', de: ['B'], fa: ['ب'], reps: 5, lastReview: 900, s: 9, updatedAt: 50 }
  ], logs: [{ date: 1, rating: 3, cardId: 'a' }] }).data;
  const inc = api.Schema.sanitize({ cards: [
    { id: 'a', de: ['A2'], fa: ['ا'], reps: 7, lastReview: 500, s: 5, updatedAt: 99 },
    { id: 'b', de: ['B-alt'], fa: ['ب'], reps: 2, lastReview: 200, s: 2, updatedAt: 5 },
    { id: 'c', de: ['C'], fa: ['ج'] }
  ], logs: [{ date: 1, rating: 3, cardId: 'a' }, { date: 2, rating: 1, cardId: 'b' }] }).data;
  const m = api.Backup.merge(base, inc);
  assert.equal(m.data.cards.length, 3);
  const a = m.data.cards.find(c => c.id === 'a'), b = m.data.cards.find(c => c.id === 'b');
  assert.deepEqual(plain(a.de), ['A2']); assert.equal(a.reps, 7);
  assert.deepEqual(plain(b.de), ['B']); assert.equal(b.reps, 5);
  assert.equal(m.data.logs.length, 2);
});

test('Schnappschüsse werden begrenzt (Auto: 7, Sonstige: 8)', async () => {
  const { api, storage } = loadApi();
  storage.setItem('dariapp.v1', V2);
  api.Store.load();
  for (let i = 0; i < 12; i++) { await api.Store.snapshot('auto'); }
  for (let i = 0; i < 12; i++) { await api.Store.snapshot('pre-restore'); }
  const list = await api.Store.listSnapshots();
  assert.equal(list.filter(s => s.reason === 'auto').length, 7);
  assert.equal(list.filter(s => s.reason === 'pre-restore').length, 8);
});

test('Tägliche Auto-Sicherung läuft höchstens einmal pro Tag', async () => {
  const { api, storage, snaps } = loadApi();
  storage.setItem('dariapp.v1', V2);
  api.Store.load(); api.Store.save();
  assert.ok(await api.Store.autoSnapshot());
  assert.equal(await api.Store.autoSnapshot(), null);
  assert.equal(snaps.list.length, 1);
});

test('Verlauf-Verdichtung erhält Serie, Zählung und XP', () => {
  const { api } = loadApi();
  api.Store.load();
  const t = api.now();
  const logs = [];
  for (let d = 400; d >= 1; d--) for (let i = 0; i < 3; i++) logs.push({ date: t - d * api.DAY + i * 1000, rating: i === 0 ? 1 : 3, time: 2, mode: 'flip' });
  api.Store.data.logs = logs;
  const before = api.computeStats(api.Store.data, t);
  const removed = api.Store.compactLogs(180);
  assert.ok(removed > 200);
  const after = api.computeStats(api.Store.data, t);
  assert.equal(after.reviews, before.reviews);
  assert.equal(after.xp, before.xp);
  assert.equal(after.streak, before.streak);
  assert.ok(api.Store.data.logs.length < logs.length);
});

test('Audio von gelöschten Karten bleibt 30 Tage erhalten, wird danach bereinigt', async () => {
  const { api } = loadApi();
  api.Store.load();
  api.Store.markOrphan('gone');
  assert.equal(await api.Store.purgeOrphans(), 0);
  api.Store.data.meta.orphans.gone = api.now() - 31 * api.DAY;
  assert.equal(await api.Store.purgeOrphans(), 1);
});
