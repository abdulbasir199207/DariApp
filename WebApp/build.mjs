// Baut WebApp/ZARA.html aus den Quelldateien in WebApp/src/.
//   node build.mjs          → schreibt ZARA.html
//   node build.mjs --check  → bricht ab, wenn ZARA.html nicht zum Quellstand passt
import { readFileSync, writeFileSync, readdirSync, existsSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = dirname(fileURLToPath(import.meta.url));
const src = join(root, 'src');

export function buildHtml() {
  const template = readFileSync(join(src, 'template.html'), 'utf8');
  const css = readFileSync(join(src, 'style.css'), 'utf8');
  const files = readdirSync(join(src, 'js')).filter(f => f.endsWith('.js')).sort();
  const js = files.map(f => `/* ===== ${f} ===== */\n` + readFileSync(join(src, 'js', f), 'utf8')).join('\n');
  if (js.includes('</script')) throw new Error('JS enthält "</script" – im Template nicht erlaubt');
  const iconPath = join(root, '..', 'Design', 'zara-icon-180.png');
  const icon = existsSync(iconPath) ? 'data:image/png;base64,' + readFileSync(iconPath).toString('base64') : '';
  return template.replace('/*__CSS__*/', () => css).replace('/*__JS__*/', () => js).split('__ICON__').join(icon);
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  const out = join(root, 'ZARA.html');
  const html = buildHtml();
  if (process.argv.includes('--check')) {
    const cur = existsSync(out) ? readFileSync(out, 'utf8') : '';
    if (cur !== html) { console.error('ZARA.html ist nicht aktuell – bitte "node build.mjs" ausführen.'); process.exit(1); }
    console.log('ZARA.html ist aktuell.');
  } else {
    writeFileSync(out, html);
    console.log('ZARA.html geschrieben (' + Math.round(html.length / 1024) + ' KB, ' + html.split('\n').length + ' Zeilen)');
  }
}
