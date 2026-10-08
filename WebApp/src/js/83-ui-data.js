/* ============================================================
   83-ui-data: Karten-Editor, Backup, Wiederherstellung,
   automatische Sicherungen und der Wiederherstellungs-Bildschirm.
   ============================================================ */

/* ---------- Karten-Editor ---------- */
let Editor = null;

A.openEditor = id => {
  const c = id ? cardById(id) : null;
  Editor = { id: id || null,
    de: (c && c.de.length ? c.de.slice() : ['']), fa: (c && c.fa.length ? c.fa.slice() : ['']),
    translit: c ? c.translit : '', tags: c ? c.tags.slice() : [], audio: c ? !!c.audio : false,
    active: c ? c.active : true, fav: c ? c.fav : false, exDe: c ? c.exDe : '', exFa: c ? c.exFa : '',
    newTag: '', _pendingAudio: null, _dupAck: false };
  renderEditor();
};
function renderEditor() {
  const E = Editor, root = $('modalRoot');
  const termFields = (arr, fa, key) => arr.map((v, i) => `<div class="row" style="gap:6px;margin-bottom:6px">
     <input class="field ${fa ? 'persian' : ''}" style="margin:0" ${fa ? 'lang="fa" dir="rtl" autocapitalize="none" autocorrect="off"' : ''} placeholder="${fa ? 'واژه' : 'Begriff'}" value="${esc(v)}" data-i="edTerm" data-k="${key}" data-idx="${i}">
     ${arr.length > 1 ? `<button class="iconbtn" style="background:var(--surface-2);color:var(--text-2)" data-a="edRemoveTerm" data-v="${key}:${i}" aria-label="Entfernen">−</button>` : ''}</div>`).join('')
    + `<button class="chip" data-a="edAddTerm" data-v="${key}">＋ Begriff hinzufügen</button>`;
  const sugg = allTags().filter(t => !E.tags.includes(t)).filter(t => !E.newTag || t.toLowerCase().includes(E.newTag.toLowerCase()));
  root.innerHTML = `<div class="modal"><div class="screen">
    <div class="row editor-head"><button class="chip" data-a="closeEditor">Abbrechen</button>
      <b>${E.id ? 'Karte bearbeiten' : 'Neue Karte'}</b>
      <button class="chip on" data-a="saveEditor">Speichern</button></div>
    <label class="lbl">Deutsch</label>${termFields(E.de, false, 'de')}
    <label class="lbl">Persisch</label>${termFields(E.fa, true, 'fa')}
    <label class="lbl">Lautschrift (nur Hilfe)</label>
    <input class="field" placeholder="z. B. khâne" value="${esc(E.translit)}" autocapitalize="none" autocorrect="off" data-i="edTranslit">
    <label class="lbl">Tags</label>
    <div style="display:flex;flex-wrap:wrap;gap:8px;margin-bottom:8px">${E.tags.map(t => `<button class="chip on" data-a="edRemoveTag" data-v="${esc(t)}">${esc(t)} <span class="x">✕</span></button>`).join('')}</div>
    <div class="row" style="gap:6px"><input class="field" style="margin:0" placeholder="Tag hinzufügen" value="${esc(E.newTag)}" data-i="edNewTag" data-enter="edAddTag" data-v=""><button class="iconbtn" data-a="edAddTag" data-v="" aria-label="Tag hinzufügen">＋</button></div>
    ${sugg.length ? `<div style="display:flex;flex-wrap:wrap;gap:6px;margin-top:8px">${sugg.map(t => `<button class="chip" data-a="edAddTag" data-v="${esc(t)}">${esc(t)}</button>`).join('')}</div>` : ''}
    <label class="lbl">Beispielsatz (optional)</label>
    <div class="exwrap"><div class="muted small">Für Lückentexte aus deinen eigenen Wörtern – das persische Wort muss im Satz vorkommen.</div>
      <input class="field persian" style="margin-bottom:6px" lang="fa" dir="rtl" autocapitalize="none" autocorrect="off" placeholder="جملهٔ نمونه" value="${esc(E.exFa)}" data-i="edExFa">
      <input class="field" style="margin:0" placeholder="Deutsche Übersetzung" value="${esc(E.exDe)}" data-i="edExDe"></div>
    <label class="lbl">Audio (Persisch)</label>
    <div id="audioArea">${audioAreaHTML()}</div>
    <label class="lbl">Status</label>
    <div class="card row"><span>Aktiv</span><button class="toggle ${E.active ? 'on' : ''}" data-a="edToggle" data-v="active" aria-label="Aktiv"><span></span></button></div>
    <div class="card row"><span>Favorit</span><button class="toggle ${E.fav ? 'on' : ''}" data-a="edToggle" data-v="fav" aria-label="Favorit"><span></span></button></div>
    ${E.id ? `<button class="btn-danger" style="margin-top:20px" data-a="askDeleteCard">Karte löschen</button>` : ''}
    <div style="height:30px"></div>
  </div></div>`;
}
function audioAreaHTML() {
  const E = Editor;
  if (Recorder.active()) return `<button class="pillbtn" style="background:var(--terra)" data-a="stopRec">⏹ Aufnahme stoppen…</button>`;
  let s = `<div class="row" style="gap:8px"><button class="pillbtn secondary" style="flex:1" data-a="startRec">${E.audio ? '● Neu aufnehmen' : '● Aufnehmen'}</button>`;
  if (E.audio) s += `<button class="iconbtn" style="background:var(--surface-2)" data-a="playEditorAudio" aria-label="Abspielen">▶</button><button class="iconbtn" style="background:var(--surface-2);color:var(--terra)" data-a="deleteEditorAudio" aria-label="Aufnahme löschen">🗑</button>`;
  return s + '</div>';
}
IN.edTerm = (v, el) => { Editor[el.dataset.k][Number(el.dataset.idx)] = v; };
IN.edTranslit = v => { Editor.translit = v; };
IN.edNewTag = v => { Editor.newTag = v; };
IN.edExFa = v => { Editor.exFa = v; };
IN.edExDe = v => { Editor.exDe = v; };
A.edAddTerm = k => { Editor[k].push(''); renderEditor(); };
A.edRemoveTerm = v => { const [k, i] = v.split(':'); Editor[k].splice(Number(i), 1); renderEditor(); };
A.edAddTag = (t, el) => {
  const name = ((t && t.length) ? t : Editor.newTag).trim();
  if (!name) return;
  if (!Editor.tags.some(x => x.toLowerCase() === name.toLowerCase())) Editor.tags.push(name);
  Editor.newTag = ''; renderEditor();
};
A.edRemoveTag = t => { Editor.tags = Editor.tags.filter(x => x !== t); renderEditor(); };
A.edToggle = k => { Editor[k] = !Editor[k]; renderEditor(); };
A.closeEditor = () => { if (Recorder.active()) Recorder.abort(); $('modalRoot').innerHTML = ''; Editor = null; };

A.startRec = async () => {
  if (!Recorder.supported()) { toast('Aufnahme wird in dieser Umgebung nicht unterstützt.', 3000); return; }
  try { await Recorder.start(); renderEditor(); }
  catch (e) { toast(Recorder.errorMessage(e), 3500); }
};
A.stopRec = async () => {
  const blob = await Recorder.stop();
  if (blob) { Editor._pendingAudio = blob; Editor.audio = true; }
  renderEditor();
};
A.playEditorAudio = async () => {
  let blob = Editor._pendingAudio;
  if (!blob && Editor.id) blob = await AudioStore.get(Editor.id);
  if (!(await Player.playBlob(blob))) toast('Keine Aufnahme');
};
A.deleteEditorAudio = () => { Editor.audio = false; Editor._pendingAudio = null; Editor._audioRemoved = true; renderEditor(); };

function showDupDialog(dup) {
  openDialog(`<div class="dlg-ic">⚠︎</div><h3>Wort schon vorhanden</h3>
    <p>Eine Karte mit <span class="dup-word">${esc(dup.de.join(', '))}</span>${dup.fa.length ? ` / <span class="dup-word persian">${esc(dup.fa.join('، '))}</span>` : ''} existiert bereits. Du kannst sie bearbeiten oder die neue Karte trotzdem anlegen.</p>
    <div class="dlg-actions"><button class="pillbtn secondary" data-a="dupEdit" data-v="${esc(dup.id)}">Karte bearbeiten</button>
    <button class="pillbtn" data-a="dupProceed">Trotzdem anlegen</button></div>`);
}
A.dupProceed = () => { if (Editor) Editor._dupAck = true; closeDialog(); return A.saveEditor(); };
A.dupEdit = id => { closeDialog(); A.closeEditor(); A.openEditor(id); };

A.saveEditor = async () => {
  const E = Editor; if (!E) return;
  const de = E.de.map(s => s.trim()).filter(Boolean), fa = E.fa.map(s => s.trim()).filter(Boolean);
  if (!de.length || !fa.length) { toast('Je Seite mind. ein Begriff'); return; }
  if (!E.id && !E._dupAck) {
    const dset = new Set(de.map(x => x.toLowerCase())), fset = new Set(fa.map(x => Answer.normalize(x, true)));
    const dup = DB.data.cards.find(c => c.de.some(x => dset.has(x.toLowerCase())) || c.fa.some(x => fset.has(Answer.normalize(x, true))));
    if (dup) { showDupDialog(dup); return; }
  }
  let card = E.id ? cardById(E.id) : null;
  if (!card) {
    card = Schema.fixCard({ id: uid(), de, fa, createdAt: now(), updatedAt: now() }, []);
    DB.data.cards.push(card);
  }
  card.de = de; card.fa = fa; card.translit = E.translit.trim(); card.tags = E.tags.slice();
  card.active = E.active; card.fav = E.fav; card.audio = E.audio; card.exDe = E.exDe.trim(); card.exFa = E.exFa.trim();
  card.updatedAt = now();
  if (E._pendingAudio) await AudioStore.put(card.id, E._pendingAudio);
  if (E._audioRemoved && !E.audio && E.id) DB.markOrphan(card.id);
  if (!DB.save()) toast('Speichern fehlgeschlagen – bitte Backup sichern', 4000);
  else toast('Gespeichert');
  A.closeEditor(); render();
};
A.askDeleteCard = () => {
  const E = Editor; if (!E || !E.id) return;
  const card = cardById(E.id); if (!card) return;
  confirmDialog({ icon: '🗑', iconColor: 'var(--terra)', title: 'Karte löschen?', danger: true, ok: 'Löschen',
    body: `„<span class="dup-word">${esc(card.de.join(', '))}</span>${card.fa.length ? ` / <span class="dup-word persian">${esc(card.fa.join('، '))}</span>` : ''}" wird gelöscht. Vorher wird automatisch eine Sicherungskopie angelegt.`,
    onOk: async () => {
      await DB.snapshot('pre-delete', 10 * 60 * 1000);
      const idx = DB.data.cards.findIndex(c => c.id === E.id);
      if (idx >= 0) { const c = DB.data.cards[idx]; if (c.audio) DB.markOrphan(c.id); DB.data.cards.splice(idx, 1); DB.save(); }
      A.closeEditor(); render(); toast('Karte gelöscht');
    } });
};

/* ---------- Backup sichern ---------- */
function markBackupDone() { DB.data.meta.lastExternalBackup = now(); DB.save(); }

A.openBackup = () => {
  const count = DB.data.cards.length, audioN = DB.data.cards.filter(c => c.audio).length;
  const sizeKB = Math.max(1, Math.round(JSON.stringify(DB.data).length / 1024));
  openDialog(`<div class="dlg-ic" style="color:var(--sage)">💾</div><h3>Backup sichern</h3>
    <p><b>${count}</b> Karten · ${sizeKB} KB${audioN ? ` · ${audioN} Aufnahmen` : ''}. So gehen deine Wörter und dein Fortschritt nie verloren.</p>
    <div class="dlg-actions">
      <button class="pillbtn" data-a="shareBackup">⤴ Als Datei sichern${audioN ? ' (mit Aufnahmen)' : ''}</button>
      <button class="pillbtn secondary" data-a="copyBackup">⧉ Als Text kopieren${audioN ? ' (ohne Aufnahmen)' : ''}</button>
      <button class="pillbtn secondary" data-a="toggleBackupText">Text anzeigen</button>
    </div>
    <textarea id="backupText" readonly class="field hidden" style="height:110px;font-family:monospace;font-size:11px;margin:12px 0 0" data-a="selectAll"></textarea>
    <div class="hint" style="margin-top:10px">„Datei sichern" öffnet das iOS-Menü → <b>In Dateien sichern</b> (legt eine <code>.json</code> an) oder an dich selbst per Mail/Notiz senden. Zurückholen über „Backup wiederherstellen".</div>`, true);
};
A.selectAll = (v, el) => { try { el.select(); } catch (e) {} };
A.toggleBackupText = async () => {
  const ta = $('backupText'); if (!ta) return;
  ta.classList.toggle('hidden');
  if (!ta.classList.contains('hidden')) {
    if (!ta.value) ta.value = (await Backup.build({ includeAudio: false })).json;
    ta.focus(); try { ta.select(); } catch (e) {}
  }
};
A.shareBackup = async () => {
  const { json } = await Backup.build({ includeAudio: true });
  const name = Backup.fileName();
  try {
    const file = new File([json], name, { type: 'application/json' });
    if (navigator.canShare && navigator.canShare({ files: [file] })) {
      await navigator.share({ files: [file], title: 'ZARA Backup' });
      markBackupDone(); toast('Backup gesichert ✓'); closeDialog(); return;
    }
  } catch (e) { if (e && e.name === 'AbortError') return; }
  try {
    if (navigator.share) { await navigator.share({ title: 'ZARA Backup', text: (await Backup.build()).json }); markBackupDone(); closeDialog(); return; }
  } catch (e) { if (e && e.name === 'AbortError') return; }
  let embedded = true; try { embedded = window.self !== window.top; } catch (_) {}
  if (!embedded) {
    try {
      const url = URL.createObjectURL(new Blob([json], { type: 'application/json' }));
      const a = document.createElement('a'); a.href = url; a.download = name;
      document.body.appendChild(a); a.click(); a.remove();
      setTimeout(() => URL.revokeObjectURL(url), 1500);
      markBackupDone(); toast('Gespeichert als ' + name); return;
    } catch (e) {}
  }
  await A.copyBackup();
};
A.copyBackup = async () => {
  const json = (await Backup.build({ includeAudio: false })).json;
  try { await navigator.clipboard.writeText(json); markBackupDone(); toast('In Zwischenablage kopiert ✓'); }
  catch (e) {
    const ta = $('backupText');
    if (ta) { ta.value = json; ta.classList.remove('hidden'); ta.focus(); try { ta.select(); ta.setSelectionRange(0, ta.value.length); } catch (_) {} }
    toast('Text ist markiert – jetzt „Kopieren" antippen', 3500);
  }
};

/* ---------- Wiederherstellen ---------- */
const Restore = { pending: null, source: '' };

A.openRestore = () => {
  openDialog(`<div class="dlg-ic">⟲</div><h3>Backup wiederherstellen</h3>
    <p>Füge deinen kopierten Backup-Text ein oder wähle die Backup-Datei. Vor jeder Wiederherstellung sichert ZARA den aktuellen Stand automatisch.</p>
    <textarea id="restoreText" class="field" style="height:120px;font-family:monospace;font-size:11px;margin:0 0 4px" placeholder="Backup-Text hier einfügen…"></textarea>
    <div class="dlg-actions"><button class="pillbtn" data-a="restoreFromText">Prüfen</button>
    <button class="pillbtn secondary" data-a="pickFile">Datei wählen</button></div>`, true);
};
A.pickFile = () => { closeDialog(); const f = $('importFile') || document.querySelector('#importFile'); if (f) f.click(); else { A.sub('more'); } };
A.restoreFromText = () => {
  const ta = $('restoreText'); const txt = ta ? ta.value.trim() : '';
  if (!txt) { toast('Kein Text eingefügt'); return; }
  showRestorePreview(Backup.parse(txt), 'Einfügen');
};
document.addEventListener('change', e => {
  const el = e.target.closest('[data-c="importFile"]');
  if (!el) return;
  const f = el.files && el.files[0]; if (!f) return;
  f.text().then(t => { showRestorePreview(Backup.parse(t), f.name); }).catch(() => toast('Datei konnte nicht gelesen werden.'));
  el.value = '';
});

function showRestorePreview(parsed, source) {
  if (!parsed.ok) { openDialog(`<div class="dlg-ic" style="color:var(--terra)">✕</div><h3>Backup nicht verwendbar</h3><p>${esc(parsed.error)}</p>
    <div class="dlg-actions"><button class="pillbtn secondary" data-a="closeDialog">OK</button></div>`); return; }
  Restore.pending = parsed; Restore.source = source;
  const sm = parsed.summary, recovery = Store.mode === 'recovery';
  const cur = recovery ? 0 : DB.data.cards.length;
  openDialog(`<div class="dlg-ic" style="color:var(--sage)">⟲</div><h3>Backup gefunden</h3>
    <p><b>${sm.cards}</b> Karten · ${sm.logs} Verlaufseinträge · ${sm.tags} Tags${sm.audio ? ' · ' + sm.audio + ' Aufnahmen' : ''}
    ${parsed.createdAt ? '<br>Erstellt: ' + esc(fmtDate(parsed.createdAt)) : ''}
    ${parsed.migratedFrom ? '<br>Älteres Format – wird automatisch aktualisiert.' : ''}
    ${parsed.checksumOk === false ? '<br><b style="color:var(--terra)">Achtung: Prüfsumme stimmt nicht – die Datei wurde verändert oder ist beschädigt.</b>' : ''}
    ${parsed.issues.length ? '<br>' + parsed.issues.length + ' kleine Unstimmigkeiten werden repariert.' : ''}
    ${recovery ? '' : `<br><br>Aktuell auf diesem Gerät: <b>${cur}</b> Karten.`}</p>
    <div class="dlg-actions">
      <button class="pillbtn" data-a="applyRestore" data-v="replace">${recovery ? 'Wiederherstellen' : 'Ersetzen (aktuellen Stand vorher sichern)'}</button>
      ${recovery ? '' : '<button class="pillbtn secondary" data-a="applyRestore" data-v="merge">Zusammenführen (nichts geht verloren)</button>'}
      <button class="pillbtn secondary" data-a="closeDialog">Abbrechen</button></div>`, true);
}
A.applyRestore = async mode => {
  const parsed = Restore.pending; if (!parsed) return;
  closeDialog();
  const res = await Backup.apply(parsed, mode);
  Restore.pending = null;
  if (!res.ok) { openDialog(`<div class="dlg-ic" style="color:var(--terra)">✕</div><h3>Nicht wiederhergestellt</h3><p>${esc(res.error)}</p><div class="dlg-actions"><button class="pillbtn secondary" data-a="closeDialog">OK</button></div>`); return; }
  applyTheme();
  App.tab = 'cards'; App.sub = null; App.session = false; render();
  openDialog(`<div class="dlg-ic" style="color:var(--sage)">✓</div><h3>Wiederhergestellt</h3>
    <p>${res.cards} Karten sind jetzt in ZARA.${res.added != null ? ` (${res.added} neu hinzugefügt, ${res.updated} aktualisiert)` : ''}${res.audioRestored ? ` ${res.audioRestored} Aufnahmen übernommen.` : ''}</p>
    <div class="dlg-actions">${res.undoId ? '<button class="pillbtn secondary" data-a="undoRestore">Rückgängig machen</button>' : ''}<button class="pillbtn" data-a="closeDialog">OK</button></div>`);
};
A.undoRestore = async () => {
  closeDialog();
  const res = await Backup.undo();
  if (res.ok) { applyTheme(); render(); toast('Rückgängig gemacht ✓'); } else toast(res.error || 'Nicht möglich', 3500);
};

/* ---------- Automatische Sicherungen ---------- */
const SNAP_LABEL = { auto: 'Automatisch (täglich)', 'pre-migration': 'Vor Update', 'pre-restore': 'Vor Wiederherstellung', 'pre-delete': 'Vor Löschen' };
A.openSnapshots = async () => {
  const list = await DB.listSnapshots();
  openDialog(`<div class="dlg-ic" style="color:var(--sage)">◷</div><h3>Automatische Sicherungen</h3>
    <p>ZARA sichert deinen Stand täglich und vor Updates, Löschen und Wiederherstellungen – nur auf diesem Gerät. Ein Backup in „Dateien" schützt zusätzlich.</p>
    ${list.length ? list.map(s => `<div class="snaprow"><div><b>${esc(fmtDate(s.at))}</b><br><span class="muted small">${esc(SNAP_LABEL[s.reason] || s.reason)} · ${s.cards} Karten</span></div><button data-a="snapLoad" data-v="${esc(s.id)}">Laden</button></div>`).join('') : '<div class="muted small">Noch keine Sicherungen vorhanden.</div>'}
    <div class="dlg-actions"><button class="pillbtn secondary" data-a="closeDialog">Schließen</button></div>`, true);
};
A.snapLoad = async id => {
  const snap = await DB.getSnapshot(id);
  if (!snap) { toast('Sicherung nicht gefunden'); return; }
  showRestorePreview(Backup.parse(snap.json), 'Sicherung');
};

/* ---------- Wiederherstellungs-Bildschirm (Daten nicht automatisch geladen) ---------- */
function renderRecovery() {
  $('tabbar').innerHTML = '';
  const r = Store.recovery || {};
  const msgs = {
    corrupt: 'Die gespeicherten Daten konnten nicht gelesen werden. <b>Es wurde nichts gelöscht oder überschrieben</b> – eine Kopie liegt sicher auf diesem Gerät.',
    tooNew: 'Diese Daten wurden mit einer neueren Version von ZARA gespeichert. Bitte die App ganz schließen und neu öffnen, damit die neueste Version geladen wird. Deine Daten bleiben unverändert.',
    missing: 'Auf diesem Gerät wurden keine ZARA-Daten gefunden, es gibt aber automatische Sicherungen.'
  };
  $('screen').className = 'screen';
  $('screen').innerHTML = `<div class="rec-wrap" style="text-align:center">
    <span style="width:64px;height:64px;display:inline-block">${CAT_SVG}</span>
    <h2>Deine Daten brauchen Aufmerksamkeit</h2>
    <p class="muted" style="font-size:14px;line-height:1.5">${msgs[r.reason] || msgs.corrupt}</p>
    ${r.reason === 'tooNew' ? '' : `
    <div style="display:flex;flex-direction:column;gap:10px;margin-top:18px">
      <button class="pillbtn" data-a="openSnapshots">Aus automatischer Sicherung wiederherstellen</button>
      <button class="pillbtn secondary" data-a="openRestore">Backup einfügen oder Datei wählen</button>
      ${r.reason === 'corrupt' ? '<button class="pillbtn secondary" data-a="copyQuarantine">Beschädigten Text kopieren</button>' : ''}
      <button class="pillbtn secondary" style="color:var(--terra)" data-a="startFresh">Neu beginnen</button>
    </div>`}
  </div><input type="file" id="importFile" accept="application/json,.json,text/plain" class="hidden" data-c="importFile">`;
}
A.copyQuarantine = async () => {
  const k = Store.recovery && Store.recovery.quarantineKey;
  const raw = k ? Store._get(k) : null;
  if (!raw) { toast('Nichts zu kopieren'); return; }
  try { await navigator.clipboard.writeText(raw); toast('Kopiert ✓'); } catch (e) { toast('Kopieren nicht möglich', 3000); }
};
A.startFresh = () => {
  confirmDialog({ title: 'Wirklich neu beginnen?', danger: true, ok: 'Neu beginnen',
    body: 'ZARA startet leer. Der beschädigte Text bleibt als Kopie auf dem Gerät erhalten, und du kannst später jederzeit ein Backup einspielen.',
    onOk: () => { Backup.startFresh(); applyTheme(); App.tab = 'today'; render(); } });
};
