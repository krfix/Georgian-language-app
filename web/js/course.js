// The learning half of Ara on the web, drawn like the iPhone app's screens: the welcome steps
// (Onboarding), Home, Learn (the path, a lesson's preview, the alphabet), the lesson player
// with every exercise shape and the completion screen, Review, a word's card, Progress and the
// Profile part of Settings. The rules live in engine.js; what's kept lives in store.js.

import { tr, plural, lang } from "./i18n.js";
import * as audio from "./audio.js";
import * as store from "./store.js";
import { icon } from "./icons.js";
import { Builder, Session, evaluate, isGraded, lessonStates, currentStage, stages, streak, dayKey, isLearnedState, isDifficultState, rng } from "./engine.js";
import { C, esc, $, speaker, sourceLabel, pronunciationHints, sectionTitle, topBar, toast, render, navigate, checkNote, miniCard, applySetting, goBack, reportHref, reportLink } from "./app.js";

// ---------------------------------------------------------------------------------------
// Progress, worked out from what's kept (LearningStore.swift)

const ALPHABET = () => C.course.modules[0].lessons.length;
const level = () => store.profile().level || "beginner";
const startIndex = () => (level() === "canRead" ? ALPHABET() : 0);
const openBefore = () => (level() === "beginner" ? 0 : ALPHABET());

export function states() {
  const s = lessonStates(C.course.lessons.map((l) => l.id), store.completed(), startIndex(), openBefore());
  if (store.setting("devOpenAll")) for (const k in s) if (s[k] === "locked") s[k] = "available";
  return s;
}
export function nextLesson() {
  const s = states();
  const ls = C.course.lessons;
  return ls.find((l) => s[l.id] === "current") || ls.find((l) => s[l.id] === "available");
}
const modulesDone = () => {
  const done = store.completed();
  const out = new Set(C.course.modules.filter((m) => m.lessons.every((l) => done.has(l.id))).map((m) => m.id));
  if (level() === "canRead") out.add("alphabet");
  return out;
};
const stage = () => currentStage(modulesDone());
const doneIn = (m) => { const d = store.completed(); return m.lessons.filter((l) => d.has(l.id)).length; };
const activeDays = () => new Set(Object.entries(store.days()).filter(([, d]) => d.xp > 0 || d.answers > 0).map(([k]) => k));
const goal = () => store.profile().goal || 20;
export function dueItems() {
  const now = Date.now();
  return Object.entries(store.mastery()).filter(([, m]) => m.due <= now).sort((a, b) => a[1].due - b[1].due)
    .map(([id]) => C.course.item(id)).filter(Boolean);
}
const learnedCount = (letters) => Object.entries(store.mastery()).filter(([id, m]) => id.startsWith("letter-") === letters && !id.startsWith("pb-") && isLearnedState(m)).length;
const pct = () => Math.round((store.completed().size / C.course.lessons.length) * 100);

const MODULE_ICON = { "character.book.closed.fill": "book", "text.book.closed.fill": "book", "cup.and.saucer.fill": "cup", "puzzlepiece.fill": "puzzle", "bubble.left.and.bubble.right.fill": "bubbles" };
const KIND_ICON = { vocabulary: "book", phrases: "bubble", grammar: "puzzle", conversation: "bubbles", contrast: "wave", letters: "book" };
const brandOfLesson = (l) => (C.course.module(l.id) || {}).color || "pomegranate";

function glyph(lesson, size = 60) {
  const first = (lesson.letters || [])[0];
  return `<span class="glyph" style="--g:${size}px">${first ? `<span class="ka">${esc(first)}</span>` : icon(KIND_ICON[lesson.kind] || "book", { size: Math.round(size * 0.45) })}</span>`;
}

// ---------------------------------------------------------------------------------------
// Tappable words (TappableGeorgian.swift): a dotted underline; a tap opens a small bubble with
// the Latin spelling, the meaning, the dictionary form and why the word looks as it does.

const glossKey = (w) => w.replace(/^[.,?!—–:;"«»…()-]+|[.,?!—–:;"«»…()-]+$/g, "");

/** Georgian text whose words can be tapped. */
export function tapGeorgian(text) {
  return String(text).split(/(\s+)/).map((tok) => {
    const key = glossKey(tok);
    return key && C.glossary[key] ? `<span class="tw" data-gloss="${esc(key)}">${esc(tok)}</span>` : esc(tok);
  }).join("");
}

/** A paragraph in the learner's language with Georgian words in it: those words can be tapped.
 *  Hyphenated pieces (-ში) and single letters are about spelling, so they stay plain. */
export function tapProse(text) {
  return String(text).split(/([\u10D0-\u10FF]+(?:-[\u10D0-\u10FF]+)*-?)/).map((part, i, all) => {
    if (i % 2 === 0) return esc(part);
    const hyphen = part.includes("-") || /-$/.test(all[i - 1] || "") || /^-/.test(all[i + 1] || "");
    if (hyphen || [...part].length < 2 || !C.glossary[part]) return `<span class="ka-in">${esc(part)}</span>`;
    return `<span class="tw ka-in" data-gloss="${esc(part)}">${esc(part)}</span>`;
  }).join("");
}

export function showGloss(el) {
  closeGloss();
  const key = el.dataset.gloss;
  const g = C.glossary[key];
  if (!g) return;
  el.classList.add("on");
  const b = document.createElement("div");
  b.className = "gloss";
  b.setAttribute("role", "dialog");
  b.innerHTML = `<div class="gloss-head"><span class="ka">${esc(key)}</span>${audio.canPlay(key) ? speaker(key, { size: 32 }) : ""}
      <button class="close-x static" data-act="close-gloss" aria-label="${esc(tr("Close"))}">${icon("close", { size: 14 })}</button></div>
    <div class="lat">${esc(g.lat)}</div>
    ${g.meaning ? `<div class="gloss-meaning">${esc(g.meaning)}</div>` : ""}
    ${g.base ? `<div class="gloss-base"><small>${esc(tr("Dictionary form"))}</small><div><span class="ka">${esc(g.base)}</span> ${g.baseLat ? `<span class="lat">${esc(g.baseLat)}</span>` : ""}</div>${g.baseMeaning ? `<div>${esc(g.baseMeaning)}</div>` : ""}</div>` : ""}
    ${g.note ? `<p class="gloss-note">${esc(g.note)}</p>` : ""}`;
  document.body.appendChild(b);
  const r = el.getBoundingClientRect();
  const w = Math.min(320, window.innerWidth - 24);
  b.style.width = `${w}px`;
  b.style.left = `${Math.max(12, Math.min(window.innerWidth - w - 12, r.left + r.width / 2 - w / 2))}px`;
  const below = r.bottom + 8 + b.offsetHeight < window.innerHeight - 90;
  b.style.top = `${below ? r.bottom + 8 : Math.max(12, r.top - b.offsetHeight - 8)}px`;
}

export function closeGloss() {
  document.querySelectorAll(".gloss").forEach((g) => g.remove());
  document.querySelectorAll(".tw.on").forEach((t) => t.classList.remove("on"));
}

function bar(progress, cls = "") { return `<div class="bar ${cls}"><span style="width:${Math.round(Math.min(1, Math.max(0, progress)) * 100)}%"></span></div>`; }

// ---------------------------------------------------------------------------------------
// Welcome (OnboardingView.swift): welcome, Georgian, method, voice, level, goal, name, ready

const STEPS = ["welcome", "language", "method", "voice", "level", "goal", "name", "ready"];
const STEP_TINT = { welcome: "pomegranate", language: "saperavi", method: "blacksea", voice: "saperavi", level: "tkemali", goal: "gold", name: "saperavi", ready: "pomegranate" };
let draft = null;

export function needsWelcome() { return !store.profile().onboarded; }

export function welcomeScreen(n) {
  if (!draft) draft = { level: "beginner", goal: 20, name: "" };
  const step = STEPS[Math.max(0, Math.min(STEPS.length - 1, n))];
  const tint = STEP_TINT[step];
  const i = STEPS.indexOf(step);
  const top = step === "welcome" ? "" : `<div class="ob-top">
      <button class="back" data-ob="${i - 1}" aria-label="${esc(tr("Back"))}">${icon("chevronLeft", { size: 22 })}</button>
      <div class="ob-dots">${STEPS.slice(1).map((_, k) => `<span class="${k < i ? "on" : ""}"></span>`).join("")}</div></div>`;
  return `<div class="welcome tint-${tint}" data-screen="welcome">${top}<div class="ob-page">${welcomePage(step)}</div>
    <div class="ob-bottom">${welcomeButtons(step, i, tint)}</div></div>`;
}

function fact(ic, title, text, color) {
  return `<div class="fact"><span class="fact-icon grad b-${color}">${icon(ic, { size: 22 })}</span><div><strong>${esc(title)}</strong><p class="soft">${esc(text)}</p></div></div>`;
}

function choicePage(title, subtitle, options, selected, key, color) {
  return `<h1 class="ob-title">${esc(title)}</h1><p class="soft center">${esc(subtitle)}</p>
    <div class="ob-choices">${options.map(([value, t, d, ic]) => `<button class="ob-choice b-${color}${String(value) === String(selected) ? " on" : ""}" data-draft="${key}" data-value="${esc(value)}">
      <span class="fact-icon grad b-${color}">${icon(ic, { size: 20 })}</span><span><strong>${esc(t)}</strong><small>${esc(d)}</small></span>
      <span class="tick">${icon("check", { size: 18 })}</span></button>`).join("")}</div>`;
}

export const LEVELS = () => [
  ["beginner", tr("I'm brand new"), tr("Start with the alphabet, from the first letter."), "leaf"],
  ["someLetters", tr("I know a few letters"), tr("Start with the alphabet; every letter lesson is open to jump ahead."), "letters"],
  ["canRead", tr("I can read Georgian"), tr("Skip to everyday words. The alphabet stays open for revision."), "book"],
];
export const GOALS = () => [
  [10, tr("Casual"), cap(tr("about 5 minutes a day")), "cup"],
  [20, tr("Regular"), cap(tr("about 10 minutes a day")), "walk"],
  [30, tr("Serious"), cap(tr("about 15 minutes a day")), "run"],
  [50, tr("Intense"), cap(tr("about 25 minutes a day")), "flame"],
];
const cap = (s) => s.charAt(0).toUpperCase() + s.slice(1);
const bold = (s) => esc(s).replace(/\*\*(.+?)\*\*/g, '<b class="ka">$1</b>');

function welcomePage(step) {
  switch (step) {
    case "welcome": {
      const letters = ["ა", "ბ", "გ", "დ", "ე", "ვ", "ზ", "თ", "ი", "კ", "ლ", "მ"];
      const colors = ["pomegranate", "saperavi", "gold", "tkemali", "blacksea"];
      return `<div class="lang-switch">${["en", "pl"].map((l) => `<button class="${l === lang ? "on" : ""}" data-set="language" data-value="${l}">${l === "en" ? "🇬🇧 English" : "🇵🇱 Polski"}</button>`).join("")}</div>
        <div class="ob-hero">${letters.map((l, k) => { const a = (k / letters.length) * 2 * Math.PI; return `<span class="ring ka c-${colors[k % 5]}" style="--x:${Math.cos(a) * 130}px;--y:${Math.sin(a) * 130}px;--d:${k * 40}ms">${l}</span>`; }).join("")}
          <span class="sun"></span><img src="icons/mascot-hello.svg" alt="" class="ob-parrot"></div>
        <div class="ob-name">${esc(tr("Ara"))}</div>
        <h1 class="ob-title">${esc(tr("Learn Georgian, and use it every day"))}</h1>
        <p class="soft center">${bold(tr("Ara (**არა**) means “no” in Georgian. By the end, you’ll be saying **კი**: yes!"))}</p>`;
    }
    case "language":
      return `<h1 class="ob-title">${esc(tr("Meet Georgian"))}</h1><div class="facts">
        ${fact("book", tr("33 letters, no capitals"), tr("Mkhedruli, today's alphabet, has one form for every letter."), "pomegranate")}
        ${fact("speaker", tr("One letter, one sound"), tr("Words are spelled exactly as they're said. Learn the letters and you can read anything aloud."), "saperavi")}
        ${fact("scroll", tr("Over 1,500 years of writing"), tr("Georgian has its own script. UNESCO lists the living culture of its three alphabets."), "gold")}
        ${fact("globe", tr("A language family of its own"), tr("Georgian is Kartvelian: not related to Russian, Turkish or any language outside the Caucasus. About four million people speak it."), "blacksea")}</div>`;
    case "method":
      return `<h1 class="ob-title">${esc(tr("How you'll learn"))}</h1><div class="facts">
        ${fact("one", tr("Learn"), tr("Short lessons: a few new letters or words, shown, then practised straight away."), "pomegranate")}
        ${fact("two", tr("Practise"), tr("Ten kinds of exercise: matching, spelling with letter tiles, building sentences, conversations…"), "saperavi")}
        ${fact("three", tr("Review"), tr("Every word comes back just before you'd forget it. Mistakes come back sooner."), "blacksea")}
        ${fact("bulb", tr("Understand why"), tr("Every rule explained with examples and comparisons. Tap a word to see why it looks the way it does."), "gold")}</div>`;
    case "voice":
      return `<h1 class="ob-title">${esc(tr("Choose a voice"))}</h1><p class="soft center">${esc(tr("Every Georgian word and sentence in the app is spoken in this voice. Tap Listen to hear each one."))}</p>
        <div class="voices">${["eka", "giorgi"].map((x) => `<div class="voice${x === audio.currentVoice() ? " on" : ""}">
          <button class="voice-pick" data-set="voice" data-value="${x}"><strong>${audio.voiceName(x)}</strong><small>${esc(x === "eka" ? tr("Female voice") : tr("Male voice"))}</small></button>
          <button class="listen" data-sample="${x}">${icon("speaker", { size: 16 })}${esc(tr("Listen"))}</button></div>`).join("")}</div>
        <p class="soft small center">${esc(tr("“Hello, how are you?”"))} · ${esc(tr("Synthetic voice"))}</p>`;
    case "level":
      return choicePage(tr("How much Georgian do you know?"), tr("We'll start you in the right place. You can change it later."), LEVELS(), draft.level, "level", "tkemali");
    case "goal":
      return choicePage(tr("Pick a daily goal"), tr("Little and often works best: a short lesson or a review most days."), GOALS(), draft.goal, "goal", "gold");
    case "name":
      return `<h1 class="ob-title">${esc(tr("What should we call you?"))}</h1><p class="soft center">${esc(tr("Optional. It's only used to greet you, and it stays on this device."))}</p>
        <input id="ob-name" class="text-input" maxlength="30" autocomplete="given-name" placeholder="${esc(tr("Your name"))}" value="${esc(draft.name)}">`;
    default: {
      const first = firstLesson();
      const lv = LEVELS().find((x) => x[0] === draft.level), g = GOALS().find((x) => x[0] === draft.goal);
      return `<img src="icons/mascot-hello.svg" alt="" class="mascot"><h1 class="display center">${esc(tr("You're all set!"))}</h1>
        <p class="soft center">${esc(tr("Your first lesson takes about five minutes."))}</p>
        ${first ? `<div class="grad b-pomegranate first-lesson">${glyph(first, 60)}<div><small>${esc(tr("First lesson"))}</small><strong>${esc(first.title)}</strong><span>${esc(first.subtitle)}</span></div></div>` : ""}
        <div class="pills"><span class="pill c-gold">${icon("target", { size: 14 })}${esc(g[2])}</span><span class="pill c-tkemali">${icon(lv[3], { size: 14 })}${esc(lv[1])}</span></div>`;
    }
  }
}

const firstLesson = () => (draft && draft.level === "canRead" ? C.course.lesson("v1") : C.course.lessons[0]);

function welcomeButtons(step, i, tint) {
  if (step === "welcome") {
    return `<button class="chunky b-pomegranate" data-ob="1" data-id="onboarding-next">${esc(tr("Get started"))}</button>
      <button class="soft-button" data-act="ob-phrases">${icon("bubbles", { size: 18 })}${esc(tr("I just need phrases now"))}</button>
      <p class="faint small center">${esc(tr("No account needed. Stays on this device, works offline."))}</p>`;
  }
  if (step === "ready") {
    return `<button class="chunky b-pomegranate" data-act="ob-start" data-id="onboarding-start-lesson">${icon("play", { size: 18 })}${esc(tr("Start my first lesson"))}</button>
      <button class="text-button" data-act="ob-explore">${esc(tr("Explore first"))}</button>`;
  }
  const label = step === "name" && !draft.name.trim() ? tr("Skip") : tr("Continue");
  return `<button class="chunky b-${tint}" data-ob="${i + 1}" data-id="onboarding-next">${esc(label)}</button>`;
}

function finishWelcome(startLesson) {
  store.setProfile({ onboarded: true, name: (draft && draft.name.trim()) || "", level: (draft && draft.level) || "beginner", goal: (draft && draft.goal) || 20 });
  const first = firstLesson();
  draft = null;
  if (startLesson && first) location.replace(`#/lesson/${first.id}`);
  else location.replace("#/");
}

// ---------------------------------------------------------------------------------------
// Home (HomeView.swift): greeting, search, progress card, Learn | Use in Georgia, continue,
// "Right now I need…", review when due, recent and saved phrases.

function greeting() {
  const h = new Date().getHours();
  if (h >= 5 && h < 12) return ["დილა მშვიდობისა", tr("Good morning")];
  if (h >= 18) return ["საღამო მშვიდობისა", tr("Good evening")];
  return ["გამარჯობა", tr("Hello")];
}

function weekDots() {
  const fmt = new Intl.DateTimeFormat(lang === "pl" ? "pl-PL" : "en-GB", { weekday: "narrow" });
  const days = store.days();
  const out = [];
  for (let k = 6; k >= 0; k--) {
    const d = new Date(); d.setDate(d.getDate() - k);
    const rec = days[dayKey(d)] || {};
    const cls = (rec.xp || 0) >= goal() ? "full" : (rec.xp || 0) > 0 || (rec.answers || 0) > 0 ? "some" : "";
    out.push(`<span class="wd"><i class="${cls}">${cls === "full" ? icon("check", { size: 10 }) : ""}</i><small>${esc(fmt.format(d))}</small></span>`);
  }
  return `<div class="week">${out.join("")}</div>`;
}

export function homeScreen() {
  const [ka, hello] = greeting();
  const name = store.profile().name;
  const st = stage();
  const s = streak(activeDays());
  const lessonsDone = store.completed().size, total = C.course.lessons.length;
  const phrasesLearned = C.pb.phrases.filter((p) => store.isLearned(p.id)).length;
  const next = nextLesson();
  const due = dueItems();
  const saved = store.savedIDs().map((id) => C.phraseByID.get(id)).filter(Boolean);
  const recent = store.recent().map((id) => C.phraseByID.get(id)).filter(Boolean);
  const shelf = recent.length ? recent : saved;
  const quick = ["transport", "shopping", "food", "health", "home", "social", "emergency"];
  const short = { transport: tr("Taxi & bus"), shopping: tr("Shopping"), food: tr("Café"), health: tr("Pharmacy"), home: tr("At home"), social: tr("People"), emergency: tr("Emergency") };
  return `<div class="screen" data-screen="home">
    <header class="home-head">
      <div><div class="ka head-ka">${esc(ka)}</div><h1 class="display">${esc(name ? `${hello}, ${name}!` : `${hello}!`)}</h1></div>
      <a class="profile-button" href="#/settings" aria-label="${esc(tr("Profile and settings"))}" data-id="profile-button">${esc(name ? [...name][0].toUpperCase() : "ა")}</a>
    </header>
    <a class="search-bar" href="#/search" data-id="search-bar">${icon("search", { size: 20 })}<span>${esc(tr("Search: taxi, water, pharmacy…"))}</span></a>
    <a class="card progress-card" href="#/progress" data-id="home-progress">
      <div class="pc-row"><span class="stage-emoji">${st.emoji}</span><span class="pc-text"><small>${esc(tr("Your level"))}</small><strong>${esc(st.name)}</strong></span>
        <b class="pc-pct">${pct()}%</b>${icon("chevronRight", { size: 16, cls: "faint" })}</div>
      <div class="pc-row">${weekDots()}${s > 0 ? `<span class="streak">${icon("flame", { size: 14 })}${esc(tr("{0}-day streak", s))}</span>` : ""}</div>
    </a>
    <div class="halves">
      <a class="grad half b-saperavi" href="#/learn" data-id="purpose-learn"><span class="half-top"><strong>${esc(tr("Learn"))}</strong><span class="half-icon">${icon("map", { size: 16 })}</span></span>
        <small>${esc(tr("Your course, step by step"))}</small>${bar(lessonsDone / total, "on-color")}<em>${esc(tr("{0} of {1} lessons", lessonsDone, total))}</em></a>
      <a class="grad half b-pomegranate" href="#/phrasebook" data-id="purpose-use"><span class="half-top"><strong>${esc(tr("Use in Georgia"))}</strong><span class="half-icon">${icon("bubbles", { size: 16 })}</span></span>
        <small>${esc(tr("Phrases for real situations"))}</small>${bar(phrasesLearned / C.pb.phrases.length, "on-color")}<em>${esc(tr("{0} of {1} phrases learned", phrasesLearned, C.pb.phrases.length))}</em></a>
    </div>
    <div class="section-row"><h2 class="section-title">${esc(tr("Continue learning"))}</h2><a class="more-link" href="#/learn">${esc(tr("Course"))}</a></div>
    ${next ? continueCard(next) : `<div class="grad b-tkemali hero-card"><div><div class="hero-title">${esc(tr("You've finished the course!"))}</div><p>${esc(tr("Keep your Georgian fresh with daily reviews."))}</p></div></div>`}
    <div class="section-row"><h2 class="section-title">${esc(tr("Right now I need…"))}</h2><a class="more-link" href="#/phrasebook">${esc(tr("All"))}</a></div>
    <div class="carousel quick">${quick.map((id) => C.catByID.get(id)).filter(Boolean).map((c) => `<a class="quick-tile${c.id === "emergency" ? " urgent" : ""}" href="#/c/${c.id}" data-id="quick-${c.id}">
      <span class="qt-icon grad b-${c.color}">${icon(c.symbol, { size: 24 })}</span><small>${esc(short[c.id] || c.title)}</small></a>`).join("")}</div>
    ${due.length ? reviewNudge(due) : ""}
    ${shelf.length ? `<div class="section-row"><h2 class="section-title">${esc(recent.length ? tr("Recently used") : tr("Your saved phrases"))}</h2>${saved.length ? `<a class="more-link" href="#/saved">${esc(tr("My phrasebook"))}</a>` : ""}</div><div class="carousel">${shelf.slice(0, 8).map(miniCard).join("")}</div>` : ""}
  </div>`;
}

function continueCard(lesson) {
  const m = C.course.module(lesson.id);
  const color = m.color;
  const done = doneIn(m);
  return `<div class="grad continue b-${color}">
    <div class="cc-head"><span>${icon(MODULE_ICON[m.symbol] || "book", { size: 14 })}${esc(m.title)}</span><b>${done}/${m.lessons.length}</b></div>
    <div class="cc-body"><div><small>${esc(store.completed().size ? tr("Continue") : tr("Start learning"))}</small><strong>${esc(lesson.title)}</strong><span>${esc(lesson.subtitle)}</span></div>${glyph(lesson, 74)}</div>
    ${bar(done / m.lessons.length, "on-color thick")}
    <a class="chunky b-${color === "gold" ? "pomegranate" : "gold"}" href="#/lesson/${lesson.id}" data-id="continue-lesson">${icon("play", { size: 18 })}${esc(tr("Start lesson"))}</a>
  </div>`;
}

function reviewNudge(due) {
  return `<div class="card review-nudge"><div class="rn-head"><span class="rn-icon">${icon("review", { size: 22 })}</span>
    <div><strong>${esc(tr("{0} to review", due.length))}</strong><small class="soft">${esc(tr("Words and letters you're about to forget."))}</small></div></div>
    <div class="rn-items">${due.slice(0, 8).map((it) => `<span class="ka">${esc(it.ka)}</span>`).join("")}</div>
    <a class="chunky b-blacksea" href="#/session/review" data-id="review-now">${icon("play", { size: 18 })}${esc(tr("Review now"))}</a></div>`;
}

// ---------------------------------------------------------------------------------------
// Learn (LearnView.swift): one card per part of the course and its lessons as stones.

export function learnScreen() {
  const s = states();
  const swing = [0, 40, 60, 40, 0, -40, -60, -40];
  return `<div class="screen" data-screen="learn">
    <header class="page-head compact"><h1 class="display">${esc(tr("Learn"))}</h1></header>
    ${C.course.modules.map((m) => {
      const done = doneIn(m);
      return `<section class="module">
        <div class="grad module-card b-${m.color}">
          <div class="mc-top"><div><div class="hero-title">${esc(m.title)}</div><div class="mc-sub">${esc(m.subtitle)}</div></div>${icon(MODULE_ICON[m.symbol] || "book", { size: 30 })}</div>
          <p>${esc(m.intro)}</p>
          <div class="mc-bar">${bar(done / m.lessons.length, "on-color thick")}<b>${done}/${m.lessons.length}</b></div>
          ${m.id === "alphabet" ? `<a class="pill-white c-${m.color}" href="#/alphabet" data-id="alphabet-chart">${icon("grid", { size: 16 })}${esc(tr("All 33 letters"))}</a>` : ""}
        </div>
        <div class="path">${m.lessons.map((l, i) => {
          const st = s[l.id] || "locked";
          return `<button class="stone-row" style="--x:${swing[i % swing.length]}px" data-lesson="${l.id}" data-id="lesson-${l.id}">
            <span class="stone ${st} b-${m.color}">${st === "completed" ? icon("check", { size: 28 }) : st === "locked" ? icon("lock", { size: 22 }) : glyph(l, 56)}</span>
            <span class="stone-text"><strong>${esc(l.title)}</strong><small>${esc(l.subtitle)}</small></span></button>`;
        }).join("")}</div></section>`;
    }).join("")}
  </div>`;
}

/** The ribbon (LessonRibbon in LearnView.swift): a soft band and a line weaving through each
 *  part's stones, in the part's colour up to the next lesson. */
export function drawRibbons() {
  document.querySelectorAll(".path").forEach((path) => {
    path.querySelector("svg.ribbon")?.remove();
    const box = path.getBoundingClientRect();
    const stones = [...path.querySelectorAll(".stone")];
    if (stones.length < 2) return;
    const pts = stones.map((s) => { const r = s.getBoundingClientRect(); return [r.left + r.width / 2 - box.left, r.top + r.height / 2 - box.top]; });
    const lastDone = stones.reduce((k, s, i) => (s.classList.contains("completed") ? i : k), -1);
    const reach = Math.min(stones.length - 1, lastDone + 1);
    const seg = (a, b, i) => { const bow = (i % 2 ? 1 : -1) * 26; const mx = (a[0] + b[0]) / 2 + bow, my = (a[1] + b[1]) / 2; return `Q ${mx} ${my} ${b[0]} ${b[1]}`; };
    const d = (from, to) => { let out = `M ${pts[from][0]} ${pts[from][1]}`; for (let i = from + 1; i <= to; i++) out += ` ${seg(pts[i - 1], pts[i], i)}`; return out; };
    const color = getComputedStyle(stones[0]).getPropertyValue("--fill").trim() || "#E23B4E";
    const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
    svg.setAttribute("class", "ribbon");
    svg.setAttribute("width", box.width); svg.setAttribute("height", box.height);
    svg.innerHTML = `<path d="${d(0, pts.length - 1)}" fill="none" stroke="${color}" stroke-opacity="0.12" stroke-width="40" stroke-linecap="round"/>
      <path d="${d(0, pts.length - 1)}" fill="none" stroke="currentColor" stroke-opacity="0.18" stroke-width="5" stroke-dasharray="2 10" stroke-linecap="round"/>
      ${reach > 0 ? `<path d="${d(0, reach)}" fill="none" stroke="${color}" stroke-width="5" stroke-linecap="round"/>` : ""}`;
    path.prepend(svg);
  });
}

function kindLabel(l) {
  switch (l.kind) {
    case "letters": return (l.letters || []).length ? tr("New letters and your first reading") : tr("Reading practice");
    case "contrast": return tr("Sound pairs");
    case "vocabulary": return tr("New words");
    case "phrases": return tr("Everyday phrases");
    case "grammar": return tr("Grammar, step by step");
    default: return tr("A conversation");
  }
}

export function lessonSheet(id, openSheet) {
  const l = C.course.lesson(id);
  if (!l) return;
  const st = states()[id];
  if (st === "locked") {
    const s = states();
    const before = C.course.lessons.find((x) => s[x.id] === "current");
    toast(tr("Finish the lessons before \"{0}\" to open it.", l.title));
    void before;
    return;
  }
  const m = C.course.module(id);
  const items = (l.letters || []).length ? l.letters : C.course.wordsIn(l).map((w) => w.ka);
  const read = (l.read || []).map((g) => g.ka);
  const chips = (items.length ? items : read).slice(0, 12);
  openSheet(`<div class="ls-head"><span class="stone ${st === "completed" ? "completed" : "available"} b-${m.color}">${st === "completed" ? icon("check", { size: 26 }) : glyph(l, 52)}</span>
      <div><small class="c-${m.color} upper">${esc(m.title)}</small><h3>${esc(l.title)}</h3><p class="soft">${esc(kindLabel(l))}</p></div></div>
    ${chips.length ? `<strong>${esc(tr("You'll learn"))}</strong><div class="chip-flow">${chips.map((c) => `<span class="chip b-${m.color} ka">${esc(c)}</span>`).join("")}</div>` : ""}
    ${st === "completed" ? `<p class="ok">${icon("check", { size: 16 })}${esc(tr("Done: practise again"))}</p>` : ""}
    <a class="chunky b-${m.color === "gold" ? "pomegranate" : m.color}" href="#/lesson/${l.id}" data-id="preview-start">${icon("play", { size: 18 })}${esc(st === "completed" ? tr("Practise again") : tr("Start"))}</a>`);
}

// The alphabet chart (AlphabetChartView.swift): every letter, coloured by how well it's known.
export function alphabetScreen() {
  const ms = store.mastery();
  const status = (c) => { const m = ms[`letter-${c}`]; return !m ? "new" : isDifficultState(m) ? "difficult" : isLearnedState(m) ? "learned" : "learning"; };
  return `<div class="screen tint-pomegranate">
    ${topBar(tr("ანბანი · Alphabet"))}
    <p class="soft">${esc(tr("Mkhedruli: 33 letters, no capitals, one sound each."))}</p>
    <div class="legend">${[["new", tr("New")], ["learning", tr("Learning")], ["learned", tr("Learned")], ["difficult", tr("Difficult")]].map(([k, t]) => `<span><i class="st-${k}"></i>${esc(t)}</span>`).join("")}</div>
    <div class="letter-grid">${C.course.letters.map((l) => `<button class="letter-cell st-${status(l.char)}" data-say="${esc(l.char)}"><span class="ka">${esc(l.char)}</span><small>${esc(l.latin)}</small></button>`).join("")}</div>
    <a class="chunky b-pomegranate" href="#/session/letters" data-id="letter-practice">${icon("shuffle", { size: 18 })}${esc(tr("Practise 12 letters"))}</a>
  </div>`;
}

// ---------------------------------------------------------------------------------------
// The lesson player (LessonPlayerView.swift and the exercise views)

let P = null; // { session, phase, pending, ev, combo, mode, lesson, title, tint, praise, match, flipped }

const PRAISE = () => [tr("Brilliant!"), tr("Great job!"), tr("ყოჩაღ! Well done!"), tr("Perfect!"), tr("Spot on!"), tr("Excellent!")];

function builder() { return new Builder(C.course, (t) => audio.canPlay(t)); }

/** Starts a lesson ("lesson", id) or a review ("review" | "letters" | "difficult" | "word:<id>" | "saved"). */
export function startSession(kind, id) {
  const b = builder();
  const r = rng();
  if (kind === "lesson") {
    const l = C.course.lesson(id);
    if (!l) return false;
    P = { mode: "lesson", lesson: l, title: l.title, tint: brandOfLesson(l), session: new Session(b.exercises(l, r)) };
  } else {
    let items = [], title = tr("Daily review");
    if (id === "review") { items = dueItems(); if (!items.length) { items = weakest(); title = tr("Practice"); } }
    else if (id === "letters") { items = shuffle(C.course.letters).slice(0, 12).map((l) => C.course.item(`letter-${l.char}`)); title = tr("Letter workout"); }
    else if (id === "difficult") { items = difficult(); title = tr("Difficult words"); }
    else if (id === "saved") { items = store.savedIDs().map((x) => C.course.item(x)).filter(Boolean); title = tr("My phrasebook"); }
    else if (id && id.startsWith("word:")) { const it = C.course.item(id.slice(5)); items = it ? [it] : []; title = tr("Practice"); }
    items = items.filter(Boolean).slice(0, 15);
    if (!items.length) return false;
    P = { mode: "review", title, tint: "blacksea", session: new Session(b.review(items, r)), items: items.length };
  }
  Object.assign(P, { phase: "answering", pending: null, ev: null, combo: 0, match: null, flipped: false });
  return true;
}
const shuffle = (a) => { const o = [...a]; for (let i = o.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [o[i], o[j]] = [o[j], o[i]]; } return o; };
function weakest() {
  return Object.entries(store.mastery()).sort((a, b) => a[1].ease - b[1].ease || b[1].wrong - a[1].wrong).map(([id]) => C.course.item(id)).filter(Boolean);
}
function difficult() {
  return Object.entries(store.mastery()).filter(([, m]) => isDifficultState(m)).sort((a, b) => (b[1].lapses || 0) - (a[1].lapses || 0)).map(([id]) => C.course.item(id)).filter(Boolean);
}

export function hasSession() { return !!P; }
export function endSession() { P = null; }

// The badge beside each instruction (ExerciseKind.symbol on the iPhone).
const KIND_BADGE = { teachLetter: "sparkles", teachWord: "charBubble", note: "bulb", letterRecognition: "eye", multipleChoice: "checklist",
  reading: "book", missingLetter: "missing", fillBlank: "gap", listening: "ear", translation: "keyboard", matching: "grid",
  sentenceBuilder: "words", spelling: "spell", flashcard: "cards", dialogue: "bubbles" };
const chars = (s) => [...s].length;

export function playerScreen() {
  if (!P) return "";
  if (P.phase === "finished") return completeScreen();
  const ex = P.session.current;
  const tint = P.tint;
  return `<div class="player tint-${tint} b-${tint}" data-screen="lesson">
    <div class="player-top">
      <button class="back" data-act="quit" aria-label="${esc(tr("Close"))}">${icon("close", { size: 20 })}</button>
      <div class="bar thick"><span style="width:${Math.round(P.session.progress * 100)}%"></span></div>
      ${P.combo >= 3 ? `<span class="combo" aria-label="${esc(tr("{0} right in a row", P.combo))}">${icon("flame", { size: 16 })}${P.combo}</span>` : ""}
      <a class="back" href="${esc(reportHref(reportSubject(ex)))}" aria-label="${esc(tr("Report a mistake"))}" data-id="report-mistake">${icon("flag", { size: 19 })}</a>
      ${store.setting("devMode") && store.setting("devQuickPass") ? `<button class="pass" data-act="pass">${icon("play", { size: 12 })}${esc(tr("Pass"))}</button>` : ""}
    </div>
    <div class="player-body" data-shape="${ex.shape}" data-kind="${ex.kind}">
      <div class="instruction-row"><span class="ex-badge" aria-hidden="true">${icon(KIND_BADGE[ex.kind] || "bubble", { size: 19 })}</span><h2 class="instruction" data-id="instruction">${esc(ex.instruction)}</h2></div>
      ${exerciseView(ex)}
    </div>
    <div class="player-bottom${P.phase === "feedback" ? ` fb fb-${P.ev.verdict}` : ""}">${bottomBar(ex)}</div>
  </div>`;
}

// What "Report a mistake" sends from a lesson: the exercise on screen, and the answer and
// the right one while the feedback shows (LessonPlayerModel.reportSubject on the iPhone).
function reportSubject(ex) {
  const ref = P.mode === "lesson" ? P.lesson.id : "review";
  const shown = ex.prompt || ex.front || (ex.word && `${ex.word.ka} ${ex.word.lat}, ${ex.word.en}`) || (ex.letter && `${ex.letter.char} ${ex.letter.latin}`)
    || (ex.note && ex.note.title) || (ex.pairs && ex.pairs.map((p) => `${p.georgian} = ${p.other}`).join("; ")) || "";
  const lines = [tr("Lesson: {0}", P.title), tr("Exercise: {0} ({1})", ex.instruction, ex.kind), shown];
  if (ex.options && ex.options.length) lines.push(tr("Options: {0}", ex.options.map((o) => (typeof o === "string" ? o : o.text)).join(" / ")));
  if (P.phase === "feedback") {
    if (P.given) lines.push(tr("My answer: {0}", P.given));
    if (P.ev && P.ev.correct) lines.push(tr("Answer shown: {0}", P.ev.correct));
  }
  return { title: tr("the lesson {0}", P.title), lines: lines.filter(Boolean), id: `${ref}/${ex.id}` };
}

function bottomBar(ex) {
  if (P.phase === "feedback") {
    const v = P.ev.verdict;
    const title = v === "correct" ? P.praise : v === "almost" ? tr("Almost!") : tr("Not quite");
    const why = P.ev.explanation && (v !== "correct" || chars(P.ev.explanation) < 90) ? P.ev.explanation : "";
    return `<div class="feedback" data-id="feedback">
      <div class="fb-title"><span class="fb-icon">${icon(v === "wrong" ? "close" : "check", { size: 18 })}</span><strong>${esc(title)}</strong></div>
      ${v !== "correct" && P.ev.correct ? `<div class="fb-answer"><small>${esc(v === "almost" ? tr("Watch the spelling:") : tr("Right answer:"))}</small><b class="${/[ა-ჿ]/.test(P.ev.correct) ? "ka" : ""}">${esc(P.ev.correct)}</b></div>` : ""}
      ${why ? `<p class="fb-why">${esc(why)}</p>` : ""}
      <button class="chunky ${v === "wrong" ? "b-pomegranate" : v === "almost" ? "b-gold" : "b-tkemali"}" data-act="next" data-id="lesson-continue">${esc(tr("Continue"))}</button></div>`;
  }
  if (!isGraded(ex)) return `<button class="chunky b-${P.tint}" data-act="next" data-id="lesson-continue">${esc(tr("Continue"))}</button>`;
  // Matching and flashcards answer themselves.
  if (ex.shape === "matching" || ex.shape === "flashcard") return "";
  const ready = canCheck();
  return `<button class="chunky b-${P.tint}" data-act="check" data-id="lesson-check"${ready ? "" : " disabled"}>${esc(tr("Check"))}</button>`;
}

function canCheck() {
  const p = P.pending;
  if (!p) return false;
  if ("text" in p) return !!p.text.trim();
  if ("tiles" in p) return p.tiles.length > 0;
  return true;
}

// Georgian prompt sizes, as on the iPhone: a letter is huge, a sentence smaller.
function kaSize(text) {
  const n = chars(text);
  return n <= 2 ? "k96" : n <= 8 ? "k48" : n <= 16 ? "k34" : "k26";
}

function promptBlock(ex) {
  const fb = P.phase === "feedback";
  if (ex.kind === "listening" && ex.audioText) {
    return `<div class="prompt-card listen">
      <button class="listen-big${audio.isPlaying(ex.audioText) ? " playing" : ""}" data-say="${esc(ex.audioText)}" aria-label="${esc(tr("Play again"))}">${icon("speaker", { size: 44 })}</button>
      <button class="slower" data-say-slow="${esc(ex.audioText)}">${esc(tr("Slower"))}</button>
      ${fb ? `<div class="ka k26">${esc(ex.audioText)}</div>` : ""}</div>`;
  }
  let main;
  if (ex.promptIsGeorgian) {
    // Hearing a letter or a word to read would give the answer away: only afterwards.
    const hear = !ex.prompt.includes("_") && (fb || !["letterRecognition", "reading"].includes(ex.kind));
    main = `<div class="ka prompt-ka ${kaSize(ex.prompt)}" data-id="prompt">${esc(ex.prompt)}</div>${hear ? speaker(ex.prompt, { size: 38, slow: true }) : ""}`;
  } else {
    main = `<div class="prompt-en${chars(ex.prompt) <= 6 ? " huge" : ""}" data-id="prompt">${esc(ex.prompt)}</div>`;
  }
  return `<div class="prompt-card">${main}${ex.promptDetail ? `<div class="prompt-detail">${esc(ex.promptDetail)}</div>` : ""}</div>`;
}

/** One answer to tap (OptionTile): big tiles in a 2×2 grid, or full-width rows. */
function optionTile(text, detail, i, { georgian, large, chosen, answer }) {
  const fb = P.phase === "feedback";
  let state = i === chosen ? "picked" : "";
  if (fb) state = i === answer ? "right" : i === chosen ? "wrong" : "dim";
  const showDetail = detail && (!large || (state && state !== "picked"));
  return `<button class="option${large ? " large" : ""}${georgian ? " ka-opt" : ""} ${state}" data-opt="${i}" data-id="option-${i}"${fb ? " disabled" : ""}${state === "picked" ? ' aria-pressed="true"' : ""}>
    <span class="${georgian ? "ka" : ""}">${esc(text)}</span>${showDetail ? `<small>${esc(detail)}</small>` : ""}</button>`;
}

function exerciseView(ex) {
  const fb = P.phase === "feedback";
  switch (ex.shape) {
    case "teachLetter": {
      const l = ex.letter;
      return `<div class="teach-letter">
        <div class="letter-tile" role="img" aria-label="${esc(tr("The letter {0}, written {1}", l.name, l.latin))}">${sun("letter-sun")}<span class="ka">${esc(l.char)}</span></div>
        <div class="pill-row"><span class="pill c-saperavi">${esc(tr("Name: {0}", l.name))}</span><span class="pill c-blacksea">${esc(tr("Written {0}", l.latin))}</span>${speaker(l.char, { size: 36, slow: true })}</div>
        <div class="card sound-card"><h3>${icon("lips", { size: 26 })}<span>${esc(tr("Sounds like {0}", l.sound))}</span></h3>${l.tip ? `<p>${tapProse(l.tip)}</p>` : ""}</div>
        <div class="card example-row"><span class="ka">${esc(l.word)}</span><div><strong>${esc(l.wordLatin)}</strong><span class="soft">${esc(l.meaning)}</span></div>${speaker(l.word, { size: 36, slow: true })}</div>
      </div>`;
    }
    case "teachWord": {
      const w = ex.word;
      const color = ((C.course.categories || []).find((c) => c.id === w.category) || {}).color || "saperavi";
      const hints = pronunciationHints(w.ka);
      const src = sourceLabel(w.ka);
      return `<div class="teach-word-ex">
        <div class="grad b-${color} word-hero"><div class="ka hero-word">${esc(w.ka)}</div><div class="hero-lat">${esc(w.lat)}</div><div class="hero-en">${esc(w.en)}</div>
          ${audio.canPlay(w.ka) ? `<div class="hero-play">${speaker(w.ka, { size: 40, slow: true, cls: "on-color" })}${src ? `<span class="pill on-pill">${icon("wave", { size: 14 })}${esc(src)}</span>` : ""}</div>` : ""}</div>
        ${hints.length || w.pron ? `<div class="card"><h3 class="card-title c-blacksea">${icon("wave", { size: 18 })}${esc(tr("Say it"))}</h3>${w.pron ? `<p>${esc(w.pron)}</p>` : ""}${hints.map((h) => `<p class="soft small-text">${esc(h)}</p>`).join("")}</div>` : ""}
        ${w.example ? exampleCard(w.example) : ""}
        ${w.note ? `<div class="card tip-card">${icon("bulb", { size: 18 })}<p>${tapProse(w.note)}</p></div>` : ""}
      </div>`;
    }
    case "note": {
      const n = ex.note;
      const tappable = /[ა-ჿ]{2,}/.test(n.text);
      return `<div class="card note-card"><h3>${esc(n.title)}</h3><p>${tapProse(n.text)}</p>
        ${tappable ? `<p class="hint">${icon("hand", { size: 14 })}${esc(tr("Tap a Georgian word to see what it means."))}</p>` : ""}
        ${(n.table || []).length ? `<div class="note-table">${n.table.map((g) => `<div class="nt-row"><div class="nt-ka"><span class="ka">${esc(g.ka)}</span><span class="lat">${esc(g.lat)}</span></div><span class="nt-en">${esc(g.en)}</span>${speaker(g.ka, { size: 30 })}</div>`).join("")}</div>` : ""}</div>`;
    }
    case "choice": {
      const chosen = P.pending ? P.pending.choice : null;
      const limit = ex.optionsAreGeorgian ? 6 : 10;
      const large = ex.options.length === 4 && ex.options.every((o) => chars(o.text) <= limit);
      return `<div class="choice-ex">${promptBlock(ex)}<div class="options${large ? " grid" : ""}">${ex.options.map((o, i) =>
        optionTile(o.text, o.detail, i, { georgian: ex.optionsAreGeorgian, large, chosen, answer: ex.answer })).join("")}</div></div>`;
    }
    case "dialogue": {
      const chosen = P.pending ? P.pending.choice : null;
      const lines = [...ex.history.slice(-4), ...(fb ? [ex.line] : [])];
      return `<div class="dialogue-ex"><div class="chat">${lines.map((l) => chatLine(l)).join("")}</div><hr>
        <div class="options">${ex.options.map((o, i) => optionTile(o, null, i, { georgian: true, large: false, chosen, answer: ex.answer })).join("")}</div></div>`;
    }
    case "typing": {
      const state = fb ? (P.ev.verdict === "wrong" ? " wrong" : " right") : "";
      return `<div class="prompt-card"><div class="ka prompt-ka ${chars(ex.prompt) <= 10 ? "k48" : "k34"}">${esc(ex.prompt)}</div><div class="prompt-lat">${esc(ex.promptLatin)}</div>${speaker(ex.prompt, { size: 38, slow: true })}</div>
        <input id="answer" class="answer-field${state}" data-id="answer-field" autocomplete="off" autocapitalize="off" spellcheck="false" enterkeyhint="done" placeholder="${esc(tr("Type in English"))}" value="${esc(P.pending ? P.pending.text : "")}"${fb ? " disabled" : ""}>`;
    }
    case "tiles": {
      const used = P.pending ? P.pending.tiles : [];
      const left = [...ex.bank];
      for (const t of used) { const k = left.indexOf(t); if (k >= 0) left[k] = null; }
      const sp = ex.isSpelling;
      const label = (t) => `<span class="${sp ? "ka" : "ka"}">${esc(t)}</span>${sp ? `<small>${esc(C.course.latin(t))}</small>` : ""}`;
      const state = fb ? (P.ev.verdict === "wrong" ? " wrong" : " right") : used.length ? " filled" : "";
      return `<div class="prompt-card"><div class="prompt-en">${esc(ex.prompt)}</div>${ex.promptDetail ? `<div class="prompt-detail strong">${esc(ex.promptDetail)}</div>` : ""}</div>
        <div class="tile-answer${sp ? " spelling" : ""}${state}" aria-label="${esc(tr("Your answer"))}">${used.map((t, i) => `<button class="tile${sp ? " spelling" : ""}" data-untile="${i}" data-id="answer-tile-${i}"${fb ? " disabled" : ""}>${label(t)}</button>`).join("")}</div>
        <div class="tile-bank${sp ? " spelling" : ""}">${ex.bank.map((t, i) => left[i] === null
          ? `<span class="tile${sp ? " spelling" : ""} used" aria-hidden="true">${label(t)}</span>`
          : `<button class="tile${sp ? " spelling" : ""}" data-tile="${i}" data-id="tile-${i}"${fb ? " disabled" : ""}>${label(t)}</button>`).join("")}</div>`;
    }
    case "matching": {
      if (!P.match) {
        P.match = { left: shuffle(ex.pairs), right: shuffle(ex.pairs), done: [], sel: null, selOther: null, mistakes: 0, flash: null };
      }
      const m = P.match;
      const cell = (p, side) => {
        const done = m.done.includes(p.id);
        const sel = side === "ka" ? m.sel === p.id : m.selOther === p.id;
        const flash = m.flash && m.flash.includes(`${side}:${p.id}`) ? " wrong" : "";
        const text = side === "ka" ? p.georgian : p.other;
        return `<button class="match ${side === "ka" ? `ka${chars(text) <= 2 ? " solo" : ""}` : ""}${done ? " done" : ""}${sel ? " picked" : ""}${flash}" data-match="${side}" data-pid="${esc(p.id)}" data-id="match-${side === "ka" ? "ka" : "other"}-${esc(p.id)}"${done ? " disabled" : ""}>${esc(text)}</button>`;
      };
      return `<div class="match-grid"><div>${m.left.map((p) => cell(p, "ka")).join("")}</div><div>${m.right.map((p) => cell(p, "other")).join("")}</div></div>`;
    }
    case "flashcard": {
      const face = P.flipped
        ? `<div class="flash-face flash-back b-tkemali"><div class="flash-en">${esc(ex.back)}</div><div class="ka flash-small">${esc(ex.front)}</div>${ex.note ? `<p>${esc(ex.note)}</p>` : ""}</div>`
        : `<div class="flash-face b-saperavi"><div class="ka flash-ka">${esc(ex.front)}</div><div class="flash-lat">${esc(ex.frontLatin)}</div>${speaker(ex.front, { size: 38, slow: true })}</div>`;
      const buttons = P.flipped
        ? (fb ? "" : `<div class="two"><button class="soft-button" data-act="recall" data-value="0" data-id="recall-no">${esc(tr("Still learning"))}</button><button class="chunky b-tkemali" data-act="recall" data-value="1" data-id="recall-yes">${esc(tr("I knew it"))}</button></div>`)
        : `<button class="soft-button" data-act="flip" data-id="flip">${esc(tr("Show the meaning"))}</button>`;
      return `<div class="flashcard-ex"><div class="flashcard${P.flipped ? " flipped" : ""}"${P.flipped ? "" : ` data-act="flip" role="button" tabindex="0" aria-label="${esc(tr("Shows the meaning"))}"`} data-id="flashcard">${face}</div>${buttons}</div>`;
    }
    default: return "";
  }
}

/** One line of a conversation (Bubble): the partner's initial, the line, its speakers. */
function chatLine(l) {
  return `<div class="chat-row${l.isLearner ? " mine" : ""}">
    ${l.isLearner ? "" : `<span class="chat-avatar" aria-hidden="true">${esc([...(l.speaker || "?")][0])}</span>`}
    <div class="chat-bubble"><span class="ka">${tapGeorgian(l.ka)}</span><small>${esc(l.en)}</small></div>
    ${speaker(l.ka, { size: 30, slow: true })}</div>`;
}

/** A word's example (ExampleCard). */
function exampleCard(e) {
  return `<div class="card example-card"><div class="ex-head"><small class="upper c-gold">${esc(tr("Example"))}</small>${speaker(e.ka, { size: 32, slow: true })}</div>
    <div class="ka ex-ka">${tapGeorgian(e.ka)}</div><div class="lat">${esc(e.lat)}</div><div>${esc(e.en)}</div></div>`;
}

/** The borjgali, Georgia's sun symbol (Borjgali.swift): seven curling arms round a centre. */
function sun(cls, colors = null) {
  const r = 50, arms = [];
  const pt = (rad, a) => `${(50 + Math.cos(a) * rad).toFixed(2)} ${(50 + Math.sin(a) * rad).toFixed(2)}`;
  for (let i = 0; i < 7; i++) {
    const a = (i / 7) * 2 * Math.PI;
    arms.push(`M${pt(r * 0.14, a)}Q${pt(r, a + 0.25)} ${pt(r * 0.92, a + 1.25)}Q${pt(r * 0.62, a + 1)} ${pt(r * 0.14, a + 0.62)}Z`);
  }
  const fill = colors
    ? `<defs><linearGradient id="sun-${cls}" x1="0" y1="0" x2="1" y2="1">${colors.map((c, i) => `<stop offset="${i / (colors.length - 1)}" stop-color="${c}"/>`).join("")}</linearGradient></defs>`
    : "";
  return `<svg class="sun-svg ${cls}" viewBox="0 0 100 100" aria-hidden="true">${fill}<path fill="${colors ? `url(#sun-${cls})` : "currentColor"}" d="${arms.join("")}M59 50a9 9 0 1 1-18 0a9 9 0 1 1 18 0Z"/></svg>`;
}

function itemIDsFor(ex, ev) {
  if (ex.itemID) return [ex.itemID];
  if (ex.shape === "matching" && ev.verdict !== "wrong") return ex.pairs.map((p) => p.id);
  return [];
}

function check(answer) {
  const ex = P.session.current;
  const a = answer || P.pending;
  if (!ex || !a || P.phase !== "answering") return;
  const ev = evaluate(ex, a);
  const given = a.choice != null ? (ex.options[a.choice] || {}).text || ex.options[a.choice] : a.text ?? (a.tiles ? a.tiles.join(ex.joiner) : "");
  P.session.record(ev, given);
  P.given = given;
  store.record(ex, ev, { itemIDs: itemIDsFor(ex, ev), inReview: P.mode !== "lesson" });
  P.ev = ev;
  P.phase = "feedback";
  P.combo = ev.verdict === "wrong" ? 0 : P.combo + 1;
  P.praise = PRAISE()[Math.floor(Math.random() * 6)];
  if (navigator.vibrate) navigator.vibrate(ev.verdict === "wrong" ? [20, 40, 20] : 15);
}

function next() {
  P.session.advance();
  P.pending = null; P.ev = null; P.match = null; P.flipped = false;
  if (P.session.finished) {
    const summary = P.session.summary;
    const before = new Set(milestones().filter((m) => m[4] >= 1).map((m) => m[0]));
    const xpBefore = (store.days()[dayKey()] || {}).xp || 0;
    P.goalReachedNow = false;
    P.newMilestones = [];
    if (P.mode === "lesson") store.finishLesson(P.lesson.id, summary); else store.finishReview(summary);
    P.summary = summary;
    P.newMilestones = milestones().filter((m) => m[4] >= 1 && !before.has(m[0]));
    P.goalReachedNow = xpBefore < goal() && ((store.days()[dayKey()] || {}).xp || 0) >= goal();
    P.phase = "finished";
  } else {
    P.phase = "answering";
    autoplay();
  }
}

export function autoplay() {
  if (!P || P.phase !== "answering") return;
  const ex = P.session.current;
  if (!ex) return;
  const t = ex.audioText || (ex.shape === "teachLetter" ? ex.letter.char : ex.shape === "teachWord" ? ex.word.ka : null);
  // Sound plays only when the learner taps a speaker (owner, KART #9).
  void t;
}

function completeScreen() {
  const s = P.summary;
  const lesson = P.mode === "lesson" ? P.lesson : null;
  const title = s.perfect ? tr("Flawless!") : lesson ? tr("Lesson complete!") : tr("Review complete!");
  const next = lesson ? nextLesson() : null;
  const tile = (ic, value, label, color) => `<div class="stat-tile c-${color}">${icon(ic, { size: 22 })}<b>${value}</b><small>${esc(label)}</small></div>`;
  return `<div class="player complete tint-tkemali" data-screen="complete">
    <div class="complete-body">
      <div class="confetti">${Array.from({ length: 18 }, (_, i) => `<i style="--i:${i}"></i>`).join("")}</div>
      <div class="reward-hero" aria-hidden="true">${sun("reward-sun", ["#F5A623", "#E23B4E", "#7A3BC2", "#F5A623"])}<img src="icons/mascot-cheer.svg" alt="" class="reward-parrot">${s.perfect ? `<span class="crown">${icon("crown", { size: 40 })}</span>` : ""}</div>
      <div class="reward-title" data-id="lesson-complete"><h1 class="display">${esc(title)}</h1><p class="soft strong">${esc(lesson ? lesson.title : P.title)}</p><p class="faint">${esc(tr("ყოჩაღ! (well done!)"))}</p></div>
      <div class="stat-tiles">
        ${tile("target", `${Math.round(s.accuracy * 100)}%`, tr("Accuracy"), "tkemali")}
        ${tile("book", learnedCount(false), tr("Words you know"), "saperavi")}
        ${tile("flame", streak(activeDays()), tr("Day streak"), "flame")}
      </div>
      ${goalCard()}
      ${P.newMilestones.map(([t, d, ic, color]) => `<div class="card milestone-new"><span class="badge-core grad b-${color}">${icon(ic, { size: 22 })}</span><div><small class="upper c-tkemali">${esc(tr("Milestone reached"))}</small><strong>${esc(tr(t))}</strong><small class="soft">${esc(tr(d))}</small></div></div>`).join("")}
      ${next && lesson ? `<div class="card next-up"><small class="soft">${esc(tr("Next:"))}</small><strong>${esc(next.title)}</strong></div>` : ""}
    </div>
    <div class="player-bottom">
      ${next && lesson ? `<a class="chunky b-tkemali" href="#/lesson/${next.id}" data-act="replace" data-id="complete-next">${icon("play", { size: 18 })}${esc(tr("Start lesson"))}</a>` : ""}
      <button class="${next && lesson ? "soft-button" : "chunky b-tkemali"}" data-act="done" data-id="complete-continue">${esc(tr("Continue"))}</button>
    </div>
  </div>`;
}

/** The daily goal as a ring (ProgressRing), as on the iPhone. */
function goalCard() {
  const xp = (store.days()[dayKey()] || {}).xp || 0;
  const p = Math.min(1, xp / goal());
  const c = 2 * Math.PI * 27;
  return `<div class="card goal-card">
    <span class="goal-ring" aria-hidden="true"><svg class="ring-svg" viewBox="0 0 64 64"><circle cx="32" cy="32" r="27" class="ring-track"/><circle cx="32" cy="32" r="27" class="ring-fill" stroke-dasharray="${c.toFixed(1)}" stroke-dashoffset="${(c * (1 - p)).toFixed(1)}"/></svg>${icon(p >= 1 ? "check" : "target", { size: 20, cls: p >= 1 ? "c-tkemali" : "c-gold" })}</span>
    <div><strong>${esc(p >= 1 ? (P.goalReachedNow ? tr("Daily goal reached!") : tr("Daily goal done")) : tr("Daily goal"))}</strong>
    <span class="soft">${esc(p >= 1 ? tr("Done for today. ყოჩაღ!") : tr("{0}% of today's goal", Math.round(p * 100)))}</span></div></div>`;
}

/** Taps inside the player. Returns true when handled. */
export function playerTap(el) {
  if (!P) return false;
  const ds = el.dataset;
  const ex = P.session.current;
  if (ds.opt !== undefined && P.phase === "answering") { P.pending = { choice: +ds.opt }; render({ keepScroll: true }); return true; }
  if (ds.tile !== undefined && P.phase === "answering") {
    const tiles = P.pending ? [...P.pending.tiles] : [];
    tiles.push(ex.bank[+ds.tile]);
    P.pending = { tiles };
    render({ keepScroll: true });
    return true;
  }
  if (ds.untile !== undefined && P.phase === "answering") {
    const tiles = [...P.pending.tiles]; tiles.splice(+ds.untile, 1);
    P.pending = tiles.length ? { tiles } : null;
    render({ keepScroll: true });
    return true;
  }
  if (ds.match) { matchTap(ds.match, ds.pid); return true; }
  switch (ds.act) {
    case "check": check(); render({ keepScroll: true }); return true;
    case "next": next(); render(); return true;
    case "flip": P.flipped = true; render({ keepScroll: true }); return true;
    case "recall": check({ recalled: ds.value === "1" }); render({ keepScroll: true }); return true;
    case "pass": {
      if (P.phase === "feedback") { next(); render(); return true; }
      if (isGraded(ex)) { const right = { verdict: "correct", correct: "", explanation: null }; P.session.record(right, ""); store.record(ex, right, { itemIDs: itemIDsFor(ex, right), inReview: P.mode !== "lesson" }); }
      next(); render();
      return true;
    }
    case "quit":
      if (P.phase === "finished" || confirm(`${tr("Leave this lesson?")}\n${tr("Your answers so far are saved, but the lesson won't count as finished.")}`)) { P = null; audio.stop(); goBack(); }
      return true;
    case "done": P = null; goBack(); return true;
    case "replace": P = null; return false;
    default: return false;
  }
}

function matchTap(side, id) {
  const m = P.match;
  if (side === "ka") m.sel = m.sel === id ? null : id; else m.selOther = m.selOther === id ? null : id;
  if (m.sel && m.selOther) {
    if (m.sel === m.selOther) { m.done.push(m.sel); m.flash = null; }
    else { m.mistakes += 1; m.flash = [`ka:${m.sel}`, `other:${m.selOther}`]; if (navigator.vibrate) navigator.vibrate(30); }
    m.sel = null; m.selOther = null;
  }
  if (m.done.length === P.session.current.pairs.length) check({ mistakes: m.mistakes });
  render({ keepScroll: true });
}

export function playerInput(e) {
  if (!P || e.target.id !== "answer") return false;
  P.pending = { text: e.target.value };
  const btn = $('[data-act="check"]');
  if (btn) btn.disabled = !canCheck();
  return true;
}
export function playerKey(e) {
  if (!P || e.key !== "Enter") return false;
  if (P.phase === "answering" && canCheck()) { check(); render({ keepScroll: true }); return true; }
  if (P.phase === "feedback" || (P.phase === "answering" && !isGraded(P.session.current))) { next(); render(); return true; }
  return false;
}

// ---------------------------------------------------------------------------------------
// Review (ReviewView.swift)

export function reviewScreen() {
  const due = dueItems();
  const practice = due.length ? due : weakest();
  const lettersMet = Object.keys(store.mastery()).filter((id) => id.startsWith("letter-")).length;
  const hard = difficult();
  return `<div class="screen" data-screen="review">
    <header class="page-head compact"><h1 class="display">${esc(tr("Review"))}</h1></header>
    <div class="grad b-${due.length ? "blacksea" : "tkemali"} review-hero">
      <small class="upper">${esc(due.length ? tr("Due today") : tr("All caught up"))}</small>
      <div class="rh-count">${esc(due.length ? plural(due.length, "item", "items", ["powtórka", "powtórki", "powtórek"]) : tr("Nothing due"))}</div>
      <p>${esc(due.length ? tr("Review now, before they slip away.") : practice.length ? tr("Practise your weakest words anyway.") : tr("Finish a lesson and its words come back here at the right time."))}</p>
      ${practice.length ? `<a class="chunky b-gold" href="#/session/review" data-id="start-review">${icon("play", { size: 18 })}${esc(due.length ? tr("Start review") : tr("Practise"))}</a>` : ""}
    </div>
    <a class="card letter-workout" href="#/session/letters"><span class="lw-icon ka">ა</span><span><strong>${esc(tr("Letter workout"))}</strong>
      <small class="soft">${esc(lettersMet ? tr("{0} letters met. Keep them sharp.", lettersMet) : tr("Meet your first letters in Learn."))}</small></span>${icon("play", { size: 18, cls: "c-pomegranate" })}</a>
    ${hard.length ? `<div class="section-row"><h2 class="section-title">${esc(tr("Difficult"))}</h2><a class="more-link" href="#/session/difficult">${esc(tr("Practise"))}</a></div>
      <div class="rows">${hard.slice(0, 8).map((it) => `<div class="word-row"><div><span class="ka row-ka">${esc(it.ka)}</span><span class="lat">${esc(it.lat)}</span><span class="row-en">${esc(it.en)}</span></div>${icon("alert", { size: 18, cls: "c-error" })}</div>`).join("")}</div>` : ""}
    <section class="card"><h3 class="card-title c-blacksea">${icon("info", { size: 18 })}${esc(tr("How review works"))}</h3>
      <p class="soft">${esc(tr("Every word and letter has its own schedule. Get it right and it comes back later each time: tomorrow, in three days, then weeks. Miss it and it comes back soon. A few minutes a day keeps everything you've learned."))}</p></section>
  </div>`;
}

// ---------------------------------------------------------------------------------------
// A word's card (WordsView.swift / VocabularyView.swift)

export function wordScreen(id) {
  const w = C.course.word(id);
  if (!w) return null;
  const m = store.mastery()[id];
  const cat = C.course.categories.find((c) => c.id === w.category);
  const color = (cat && cat.color) || "saperavi";
  const rel = (t) => new Intl.RelativeTimeFormat(lang === "pl" ? "pl" : "en", { numeric: "auto" }).format(Math.round((t - Date.now()) / 86400000), "day");
  return `<div class="screen tint-${color}">
    ${topBar((cat && cat.title) || tr("Words"))}
    <section class="grad phrase-hero b-${color}"><div class="ka hero-phrase">${esc(w.ka)}</div><div class="hero-lat">${esc(w.lat)}</div><div class="hero-en">${esc(w.en)}</div>
      ${audio.canPlay(w.ka) ? `<div class="hero-play">${speaker(w.ka, { size: 52, cls: "on-color" })}<button class="speaker on-color soft" style="--s:40px" data-say-slow="${esc(w.ka)}" aria-label="${esc(tr("Play slowly"))}">${icon("slow", { size: 20 })}</button></div>` : ""}</section>
    ${w.example ? `<section class="card"><h3 class="card-title c-saperavi">${icon("bubble", { size: 18 })}${esc(tr("Example"))}</h3>
      <div class="form-row"><div><div class="ka form-ka">${tapGeorgian(w.example.ka)}</div><div class="lat">${esc(w.example.lat)}</div><div>${esc(w.example.en)}</div></div>${speaker(w.example.ka, { size: 36 })}</div></section>` : ""}
    ${w.note ? `<section class="card"><h3 class="card-title c-gold">${icon("bulb", { size: 18 })}${esc(tr("When to use it"))}</h3><p>${tapProse(w.note)}</p></section>` : ""}
    <section class="card"><h3 class="card-title c-blacksea">${icon("review", { size: 18 })}${esc(tr("Review"))}</h3>
      <p class="soft">${esc(m ? tr("Right {0} times, missed {1}. Next review {2}.", m.right, m.wrong, rel(m.due)) : tr("Not practised yet."))}</p>
      <a class="chunky b-blacksea" href="#/session/word:${esc(id)}">${icon("play", { size: 18 })}${esc(tr("Practise this word"))}</a></section>
    ${reportLink({ title: tr("the word {0}", w.ka), lines: [w.ka, w.lat, w.en, w.example ? `${w.example.ka} — ${w.example.en}` : ""].filter(Boolean), id })}
  </div>`;
}

// ---------------------------------------------------------------------------------------
// Progress (ProgressScreen.swift): the stage, what you know, the course, activity.

export function progressScreen() {
  const st = stage();
  const nextSt = stages()[st.id + 1];
  const days = store.days();
  const fmt = new Intl.DateTimeFormat(lang === "pl" ? "pl-PL" : "en-GB", { weekday: "short" });
  const week = [];
  for (let k = 6; k >= 0; k--) { const d = new Date(); d.setDate(d.getDate() - k); week.push([fmt.format(d), (days[dayKey(d)] || {}).answers || 0]); }
  const max = Math.max(1, ...week.map((w) => w[1]));
  const total = Object.values(days).reduce((a, d) => a + (d.answers || 0), 0);
  return `<div class="screen tint-saperavi">
    ${topBar(tr("Your progress"))}
    <section class="grad b-saperavi stage-card"><span class="stage-big">${st.emoji}</span><small class="upper">${esc(tr("Your level"))}</small>
      <div class="hero-title">${esc(st.name)}</div><p><b>${esc(st.canDo)}</b></p><p>${esc(st.story)}</p>
      ${nextSt ? `<p class="next-stage">${esc(tr("Next:"))} ${nextSt.emoji} ${esc(nextSt.name)}</p>` : ""}
      <small class="faint-on">${esc(tr("Not an official exam level: it shows how far you are in Ara's course."))}</small></section>
    <div class="stats four">
      <div class="stat c-saperavi">${icon("map", { size: 20 })}<b>${store.completed().size}</b><small>${esc(tr("Lessons finished"))}</small></div>
      <div class="stat c-tkemali">${icon("book", { size: 20 })}<b>${learnedCount(false)}</b><small>${esc(tr("words learned"))}</small></div>
      <div class="stat c-pomegranate">${icon("letters", { size: 20 })}<b>${learnedCount(true)}</b><small>${esc(tr("letters learned"))}</small></div>
      <div class="stat c-flame">${icon("flame", { size: 20 })}<b>${streak(activeDays())}</b><small>${esc(tr("Day streak"))}</small></div>
    </div>
    ${sectionTitle(tr("Modules"))}
    <div class="rows">${C.course.modules.map((m) => `<div class="card module-row"><span class="mr-icon grad b-${m.color}">${icon(MODULE_ICON[m.symbol] || "book", { size: 20 })}</span>
      <div><strong>${esc(m.title)}</strong>${bar(doneIn(m) / m.lessons.length, `b-${m.color}`)}<small class="soft">${doneIn(m)}/${m.lessons.length}</small></div></div>`).join("")}</div>
    ${milestonesCard()}
    ${sectionTitle(tr("Activity"))}
    <section class="card"><div class="chart">${week.map(([d, n]) => `<div class="col"><span style="height:${Math.round((n / max) * 100)}%"></span><small>${esc(d)}</small></div>`).join("")}</div>
      <p class="soft small">${esc(tr("{0} answers · {1} active days", total, activeDays().size))}</p></section>
  </div>`;
}

// Milestones (Achievement in Gamification.swift): what's reached, and how far towards the rest.
function longestStreak(days) {
  const keys = [...days].sort();
  let best = 0, run = 0, prev = null;
  for (const k of keys) {
    const d = new Date(`${k}T12:00:00`);
    run = prev && Math.round((d - prev) / 86400000) === 1 ? run + 1 : 1;
    best = Math.max(best, run);
    prev = d;
  }
  return best;
}

export function milestones() {
  const days = Object.values(store.days());
  const done = store.completed();
  const mods = modulesDone();
  const longest = longestStreak(activeDays());
  const perfect = days.reduce((a, d) => a + (d.perfect || 0), 0);
  const reviews = days.reduce((a, d) => a + (d.reviews || 0), 0);
  const goalDays = days.filter((d) => (d.xp || 0) >= goal()).length;
  const words = learnedCount(false), letters = learnedCount(true);
  const r = (v, t) => Math.min(1, v / t);
  return [
    ["First steps", "Finish your first lesson", "walk", "tkemali", r(done.size, 1)],
    ["Ten letters", "Learn 10 letters", "letters", "blacksea", r(letters, 10)],
    ["ანბანი", "Finish the whole alphabet module", "book", "pomegranate", mods.has("alphabet") ? 1 : 0],
    ["Flawless", "Finish a lesson without a mistake", "star", "gold", r(perfect, 1)],
    ["On a roll", "Learn 3 days in a row", "flame", "pomegranate", r(longest, 3)],
    ["One week", "Learn 7 days in a row", "flame", "gold", r(longest, 7)],
    ["A month of Georgian", "Learn 30 days in a row", "flame", "saperavi", r(longest, 30)],
    ["Word collector", "Learn 25 words", "book", "tkemali", r(words, 25)],
    ["Wordsmith", "Learn 100 words", "book", "saperavi", r(words, 100)],
    ["Count to a hundred", "Finish How numbers are built", "grid", "gold", done.has("v6c") ? 1 : 0],
    ["Order in a café", "Finish the café conversation", "cup", "pomegranate", done.has("c1") ? 1 : 0],
    ["Your own sentences", "Finish the Grammar module", "puzzle", "blacksea", mods.has("grammar") ? 1 : 0],
    ["Goal getter", "Reach your daily goal on 7 days", "target", "blacksea", r(goalDays, 7)],
    ["Never forget", "Finish 10 review sessions", "review", "saperavi", r(reviews, 10)],
    ["Ready for Tbilisi", "Finish Everyday Georgian", "map", "gold", mods.has("everyday") ? 1 : 0],
    ["Chatterbox", "Finish every conversation", "bubbles", "tkemali", mods.has("conversation") ? 1 : 0],
  ];
}

function milestonesCard() {
  const all = milestones();
  const got = all.filter((m) => m[4] >= 1).length;
  return `<section class="card"><div class="section-row"><h2 class="section-title">${esc(tr("Milestones"))}</h2><small class="soft">${got}/${all.length}</small></div>
    <div class="badges">${all.map(([t, d, ic, color, p]) => `<div class="badge${p >= 1 ? " on" : ""}" title="${esc(tr(d))}">
      <span class="badge-ring b-${color}" style="--p:${Math.round(p * 100)}"><span class="badge-core${p >= 1 ? ` grad b-${color}` : ""}">${icon(ic, { size: 24 })}</span></span>
      <strong>${esc(tr(t))}</strong><small>${esc(tr(d))}</small></div>`).join("")}</div></section>`;
}

// ---------------------------------------------------------------------------------------
// Profile cards for Settings (ProfileView.swift)

export function profileCards() {
  const p = store.profile();
  return `<section class="card">
      <h3 class="card-title c-pomegranate">${icon("people", { size: 18 })}${esc(tr("Profile"))}</h3>
      <label class="field"><span>${esc(tr("Your name"))}</span><input id="profile-name" class="text-input" maxlength="30" value="${esc(p.name || "")}" placeholder="${esc(tr("Your name"))}"></label>
      <label class="field"><span>${esc(tr("Starting point"))}</span><select id="profile-level" class="text-input">${LEVELS().map(([v, t]) => `<option value="${v}"${v === level() ? " selected" : ""}>${esc(t)}</option>`).join("")}</select></label>
      <label class="field"><span>${esc(tr("Daily goal"))}</span><select id="profile-goal" class="text-input">${GOALS().map(([v, t]) => `<option value="${v}"${v === goal() ? " selected" : ""}>${esc(t)}</option>`).join("")}</select>
        <small class="field-note">${esc((GOALS().find(([v]) => v === goal()) || [])[2] || "")}</small></label>
    </section>`;
}

export function dangerCards() {
  return `<section class="card">
      <h3 class="card-title c-saperavi">${icon("sliders", { size: 18 })}${esc(tr("Developer"))}</h3>
      <label class="switch-row"><span>${esc(tr("Developer mode"))}</span><input type="checkbox" data-dev="devMode"${store.setting("devMode") ? " checked" : ""}></label>
      ${store.setting("devMode") ? `<label class="switch-row"><span>${esc(tr("Open all lessons"))}<small class="soft">${esc(tr("Every lesson can be opened, whatever you've finished."))}</small></span><input type="checkbox" data-dev="devOpenAll"${store.setting("devOpenAll") ? " checked" : ""}></label>
      <label class="switch-row"><span>${esc(tr("Quick pass in lessons"))}<small class="soft">${esc(tr("A Pass button at the top of a lesson: tap it to count the exercise as right, hold it to finish the lesson."))}</small></span><input type="checkbox" data-dev="devQuickPass"${store.setting("devQuickPass") ? " checked" : ""}></label>` : `<p class="soft small">${esc(tr("Off: the app works as it does for everyone."))}</p>`}
    </section>
    <section class="card"><button class="soft-button danger" data-act="reset">${icon("trash", { size: 18 })}${esc(tr("Start over"))}</button></section>`;
}

/** Changes in the welcome steps and Settings. Returns true when handled. */
export function courseTap(el) {
  const ds = el.dataset;
  if (ds.ob !== undefined) {
    const n = +ds.ob;
    const name = $("#ob-name");
    if (name) draft.name = name.value;
    audio.stop();
    if (n < 0) return true;
    location.replace(`#/welcome/${n}`);
    return true;
  }
  if (ds.draft) { draft[ds.draft] = ds.draft === "goal" ? +ds.value : ds.value; render({ keepScroll: true }); return true; }
  switch (ds.act) {
    case "ob-phrases": draft = draft || { level: "beginner", goal: 20, name: "" }; finishWelcome(false); location.replace("#/phrasebook"); return true;
    case "ob-start": finishWelcome(true); return true;
    case "ob-explore": finishWelcome(false); return true;
    case "reset":
      if (confirm(`${tr("Delete all progress?")}\n${tr("Your lessons, words and streak will be gone. This can't be undone.")}`)) { store.resetAll(); location.replace("#/welcome/0"); }
      return true;
    default: break;
  }
  if (ds.lesson) return "lesson";
  return false;
}

export function courseChange(e) {
  const t = e.target;
  if (t.id === "profile-name") { store.setProfile({ name: t.value.trim() }); return true; }
  if (t.id === "profile-level") { store.setProfile({ level: t.value }); toast(tr("Saved")); return true; }
  if (t.id === "profile-goal") { store.setProfile({ goal: +t.value }); const n = t.parentElement.querySelector(".field-note"); if (n) n.textContent = (GOALS().find(([v]) => v === +t.value) || [])[2] || ""; toast(tr("Saved")); return true; }
  if (t.dataset && t.dataset.dev) { store.setSetting(t.dataset.dev, t.checked); render({ keepScroll: true }); return true; }
  if (t.id === "ob-name") { draft.name = t.value; const b = $('[data-id="onboarding-next"]'); if (b) b.textContent = t.value.trim() ? tr("Continue") : tr("Skip"); return true; }
  return false;
}

export { applySetting };
