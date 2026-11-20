// What the learner keeps, in this browser only (nothing is sent anywhere): saved phrases and
// their lists, phrases marked learned, recently opened phrases, and the settings. If the
// browser won't store anything (some private windows), everything still works for the visit.

const KEY = "ara.web.v1";
const blank = () => ({ saved: {}, learned: {}, recent: [], settings: {} });
let data = blank();

export function load() {
  try {
    const raw = localStorage.getItem(KEY);
    if (raw) data = { ...blank(), ...JSON.parse(raw) };
  } catch { data = blank(); }
}

function persist() {
  try { localStorage.setItem(KEY, JSON.stringify(data)); } catch { /* kept for this visit */ }
}

// Settings: language ("en"/"pl"), voice ("eka"/"giorgi"), appearance ("system"/"light"/"dark").
export function setting(name) { return data.settings[name]; }
export function setSetting(name, value) { data.settings[name] = value; persist(); }

// Saved phrases, each with an optional list name.
export function isSaved(id) { return !!data.saved[id]; }
export function savedIDs() {
  return Object.entries(data.saved).sort((a, b) => (b[1].at || 0) - (a[1].at || 0)).map(([id]) => id);
}
export function setSaved(id, on) {
  if (on) data.saved[id] = data.saved[id] || { list: "", at: Date.now() };
  else delete data.saved[id];
  persist();
}
export function toggleSaved(id) { setSaved(id, !isSaved(id)); return isSaved(id); }

export function listOf(id) { return (data.saved[id] && data.saved[id].list) || ""; }
export function lists() {
  return [...new Set(Object.values(data.saved).map((s) => s.list).filter(Boolean))].sort((a, b) => a.localeCompare(b));
}
/** Moving a phrase to a list also saves it. "" takes it out of any list. */
export function move(id, list) {
  data.saved[id] = { ...(data.saved[id] || { at: Date.now() }), list: list.trim() };
  persist();
}

export function isLearned(id) { return !!data.learned[id]; }
export function setLearned(id, on) {
  if (on) data.learned[id] = Date.now(); else delete data.learned[id];
  persist();
}

export function noteOpened(id) {
  data.recent = [id, ...data.recent.filter((x) => x !== id)].slice(0, 12);
  persist();
}
export function recent() { return data.recent; }
