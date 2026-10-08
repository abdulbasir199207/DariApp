/* ============================================================
   81-ui-views: Tabs „Heute", „Üben", „Karten", „Statistik", „Mehr"
   und die Unterseiten „Vokabeln lernen" und „Grammatik".
   ============================================================ */

/* Die schwarze Katze – Markenzeichen von ZARA (eigener Entwurf). */
const CAT_SVG = `<svg viewBox="0 0 100 100" aria-hidden="true" xmlns="http://www.w3.org/2000/svg">
<polygon points="20,46 22,14 46,31" fill="#16181b"/><polygon points="80,46 78,14 54,31" fill="#16181b"/>
<polygon points="26,40 27,22 40,32" fill="#C77B58" opacity=".85"/><polygon points="74,40 73,22 60,32" fill="#C77B58" opacity=".85"/>
<ellipse cx="50" cy="57" rx="32" ry="27" fill="#16181b"/>
<ellipse cx="39" cy="54" rx="7" ry="7.6" fill="#E3D27B"/><ellipse cx="61" cy="54" rx="7" ry="7.6" fill="#E3D27B"/>
<ellipse cx="39" cy="54" rx="2" ry="5.6" fill="#0b0c0e"/><ellipse cx="61" cy="54" rx="2" ry="5.6" fill="#0b0c0e"/>
<circle cx="41" cy="51" r="1.6" fill="#fff" opacity=".9"/><circle cx="63" cy="51" r="1.6" fill="#fff" opacity=".9"/>
<polygon points="46.5,63 53.5,63 50,67.5" fill="#C77B58"/>
<path d="M50 67.5 q-3.5 5 -8 3.2 M50 67.5 q3.5 5 8 3.2" fill="none" stroke="#6b757d" stroke-width="1.6" stroke-linecap="round"/>
<g stroke="#8d979f" stroke-width="1.2" stroke-linecap="round"><path d="M30 64 L12 61M30 68 L13 71M70 64 L88 61M70 68 L87 71"/></g></svg>`;

const LearnCfg = { mode: null, direction: null, tags: new Set(), gLang: 'fa', gTopic: null };
const dirLabel = { g2p: 'DE → FA', p2g: 'FA → DE', mixed: 'Gemischt' };

function cardById(id) { return DB.data.cards.find(c => c.id === id) || null; }
function activeCards() { return DB.data.cards.filter(c => c.active); }

function suggestNext(st) {
  if (!st.total) return { a: 'newCard', t: 'Erste Karte anlegen', s: 'Lege dein erstes Wort an – dann geht es los.' };
  if (st.dueCount > 0) return { a: 'startToday', t: 'Heute lernen', s: st.dueCount + (st.dueCount === 1 ? ' Karte ist' : ' Karten sind') + ' fällig' };
  if (st.weakCount > 0) return { a: 'startWeak', t: 'Schwierige Wörter üben', s: st.weakCount + ' Wörter brauchen noch Wiederholung' };
  return { a: 'startMore', t: 'Weiterlernen', s: 'Alles Fällige ist erledigt – festige weitere Wörter.' };
}

function backupAgeDays() {
  const last = DB.data.meta.lastExternalBackup;
  return last ? (now() - last) / DAY : Infinity;
}

Views.today = () => {
  const st = computeStats(), sug = suggestNext(st), lv = st.level;
  const C = 2 * Math.PI * 38;
  const ring = `<svg class="ring" viewBox="0 0 100 100" role="img" aria-label="Tagesziel ${st.today} von ${st.goal}">
    <circle class="bg" cx="50" cy="50" r="38"/><circle class="fg" cx="50" cy="50" r="38" stroke-dasharray="${C.toFixed(1)}" stroke-dashoffset="${(C * (1 - st.goalPct / 100)).toFixed(1)}" transform="rotate(-90 50 50)"/>
    <text x="50" y="57">${st.today}/${st.goal}</text></svg>`;
  const needBackup = st.total >= 5 && st.reviews >= 10 && backupAgeDays() > 7;
  const canLearn = st.total > 0;
  return `
  <div class="row" style="margin:6px 2px 12px"><div class="row" style="gap:10px;justify-content:flex-start"><span style="width:38px;height:38px;display:block">${CAT_SVG}</span>
    <div class="nav-title" style="margin:0">Heute</div></div>
    <span class="muted small">${esc(new Date().toLocaleDateString('de-DE', { weekday: 'long', day: 'numeric', month: 'long' }))}</span></div>
  ${Store.lastSaveError ? `<div class="banner danger"><span>Speichern fehlgeschlagen – bitte sofort ein Backup sichern.</span><button data-a="openBackup">Sichern</button></div>` : ''}
  ${needBackup ? `<div class="banner"><span>${backupAgeDays() === Infinity ? 'Noch kein Backup.' : 'Letztes Backup vor ' + Math.floor(backupAgeDays()) + ' Tagen.'} Dein Fortschritt liegt nur auf diesem Gerät.</span><button data-a="openBackup">Sichern</button></div>` : ''}
  <div class="card"><div class="stat-row">${ring}
    <div style="flex:1;min-width:0">
      <div style="font-weight:700;font-size:16px">${st.goalPct >= 100 ? 'Tagesziel erreicht!' : 'Tagesziel'}</div>
      <div class="muted small">${st.streak > 0 ? '🔥 ' + st.streak + (st.streak === 1 ? ' Tag' : ' Tage') + ' in Folge' : 'Lerne heute, um eine Serie zu starten'}</div>
      <div class="small" style="margin-top:8px"><span class="lvl">Level ${lv.level}</span> <span class="muted">· ${lv.xp - lv.base}/${lv.next - lv.base} XP</span></div>
      <div class="xpbar"><div style="width:${clamp(lv.pct, 0, 100)}%"></div></div>
    </div></div></div>
  <button class="hero" data-a="${sug.a}"><div class="t">${esc(sug.t)}</div><div class="s">${esc(sug.s)}</div></button>
  <h2 class="sec">Weitere Möglichkeiten</h2>
  <div class="tiles">
    <button class="tile" data-a="startMix" ${canLearn ? '' : 'disabled'}><span class="ic">◷</span><span class="t">5-Minuten-Spiel</span><span class="s">Abwechslungsreiche Mischung</span></button>
    <button class="tile" data-a="startWeak" ${st.weakCount ? '' : 'disabled'}>${st.weakCount ? `<span class="badge">${st.weakCount}</span>` : ''}<span class="ic">◎</span><span class="t">Schwierige Wörter</span><span class="s">${st.weakCount ? 'Gezielt wiederholen' : 'Noch keine – gut so!'}</span></button>
    <button class="tile" data-a="startCloze"><span class="ic">▭</span><span class="t">Sätze üben</span><span class="s">Lückentext mit Beispielsätzen</span></button>
    <button class="tile" data-a="sub" data-v="grammar"><span class="ic">✎</span><span class="t">Grammatik</span><span class="s">Persisch &amp; Deutsch</span></button>
  </div>
  <div style="height:16px"></div>`;
};

/* ---------- Üben (Übersicht) ---------- */
function dirSeg() {
  const st = DB.data.settings;
  if (LearnCfg.direction === null) LearnCfg.direction = st.defaultDirection;
  return `<div class="seg">${[['g2p', 'DE → FA'], ['p2g', 'FA → DE'], ['mixed', 'Gemischt']].map(([k, l]) =>
    `<button class="${LearnCfg.direction === k ? 'on' : ''}" data-a="setDir" data-v="${k}">${l}</button>`).join('')}</div>`;
}
A.setDir = v => { LearnCfg.direction = v; render(); };

Views.learn = () => {
  const n = activeCards().length, distinct = makeMatchRound(activeCards(), 5).length;
  const weak = weakCards(DB.data.cards).length;
  const faOk = Speech.can('fa'), deOk = Speech.can('de');
  const withAudio = activeCards().filter(c => c.audio).length;
  const listenOk = n >= 2 && (faOk || deOk || withAudio > 0);
  const speakOk = n >= 1 && Recorder.supported() && (faOk || deOk || withAudio > 0);
  const tile = (a, ic, t, s, ok = true, badge = '', v = '') =>
    `<button class="tile" data-a="${a}" data-v="${v}" ${ok ? '' : 'disabled'}>${badge ? `<span class="badge">${badge}</span>` : ''}<span class="ic">${ic}</span><span class="t">${t}</span><span class="s">${s}</span></button>`;
  return `<div class="nav-title">Üben</div>
  <label class="lbl" style="margin-top:0">Richtung</label>${dirSeg()}
  <h2 class="sec">Vokabeln</h2>
  <div class="tiles">
    ${tile('sub', '◫', 'Karten lernen', 'Modus, Richtung &amp; Tags wählen', n > 0, '', 'vocab')}
    ${tile('startWeak', '◎', 'Schwierige Wörter', weak ? 'Gezielt wiederholen' : 'Noch keine – gut so!', weak > 0, weak || '')}
  </div>
  <h2 class="sec">Spiele</h2>
  <div class="tiles">
    ${tile('startMatch', '⇄', 'Zuordnung', distinct >= 3 ? 'Wörter einander zuordnen' : 'Mind. 3 Karten nötig', distinct >= 3)}
    ${tile('startListen', '♪', 'Hören', listenOk ? 'Hören &amp; Bedeutung wählen' : 'Keine Sprachausgabe verfügbar', listenOk)}
    ${tile('startSpeak', '◉', 'Aussprache', speakOk ? 'Nachsprechen &amp; vergleichen' : 'Mikrofon/Sprachausgabe fehlt', speakOk)}
    ${tile('startMix', '◷', '5-Minuten-Spiel', 'Abwechslungsreiche Mischung', n > 0)}
  </div>
  <h2 class="sec">Sätze &amp; Grammatik</h2>
  <div class="tiles">
    ${tile('startCloze', '▭', 'Lückentext', 'Fehlendes Wort einsetzen')}
    ${tile('startBuild', '⇆', 'Satzbildung', 'Wörter ordnen')}
    ${tile('startTranslate', '✎', 'Übersetzen', 'Kurze Sätze schreiben')}
    ${tile('sub', '§', 'Grammatik', 'Persisch &amp; Deutsch', true, '', 'grammar')}
  </div>
  <div class="pill-note">Alle Übungen passen die Wiederholung an deine Fehler an.</div>
  <div style="height:16px"></div>`;
};

/* ---------- Vokabeln lernen (Konfiguration wie in v2.0) ---------- */
function candidates() {
  const active = activeCards();
  if (LearnCfg.tags.size === 0) return active;
  return active.filter(c => c.tags.some(t => LearnCfg.tags.has(t)));
}
function allTags() { const s = new Set(); DB.data.cards.forEach(c => c.tags.forEach(t => s.add(t))); return [...s].sort((a, b) => a.localeCompare(b)); }

Views.vocab = () => {
  const st = DB.data.settings;
  if (LearnCfg.mode === null) LearnCfg.mode = st.defaultMode;
  const cands = candidates(), dueN = DB.data.cards.filter(c => isDue(c)).length;
  const modes = [['flip', 'Umdrehen', '◫'], ['mc', 'Multiple Choice', '☰'], ['write', 'Schreiben', '✎']];
  const tags = allTags();
  return `<div class="backrow"><button class="chip" data-a="back">‹ Zurück</button></div>
  <div class="nav-title" style="margin-top:0">Karten lernen</div>
  <div class="muted small" style="margin:-8px 2px 0">${dueN} fällige Karten heute</div>
  <label class="lbl">Modus</label>
  ${modes.map(([k, l, i]) => `<button class="card row" style="width:100%;text-align:left;${LearnCfg.mode === k ? 'background:var(--accent);color:#fff' : ''}" data-a="setMode" data-v="${k}">
     <span><span style="margin-right:10px">${i}</span>${l}</span>${LearnCfg.mode === k ? '<span>✓</span>' : ''}</button>`).join('')}
  <label class="lbl">Richtung</label>${dirSeg()}
  <label class="lbl">Tags</label>
  ${tags.length ? `<div style="display:flex;flex-wrap:wrap;gap:8px">
     <button class="chip ${LearnCfg.tags.size === 0 ? 'on' : ''}" data-a="toggleTag" data-v="">Alle</button>
     ${tags.map(t => `<button class="chip ${LearnCfg.tags.has(t) ? 'on' : ''}" data-a="toggleTag" data-v="${esc(t)}" data-lp="askDeleteTag">${esc(t)}</button>`).join('')}
   </div><div class="hint">Tipp: Tag lange gedrückt halten, um ihn zu löschen.</div>` : `<div class="muted small">Keine Tags – es werden alle Karten gelernt.</div>`}
  <div class="card row" style="margin-top:16px"><span class="muted small">ℹ︎ Auswahl: ${cands.length} Karten</span></div>
  <div style="margin-top:8px"><button class="pillbtn" ${cands.length ? '' : 'disabled'} data-a="startVocab">Lernen starten</button></div>
  <div style="height:20px"></div>`;
};
A.setMode = v => { LearnCfg.mode = v; render(); };
A.toggleTag = v => {
  if (v === '' || v == null) LearnCfg.tags.clear();
  else if (LearnCfg.tags.has(v)) LearnCfg.tags.delete(v); else LearnCfg.tags.add(v);
  render();
};
A.askDeleteTag = name => {
  confirmDialog({ title: 'Tag löschen?', danger: true, ok: 'Löschen',
    body: `Der Tag „<span class="dup-word">${esc(name)}</span>" wird aus allen Karten entfernt. Die Karten selbst bleiben erhalten.`,
    onOk: async () => {
      await DB.snapshot('pre-delete', 10 * 60 * 1000);
      DB.data.cards.forEach(c => { if (c.tags.includes(name)) { c.tags = c.tags.filter(t => t !== name); c.updatedAt = now(); } });
      LearnCfg.tags.delete(name);
      DB.save(); render(); toast('Tag gelöscht');
    } });
};

/* ---------- Grammatik ---------- */
Views.grammar = () => {
  const lang = LearnCfg.gLang, topics = GRAMMAR_TOPICS[lang];
  const pool = GRAMMAR.filter(g => g.lang === lang && (!LearnCfg.gTopic || g.topic === LearnCfg.gTopic));
  return `<div class="backrow"><button class="chip" data-a="back">‹ Zurück</button></div>
  <div class="nav-title" style="margin-top:0">Grammatik</div>
  <label class="lbl">Sprache</label>
  <div class="seg">${[['fa', 'Persisch lernen'], ['de', 'Deutsch lernen']].map(([k, l]) => `<button class="${lang === k ? 'on' : ''}" data-a="setGLang" data-v="${k}">${l}</button>`).join('')}</div>
  <label class="lbl">Thema</label>
  <div class="topicchips">
    <button class="chip ${LearnCfg.gTopic === null ? 'on' : ''}" data-a="setGTopic" data-v="">Alle Themen</button>
    ${topics.map(t => `<button class="chip ${LearnCfg.gTopic === t ? 'on' : ''}" data-a="setGTopic" data-v="${esc(t)}">${esc(t)}</button>`).join('')}
  </div>
  <div class="card row" style="margin-top:16px"><span class="muted small">ℹ︎ ${pool.length} Aufgaben${lang === 'de' ? ' · Erklärungen auch auf Persisch' : ''}</span></div>
  <div style="margin-top:8px"><button class="pillbtn" data-a="startGrammar">Üben starten</button></div>
  <div style="height:20px"></div>`;
};
A.setGLang = v => { LearnCfg.gLang = v; LearnCfg.gTopic = null; render(); };
A.setGTopic = v => { LearnCfg.gTopic = v || null; render(); };

/* ---------- Karten ---------- */
let CardSearch = '';
function searchNorm(s, fa) { return Answer.normalize(s || '', fa).replace(/\s+/g, ''); }
function cardMatches(c, q) {
  const qn = searchNorm(q, false), qf = searchNorm(q, true);
  if (!qn && !qf) return true;
  return searchNorm(c.de.join(' '), false).includes(qn) || c.fa.map(x => searchNorm(x, true)).join('').includes(qf)
    || searchNorm(c.translit || '', false).includes(qn);
}
function filteredCards() {
  const q = CardSearch.trim();
  const list = DB.data.cards.slice().sort((a, b) => b.updatedAt - a.updatedAt);
  return q ? list.filter(c => cardMatches(c, q)) : list;
}
function cardRowHTML(c) {
  const weak = isWeak(c);
  return `<button class="card" style="width:100%;text-align:left" data-a="openEditor" data-v="${esc(c.id)}">
     <div class="row"><div>
        <div class="term-de">${esc(c.de.join(', '))}</div>
        <div class="term-fa persian" style="text-align:left">${esc(c.fa.join('، '))}</div>
        ${c.tags.length ? `<div class="tag-line">${esc(c.tags.join(' · '))}</div>` : ''}
      </div><div class="badges">
        ${c.fav ? '<span style="color:var(--turq)">★</span>' : ''}
        ${weak ? '<span style="color:var(--terra)" title="schwierig">◎</span>' : ''}
        ${!c.active ? '<span class="muted">⏸</span>' : ''}
        ${c.audio ? '<span style="color:var(--sage)">♪</span>' : ''}
      </div></div></button>`;
}
const NO_HITS = '<div class="muted small" style="text-align:center;padding:20px">Keine Treffer</div>';
Views.cards = () => {
  const head = `<div class="topbar"><div class="nav-title" style="margin:0">Karten</div><button class="iconbtn" data-a="openEditor" data-v="" aria-label="Neue Karte">＋</button></div>`;
  if (!DB.data.cards.length) {
    return head + `<div class="empty"><div class="big">▤</div><div style="color:var(--text);font-weight:600;font-size:18px">Noch keine Karten</div>
      <div style="margin:8px 0 20px">Lege deine erste Karte an.</div>
      <button class="pillbtn" style="max-width:220px;margin:0 auto" data-a="openEditor" data-v="">Karte anlegen</button></div>`;
  }
  return head + `<input class="field" placeholder="Suchen" value="${esc(CardSearch)}" data-i="cardSearch" enterkeyhint="search">
    <div id="cardsList">${filteredCards().map(cardRowHTML).join('') || NO_HITS}</div>`;
};
IN.cardSearch = v => { CardSearch = v; const el = $('cardsList'); if (el) el.innerHTML = filteredCards().map(cardRowHTML).join('') || NO_HITS; };

/* ---------- Statistik ---------- */
Views.stats = () => {
  const s = computeStats(), maxBar = Math.max(1, ...s.perDay);
  const tile = (ic, col, val, lbl) => `<div class="card metric"><div class="ic" style="color:${col}">${ic}</div><div class="val">${val}</div><div class="lbl">${lbl}</div></div>`;
  const k = s.known, tot = Math.max(1, k.neu + k.lernend + k.gefestigt);
  const seg = (n, col) => n ? `<div style="width:${n / tot * 100}%;background:${col}"></div>` : '';
  const achOn = ACHIEVEMENTS.filter(a => a.test(s)).length;
  return `<div class="nav-title">Statistik</div>
   <div class="metric-grid">
     ${tile('▤', 'var(--sage)', s.total, 'Karten gesamt')}
     ${tile('✓', 'var(--turq)', s.active, 'Aktiv')}
     ${tile('☀', 'var(--terra)', s.today + '/' + s.goal, 'Heute (Ziel)')}
     ${tile('🔥', 'var(--warn)', s.streak + (s.streak === 1 ? ' Tag' : ' Tage'), 'Serie')}
     ${tile('◎', 'var(--sage)', Math.round(s.rate * 100) + '%', 'Erfolgsquote')}
     ${tile('⏱', 'var(--turq)', (s.avg ? s.avg.toFixed(1) + 's' : '–'), 'Ø Antwortzeit')}
   </div>
   <div class="card" style="margin-top:12px"><div class="row"><b>Level ${s.level.level}</b><span class="muted small">${s.xp} XP</span></div>
     <div class="xpbar"><div style="width:${clamp(s.level.pct, 0, 100)}%"></div></div>
     <div class="muted small" style="margin-top:6px">Noch ${s.level.next - s.xp} XP bis Level ${s.level.level + 1}. Punkte gibt es fürs richtige Erinnern – mehr, wenn du schwierige Wörter meisterst.</div></div>
   <div class="card"><div style="font-weight:600;font-size:14px;margin-bottom:10px">Wissensstand</div>
     <div class="stack">${seg(k.gefestigt, 'var(--sage)')}${seg(k.lernend, 'var(--turq)')}${seg(k.neu, 'var(--sand)')}</div>
     <div class="legend"><span><i style="background:var(--sage)"></i>Gefestigt ${k.gefestigt}</span><span><i style="background:var(--turq)"></i>Lernend ${k.lernend}</span><span><i style="background:var(--sand)"></i>Neu ${k.neu}</span></div></div>
   <div class="card"><div style="font-weight:600;font-size:14px">Wiederholungen (14 Tage)</div>
     <div class="bars">${s.perDay.map(v => `<div style="height:${Math.max(2, v / maxBar * 100)}%"></div>`).join('')}</div></div>
   <div class="card"><div style="font-weight:600;font-size:14px;margin-bottom:8px">Schwierigste Wörter</div>
     ${s.hardest.length ? s.hardest.map(c => `<div class="row" style="padding:3px 0"><span>${esc(c.de[0])}</span><span class="persian muted">${esc(c.fa[0])}</span></div>`).join('') : '<div class="muted small">Noch keine schwierigen Wörter.</div>'}</div>
   <div class="card"><div style="font-weight:600;font-size:14px;margin-bottom:8px">Häufigste Tags</div>
     ${s.topTags.length ? `<div style="display:flex;flex-wrap:wrap;gap:8px">${s.topTags.map(([t, n]) => `<span class="chip">${esc(t)} (${n})</span>`).join('')}</div>` : '<div class="muted small">Noch keine Tags.</div>'}</div>
   <div class="card"><div style="font-weight:600;font-size:14px;margin-bottom:10px">Meilensteine (${achOn}/${ACHIEVEMENTS.length})</div>
     <div class="ach">${ACHIEVEMENTS.map(a => `<div class="${a.test(s) ? 'on' : ''}" title="${esc(a.desc)}"><span class="i">${a.icon}</span>${esc(a.name)}</div>`).join('')}</div></div>
   <div style="height:12px"></div>`;
};

/* ---------- Mehr (Einstellungen, Daten, Info) ---------- */
function seg(val, opts, act) {
  return `<div class="seg">${opts.map(([k, l]) => `<button class="${val === k ? 'on' : ''}" data-a="${act}" data-v="${k}">${l}</button>`).join('')}</div>`;
}
function fmtDate(ts) { return new Date(ts).toLocaleString('de-DE', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' }); }

Views.more = () => {
  const st = DB.data.settings, m = DB.data.meta;
  const last = m.lastExternalBackup;
  return `<div class="nav-title">Mehr</div>
   <label class="lbl">Darstellung</label>
   ${seg(st.appearance, [['system', 'System'], ['light', 'Hell'], ['dark', 'Dunkel']], 'setAppearance')}
   <div class="card row" style="margin-top:10px"><span>Animationen</span><button class="toggle ${st.animations ? 'on' : ''}" data-a="toggleAnim" aria-label="Animationen"><span></span></button></div>
   <div class="card row"><span>Vibration</span><button class="toggle ${st.haptics ? 'on' : ''}" data-a="toggleHaptics" aria-label="Vibration"><span></span></button></div>
   <label class="lbl">Standard-Modus</label>
   ${seg(st.defaultMode, [['flip', 'Umdrehen'], ['mc', 'Multiple'], ['write', 'Schreiben']], 'setDefMode')}
   <label class="lbl">Standard-Richtung</label>
   ${seg(st.defaultDirection, [['g2p', 'DE→FA'], ['p2g', 'FA→DE'], ['mixed', 'Gemischt']], 'setDefDir')}
   <label class="lbl">Tägliches Ziel</label>
   <div class="card row"><span>${st.dailyGoal} Karten</span><div class="stepper"><button data-a="goalStep" data-v="-5" aria-label="weniger">−</button><button data-a="goalStep" data-v="5" aria-label="mehr">＋</button></div></div>
   <label class="lbl">Daten &amp; Backup</label>
   <button class="card row" style="width:100%;text-align:left" data-a="openBackup"><span>⭳ Backup sichern</span><span class="muted">›</span></button>
   <button class="card row" style="width:100%;text-align:left" data-a="openRestore"><span>⭱ Backup wiederherstellen</span><span class="muted">›</span></button>
   <button class="card row" style="width:100%;text-align:left" data-a="openSnapshots"><span>◷ Automatische Sicherungen</span><span class="muted">›</span></button>
   <input type="file" id="importFile" accept="application/json,.json,text/plain" class="hidden" data-c="importFile">
   <div class="card"><div class="muted small">
     ${last ? 'Letztes Backup: <b>' + esc(fmtDate(last)) + '</b>' : '<b>Noch kein Backup.</b>'}<br>
     Speicher: ${m.persisted ? 'dauerhaft geschützt' : 'Standard'} · ${DB.data.cards.length} Karten · ${DB.data.logs.length} Verlaufseinträge<br><br>
     <b>ZARA</b> arbeitet vollständig offline. Alle Daten bleiben in diesem Browser auf deinem iPhone. Vor jedem Update und jeder Wiederherstellung legt ZARA automatisch eine Sicherungskopie an. Zusätzlich solltest du regelmäßig ein Backup in „Dateien" sichern.
     <br><br>Version ${APP_VERSION}</div></div>
   <div style="height:20px"></div>`;
};
A.setAppearance = v => { DB.data.settings.appearance = v; DB.save(); applyTheme(); render(); };
A.toggleAnim = () => { DB.data.settings.animations = !DB.data.settings.animations; DB.save(); applyTheme(); render(); };
A.toggleHaptics = () => { DB.data.settings.haptics = !DB.data.settings.haptics; DB.save(); render(); };
A.setDefMode = v => { DB.data.settings.defaultMode = v; DB.save(); render(); };
A.setDefDir = v => { DB.data.settings.defaultDirection = v; DB.save(); render(); };
A.goalStep = v => { DB.data.settings.dailyGoal = clamp(DB.data.settings.dailyGoal + Number(v), 5, 200); DB.save(); render(); };
