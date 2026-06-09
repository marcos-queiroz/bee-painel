// ASAPainel — Polyfill da Web Speech API (speechSynthesis) com ponte para TTS nativo.
// Injetado em AT_DOCUMENT_START. Substitui window.speechSynthesis e
// window.SpeechSynthesisUtterance para que sistemas web que dependem de narracao
// funcionem mesmo em WebViews (ex.: Android TV) que nao implementam a API.
//
// As mensagens sao enviadas ao Flutter via flutter_inappwebview.callHandler.
// O lado Dart responde chamando window.__ttsBridge.fireEnd / fireError / setVoices.
(function () {
  if (window.__beePainelTtsInstalled) return;
  window.__beePainelTtsInstalled = true;

  var pending = {};      // id -> utterance
  var queue = [];        // utterances aguardando
  var speaking = false;
  var voices = [];
  var nextId = 1;

  function hasBridge() {
    return window.flutter_inappwebview &&
      typeof window.flutter_inappwebview.callHandler === 'function';
  }

  function post(method, payload) {
    if (!hasBridge()) return;
    try {
      window.flutter_inappwebview.callHandler(method, payload);
    } catch (e) { /* noop */ }
  }

  function fire(u, type, extra) {
    var handler = u ? u['on' + type] : null;
    var evt = Object.assign({ type: type, utterance: u, name: type, charIndex: 0 }, extra || {});
    if (typeof handler === 'function') {
      try { handler.call(u, evt); } catch (e) { /* noop */ }
    }
    if (u && u.__listeners && u.__listeners[type]) {
      u.__listeners[type].forEach(function (cb) {
        try { cb.call(u, evt); } catch (e) { /* noop */ }
      });
    }
  }

  function Utterance(text) {
    this.text = text || '';
    this.lang = '';
    this.rate = 1;
    this.pitch = 1;
    this.volume = 1;
    this.voice = null;
    this.onstart = null;
    this.onend = null;
    this.onerror = null;
    this.onpause = null;
    this.onresume = null;
    this.onboundary = null;
    this.onmark = null;
    this.__listeners = {};
  }
  Utterance.prototype.addEventListener = function (type, cb) {
    if (!this.__listeners[type]) this.__listeners[type] = [];
    this.__listeners[type].push(cb);
  };
  Utterance.prototype.removeEventListener = function (type, cb) {
    var arr = this.__listeners[type];
    if (!arr) return;
    var i = arr.indexOf(cb);
    if (i >= 0) arr.splice(i, 1);
  };
  Utterance.prototype.dispatchEvent = function () { return true; };

  function drain() {
    if (speaking || queue.length === 0) return;
    var u = queue.shift();
    var id = nextId++;
    pending[id] = u;
    speaking = true;
    synth.speaking = true;
    synth.pending = queue.length > 0;
    fire(u, 'start');
    post('tts.speak', {
      id: id,
      text: u.text,
      lang: u.lang || '',
      rate: u.rate,
      pitch: u.pitch,
      volume: u.volume,
      voice: u.voice ? (u.voice.name || u.voice.voiceURI || null) : null
    });
  }

  var synth = {
    speaking: false,
    pending: false,
    paused: false,
    onvoiceschanged: null,
    speak: function (u) {
      if (!(u instanceof Utterance)) {
        var wrapped = new Utterance(u && u.text ? u.text : String(u || ''));
        u = wrapped;
      }
      queue.push(u);
      synth.pending = true;
      drain();
    },
    cancel: function () {
      queue = [];
      pending = {};
      speaking = false;
      synth.speaking = false;
      synth.pending = false;
      post('tts.cancel', {});
    },
    pause: function () {
      synth.paused = true;
      post('tts.pause', {});
    },
    resume: function () {
      synth.paused = false;
      post('tts.resume', {});
    },
    getVoices: function () { return voices.slice(); },
    addEventListener: function (type, cb) {
      if (type === 'voiceschanged') synth.onvoiceschanged = cb;
    },
    removeEventListener: function () {}
  };

  // API chamada pelo lado Dart:
  window.__ttsBridge = {
    fireEnd: function (id) {
      var u = pending[id];
      delete pending[id];
      speaking = false;
      synth.speaking = false;
      synth.pending = queue.length > 0;
      if (u) fire(u, 'end');
      drain();
    },
    fireError: function (id, msg) {
      var u = pending[id];
      delete pending[id];
      speaking = false;
      synth.speaking = false;
      synth.pending = queue.length > 0;
      if (u) fire(u, 'error', { error: msg || 'synthesis-failed' });
      drain();
    },
    setVoices: function (list) {
      voices = (list || []).map(function (v) {
        return {
          name: v.name,
          lang: v.lang,
          default: !!v.default,
          localService: true,
          voiceURI: v.name
        };
      });
      if (typeof synth.onvoiceschanged === 'function') {
        try { synth.onvoiceschanged({ type: 'voiceschanged' }); } catch (e) {}
      }
    }
  };

  // Override total (modo recomendado: voz consistente em todas as plataformas).
  window.SpeechSynthesisUtterance = Utterance;
  try {
    Object.defineProperty(window, 'speechSynthesis', {
      value: synth,
      configurable: true,
      writable: false
    });
  } catch (e) {
    window.speechSynthesis = synth;
  }

  // Solicita as vozes nativas disponiveis.
  post('tts.getVoices', {});
})();
