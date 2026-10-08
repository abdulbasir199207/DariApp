/* ============================================================
   70-media: Sprachausgabe (TTS), Wiedergabe eigener Aufnahmen,
   Aufnahme, Haptik. Alles per Funktionserkennung – fehlt etwas
   (z. B. persische Stimme), blendet die Oberfläche es sauber aus.
   ============================================================ */

const Speech = {
  voices: [],
  init() {
    try {
      if (typeof speechSynthesis === 'undefined') return;
      const load = () => { this.voices = speechSynthesis.getVoices() || []; };
      load();
      speechSynthesis.onvoiceschanged = load;
    } catch (e) {}
  },
  voiceFor(lang) {
    return this.voices.find(v => {
      const vl = String(v.lang || '').toLowerCase().replace('_', '-');
      return lang === 'fa' ? (vl.startsWith('fa') || vl.startsWith('prs')) : vl.startsWith('de');
    }) || null;
  },
  can(lang) { return !!this.voiceFor(lang); },
  speak(text, lang) {
    return new Promise(res => {
      const v = this.voiceFor(lang);
      if (!v || !text) return res(false);
      try {
        speechSynthesis.cancel();
        const u = new SpeechSynthesisUtterance(text);
        u.voice = v; u.lang = v.lang; u.rate = 0.85;
        u.onend = () => res(true); u.onerror = () => res(false);
        speechSynthesis.speak(u);
      } catch (e) { res(false); }
    });
  },
  stop() { try { speechSynthesis.cancel(); } catch (e) {} }
};

const Player = {
  _a: null,
  async playBlob(blob) {
    if (!blob) return false;
    try {
      if (this._a) { this._a.pause(); }
      const url = URL.createObjectURL(blob);
      const a = new Audio(url); this._a = a;
      a.onended = () => URL.revokeObjectURL(url);
      await a.play();
      return true;
    } catch (e) { return false; }
  },
  async playCard(id) { return this.playBlob(await AudioStore.get(id)); },
  /** Referenz-Aussprache: eigene Aufnahme bevorzugt (Persisch), sonst Sprachausgabe. */
  async playRef(card, lang) {
    if (lang === 'fa' && card.audio && await this.playCard(card.id)) return true;
    return Speech.speak(lang === 'fa' ? card.fa[0] : card.de[0], lang);
  }
};

const Recorder = {
  supported() { return !!(navigator.mediaDevices && navigator.mediaDevices.getUserMedia && typeof MediaRecorder !== 'undefined'); },
  _mr: null, _chunks: [], _stream: null,
  async start() {
    this._stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    this._chunks = [];
    this._mr = new MediaRecorder(this._stream);
    this._mr.ondataavailable = e => { if (e.data && e.data.size) this._chunks.push(e.data); };
    this._mr.start();
  },
  stop() {
    return new Promise(res => {
      const mr = this._mr;
      if (!mr || mr.state !== 'recording') return res(null);
      mr.onstop = () => {
        const blob = new Blob(this._chunks, { type: (this._chunks[0] && this._chunks[0].type) || 'audio/mp4' });
        if (this._stream) this._stream.getTracks().forEach(t => t.stop());
        this._mr = null; this._stream = null;
        res(blob);
      };
      mr.stop();
    });
  },
  active() { return !!(this._mr && this._mr.state === 'recording'); },
  abort() {
    try { if (this._mr && this._mr.state === 'recording') { this._mr.onstop = null; this._mr.stop(); } } catch (e) {}
    try { if (this._stream) this._stream.getTracks().forEach(t => t.stop()); } catch (e) {}
    this._mr = null; this._stream = null;
  },
  errorMessage(e) {
    const n = e && e.name;
    if (n === 'NotAllowedError' || n === 'SecurityError') {
      let embedded = false; try { embedded = window.self !== window.top; } catch (_) { embedded = true; }
      return embedded ? 'In der eingebetteten Vorschau ist das Mikrofon gesperrt – öffne ZARA vom Home-Bildschirm.'
                      : 'Mikrofon nicht erlaubt – bitte in den iPhone-Einstellungen freigeben.';
    }
    if (n === 'NotFoundError') return 'Kein Mikrofon gefunden.';
    return 'Aufnahme nicht möglich.';
  }
};

/** Kurzes Vibrationsfeedback (wo vom Browser unterstützt, z. B. nicht auf iOS-Safari). */
function buzz(p) {
  try {
    if (DB.data.settings.haptics === false) return;
    if (navigator.vibrate) navigator.vibrate(p);
  } catch (e) {}
}
