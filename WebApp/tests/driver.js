/* Browser-seitiger End-to-End-Treiber (wird per fetch geladen und im Seitenkontext ausgeführt).
   Bedient die echte Oberfläche per DOM-Klicks: jede Übungsart, jede Richtung, richtige/falsche/Tippfehler-Antworten. */
(function () {
  const errors = [];
  window.addEventListener('error', e => errors.push('error: ' + (e.message || e.error)));
  window.addEventListener('unhandledrejection', e => errors.push('rejection: ' + (e.reason && e.reason.message || e.reason)));
  const origErr = console.error; console.error = (...a) => { errors.push('console.error: ' + a.map(x => (x && x.message) || String(x)).join(' ')); };
  const sleep = ms => new Promise(r => setTimeout(r, ms));
  const q = (sel, root = document) => root.querySelector(sel);
  const qa = (sel, root = document) => [...root.querySelectorAll(sel)];
  const click = el => { if (!el) throw new Error('Element fehlt'); el.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true })); };
  const clickA = (a, v) => { const el = q(`[data-a="${a}"]${v != null ? `[data-v="${CSS.escape(String(v))}"]` : ''}`); if (!el) throw new Error(`[data-a=${a}${v != null ? ' v=' + v : ''}] nicht gefunden`); if (el.disabled) throw new Error(`[data-a=${a}] ist deaktiviert`); click(el); };
  const has = a => !!q(`[data-a="${a}"]:not([disabled])`);
  const rnd = n => Math.floor(Math.random() * n);

  async function solveStep(policy) {
    const step = Session.step(), ss = Session.ss, t = step.type;
    const wantRight = policy === 'right' ? true : policy === 'wrong' ? false : Math.random() < 0.65;
    const card = step.cardId ? cardById(step.cardId) : null;
    if (t === 'flip') {
      clickA('flip'); await sleep(5);
      clickA('rate', wantRight ? (Math.random() < 0.3 ? 4 : 3) : (Math.random() < 0.5 ? 1 : 2));
    } else if (t === 'mc' || t === 'listen' || t === 'cloze' || t === 'ccloze' || t === 'grammar') {
      const ci = t === 'mc' ? ss.ch.correctIdx : t === 'listen' ? ss.data.correctIdx : (t === 'cloze' || t === 'ccloze') ? ss.c.correctIdx : ss.q.correctIdx;
      const n = qa('[data-a="pick"]').length;
      const idx = wantRight ? ci : (ci + 1) % n;
      clickA('pick', idx); await sleep(5);
      clickA('sNext');
    } else if (t === 'write' || t === 'translate') {
      const fa = t === 'write' ? step.dir === 'g2p' : ss.t.answerIsFa;
      const sol = t === 'write' ? (fa ? card.fa[0] : card.de[0]) : ss.t.solutions[0];
      let val = sol;
      const mode = wantRight ? (Math.random() < 0.8 ? 'exact' : 'typo') : 'wrong';
      if (mode === 'typo' && sol.length > 5) val = sol.slice(0, -1);
      if (mode === 'wrong') val = fa ? 'ظظظظ' : 'Xqzw';
      const input = q('#writeInput'); if (!input) throw new Error('Eingabefeld fehlt');
      input.value = val; input.dispatchEvent(new Event('input', { bubbles: true }));
      clickA('sCheck'); await sleep(5);
      clickA('sNext');
    } else if (t === 'match') {
      const ids = step.cardIds.slice();
      for (const id of ids) {
        if (!wantRight && id === ids[0]) { clickA('mpick', 'L:' + id); clickA('mpick', 'R:' + ids[1]); await sleep(5); }
        clickA('mpick', 'L:' + id); clickA('mpick', 'R:' + id);
      }
      await sleep(5); clickA('sNext');
    } else if (t === 'build') {
      const b = ss.b;
      let order = b.solution.map(tok => b.tokens.findIndex((x, i) => x.t === tok && !ss._used?.includes(i)));
      // eindeutige Zuordnung (auch bei doppelten Wörtern)
      const used = new Set(); order = b.solution.map(tok => { const i = b.tokens.findIndex((x, k) => x.t === tok && !used.has(k)); used.add(i); return i; });
      if (!wantRight) order = order.slice().reverse();
      for (const i of order) clickA('place', i);
      if (order.length > 1) { clickA('unplace', order[order.length - 1]); clickA('place', order[order.length - 1]); }
      clickA('buildCheck'); await sleep(5);
      clickA('sNext');
    } else if (t === 'speak') {
      ss.userBlob = new Blob(['x']); render();
      clickA('speakRate', wantRight ? 3 : 1);
    } else throw new Error('Unbekannter Typ ' + t);
  }

  async function runSession(label, startAction, { policy = 'mixed', max = 60 } = {}) {
    const before = { logs: DB.data.logs.length, cards: DB.data.cards.length };
    clickA(startAction);
    await sleep(20);
    if (!Session.s) return { label, skipped: true };
    const types = new Set(); let n = 0;
    while (Session.s && !Session.s.done && n < max) {
      types.add(Session.step().type);
      await solveStep(policy);
      n++;
      if (Store.lastSaveError) throw new Error('Speicherfehler: ' + Store.lastSaveError);
    }
    const finished = Session.s && Session.s.done;
    const text = $('screen').innerText;
    const s = Session.s;
    const out = { label, steps: n, types: [...types], finished, summary: finished && /abgeschlossen/.test(text), answered: s && s.answered, newLogs: DB.data.logs.length - before.logs, cards: DB.data.cards.length };
    if (finished) { clickA('go', App.tab); await sleep(10); }
    return out;
  }

  window.__e2e = { errors, sleep, q, qa, click, clickA, has, runSession, solveStep };
  return 'driver bereit';
})();
