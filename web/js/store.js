import { schedule, gradeOf, dayKey } from "./engine.js";
// What the learner keeps, in this browser only (nothing is sent anywhere): the profile from the
// welcome steps, finished lessons, every letter's and word's review schedule, daily activity,
// saved phrases and their lists, phrases marked learned, recently opened phrases, settings. If the
// browser won't store anything (some private windows), everything still works for the visit.

const KEY = "ara.web.v1";
const blank = () => ({ saved: {}, learned: {}, recent: [], settings: {}, profile: {}, completed: {}, mastery: {}, days: {} });
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

// ---------------------------------------------------------------------------------------
// The course side (LearningStore.swift)


export function profile() { return data.profile; }
export function setProfile(change) { data.profile = { ...data.profile, ...change }; persist(); }

export function completed() { return new Set(Object.keys(data.completed)); }
export function mastery() { return data.mastery; }
export function days() { return data.days; }

function day(key = dayKey()) {
  data.days[key] = data.days[key] || { xp: 0, answers: 0, correct: 0, lessons: 0, reviewed: 0 };
  return data.days[key];
}

/** One answer: its review schedule (not for retries) and today's counts. */
export function record(ex, evaluation, { itemIDs, inReview }) {
  const now = Date.now();
  const ok = evaluation.verdict !== "wrong";
  if (!ex.id.endsWith("+")) {
    for (const id of itemIDs) {
      const m = data.mastery[id] || { ease: 2.5, interval: 0, repetitions: 0, lapses: 0, due: now, lastSeen: 0, right: 0, wrong: 0 };
      const grade = gradeOf(evaluation.verdict);
      // Right again on the same day doesn't move it further: spacing needs days in between.
      const sameDay = dayKey(m.lastSeen) === dayKey(now) && m.repetitions > 0;
      if (grade === "again") { Object.assign(m, schedule(m, "again", now)); m.wrong += 1; }
      else { if (!sameDay) Object.assign(m, schedule(m, grade, now)); m.right += 1; }
      m.lastSeen = now;
      data.mastery[id] = m;
    }
  }
  const d = day();
  d.answers += 1;
  if (ok) d.correct += 1;
  if (inReview) d.reviewed += 1;
  persist();
}

/** XP stays inside (the daily goal is counted in it), as on the iPhone; screens don't show it. */
export function finishLesson(lessonID, summary) {
  data.completed[lessonID] = data.completed[lessonID] || Date.now();
  const d = day();
  d.xp += 10 + summary.right + (summary.perfect ? 5 : 0);
  d.lessons += 1;
  if (summary.perfect) d.perfect = (d.perfect || 0) + 1;
  persist();
}
export function finishReview(summary) {
  const d = day();
  d.xp += 5 + summary.right;
  d.reviews = (d.reviews || 0) + 1;
  persist();
}

export function practise(id) {
  if (!data.mastery[id]) data.mastery[id] = { ease: 2.5, interval: 0, repetitions: 0, lapses: 0, due: Date.now(), lastSeen: 0, right: 0, wrong: 0 };
  setSaved(id, true);
}
export function stopPractising(id) { delete data.mastery[id]; persist(); }
export function isPractising(id) { return !!data.mastery[id]; }

export function resetAll() { data = blank(); persist(); }
