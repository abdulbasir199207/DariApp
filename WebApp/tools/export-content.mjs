// Exportiert die Übungsinhalte (Sätze + Grammatik) aus der PWA als JSON für die iOS-App.
// Einzige Quelle der Wahrheit: WebApp/src/js/30-content.js
//   node tools/export-content.mjs          → schreibt DariApp/Resources/zara-content.json
//   node tools/export-content.mjs --check  → bricht ab, wenn die Datei nicht aktuell ist
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const target = join(root, '..', 'DariApp', 'Resources', 'zara-content.json');

export function buildContentJson() {
  const code = readFileSync(join(root, 'src', 'js', '30-content.js'), 'utf8') + '\n;globalThis.__c = { SENTENCES, GRAMMAR, BLANK_POS };';
  const ctx = vm.createContext({});
  vm.runInContext(code, ctx);
  const c = JSON.parse(JSON.stringify(ctx.__c));
  const sentences = c.SENTENCES.map(s => ({
    id: s.id, category: s.cat, level: s.lvl, isQuestion: s.q,
    germanTokens: s.deT, persianTokens: s.faT, german: s.de, persian: s.fa, transliteration: s.tr,
    germanPos: s.pd.join(''), persianPos: s.pf.join(''),
    germanBlanks: s.bd, persianBlanks: s.bf, persianAlternatives: s.alts
  }));
  const grammar = c.GRAMMAR.map(g => ({ id: g.id, language: g.lang, topic: g.topic, question: g.q, answers: g.a, explanation: g.e, explanationPersian: g.x }));
  return JSON.stringify({ version: 1, blankPos: c.BLANK_POS, sentences, grammar }, null, 1) + '\n';
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  const json = buildContentJson();
  if (process.argv.includes('--check')) {
    const cur = existsSync(target) ? readFileSync(target, 'utf8') : '';
    if (cur !== json) { console.error('zara-content.json ist nicht aktuell – bitte "node tools/export-content.mjs" ausführen.'); process.exit(1); }
    console.log('zara-content.json ist aktuell.');
  } else { writeFileSync(target, json); console.log('zara-content.json geschrieben:', json.length, 'Zeichen'); }
}
