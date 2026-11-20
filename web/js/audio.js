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

export async function play(text, { slow = false, v = null } = {}) {
  if (v && !indexes[v]) await loadIndex(v).catch(() => {});
  const clip = index(v || voice)[text];
  stop();
  if (!clip) return;
  // One element for every clip: once a tap has started it, iPhone Safari lets it play again
  // without a tap (the other side of a conversation answering).
  if (!element) element = new Audio();
  player = element;
  player.src = `audio/${clip[0]}`;
  player.preservesPitch = true;
  player.defaultPlaybackRate = slow ? 0.75 : 1;
  player.playbackRate = slow ? 0.75 : 1;
  playing = text;
  changed();
  const done = () => { if (playing === text) { playing = null; player = null; changed(); } };
  player.onended = done;
  player.onerror = done;
  try { await player.play(); } catch { done(); }
}

export function stop() {
  if (player) { player.pause(); player = null; }
  if (playing !== null) { playing = null; changed(); }
}

export function toggle(text) { if (isPlaying(text)) stop(); else play(text); }

/** Every clip of a voice (for keeping them all offline). */
export function allFiles(v = voice) {
  return [...new Set(Object.values(index(v)).map((c) => `audio/${c[0]}`))];
}
