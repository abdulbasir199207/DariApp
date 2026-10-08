// Stellt sicher, dass die erzeugten Dateien zum Quellstand passen.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildHtml } from '../build.mjs';
import { buildContentJson } from '../tools/export-content.mjs';

const here = dirname(fileURLToPath(import.meta.url));

test('ZARA.html entspricht dem Quellstand (node build.mjs ausführen, falls nicht)', () => {
  const current = readFileSync(join(here, '..', 'ZARA.html'), 'utf8');
  assert.equal(current, buildHtml());
});

test('Das gebaute Skript ist syntaktisch gültig und enthält keine Inline-Handler mit Namen-Konstruktion', () => {
  const html = buildHtml();
  const js = html.match(/<script>([\s\S]*)<\/script>/)[1];
  assert.doesNotThrow(() => new Function(js));
  assert.ok(!/onclick="[^"]*\$\{esc\(/.test(html), 'onclick mit eingebettetem Namen (Apostroph-Fehler aus v2.0)');
  assert.ok(html.includes('<title>ZARA Sprachtrainer</title>'));
  assert.ok(html.includes('apple-mobile-web-app-title" content="ZARA"'));
  assert.ok(html.includes('rel="apple-touch-icon" href="data:image/png;base64,'));
});

test('iOS-Inhalte (zara-content.json) stimmen mit der Web-Quelle überein', () => {
  const current = readFileSync(join(here, '..', '..', 'DariApp', 'Resources', 'zara-content.json'), 'utf8');
  assert.equal(current, buildContentJson());
});
