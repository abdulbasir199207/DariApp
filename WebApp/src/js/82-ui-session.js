/* ============================================================
   82-ui-session: Ablauf einer Übungseinheit und die Ansichten aller
   Aufgabentypen (Umdrehen, Auswahl, Schreiben, Hören, Zuordnung,
   Lückentext, Satzbildung, Übersetzen, Grammatik, Aussprache).
   ============================================================ */

const FAST = { mc: 4, write: 5, listen: 5 };    // Sekunden für „Leicht"
const curDir = () => LearnCfg.direction || DB.data.settings.defaultDirection;
const curMode = () => LearnCfg.mode || DB.data.settings.defaultMode;
const speechCaps = () => ({ canSpeakFa: Speech.can('fa'), canSpeakDe: Speech.can('de') });

const Session = {
  s: null,
  ss: null,

  start({ title, steps, again }) {
    if (!steps || !steps.length) { toast('Dafür gibt es gerade nichts zu üben.'); return false; }
    const st0 = computeStats();
    this.s = { title, steps, i: 0, answered: 0, correct: 0, xp: 0, weakFixed: 0, again, done: false,
      xp0: st0.xp, ach0: new Set(ACHIEVEMENTS.filter(a => a.test(st0)).map(a => a.id)) };
    App.session = true; App.sub = null;
    this.prepare();
    render();
    return true;
  },
  abort() {
    if (Recorder.active()) Recorder.abort();
    Speech.stop();
    this.s = null; this.ss = null; App.session = false;
  },
  step() { return this.s.steps[this.s.i]; },

  /* ----- Vorbereitung je Aufgabe ----- */
  prepare() {
    const step = this.step(), cards = DB.data.cards;
    const ss = this.ss = { t0: now(), selected: null, quality: null, val: '' };
    const card = step.cardId ? cardById(step.cardId) : null;
    if (step.cardId && !card) { return this.advance(); }
    switch (step.type) {
      case 'flip': ss.flipped = false; ss.revealed = false; break;
      case 'mc': ss.ch = makeCardChoices(card, step.dir === 'g2p', cards.filter(c => c.active || c.id === card.id)); break;
      case 'write': break;
      case 'listen': ss.data = makeListen(card, step.spoken, cards.filter(c => c.active)); ss.played = false; break;
      case 'match': ss.sel = null; ss.done = new Set(); ss.mistakes = {}; ss.errors = 0; ss.finished = false; ss.shake = null; break;
      case 'cloze': ss.c = makeCloze(SENTENCES.find(x => x.id === step.sentId), step.lang); break;
      case 'ccloze': ss.c = makeCardCloze(card, cards.filter(c => c.active || c.id === card.id)); if (!ss.c) return this.advance(); break;
      case 'build': ss.b = makeBuild(SENTENCES.find(x => x.id === step.sentId), step.dir); ss.placed = []; ss.result = null; break;
      case 'translate': ss.t = makeTranslate(SENTENCES.find(x => x.id === step.sentId), step.dir); break;
      case 'grammar': ss.q = makeGrammar(GRAMMAR.find(x => x.id === step.itemId)); break;
      case 'speak': ss.phase = 'start'; ss.userBlob = null; ss.recording = false; ss.rated = false; break;
    }
  },
  advance() {
    const s = this.s;
    Speech.stop();
    s.i++;
    if (s.i >= s.steps.length) { s.done = true; s.i = s.steps.length; this.ss = null; }
    else this.prepare();
  },

  /* ----- Verbuchen ----- */
  tally(log, rating) {
    const s = this.s;
    s.answered++; if (rating > 1) s.correct++;
    s.xp += xpForLog(log);
    if (log.wk && rating >= 3) s.weakFixed++;
  },
  seconds() { return (now() - this.ss.t0) / 1000; },
  cardResult(step, rating, opts = {}) {
    const card = cardById(step.cardId); if (!card) return;
    const log = Engine.recordCard(card, rating, { mode: opts.mode || step.type, time: this.seconds(), practice: step.practice, fsrs: opts.fsrs });
    this.tally(log, rating);
    if (rating === 1 && !step.practice && !opts.noRequeue) requeueStep(this.s.steps, this.s.i);
    DB.save();
  },
  itemResult(step, ok, rating) {
    const log = Engine.recordItem(step.sentId || step.itemId, ok, { mode: step.type, time: this.seconds(), practice: step.practice, rating });
    this.tally(log, ok ? rating : 1);
    if (!ok && !step.practice) requeueStep(this.s.steps, this.s.i);
    DB.save();
  },

  /* ----- Interaktion ----- */
  pick(i) {
    const step = this.step(), ss = this.ss;
    if (ss.selected != null) return;
    ss.selected = i;
    if (step.type === 'mc') {
      const ok = i === ss.ch.correctIdx; ss.quality = ok ? 'perfect' : 'wrong';
      this.cardResult(step, ratingFromQuality(ss.quality, this.seconds() < FAST.mc));
    } else if (step.type === 'listen') {
      const ok = i === ss.data.correctIdx; ss.quality = ok ? 'perfect' : 'wrong';
      this.cardResult(step, ratingFromQuality(ss.quality, this.seconds() < FAST.listen));
    } else if (step.type === 'cloze') {
      const ok = i === ss.c.correctIdx; ss.quality = ok ? 'perfect' : 'wrong';
      this.itemResult(step, ok, 3);
    } else if (step.type === 'ccloze') {
      const ok = i === ss.c.correctIdx; ss.quality = ok ? 'perfect' : 'wrong';
      this.cardResult(step, ratingFromQuality(ss.quality, this.seconds() < FAST.mc));
    } else if (step.type === 'grammar') {
      const ok = i === ss.q.correctIdx; ss.quality = ok ? 'perfect' : 'wrong';
      this.itemResult(step, ok, 3);
    }
    buzz(ss.quality === 'perfect' ? 10 : [40, 30, 40]);
    render();
  },
  flip() { const ss = this.ss; ss.flipped = !ss.flipped; ss.revealed = true; buzz(10); render(); },
  rate(g) { const step = this.step(); buzz(10); this.cardResult(step, g); this.advance(); render(); },
  check() {
    const step = this.step(), ss = this.ss;
    if (ss.quality) return;
    const el = $('writeInput'), val = (el ? el.value : ss.val).trim();
    if (!val) return;
    ss.val = val;
    if (step.type === 'write') {
      const card = cardById(step.cardId), fa = step.dir === 'g2p';
      ss.quality = Answer.evaluate(val, fa ? card.fa : card.de, fa);
      this.cardResult(step, ratingFromQuality(ss.quality, this.seconds() < FAST.write));
    } else if (step.type === 'translate') {
      ss.quality = Answer.evaluateSentence(val, ss.t.solutions, ss.t.answerIsFa);
      this.itemResult(step, ss.quality !== 'wrong', ss.quality === 'typo' ? 2 : 3);
    }
    buzz(ss.quality === 'perfect' ? 10 : ss.quality === 'typo' ? 30 : [40, 30, 40]);
    render();
  },
  next() { this.advance(); render(); },

  place(i) { const ss = this.ss; if (ss.result || ss.placed.includes(i)) return; ss.placed.push(i); render(); },
  unplace(i) { const ss = this.ss; if (ss.result) return; ss.placed = ss.placed.filter(x => x !== i); render(); },
  resetBuild() { const ss = this.ss; if (ss.result) return; ss.placed = []; render(); },
  checkBuild() {
    const step = this.step(), ss = this.ss;
    if (ss.result || ss.placed.length !== ss.b.tokens.length) return;
    const ok = checkBuild(ss.b, ss.placed.map(i => ss.b.tokens[i].t));
    ss.result = ok ? 'right' : 'wrong'; ss.quality = ok ? 'perfect' : 'wrong';
    this.itemResult(step, ok, 3);
    buzz(ok ? 10 : [40, 30, 40]); render();
  },

  mpick(v) {
    const ss = this.ss, step = this.step();
    if (ss.finished) return;
    const side = v[0], id = v.slice(2);
    if (ss.done.has(id)) return;
    if (!ss.sel || ss.sel.side === side) { ss.sel = { side, id }; return render(); }
    const a = ss.sel; ss.sel = null;
    const l = a.side === 'L' ? a.id : id, r = a.side === 'L' ? id : a.id;
    if (l === r) {
      ss.done.add(l); buzz(10);
      if (ss.done.size === step.cardIds.length) this.finishMatch();
    } else {
      ss.mistakes[l] = (ss.mistakes[l] || 0) + 1; ss.mistakes[r] = (ss.mistakes[r] || 0) + 1; ss.errors++;
      ss.shake = { l, r }; buzz([40, 30, 40]);
      const key = this.s.i, self = this;
      setTimeout(() => { if (self.s && self.s.i === key && self.ss === ss) { ss.shake = null; render(); } }, 420);
    }
    render();
  },
  finishMatch() {
    const step = this.step(), ss = this.ss;
    ss.finished = true;
    const per = this.seconds() / step.cardIds.length;
    for (const id of step.cardIds) {
      const card = cardById(id); if (!card) continue;
      const rating = ss.mistakes[id] ? 1 : 3;
      const log = Engine.recordCard(card, rating, { mode: 'match', time: per, fsrs: false });
      this.tally(log, rating);
    }
    DB.save();
  },

  /* Aussprache */
  async speakRef() {
    const step = this.step(), card = cardById(step.cardId);
    const ok = await Player.playRef(card, 'fa') || await Player.playRef(card, 'de');
    if (!ok) toast('Keine Sprachausgabe oder Aufnahme vorhanden.');
  },
  async recToggle() {
    const ss = this.ss;
    if (Recorder.active()) {
      ss.userBlob = await Recorder.stop(); ss.recording = false; ss.phase = 'rec'; render(); return;
    }
    try { await Recorder.start(); ss.recording = true; render(); }
    catch (e) { toast(Recorder.errorMessage(e), 3500); }
  },
  async playMine() { if (!(await Player.playBlob(this.ss.userBlob))) toast('Wiedergabe nicht möglich.'); },
  speakRate(g) {
    const step = this.step();
    this.cardResult(step, g, { mode: 'speak', fsrs: false, noRequeue: true });
    this.advance(); render();
  },

  /* ================= Ansichten ================= */
  head() {
    const s = this.s, step = s.i < s.steps.length ? this.step() : null;
    return `<div class="row" style="margin-bottom:8px"><button class="chip" data-a="endSession">✕ Beenden</button><span class="muted small">${Math.min(s.i + 1, s.steps.length)} / ${s.steps.length}</span></div>
      <div class="progress"><div style="width:${s.i / s.steps.length * 100}%"></div></div>
      ${step && step.retry ? '<div class="langbadge">Noch einmal üben</div>' : ''}`;
  },
  nextBtn(label = 'Weiter') { return `<div style="margin-top:14px"><button class="pillbtn" data-a="sNext">${label}</button></div>`; },

  view() {
    const s = this.s;
    if (!s) return '';
    if (s.done) return this.summary();
    const step = this.step();
    const fn = this['v_' + step.type];
    const body = fn ? fn.call(this, step, this.ss) : '';
    return this.head() + body;
  },
  afterRender() {
    const s = this.s; if (!s || s.done) return;
    const step = this.step(), ss = this.ss;
    const input = $('writeInput');
    if (input && !ss.quality) { try { input.focus({ preventScroll: true }); } catch (e) {} }
    if (step.type === 'listen' && ss && !ss.played) { ss.played = true; this.listenPlay(); }
  },

  /* ----- Umdrehen ----- */
  v_flip(step, ss) {
    const card = cardById(step.cardId), g2p = step.dir === 'g2p';
    const front = !ss.flipped;
    const promptFa = !g2p, ansFa = g2p;
    const prompt = promptFa ? card.fa[0] : card.de[0], answer = ansFa ? card.fa[0] : card.de[0];
    const lang = ansFa ? 'fa' : 'de';
    const canPlay = (lang === 'fa' && card.audio) || Speech.can(lang);
    const inner = front
      ? `<div class="term-big ${promptFa ? 'fa persian' : ''}">${esc(prompt) || '—'}</div>${!ss.revealed ? '<div class="muted small" style="margin-top:8px">Zum Umdrehen tippen</div>' : ''}`
      : `<div class="term-big ${ansFa ? 'fa persian' : ''}">${esc(answer) || '—'}</div>
         ${card.translit ? `<div class="translit">${esc(card.translit)}</div>` : ''}
         ${canPlay ? `<button class="audiobtn" data-a="playRef" data-v="${lang}" aria-label="Anhören">◉</button>` : ''}`;
    const rating = ss.revealed ? `<div class="rating fadein">
        <button style="background:var(--terra)" data-a="rate" data-v="1">Nochmal</button>
        <button style="background:var(--warn)" data-a="rate" data-v="2">Schwer</button>
        <button style="background:var(--sage)" data-a="rate" data-v="3">Gut</button>
        <button style="background:var(--turq)" data-a="rate" data-v="4">Leicht</button></div>` : '';
    return `<div class="flip fadein"><div class="flip-face" data-a="flip" role="button">${inner}</div></div>${rating}`;
  },

  /* ----- Multiple Choice ----- */
  v_mc(step, ss) {
    const card = cardById(step.cardId), g2p = step.dir === 'g2p', ansFa = g2p;
    const promptFa = !g2p, prompt = promptFa ? card.fa[0] : card.de[0];
    const opts = ss.ch.options.map((o, i) => {
      let cls = 'choice';
      if (ss.selected != null) { if (i === ss.ch.correctIdx) cls += ' correct'; else if (i === ss.selected) cls += ' wrong'; else cls += ' dim'; }
      return `<button class="${cls} ${ansFa ? 'persian' : ''}" data-a="pick" data-v="${i}" ${ss.selected != null ? 'disabled' : ''}>${esc(o)}</button>`;
    }).join('');
    return `<div class="flip-face fadein" style="min-height:130px"><div class="term-big ${promptFa ? 'fa persian' : ''}">${esc(prompt)}</div></div>
      <div style="margin-top:18px">${opts}</div>${ss.selected != null ? this.nextBtn() : ''}`;
  },

  /* ----- Schreiben ----- */
  v_write(step, ss) {
    const card = cardById(step.cardId), g2p = step.dir === 'g2p', fa = g2p;
    const promptFa = !g2p, prompt = promptFa ? card.fa[0] : card.de[0], answer = fa ? card.fa[0] : card.de[0];
    return `<div class="flip-face fadein" style="min-height:110px"><div class="term-big ${promptFa ? 'fa persian' : ''}">${esc(prompt)}</div></div>
      <div style="margin-top:18px">${this.inputHTML(ss, fa)}</div>
      ${this.feedbackHTML(ss, { answer, answerFa: fa })}`;
  },
  inputHTML(ss, fa) {
    return ss.quality
      ? `<div class="field ${fa ? 'persian' : ''}" style="text-align:center;opacity:.7">${esc(ss.val)}</div>`
      : `<input id="writeInput" class="field ${fa ? 'persian' : ''}" style="text-align:center;font-size:20px" placeholder="${fa ? 'پاسخ فارسی' : 'Antwort'}" ${fa ? 'lang="fa" dir="rtl"' : 'lang="de"'} autocapitalize="${fa ? 'none' : 'sentences'}" autocorrect="off" spellcheck="false" enterkeyhint="done" value="${esc(ss.val)}" data-enter="sCheck">`;
  },
  feedbackHTML(ss, { answer, answerFa, full, tr }) {
    if (!ss.quality) return `<div style="margin-top:14px"><button class="pillbtn" data-a="sCheck">Prüfen</button></div>`;
    const map = { perfect: ['ok', 'Perfekt!'], typo: ['typo', 'Fast – kleiner Tippfehler'], wrong: ['bad', 'Leider falsch'] };
    const [cls, msg] = map[ss.quality];
    return `<div class="feedback-box"><div class="${cls}">${msg}</div>
      ${ss.quality !== 'perfect' ? `<div class="muted" style="margin-top:6px">Richtig: <span class="${answerFa ? 'persian' : ''}" dir="auto">${esc(answer)}</span></div>` : ''}
      ${full ? `<div class="full ${answerFa ? 'fa persian' : ''}">${esc(full)}</div>` : ''}
      ${tr ? `<div class="translit" style="margin-top:4px">${esc(tr)}</div>` : ''}</div>${this.nextBtn()}`;
  },

  /* ----- Hören ----- */
  async listenPlay() {
    const step = this.step(), ss = this.ss, card = cardById(step.cardId);
    const ok = await Player.playRef(card, ss.data.spoken);
    if (!ok) toast('Wiedergabe nicht möglich.');
  },
  v_listen(step, ss) {
    const d = ss.data, card = cardById(step.cardId);
    const opts = d.options.map((o, i) => {
      let cls = 'choice';
      if (ss.selected != null) { if (i === d.correctIdx) cls += ' correct'; else if (i === ss.selected) cls += ' wrong'; else cls += ' dim'; }
      return `<button class="${cls} ${d.answerIsFa ? 'persian' : ''}" data-a="pick" data-v="${i}" ${ss.selected != null ? 'disabled' : ''}>${esc(o)}</button>`;
    }).join('');
    const reveal = ss.selected != null
      ? `<div class="feedback-box"><div class="${ss.quality === 'perfect' ? 'ok' : 'bad'}">${ss.quality === 'perfect' ? 'Richtig!' : 'Leider falsch'}</div>
         <div class="full ${d.spoken === 'fa' ? 'fa persian' : ''}">${esc(d.speakText)}</div>${card.translit && d.spoken === 'fa' ? `<div class="translit">${esc(card.translit)}</div>` : ''}</div>${this.nextBtn()}` : '';
    return `<div class="langbadge">${d.spoken === 'fa' ? 'Persisch hören → Deutsch wählen' : 'Deutsch hören → Persisch wählen'}</div>
      <button class="speakbtn" data-a="listenAgain" aria-label="Noch einmal abspielen">▶</button>
      <div class="pill-note" style="margin:0 0 14px">Tippe zum erneuten Abspielen</div>
      <div>${opts}</div>${reveal}`;
  },

  /* ----- Zuordnung ----- */
  v_match(step, ss) {
    const g2p = step.dir === 'g2p';
    const text = (id, side) => { const c = cardById(id); const fa = (side === 'L') ? !g2p : g2p; return { t: fa ? c.fa[0] : c.de[0], fa }; };
    const col = (ids, side) => ids.map(id => {
      const { t, fa } = text(id, side);
      let cls = 'mbtn' + (fa ? ' fa persian' : '');
      if (ss.done.has(id)) cls += ' done';
      else if (ss.sel && ss.sel.side === side && ss.sel.id === id) cls += ' sel';
      if (ss.shake && ((side === 'L' && ss.shake.l === id) || (side === 'R' && ss.shake.r === id))) cls += ' shake';
      return `<button class="${cls}" data-a="mpick" data-v="${side}:${esc(id)}">${esc(t)}</button>`;
    }).join('');
    const sum = ss.finished ? `<div class="feedback-box"><div class="${ss.errors ? 'typo' : 'ok'}">${ss.errors ? ss.errors + (ss.errors === 1 ? ' Fehlversuch' : ' Fehlversuche') : 'Fehlerfrei!'}</div>
        <div class="muted small" style="margin-top:4px">Falsch zugeordnete Wörter kommen bald wieder dran.</div></div>${this.nextBtn()}` : '';
    return `<div class="langbadge">Tippe zwei Wörter an, die zusammengehören</div>
      <div class="matchgrid"><div class="matchcol">${col(step.left, 'L')}</div><div class="matchcol">${col(step.right, 'R')}</div></div>${sum}`;
  },

  /* ----- Lückentext ----- */
  v_ccloze(step, ss) { return this.v_cloze(step, ss); },
  v_cloze(step, ss) {
    const c = ss.c, fa = c.lang === 'fa', answered = ss.selected != null;
    const toks = c.tokens.map((t, i) => {
      if (t != null) return `<span>${esc(t)}</span>`;
      const gap = answered ? `<span class="gap ${ss.quality === 'perfect' ? 'filled' : 'bad'}">${esc(ss.quality === 'perfect' ? c.answer : c.options[ss.selected])}</span>` : '<span class="gap">&nbsp;&nbsp;&nbsp;&nbsp;</span>';
      return gap + (c.trail ? `<span>${esc(c.trail)}</span>` : '');
    }).join('');
    const opts = c.options.map((o, i) => {
      let cls = 'choice' + (fa ? ' persian' : '');
      if (answered) { if (i === c.correctIdx) cls += ' correct'; else if (i === ss.selected) cls += ' wrong'; else cls += ' dim'; }
      return `<button class="${cls}" data-a="pick" data-v="${i}" ${answered ? 'disabled' : ''}>${esc(o)}</button>`;
    }).join('');
    const fb = answered ? `<div class="feedback-box"><div class="${ss.quality === 'perfect' ? 'ok' : 'bad'}">${ss.quality === 'perfect' ? 'Richtig!' : 'Leider falsch'}</div>
        <div class="full ${fa ? 'fa persian' : ''}">${esc(c.full)}</div>${c.tr ? `<div class="translit" style="margin-top:4px">${esc(c.tr)}</div>` : ''}</div>${this.nextBtn()}` : '';
    return `<div class="langbadge">Welches Wort fehlt?</div>
      <div class="flip-face fadein" style="min-height:120px;padding:22px 14px"><div class="sentence ${fa ? 'fa persian' : ''}">${toks}</div></div>
      <div class="hintline ${c.hintIsFa ? 'persian' : ''}" dir="auto" style="margin-top:12px">${esc(c.hint)}</div>
      <div>${opts}</div>${fb}`;
  },

  /* ----- Satzbildung ----- */
  v_build(step, ss) {
    const b = ss.b, fa = b.answerIsFa;
    const placed = ss.placed.map(i => `<button class="wtok ${fa ? 'fa persian' : ''}" data-a="unplace" data-v="${i}">${esc(b.tokens[i].t)}</button>`).join('');
    const bank = b.tokens.map((tk, i) => `<button class="wtok ${fa ? 'fa persian' : ''} ${ss.placed.includes(i) ? 'used' : ''}" data-a="place" data-v="${i}">${esc(tk.t)}</button>`).join('');
    const full = ss.placed.length === b.tokens.length;
    const fb = ss.result ? `<div class="feedback-box"><div class="${ss.result === 'right' ? 'ok' : 'bad'}">${ss.result === 'right' ? 'Richtig!' : 'Leider falsch'}</div>
        <div class="full ${fa ? 'fa persian' : ''}">${esc(b.full)}</div><div class="translit" style="margin-top:4px">${esc(b.tr)}</div></div>${this.nextBtn()}`
      : `<div class="row" style="margin-top:14px;gap:10px"><button class="pillbtn secondary" style="flex:1" data-a="buildReset">Zurücksetzen</button><button class="pillbtn" style="flex:2" data-a="buildCheck" ${full ? '' : 'disabled'}>Prüfen</button></div>`;
    return `<div class="langbadge">Bilde den Satz</div>
      <div class="flip-face fadein" style="min-height:90px;padding:18px 14px"><div class="term-big ${b.promptIsFa ? 'fa persian' : ''}" style="font-size:${b.promptIsFa ? 28 : 22}px" dir="auto">${esc(b.prompt)}</div></div>
      <div class="tray answer ${fa ? 'rtl' : ''} ${ss.result === 'right' ? 'right' : ss.result === 'wrong' ? 'wrong' : ''}" style="margin-top:14px">${placed || '<span class="muted small">Tippe die Wörter in der richtigen Reihenfolge an</span>'}</div>
      <div class="tray" style="margin-top:12px;${fa ? 'direction:rtl' : ''}">${bank}</div>${fb}`;
  },

  /* ----- Übersetzen ----- */
  v_translate(step, ss) {
    const t = ss.t, fa = t.answerIsFa;
    return `<div class="langbadge">Übersetze den Satz</div>
      <div class="flip-face fadein" style="min-height:90px;padding:18px 14px"><div class="term-big ${t.promptIsFa ? 'fa persian' : ''}" style="font-size:${t.promptIsFa ? 28 : 22}px" dir="auto">${esc(t.prompt)}</div></div>
      <div style="margin-top:16px">${this.inputHTML(ss, fa)}</div>
      ${this.feedbackHTML(ss, { answer: t.solutions[0], answerFa: fa, tr: ss.quality ? t.tr : '' })}`;
  },

  /* ----- Grammatik ----- */
  v_grammar(step, ss) {
    const q = ss.q, answered = ss.selected != null;
    const opts = q.options.map((o, i) => {
      let cls = 'choice ' + (isFaText(o) ? 'pfont' : '');
      if (answered) { if (i === q.correctIdx) cls += ' correct'; else if (i === ss.selected) cls += ' wrong'; else cls += ' dim'; }
      return `<button class="${cls}" dir="auto" style="font-size:${isFaText(o) ? 21 : 17}px" data-a="pick" data-v="${i}" ${answered ? 'disabled' : ''}>${esc(o)}</button>`;
    }).join('');
    const fb = answered ? `<div class="feedback-box"><div class="${ss.quality === 'perfect' ? 'ok' : 'bad'}">${ss.quality === 'perfect' ? 'Richtig!' : 'Leider falsch'}</div>
        <div class="ex" dir="auto">${esc(q.e)}</div>${q.x ? `<div class="ex persian" style="text-align:right;font-size:16px" dir="rtl">${esc(q.x)}</div>` : ''}</div>${this.nextBtn()}` : '';
    return `<div class="langbadge">${esc(q.lang === 'fa' ? 'Persisch' : 'Deutsch')} · ${esc(q.topic)}</div>
      <div class="flip-face fadein" style="min-height:96px;padding:20px 16px"><div class="qtext" dir="auto" style="padding:0;${isFaText(q.q) ? 'font-size:22px' : ''}">${esc(q.q)}</div></div>
      <div style="margin-top:16px">${opts}</div>${fb}`;
  },

  /* ----- Aussprache ----- */
  v_speak(step, ss) {
    const card = cardById(step.cardId);
    const hasRef = card.audio || Speech.can('fa') || Speech.can('de');
    return `<div class="langbadge">Hören · Nachsprechen · Vergleichen</div>
      <div class="flip-face fadein"><div class="term-big fa persian">${esc(card.fa[0])}</div>
        ${card.translit ? `<div class="translit">${esc(card.translit)}</div>` : ''}<div class="muted">${esc(card.de[0])}</div></div>
      <div class="row" style="justify-content:center;gap:18px;margin-top:10px">
        ${hasRef ? `<div style="text-align:center"><button class="iconbtn" style="width:56px;height:56px;font-size:24px" data-a="speakRef" aria-label="Vorbild anhören">▶</button><div class="muted small" style="margin-top:4px">Vorbild</div></div>` : ''}
        <div style="text-align:center"><button class="speakbtn ${ss.recording ? 'rec' : ''}" style="margin:0" data-a="recToggle" aria-label="Aufnahme">${ss.recording ? '⏹' : '●'}</button><div class="muted small" style="margin-top:4px">${ss.recording ? 'Aufnahme läuft …' : 'Aufnehmen'}</div></div>
        ${ss.userBlob ? `<div style="text-align:center"><button class="iconbtn" style="width:56px;height:56px;font-size:24px" data-a="playMine" aria-label="Meine Aufnahme">▶</button><div class="muted small" style="margin-top:4px">Meine</div></div>` : ''}
      </div>
      ${ss.userBlob ? `<div class="rating fadein" style="grid-template-columns:1fr 1fr"><button style="background:var(--terra)" data-a="speakRate" data-v="1">Nochmal üben</button><button style="background:var(--sage)" data-a="speakRate" data-v="3">Klingt gut</button></div>` : ''}
      <div class="pill-note">Du vergleichst selbst – ZARA bewertet die Aussprache nicht automatisch.</div>`;
  },

  /* ----- Abschluss ----- */
  summary() {
    const s = this.s, st = computeStats();
    const rate = s.answered ? Math.round(s.correct / s.answered * 100) : 0;
    const lvUp = st.level.level > levelInfo(s.xp0).level;
    const newAch = ACHIEVEMENTS.filter(a => a.test(st) && !s.ach0.has(a.id));
    return `<div class="rec-wrap fadein" style="text-align:center;padding-top:40px">
      <div class="big-n">✓</div>
      <div style="font-size:22px;font-weight:700">${esc(s.title)} abgeschlossen</div>
      <div class="sumgrid">
        <div class="card"><div class="v">${s.answered}</div><div class="l">Antworten</div></div>
        <div class="card"><div class="v">${rate}%</div><div class="l">richtig</div></div>
        <div class="card"><div class="v">+${s.xp}</div><div class="l">XP</div></div>
      </div>
      ${lvUp ? `<div class="banner" style="justify-content:center"><b>Level ${st.level.level} erreicht!</b></div>` : ''}
      ${s.weakFixed ? `<div class="muted" style="margin-bottom:8px">${s.weakFixed} schwierige${s.weakFixed === 1 ? 's Wort' : ' Wörter'} richtig beantwortet – stark!</div>` : ''}
      ${newAch.map(a => `<div class="banner" style="justify-content:center">${a.icon} Neuer Meilenstein: <b>${esc(a.name)}</b></div>`).join('')}
      <div style="display:flex;flex-direction:column;gap:10px;margin-top:20px">
        ${s.again ? `<button class="pillbtn" data-a="sAgain">Noch eine Runde</button>` : ''}
        <button class="pillbtn ${s.again ? 'secondary' : ''}" data-a="go" data-v="${App.tab}">Fertig</button>
      </div></div>`;
  }
};

/* ---------- Aktionen der Übungseinheit ---------- */
A.endSession = () => {
  const s = Session.s;
  if (s && s.answered > 0 && !s.done) { s.done = true; s.i = s.steps.length; Session.ss = null; render(); }
  else { Session.abort(); render(); }
};
A.sNext = () => Session.next();
A.sCheck = () => Session.check();
A.sAgain = () => { const s = Session.s; if (s && s.again) { const steps = s.again(); if (!Session.start({ title: s.title, steps, again: s.again })) A.go(App.tab); } };
A.flip = () => Session.flip();
A.rate = v => Session.rate(Number(v));
A.pick = v => Session.pick(Number(v));
A.place = v => Session.place(Number(v));
A.unplace = v => Session.unplace(Number(v));
A.buildReset = () => Session.resetBuild();
A.buildCheck = () => Session.checkBuild();
A.mpick = v => Session.mpick(v);
A.listenAgain = () => Session.listenPlay();
A.speakRef = () => Session.speakRef();
A.recToggle = () => Session.recToggle();
A.playMine = () => Session.playMine();
A.speakRate = v => Session.speakRate(Number(v));
A.playRef = async (lang) => {
  const step = Session.step(), card = cardById(step.cardId);
  if (!(await Player.playRef(card, lang))) toast('Keine Sprachausgabe oder Aufnahme vorhanden.');
};

/* ---------- Start-Aktionen ---------- */
function startPlan(title, build) {
  const steps = build();
  return Session.start({ title, steps, again: build });
}
A.startVocab = () => startPlan('Lernen', () => planVocab(candidates(), { mode: curMode(), direction: curDir(), limit: DB.data.settings.dailyGoal }));
A.startToday = () => startPlan('Heute lernen', () => planVocab(activeCards(), { mode: curMode(), direction: curDir(), limit: DB.data.settings.dailyGoal }));
A.startMore = A.startToday;
A.startWeak = () => startPlan('Schwierige Wörter', () => planWeak(DB.data.cards, { direction: curDir() }));
A.startMix = () => startPlan('5-Minuten-Spiel', () => planMix(DB.data, Object.assign({ direction: curDir() }, speechCaps())));
A.startMatch = () => startPlan('Zuordnung', () => planMatch(activeCards(), 3, Math.random, curDir()));
A.startListen = () => startPlan('Hören', () => planListen(activeCards(), Object.assign({ direction: curDir(), count: 10 }, speechCaps())));
A.startSpeak = () => startPlan('Aussprache', () => planSpeak(activeCards(), 8));
A.startCloze = () => startPlan('Lückentext', () => planCloze(DB.data, { count: 10, direction: curDir() }));
A.startBuild = () => startPlan('Satzbildung', () => planSentences('build', DB.data.sent, { count: 8, direction: curDir() }));
A.startTranslate = () => startPlan('Übersetzen', () => planSentences('translate', DB.data.sent, { count: 8, direction: curDir() }));
A.startGrammar = () => startPlan('Grammatik', () => planGrammar(DB.data.sent, { lang: LearnCfg.gLang, topic: LearnCfg.gTopic, count: 10 }));
A.newCard = () => A.openEditor('');
