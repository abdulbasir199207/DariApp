/* ============================================================
   99-main: Start. Robust – bei jedem Fehler erscheint eine
   verständliche Meldung mit Daten-Rettung statt eines leeren Bildschirms.
   ============================================================ */

/** Demo-Karten NUR bei echter Neuinstallation (nie über vorhandene Daten). */
function seedIfEmpty() {
  if (DB.data.cards.length) return;
  const s = [
    [['Haus', 'Gebäude'], ['خانه', 'منزل'], 'khâne', ['Alltag']],
    [['Mutter'], ['مادر'], 'mâdar', ['Familie']],
    [['Vater'], ['پدر'], 'pedar', ['Familie']],
    [['Wasser'], ['آب'], 'âb', ['Alltag']],
    [['gehen'], ['رفتن'], 'raftan', ['Verben']],
    [['essen'], ['خوردن'], 'khordan', ['Verben']],
    [['Brot'], ['نان'], 'nân', ['Alltag']],
    [['Freund'], ['دوست'], 'dust', ['Familie', 'Alltag']]
  ];
  s.forEach(([de, fa, tr, tags]) => DB.data.cards.push(Schema.fixCard({ id: uid(), de, fa, translit: tr, tags, createdAt: now(), updatedAt: now() }, [])));
}

function showFatal(err) {
  let raw = ''; try { raw = localStorage.getItem(Store.KEY) || ''; } catch (_) {}
  const s = $('screen'); if (!s) return;
  s.className = 'screen';
  s.innerHTML = `<div class="rec-wrap" style="text-align:center">
    <div style="font-size:42px">⚠️</div>
    <h2>ZARA konnte nicht starten</h2>
    <p class="muted" style="font-size:14px">Bitte die App ganz schließen und neu öffnen. Deine Daten wurden nicht verändert. Zur Sicherheit kannst du sie vorher kopieren:</p>
    ${raw ? `<button class="pillbtn" style="margin-top:14px" data-a="rescueCopy">⧉ Meine Daten als Backup kopieren</button>
    <textarea id="rawBak" readonly class="field hidden" style="height:120px;font-family:monospace;font-size:11px;margin-top:10px">${esc(raw)}</textarea>` : '<p class="muted small">Keine gespeicherten Daten gefunden.</p>'}
    <p class="muted small" style="margin-top:14px;word-break:break-all">${esc((err && (err.message || String(err))) || 'Unbekannter Fehler')}</p></div>`;
}
A.rescueCopy = async () => {
  let raw = ''; try { raw = localStorage.getItem(Store.KEY) || ''; } catch (_) {}
  try { await navigator.clipboard.writeText(raw); toast('Kopiert ✓ – bitte in eine Notiz einfügen', 3500); }
  catch (e) { const t = $('rawBak'); if (t) { t.classList.remove('hidden'); t.focus(); try { t.select(); } catch (_) {} } }
};

function watchColorScheme() {
  try {
    const mq = matchMedia('(prefers-color-scheme: dark)');
    const cb = () => { if (DB.data.settings.appearance === 'system') applyTheme(); };
    if (mq.addEventListener) mq.addEventListener('change', cb); else if (mq.addListener) mq.addListener(cb);
  } catch (e) {}
}

const withTimeout = (p, ms, fallback) => Promise.race([p, new Promise(res => setTimeout(() => res(fallback), ms))]);

async function boot() {
  try {
    let ls = null;
    try { ls = window.localStorage; ls.getItem('x'); } catch (e) { throw new Error('Der Speicher dieses Browsers ist nicht verfügbar.'); }
    Store.attach(ls);
    Store.onSaveError = () => { toast('Speichern fehlgeschlagen – bitte Backup sichern', 4000); };
    Speech.init();
    const info = Store.load();
    applyTheme(); watchColorScheme();

    if (Store.mode === 'recovery') { renderRecovery(); return; }

    if (info.fresh) {
      // Keine Daten gefunden: gibt es Sicherungen? Dann NICHT stillschweigend neu anfangen.
      const snaps = await withTimeout(DB.listSnapshots(), 1500, []);
      if (snaps.some(s => s.cards > 0)) {
        Store.mode = 'recovery'; Store.recovery = { reason: 'missing' };
        renderRecovery(); return;
      }
      seedIfEmpty();
      if (!Store.save()) toast('Speichern nicht möglich – Speicher des Browsers voll?', 4000);
    } else {
      if (info.preMigration && info.originalRaw) await DB.snapshot('pre-migration', 0, info.originalRaw);
      if (info.needsSave && !Store.save()) throw new Error('Die aktualisierten Daten konnten nicht gespeichert werden. Der alte Stand bleibt erhalten.');
    }
    Store.rotatePrev();
    if (Store.compactLogs()) Store.save();
    render();
    // Im Hintergrund: tägliche Sicherung, Aufräumen, dauerhaften Speicher anfragen.
    DB.autoSnapshot().then(() => DB.purgeOrphans()).then(() => DB.requestPersistence()).then(() => DB.save()).catch(() => {});
  } catch (e) { try { showFatal(e); } catch (_) {} }
}
boot();
