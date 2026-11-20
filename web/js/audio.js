// The Georgian clips: one per text in each voice (Eka, female; Giorgi, male), made once by
// tools/audio/make_audio.py and labelled "Synthetic voice" (or "Native recording" when a
// native speaker's clip replaces one). No clip → no speaker button. Nothing is generated here.

const indexes = { eka: null, giorgi: null };
let voice = "eka";
let player = null;
let element = null;
let playing = null; // the text playing now
const listeners = new Set();

export const VOICES = ["eka", "giorgi"];
export const SAMPLE = "გამარჯობა, როგორ ხარ?";

async function loadIndex(v) {
  if (!indexes[v]) indexes[v] = await (await fetch(`audio/${v}.json`)).json();
}

/** Choose the voice; the other voice's index loads quietly for the samples in Settings. */
export async function loadVoice(v) {
  const want = VOICES.includes(v) ? v : "eka";
  await loadIndex(want);
  voice = want;
  VOICES.filter((x) => x !== want).forEach((x) => loadIndex(x).catch(() => {}));
}

export function currentVoice() { return voice; }
export function voiceName(v = voice) { return v === "giorgi" ? "Giorgi" : "Eka"; }
export function index(v = voice) { return indexes[v] || {}; }

export function canPlay(text) { return !!(text && index()[text]); }

/** "synthetic" or "native", or null without a clip. */
export function source(text) { const c = index()[text]; return c ? c[1] : null; }

export function isPlaying(text) { return playing === text; }

export function onChange(f) { listeners.add(f); return () => listeners.delete(f); }
function changed() { listeners.forEach((f) => f(playing)); }

// Playing: clips are decoded ahead of time (prepare(), for every speaker button on screen) and
// started through Web Audio, so a tap plays at once. A clip not ready yet, or slow playback
// (which must keep its pitch), goes through an <audio> element instead.
let ctx = null;
let sourceNode = null;
const buffers = new Map(); // file → AudioBuffer
const loading = new Map(); // file → Promise

function audioContext() {
  if (!ctx) {
    const AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) return null;
    // Play even with the iPhone's silent switch on, like the app (Safari 17+).
    try { if (navigator.audioSession) navigator.audioSession.type = "playback"; } catch { /* older Safari */ }
    ctx = new AC();
  }
  return ctx;
}

/** iPhone Safari starts sound only from a tap: wake the audio on the first touch. */
export function unlock() {
  const c = audioContext();
  if (c && c.state !== "running") c.resume().catch(() => {});
}

function decode(file) {
  if (buffers.has(file)) return Promise.resolve(buffers.get(file));
  if (loading.has(file)) return loading.get(file);
  const c = audioContext();
  if (!c) return Promise.resolve(null);
  const job = fetch(`audio/${file}`).then((r) => (r.ok ? r.arrayBuffer() : Promise.reject(r.status)))
    .then((data) => new Promise((ok, no) => c.decodeAudioData(data, ok, no)))
    .then((b) => { buffers.set(file, b); loading.delete(file); if (buffers.size > 300) buffers.delete(buffers.keys().next().value); return b; })
    .catch(() => { loading.delete(file); return null; });
  loading.set(file, job);
  return job;
}

/** Gets the clips for these texts ready, a few at a time. */
export function prepare(texts) {
  const files = [...new Set(texts.map((t) => (index()[t] || [])[0]).filter((f) => f && !buffers.has(f) && !loading.has(f)))].slice(0, 40);
  let i = 0;
  const next = () => { if (i < files.length) decode(files[i++]).then(next); };
  for (let k = 0; k < 4; k++) next();
}

export async function play(text, { slow = false, v = null } = {}) {
  if (v && !indexes[v]) await loadIndex(v).catch(() => {});
  const clip = index(v || voice)[text];
  stop();
  if (!clip) return;
  playing = text;
  changed();
  const done = () => { if (playing === text) { playing = null; player = null; sourceNode = null; changed(); } };
  const c = audioContext();
  const ready = buffers.get(clip[0]);
  if (c && ready && !slow) {
    if (c.state !== "running") c.resume().catch(() => {});
    const node = c.createBufferSource();
    node.buffer = ready;
    node.connect(c.destination);
    node.onended = () => { if (sourceNode === node) done(); };
    sourceNode = node;
    node.start();
    return;
  }
  if (!slow) decode(clip[0]); // ready for the next tap
  // One element for every clip: once a tap has started it, iPhone Safari lets it play again
  // without a tap (the other side of a conversation answering).
  if (!element) { element = new Audio(); element.preload = "auto"; }
  player = element;
  player.src = `audio/${clip[0]}`;
  player.preservesPitch = true;
  player.defaultPlaybackRate = slow ? 0.75 : 1;
  player.playbackRate = slow ? 0.75 : 1;
  player.onended = done;
  player.onerror = done;
  try { await player.play(); } catch { done(); }
}

export function stop() {
  if (sourceNode) { const n = sourceNode; sourceNode = null; try { n.stop(); } catch { /* ended */ } }
  if (player) { player.pause(); player = null; }
  if (playing !== null) { playing = null; changed(); }
}

export function toggle(text) { if (isPlaying(text)) stop(); else play(text); }

/** Every clip of a voice (for keeping them all offline). */
export function allFiles(v = voice) {
  return [...new Set(Object.values(index(v)).map((c) => `audio/${c[0]}`))];
}
