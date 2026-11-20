// Ara on the web: the phrasebook half of the app (Use in Georgia), for any phone or computer.
// One page; the address after # says which screen is open, so Back works and screens can be
// linked. Everything the learner keeps stays in this browser (store.js).
//
// Screens (web/README.md has the full list):
//   #/            Phrasebook: search, emergencies, my phrasebook, situations, conversations
//   #/c/<id>      a situation        #/p/<id>     a phrase card     #/show/<id>  Show mode
//   #/d/<id>      a conversation     #/d/<id>/as/<0|1>  playing one side of it
//   #/search      search             #/saved      my phrasebook     #/settings   settings

import { tr, plural, setLanguage, preferredLanguage, lang } from "./i18n.js";
import { PhraseSearch } from "./search.js";
import * as audio from "./audio.js";
import * as store from "./store.js";
import { icon } from "./icons.js";
import { Course } from "./engine.js";
import * as course from "./course.js";

const PRIVACY_URL = "https://aralearn.github.io/privacy";
const HOME_URL = "https://aralearn.github.io";

// ---------------------------------------------------------------------------------------
// Content

const C = {
  pb: null, glossary: {}, letters: new Map(), words: [], wordCats: [], wordByID: new Map(), lessons: {},
  phraseByID: new Map(), catByID: new Map(), dialogueByID: new Map(), search: null, uiPl: null,
};

async function json(path) {
  const res = await fetch(path);
  if (!res.ok) throw new Error(`${path}: ${res.status}`);
  return res.json();
}

async function loadContent(code) {
  const sfx = code === "pl" ? "-pl" : "";
  if (code === "pl" && !C.uiPl) C.uiPl = await json("data/ui-pl.json");
  const [pb, glossary, letters, vocab, courseFile] = await Promise.all([
    json(`data/phrasebook${sfx}.json`), json(`data/glossary${sfx}.json`), json(`data/letters${sfx}.json`),
    json(`data/vocabulary${sfx}.json`), json(`data/course${sfx}.json`),
  ]);
  const words = { words: [...vocab.words, ...(vocab.more || [])], categories: vocab.categories };
  const lessons = Object.fromEntries(courseFile.modules.flatMap((m) => m.lessons).map((l) => [l.id, l.title]));
  C.course = new Course({ course: courseFile, letters, vocabulary: vocab, phrasebook: pb });
  setLanguage(code, C.uiPl);
  C.pb = pb;
  C.glossary = glossary.words || {};
  C.letters = new Map(letters.letters.map((l) => [l.char, l]));
  C.words = words.words;
  C.wordCats = words.categories;
  C.wordByID = new Map(words.words.map((w) => [w.id, w]));
  C.lessons = lessons;
  C.phraseByID = new Map(pb.phrases.map((p) => [p.id, p]));
  C.catByID = new Map(pb.categories.map((c) => [c.id, c]));
  C.dialogueByID = new Map(pb.dialogues.map((d) => [d.id, d]));
  C.search = new PhraseSearch(pb, words.words, words.categories, code);
}

const phrasesIn = (cat, sub) => C.pb.phrases.filter((p) => p.category === cat && (!sub || p.sub === sub));
const dialoguesIn = (cat) => C.pb.dialogues.filter((d) => d.category === cat);
const brandOf = (p) => (p.urgent ? "pomegranate" : (C.catByID.get(p.category) || {}).color || "saperavi");

// ---------------------------------------------------------------------------------------
// Small helpers

const esc = (s) => String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);
const $ = (sel, root = document) => root.querySelector(sel);
const view = () => $("#view");

/** A speaker button for Georgian text; nothing without a clip. */
function speaker(text, { size = 40, cls = "" } = {}) {
  if (!audio.canPlay(text)) return "";
  const on = audio.isPlaying(text) ? " playing" : "";
  return `<button class="speaker ${cls}${on}" style="--s:${size}px" data-say="${esc(text)}" aria-label="${esc(tr("Play"))}">${icon("speaker", { size: Math.round(size * 0.48) })}</button>`;
}

function sourceLabel(text) {
  const s = audio.source(text);
  if (!s) return "";
  return s === "native" ? tr("Native recording") : tr("Synthetic voice");
}

let toastTimer = null;
function toast(text) {
  const t = $("#toast");
  t.innerHTML = `${icon("check", { size: 18 })}<span>${esc(text)}</span>`;
  t.classList.add("on");
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => t.classList.remove("on"), 1700);
}

function checkNote() {
  const text = C.pb.checkedBy === "native"
    ? tr("Phrases checked by a native Georgian speaker. Audio: {0}, a synthetic voice.", audio.voiceName())
    : tr("Phrases in natural everyday Georgian, prepared with the help of AI. A native speaker's check is still to come. Audio: {0}, a synthetic voice.", audio.voiceName());
  return `<p class="check-note">${icon("shield", { size: 16 })}<span>${esc(text)}</span></p>`;
}

function topBar(title, { tint = "" } = {}) {
  return `<header class="topbar ${tint}">
    <button class="back" data-back aria-label="${esc(tr("Back"))}">${icon("chevronLeft", { size: 22 })}</button>
    <h1 class="topbar-title">${esc(title)}</h1><span class="topbar-gap"></span></header>`;
}

function sectionTitle(title) { return `<h2 class="section-title">${esc(title)}</h2>`; }

// ---------------------------------------------------------------------------------------
// Pieces shared by several screens

function phraseRow(p, { showsCategory = false, menu = false } = {}) {
  const b = brandOf(p);
  const c = C.catByID.get(p.category);
  return `<div class="phrase-row b-${b}${p.urgent ? " urgent" : ""}">
    <a class="phrase-main" href="#/p/${esc(p.id)}" data-id="phrase-${esc(p.id)}">
      ${showsCategory && c ? `<span class="row-cat">${icon(c.symbol, { size: 13 })}${esc(c.title)}</span>` : ""}
      <span class="ka row-ka">${esc(p.ka)}</span>
      <span class="lat">${esc(p.lat)}</span>
      <span class="row-en">${esc(p.en)}</span>
    </a>
    <div class="row-buttons">
      ${speaker(p.ka, { size: 38 })}
      <a class="round-soft" href="#/show/${esc(p.id)}" aria-label="${esc(tr("Show to someone"))}">${icon("show", { size: 17 })}</a>
      ${menu ? `<button class="round-soft plain" data-menu="${esc(p.id)}" aria-label="${esc(tr("More"))}">⋯</button>` : ""}
    </div>
    ${store.isSaved(p.id) && !menu ? `<span class="saved-star" aria-label="${esc(tr("Saved"))}">${icon("star", { size: 11, filled: true })}</span>` : ""}
  </div>`;
}

function categoryTile(c) {
  const n = phrasesIn(c.id).length;
  return `<a class="cat-tile grad b-${c.color}" href="#/c/${esc(c.id)}" data-id="category-${esc(c.id)}">
    <span class="tile-icon">${icon(c.symbol, { size: 24 })}</span>
    <span class="tile-title">${esc(c.title)}</span>
    <span class="tile-ka ka">${esc(c.ka)}</span>
    <span class="tile-count">${esc(tr("{0} phrases", n))}</span>
  </a>`;
}

function dialogueCard(d) {
  const c = C.catByID.get(d.category);
  const b = (c && c.color) || "saperavi";
  const initial = (s) => esc([...(s || "?")][0]);
  return `<a class="dialogue-card b-${b}" href="#/d/${esc(d.id)}" data-id="dialogue-${esc(d.id)}">
    <span class="avatars"><span class="avatar a1">${initial(d.roles[0])}</span><span class="avatar a2">${initial(d.roles[1])}</span></span>
    <span class="dc-title">${esc(d.title)}</span>
    <span class="dc-roles">${esc(d.roles.join(" & "))}</span>
    <span class="dc-lines">${esc(tr("{0} lines", d.lines.length))}</span>
  </a>`;
}

function miniCard(p) {
  const b = brandOf(p);
  return `<div class="mini-card b-${b}">
    <a href="#/p/${esc(p.id)}" class="mini-main"><span class="ka mini-ka">${esc(p.ka)}</span><span class="mini-en">${esc(p.en)}</span></a>
    <div class="mini-buttons">${speaker(p.ka, { size: 32 })}<a class="round-soft small" href="#/show/${esc(p.id)}" aria-label="${esc(tr("Show to someone"))}">${icon("show", { size: 15 })}</a></div>
  </div>`;
}

function emergencyStrip() {
  return `<div class="emergency">
    <a class="emergency-open" href="#/c/emergency" data-id="emergency-open">
      <span class="em-icon">${icon("alert", { size: 22 })}</span>
      <span><strong>${esc(tr("Emergency phrases"))}</strong><small>${esc(tr("Help, police, accidents, lost"))}</small></span>
    </a>
    <a class="call-112" href="tel:112" aria-label="${esc(tr("Call 112, the emergency number"))}">${icon("phone", { size: 16 })}<b>112</b></a>
  </div>`;
}

// ---------------------------------------------------------------------------------------
// Screens

function homeScreen() {
  const saved = store.savedIDs().filter((id) => C.phraseByID.has(id));
  const recent = store.recent().map((id) => C.phraseByID.get(id)).filter(Boolean);
  const learned = saved.filter((id) => store.isLearned(id)).length;
  return `<div class="screen" data-screen="phrasebook">
    <header class="page-head">
      <div class="ka head-ka">საქართველოში</div>
      <h1 class="display">${esc(tr("Use in Georgia"))}</h1>
      <p class="lead">${esc(tr("The right words for everyday situations, ready when you need them."))}</p>
    </header>
    <a class="search-bar" href="#/search" data-id="search-bar">${icon("search", { size: 20 })}<span>${esc(tr("Search: taxi, water, pharmacy…"))}</span></a>
    ${emergencyStrip()}
    <a class="card my-card" href="#/saved" data-id="my-phrasebook">
      <span class="my-icon">${icon("star", { size: 24, filled: true })}</span>
      <span class="my-text"><strong>${esc(tr("My phrasebook"))}</strong>
        <small>${esc(saved.length ? tr("{0} saved · {1} learned", saved.length, learned) : tr("Tap ☆ on any phrase to keep it here."))}</small></span>
      ${icon("chevronRight", { size: 18, cls: "faint" })}
    </a>
    ${recent.length ? `${sectionTitle(tr("Recently used"))}<div class="carousel">${recent.map(miniCard).join("")}</div>` : ""}
    ${sectionTitle(tr("Situations"))}
    <div class="tile-grid">${C.pb.categories.filter((c) => c.id !== "emergency").map(categoryTile).join("")}</div>
    ${sectionTitle(tr("Conversations"))}
    <p class="soft">${esc(tr("Real everyday exchanges. Read them, listen, then play either side."))}</p>
    <div class="carousel">${C.pb.dialogues.map(dialogueCard).join("")}</div>
    ${installHint()}
    ${checkNote()}
  </div>`;
}


// Words: every word, with search over everything (words, phrases, situations, conversations).
let wordsQuery = "";
let wordsMore = false;

function wordsTab() {
  const cats = C.wordCats.filter((c) => c.id !== "more");
  const more = C.words.filter((w) => w.category === "more");
  return `<div class="screen" data-screen="words">
    <header class="page-head compact"><h1 class="display">${esc(tr("Words"))}</h1></header>
    <div class="search-field">${icon("search", { size: 20 })}
      <input id="wq" type="search" inputmode="search" autocomplete="off" autocapitalize="off" spellcheck="false"
        placeholder="${esc(tr("Search words and phrases"))}" value="${esc(wordsQuery)}" aria-label="${esc(tr("Search words and phrases"))}">
    </div>
    <div id="wresults">${wordsQuery.trim() ? resultsFor(wordsQuery) : `
      ${cats.map((c) => {
        const list = C.words.filter((w) => w.category === c.id);
        return list.length ? `<h2 class="sub-title c-saperavi">${esc(c.title)} <small class="count">${list.length}</small></h2><div class="rows">${list.map(wordRow).join("")}</div>` : "";
      }).join("")}
      <h2 class="sub-title c-tkemali">${esc(tr("More words"))} <small class="count">${more.length}</small></h2>
      ${wordsMore ? `<div class="rows">${more.map(wordRow).join("")}</div>` : `<button class="soft-button" data-act="more-words">${esc(tr("Show all {0}", more.length))}</button>`}`}
    </div>
  </div>`;
}

function installHint() {
  if (isStandalone() || store.setting("hideInstall")) return "";
  return `<div class="card install-hint">
    <img src="icons/apple-touch-icon.png" alt="" width="48" height="48">
    <div><strong>${esc(tr("Keep Ara on your phone"))}</strong>
      <small>${esc(isIOS() ? tr("In Safari, tap Share, then Add to Home Screen. Ara then opens like an app and works offline.") : tr("Use your browser's menu: Install app, or Add to Home screen. Ara then opens like an app and works offline."))}</small></div>
    <button class="close-x" data-act="hide-install" aria-label="${esc(tr("Close"))}">${icon("close", { size: 16 })}</button>
  </div>`;
}

const isStandalone = () => window.matchMedia("(display-mode: standalone)").matches || navigator.standalone === true;
const isIOS = () => /iPhone|iPad|iPod/.test(navigator.userAgent) || (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1);

let categorySub = {};
function categoryScreen(id) {
  const c = C.catByID.get(id);
  if (!c) return notFound();
  const sub = categorySub[id] || null;
  const subs = c.subs.filter((s) => !sub || s.id === sub);
  const dialogues = dialoguesIn(c.id);
  return `<div class="screen tint-${c.color}">
    ${topBar(c.title)}
    <div class="grad hero-card b-${c.color}">
      <div><div class="ka hero-ka">${esc(c.ka)}</div><div class="hero-title">${esc(c.title)}</div><p>${esc(c.blurb)}</p></div>
      <span class="hero-icon">${icon(c.symbol, { size: 36 })}</span>
    </div>
    ${c.id === "emergency" ? `<a class="chunky b-pomegranate" href="tel:112" data-id="call-112">${icon("phone", { size: 20 })}${esc(tr("Call 112: ambulance, police, fire"))}</a>` : ""}
    <div class="chips" role="tablist">
      <button class="chip b-${c.color}${!sub ? " on" : ""}" data-sub="" data-cat="${esc(c.id)}">${esc(tr("All"))}</button>
      ${c.subs.map((s) => `<button class="chip b-${c.color}${sub === s.id ? " on" : ""}" data-sub="${esc(s.id)}" data-cat="${esc(c.id)}">${esc(s.title)}</button>`).join("")}
    </div>
    ${subs.map((s) => {
      const list = phrasesIn(c.id, s.id);
      return list.length ? `<h2 class="sub-title b-${c.color}">${esc(s.title)}</h2><div class="rows">${list.map((p) => phraseRow(p)).join("")}</div>` : "";
    }).join("")}
    ${dialogues.length && !sub ? `${sectionTitle(tr("Conversations"))}<div class="carousel">${dialogues.map(dialogueCard).join("")}</div>` : ""}
    ${c.id === "health" ? `<p class="soft small-note">${icon("info", { size: 16 })}<span>${esc(tr("These phrases help you describe a problem. They are not medical advice. In an emergency, call 112."))}</span></p>` : ""}
    ${checkNote()}
  </div>`;
}

const TRICKY = {
  en: new Set(["თ", "კ", "პ", "ჟ", "რ", "ტ", "ფ", "ქ", "ღ", "ყ", "ჩ", "ც", "ძ", "წ", "ჭ", "ხ"]),
  pl: new Set(["თ", "კ", "პ", "ტ", "ფ", "ქ", "ღ", "ყ", "წ", "ჭ", "ჩ", "ც", "ვ", "ჟ", "ი"]),
};

function pronunciationHints(ka) {
  const seen = [];
  for (const ch of ka) if (TRICKY[lang].has(ch) && !seen.includes(ch)) seen.push(ch);
  return seen.map((c) => C.letters.get(c)).filter(Boolean).map((l) => `${l.char} (${l.latin}): ${l.sound}`);
}

const glossKey = (w) => w.replace(/^[.,?!—–:;"«»…-]+|[.,?!—–:;"«»…-]+$/g, "");

function wordByWord(ka) {
  const words = ka.split(" ").filter(Boolean).map((w) => [glossKey(w), C.glossary[glossKey(w)]]).filter(([, g]) => g);
  if (words.length < 2) return "";
  return `<section class="card">
    <h3 class="card-title c-saperavi">${icon("search", { size: 18 })}${esc(tr("Word by word"))}</h3>
    ${words.map(([w, g]) => {
      const meaning = g.meaning ?? g.baseMeaning ?? "";
      const from = g.base && (g.meaning == null || g.baseMeaning != null)
        ? `<div class="wbw-note">${esc(tr("From {0}", g.base + (g.baseMeaning ? ` (${g.baseMeaning})` : "")))}</div>` : "";
      return `<div class="wbw"><div class="wbw-line"><span class="ka wbw-ka">${esc(w)}</span><span class="lat">${esc(g.lat)}</span><span class="wbw-meaning">${esc(meaning)}</span></div>${from}${g.note ? `<div class="wbw-note">${esc(g.note)}</div>` : ""}</div>`;
    }).join("")}
  </section>`;
}

function formsCard(title, list, ic) {
  return `<section class="card">
    <h3 class="card-title c-saperavi">${icon(ic, { size: 18 })}${esc(title)}</h3>
    ${list.map((f) => `<div class="form-row"><div>
        ${f.label ? `<div class="form-label">${esc(f.label)}</div>` : ""}
        <div class="ka form-ka">${esc(f.ka)}</div><div class="lat">${esc(f.lat)}</div><div>${esc(f.en)}</div>
      </div>${speaker(f.ka, { size: 36 })}</div>`).join("")}
  </section>`;
}

function phraseScreen(id) {
  const p = C.phraseByID.get(id);
  if (!p) return notFound();
  store.noteOpened(p.id);
  const b = brandOf(p);
  const c = C.catByID.get(p.category);
  const saved = store.isSaved(p.id), learned = store.isLearned(p.id);
  const list = store.listOf(p.id);
  const reg = p.reg === "polite" ? [tr("Polite"), tr("The polite form: for strangers, shops, older people and officials.")]
    : p.reg === "informal" ? [tr("Informal"), tr("For friends, family and children.")] : null;
  const hints = pronunciationHints(p.ka);
  const linked = (p.words || []).map((w) => C.wordByID.get(w)).filter(Boolean);
  const grammar = (p.grammar || []).filter((g) => C.lessons[g.lesson]);
  const action = (act, ic, title, color, active = false, filled = false) =>
    `<button class="action c-${color}${active ? " on" : ""}" data-act="${act}" data-pid="${esc(p.id)}" data-id="action-${act}">
      <span class="action-icon">${icon(ic, { size: 21, filled })}</span><span class="action-title">${esc(title)}</span></button>`;
  return `<div class="screen tint-${b}">
    ${topBar((c && c.title) || tr("Phrase"))}
    <section class="grad phrase-hero b-${b}">
      ${p.urgent ? `<span class="pill-on">${icon("alert", { size: 14 })}${esc(tr("Emergency · call 112"))}</span>` : ""}
      <div class="ka hero-phrase" data-id="phrase-georgian">${esc(p.ka)}</div>
      <div class="hero-lat">${esc(p.lat)}</div>
      <div class="hero-en">${esc(p.en)}</div>
      ${reg ? `<span class="pill-on">${esc(reg[0])}</span>` : ""}
      ${audio.canPlay(p.ka) ? `<div class="hero-play">${speaker(p.ka, { size: 52, cls: "on-color" })}<button class="speaker on-color soft" style="--s:40px" data-say-slow="${esc(p.ka)}" aria-label="${esc(tr("Play slowly"))}">${icon("slow", { size: 20 })}</button></div><div class="source">${esc(sourceLabel(p.ka))}</div>` : ""}
    </section>
    <div class="actions">
      ${action("show", "show", tr("Show"), b === "gold" ? "pomegranate" : b)}
      ${action("save", "star", saved ? tr("Saved") : tr("Save"), "gold", saved, saved)}
      ${action("practise", store.isPractising(p.id) ? "learned" : "review", store.isPractising(p.id) ? tr("In review") : tr("Practise"), "blacksea", store.isPractising(p.id))}
      ${action("learned", "learned", tr("Learned"), "tkemali", learned)}
      ${action("copy", "copy", tr("Copy"), "saperavi")}
    </div>
    <button class="list-button" data-act="list" data-pid="${esc(p.id)}" data-id="action-list">${icon("folder", { size: 18 })}${esc(list ? tr("In your list: {0}", list) : tr("Add to a list"))}</button>
    <section class="card">
      <h3 class="card-title c-blacksea">${icon("wave", { size: 18 })}${esc(tr("Say it"))}</h3>
      <div class="sound">${esc(p.sound)}</div>
      <p class="soft small">${esc(tr("A rough English sound-alike. Vowels are short and clear (ah, eh, ee, oh, oo); stress is light, so give every syllable the same weight."))}</p>
      ${hints.map((h) => `<p class="soft">${esc(h)}</p>`).join("")}
    </section>
    ${wordByWord(p.ka)}
    ${p.note || p.lit || reg ? `<section class="card">
      <h3 class="card-title c-gold">${icon("bulb", { size: 18 })}${esc(tr("When to use it"))}</h3>
      ${p.note ? `<p>${esc(p.note)}</p>` : ""}
      ${p.lit ? `<p class="soft"><b>${esc(tr("Literally: "))}</b>${esc(p.lit)}</p>` : ""}
      ${reg ? `<p class="soft"><b>${esc(reg[0])}: </b>${esc(reg[1])}</p>` : ""}
    </section>` : ""}
    ${p.variants && p.variants.length ? formsCard(tr("Other ways to say it"), p.variants, "branch") : ""}
    ${p.replies && p.replies.length ? formsCard(tr("You may hear"), p.replies, "ear") : ""}
    ${linked.length ? `<section class="card">
      <h3 class="card-title c-tkemali">${icon("book", { size: 18 })}${esc(tr("Learn the words"))}</h3>
      <p class="soft small">${esc(tr("These words from the phrase are in the course."))}</p>
      <div class="word-chips">${linked.map((w) => `<button class="word-chip" data-say="${esc(w.ka)}"${audio.canPlay(w.ka) ? "" : " disabled"}><span class="ka">${esc(w.ka)}</span><small>${esc(w.en)}</small></button>`).join("")}</div>
    </section>` : ""}
    ${grammar.length ? `<section class="card">
      <h3 class="card-title c-saperavi">${icon("puzzle", { size: 18 })}${esc(tr("The grammar behind it"))}</h3>
      ${grammar.map((g) => `<div class="grammar-row"><span class="grammar-icon">${icon("puzzle", { size: 18 })}</span><div><strong>${esc(tr("Lesson: {0}", C.lessons[g.lesson]))}</strong><small>${esc(g.why)}</small></div></div>`).join("")}
    </section>` : ""}
  </div>`;
}

// Show mode: the Georgian huge, white on black, to hold up to a driver or a shopkeeper.
let showState = { english: true, flipped: false };
let wakeLock = null;

function showScreen(id) {
  const p = C.phraseByID.get(id);
  if (!p) return notFound();
  return `<div class="show${p.urgent ? " urgent" : ""}" data-id="show-phrase">
    <div class="show-top">
      <button class="show-btn" data-back data-id="show-close" aria-label="${esc(tr("Close"))}">${icon("close")}</button>
      <span></span>
      <button class="show-btn" data-act="show-english" aria-label="${esc(showState.english ? tr("Hide English") : tr("Show English"))}">${icon(showState.english ? "eye" : "eyeOff")}</button>
      <button class="show-btn" data-act="show-flip" aria-label="${esc(showState.flipped ? tr("Turn the right way up") : tr("Turn upside down for the person opposite"))}">${icon("flip")}</button>
    </div>
    <div class="show-stage"><div class="show-text${showState.flipped ? " flipped" : ""}">
      <div class="ka show-ka" data-id="show-georgian">${esc(p.ka)}</div>
      ${showState.english ? `<div class="show-en">${esc(p.en)}</div><div class="show-lat">${esc(p.lat)}</div>` : ""}
    </div></div>
    ${audio.canPlay(p.ka) ? `<div class="show-bottom">
      <div class="show-play-row">
        <button class="show-play${audio.isPlaying(p.ka) ? " playing" : ""}" data-say="${esc(p.ka)}" data-id="show-play">${icon("speaker", { size: 20 })}${esc(tr("Play"))}</button>
        <button class="show-btn big" data-say-slow="${esc(p.ka)}" aria-label="${esc(tr("Play slowly"))}">${icon("slow")}</button>
      </div>
      <div class="show-source">${esc(sourceLabel(p.ka))}</div>
    </div>` : ""}
  </div>`;
}

/** The largest size at which the Georgian fits its space without breaking a word. */
function fitShowText() {
  const stage = $(".show-stage"), ka = $(".show-ka");
  if (!stage || !ka) return;
  const width = stage.clientWidth - 48;
  const height = stage.clientHeight * (showState.english ? 0.62 : 0.9);
  let lo = 22, hi = 92;
  ka.style.maxWidth = `${width}px`;
  while (hi - lo > 1) {
    const mid = Math.floor((lo + hi) / 2);
    ka.style.fontSize = `${mid}px`;
    if (ka.scrollHeight <= height && ka.scrollWidth <= width + 1) lo = mid; else hi = mid;
  }
  ka.style.fontSize = `${lo}px`;
}

async function keepAwake(on) {
  try {
    if (on && "wakeLock" in navigator && !wakeLock) wakeLock = await navigator.wakeLock.request("screen");
    if (!on && wakeLock) { await wakeLock.release(); wakeLock = null; }
  } catch { wakeLock = null; }
}

// A conversation to read and hear, line by line.
let dialogueState = { english: true, latin: true };

function dialogueScreen(id) {
  const d = C.dialogueByID.get(id);
  if (!d) return notFound();
  const c = C.catByID.get(d.category);
  const b = (c && c.color) || "saperavi";
  const name = (who) => d.roles[who] || "";
  const toggle = (key, title) => `<button class="chip b-${b}${dialogueState[key] ? " on" : ""}" data-dtoggle="${key}">${icon(dialogueState[key] ? "eye" : "eyeOff", { size: 16 })}${esc(title)}</button>`;
  return `<div class="screen tint-${b}">
    ${topBar(d.title)}
    <section class="grad hero-card b-${b}"><div>
      <div class="hero-kicker">${esc((c && c.title) || "")}</div>
      <div class="hero-title">${esc(d.title)}</div>
      <p>${esc(tr("{0} and {1}. Tap a line to hear it.", name(0), name(1)))}</p>
    </div></section>
    <div class="chips">${toggle("english", tr("English"))}${toggle("latin", tr("Latin letters"))}</div>
    <div class="bubbles">${d.lines.map((l) => bubble(l, name(l.who), b, l.who === 0)).join("")}</div>
    ${d.notes.length ? `<section class="card">
      <h3 class="card-title c-gold">${icon("bulb", { size: 18 })}${esc(tr("Useful expressions"))}</h3>
      ${d.notes.map((n) => `<div class="note-row"><div><span class="ka note-ka">${esc(n.ka)}</span> <span class="soft">${esc(n.en)}</span></div><p class="soft">${esc(n.why)}</p></div>`).join("")}
    </section>` : ""}
    ${sectionTitle(tr("Practise it"))}
    <p class="soft">${esc(tr("Choose each of your lines; the other side speaks. Then swap."))}</p>
    <a class="chunky b-${b === "gold" ? "pomegranate" : b}" href="#/d/${esc(d.id)}/as/0" data-id="practise-0">${icon("play", { size: 18 })}${esc(beTheRole(name(0)))}</a>
    <a class="soft-button" href="#/d/${esc(d.id)}/as/1" data-id="practise-1">${icon("swap", { size: 18 })}${esc(beTheRole(name(1)))}</a>
  </div>`;
}

function beTheRole(role) {
  if (role === "Nana") return tr("Be Nana");
  return tr("Be the {0}", lang === "pl" ? role : role.toLowerCase());
}

function bubble(l, name, b, mine, extra = "") {
  const playable = audio.canPlay(l.ka);
  return `<div class="bubble-row${mine ? " mine" : ""}">
    ${mine ? "" : `<span class="avatar small b-${b}">${esc([...(name || "?")][0])}</span>`}
    <button class="bubble b-${b}${mine ? " mine" : ""}${audio.isPlaying(l.ka) ? " playing" : ""}"${playable ? ` data-say="${esc(l.ka)}"` : ""}>
      <span class="bubble-name">${esc(name)}${playable ? icon("speaker", { size: 13 }) : ""}</span>
      <span class="ka bubble-ka">${esc(l.ka)}</span>
      ${dialogueState.latin ? `<span class="bubble-lat">${esc(l.lat)}</span>` : ""}
      ${dialogueState.english ? `<span class="bubble-en">${esc(l.en)}</span>` : ""}
      ${extra}
    </button>
  </div>`;
}

// Playing one side of a conversation: the learner picks each of their lines among three.
let practice = null;

function startPractice(d, role) {
  const texts = d.lines.map((l) => l.ka);
  const steps = d.lines.map((line, i) => {
    const mine = line.who === role;
    let options = null;
    if (mine) {
      const wrong = [];
      for (const step of [3, 5, 2, 4, 1, 6, 7]) {
        if (wrong.length >= 2) break;
        const t = texts[(i + step) % texts.length];
        if (t !== line.ka && !wrong.includes(t)) wrong.push(t);
      }
      for (const other of C.pb.dialogues) {
        if (wrong.length >= 2) break;
        if (other.id === d.id) continue;
        for (const l of other.lines) if (wrong.length < 2 && l.ka !== line.ka && !wrong.includes(l.ka)) wrong.push(l.ka);
      }
      options = shuffle([line.ka, ...wrong]);
    }
    return { line, mine, options };
  });
  practice = { id: d.id, role, steps, at: 0, heard: 0, mistakes: 0, wrongPicks: [] };
}

function shuffle(a) {
  const out = [...a];
  for (let i = out.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [out[i], out[j]] = [out[j], out[i]]; }
  return out;
}

function practiceScreen(id, role) {
  const d = C.dialogueByID.get(id);
  if (!d) return notFound();
  if (!practice || practice.id !== id || practice.role !== role) startPractice(d, role);
  const c = C.catByID.get(d.category);
  const b = (c && c.color) || "saperavi";
  const name = (who) => d.roles[who] || "";
  // The other side's lines up to the learner's next turn have been said.
  while (practice.at < practice.steps.length && !practice.steps[practice.at].mine) practice.at += 1;
  const done = practice.at >= practice.steps.length;
  const said = practice.steps.slice(0, done ? practice.steps.length : practice.at);
  const current = done ? null : practice.steps[practice.at];
  const progress = Math.round((practice.steps.filter((s, i) => s.mine && i < practice.at).length /
    Math.max(1, practice.steps.filter((s) => s.mine).length)) * 100);
  return `<div class="screen tint-${b} practice">
    ${topBar(d.title)}
    <div class="progress"><span style="width:${progress}%"></span></div>
    <p class="soft center">${esc(role === 0 ? tr("You speak") : tr("You are the {0}", lang === "pl" ? name(role) : name(role).toLowerCase()))} · ${esc(tr("{0} and {1}. Tap a line to hear it.", name(0), name(1)))}</p>
    <div class="bubbles">${said.map((s) => bubble(s.line, s.mine ? tr("You") : name(s.line.who), b, s.mine)).join("")}</div>
    ${current ? `<section class="card choose">
      <h3 class="card-title c-${b === "gold" ? "pomegranate" : b}">${esc(tr("Your turn"))}</h3>
      <p class="say-this">${esc(tr("Say: {0}", current.line.en))}</p>
      <div class="options">${current.options.map((o, i) => `<button class="option${practice.wrongPicks.includes(o) ? " wrong" : ""}" data-pick="${esc(o)}" data-id="option-${i}"${practice.wrongPicks.includes(o) ? " disabled" : ""}><span class="ka">${esc(o)}</span></button>`).join("")}</div>
    </section>` : `<section class="card done-card">
      <img src="icons/mascot-hello.svg" alt="" class="mascot">
      <h3>${esc(practice.mistakes === 0 ? tr("Perfect conversation!") : tr("Conversation complete"))}</h3>
      <p class="soft">${esc(practice.mistakes === 0 ? tr("Every line right the first time.") : plural(practice.mistakes, "line to look at again", "lines to look at again", ["kwestia do powtórki", "kwestie do powtórki", "kwestii do powtórki"]))}</p>
      <a class="chunky b-${b === "gold" ? "pomegranate" : b}" href="#/d/${esc(d.id)}/as/${1 - role}" data-act="restart">${icon("swap", { size: 18 })}${esc(beTheRole(name(1 - role)))}</a>
      <button class="soft-button" data-act="practice-again">${icon("review", { size: 18 })}${esc(tr("Again"))}</button>
    </section>`}
  </div>`;
}

function pick(text) {
  const step = practice && practice.steps[practice.at];
  if (!step || !step.mine) return;
  if (text !== step.line.ka) {
    if (!practice.wrongPicks.length) practice.mistakes += 1;
    practice.wrongPicks.push(text);
    render({ keepScroll: true });
    const btn = [...document.querySelectorAll(".option")].find((b) => b.dataset.pick === text);
    if (btn) { btn.classList.add("shake"); if (navigator.vibrate) navigator.vibrate(30); }
    return;
  }
  practice.wrongPicks = [];
  practice.at += 1;
  audio.play(step.line.ka);
  render({ keepScroll: true });
  scrollToEnd();
}

/** After a turn: the other side's new line plays once the learner's has finished. */
function answerBack() {
  if (!practice) return;
  const last = practice.at - 1;
  const step = practice.steps[last];
  if (!step || step.mine || practice.heard >= practice.at) return;
  practice.heard = practice.at;
  const id = practice.id;
  const say = () => {
    if (!practice || practice.id !== id) return;
    if (audio.isPlaying(practice.steps[last - 1] && practice.steps[last - 1].line.ka)) { setTimeout(say, 200); return; }
    audio.play(step.line.ka);
  };
  setTimeout(say, 350);
}

function scrollToEnd() { requestAnimationFrame(() => window.scrollTo({ top: document.body.scrollHeight, behavior: "smooth" })); }

// Search: everything, as you type.
let searchQuery = "";

function searchScreen() {
  return `<div class="screen" data-screen="search">
    ${topBar(tr("Search"))}
    <div class="search-field">${icon("search", { size: 20 })}
      <input id="q" type="search" inputmode="search" autocomplete="off" autocapitalize="off" spellcheck="false"
        placeholder="${esc(tr("Search: taxi, water, pharmacy…"))}" value="${esc(searchQuery)}" aria-label="${esc(tr("Search words and phrases"))}">
      <button class="clear" data-act="clear-search" aria-label="${esc(tr("Clear"))}"${searchQuery ? "" : " hidden"}>${icon("close", { size: 16 })}</button>
    </div>
    <div id="results">${searchResults()}</div>
  </div>`;
}

function searchResults() {
  const q = searchQuery.trim();
  if (!q) {
    const recent = store.recent().map((id) => C.phraseByID.get(id)).filter(Boolean).slice(0, 5);
    return `<p class="soft">${esc(tr("English, Polish, Georgian or Latin letters: no exact wording needed."))}</p>
      <div class="suggestions">${C.pb.suggestions.map((s) => `<button class="chip b-pomegranate" data-suggest="${esc(s)}">${esc(s)}</button>`).join("")}</div>
      ${recent.length ? `${sectionTitle(tr("Recently used"))}<div class="rows">${recent.map((p) => phraseRow(p, { showsCategory: true })).join("")}</div>` : ""}`;
  }
  return resultsFor(q);
}

function resultsFor(q) {
  const r = C.search.search(q);
  if (r.isEmpty) {
    return `<div class="empty"><img src="icons/mascot-think.svg" alt="" class="mascot"><h3>${esc(tr("Nothing found"))}</h3>
      <p class="soft">${esc(tr("Try another word, or browse the situations."))}</p><a class="soft-button" href="#/phrasebook">${esc(tr("Browse situations"))}</a></div>`;
  }
  return `
    ${r.categories.length ? `${sectionTitle(tr("Situations"))}<div class="rows">${r.categories.map((c) => `<a class="cat-row grad b-${c.color}" href="#/c/${esc(c.id)}">${icon(c.symbol, { size: 22 })}<span><strong>${esc(c.title)}</strong><small class="ka">${esc(c.ka)}</small></span>${icon("chevronRight", { size: 18 })}</a>`).join("")}</div>` : ""}
    ${r.phrases.length ? `${sectionTitle(tr("Phrases"))}<div class="rows">${r.phrases.map((p) => phraseRow(p, { showsCategory: true })).join("")}</div>` : ""}
    ${r.dialogues.length ? `${sectionTitle(tr("Conversations"))}<div class="carousel">${r.dialogues.map(dialogueCard).join("")}</div>` : ""}
    ${r.words.length ? `${sectionTitle(tr("Words"))}<div class="rows">${r.words.map(wordRow).join("")}</div>` : ""}`;
}

function wordRow(w) {
  return `<div class="word-row"><a class="word-main" href="#/w/${esc(w.id)}"><span class="ka row-ka">${esc(w.ka)}</span><span class="lat">${esc(w.lat)}</span><span class="row-en">${esc(w.en)}</span></a>${speaker(w.ka, { size: 36 })}</div>`;
}

// My phrasebook: what the learner saved, by situation, filtered by their lists.
let savedFilter = { kind: "all", list: "" };

function savedScreen() {
  const all = store.savedIDs().map((id) => C.phraseByID.get(id)).filter(Boolean);
  const learnedCount = all.filter((p) => store.isLearned(p.id)).length;
  const lists = store.lists();
  if (savedFilter.kind === "list" && !lists.includes(savedFilter.list)) savedFilter = { kind: "all", list: "" };
  const shown = all.filter((p) => savedFilter.kind === "all" || (savedFilter.kind === "learned" && store.isLearned(p.id)) ||
    (savedFilter.kind === "list" && store.listOf(p.id) === savedFilter.list));
  const chip = (kind, list, title, ic) => {
    const on = savedFilter.kind === kind && (kind !== "list" || savedFilter.list === list);
    return `<button class="chip b-saperavi${on ? " on" : ""}" data-filter="${kind}" data-list="${esc(list)}">${icon(ic, { size: 15 })}${esc(title)}</button>`;
  };
  let body;
  if (!all.length) {
    body = `<div class="empty"><img src="icons/mascot-hello.svg" alt="" class="mascot"><h3>${esc(tr("Nothing saved yet"))}</h3>
      <p class="soft">${esc(tr("Open any phrase and tap Save. It stays here, ready to show or practise."))}</p>
      <a class="chunky b-gold" href="#/phrasebook">${esc(tr("Browse situations"))}</a></div>`;
  } else if (!shown.length) {
    body = `<p class="soft">${esc(tr("No phrases here yet."))}</p>`;
  } else {
    body = C.pb.categories.filter((c) => shown.some((p) => p.category === c.id)).map((c) =>
      `<h2 class="sub-title b-${c.color}">${icon(c.symbol, { size: 18 })}${esc(c.title)}</h2>
       <div class="rows">${shown.filter((p) => p.category === c.id).map((p) => phraseRow(p, { menu: true })).join("")}</div>`).join("") +
      `<p class="faint small">${esc(tr("Tap ⋯ on a phrase to move it to a list or remove it."))}</p>`;
  }
  return `<div class="screen tint-gold" data-screen="saved">
    ${topBar(tr("My phrasebook"))}
    <div class="stats">
      <div class="stat c-gold">${icon("star", { size: 20, filled: true })}<b>${all.length}</b><small>${esc(tr("saved"))}</small></div>
      <div class="stat c-tkemali">${icon("learned", { size: 20 })}<b>${learnedCount}</b><small>${esc(tr("learned"))}</small></div>
      <div class="stat c-saperavi">${icon("folder", { size: 20 })}<b>${lists.length}</b><small>${esc(tr("lists"))}</small></div>
    </div>
    ${all.length ? `<div class="chips">${chip("all", "", tr("All"), "bubble")}${chip("learned", "", tr("Learned"), "learned")}${lists.map((l) => chip("list", l, l, "folder")).join("")}</div>` : ""}
    ${body}
  </div>`;
}

// Settings.
let offline = { running: false, done: 0, total: 0, cached: null };

function settingsScreen() {
  const v = audio.currentVoice();
  const appearance = store.setting("appearance") || "system";
  const seg = (name, value, current, title) => `<button class="seg${value === current ? " on" : ""}" data-set="${name}" data-value="${value}">${title}</button>`;
  return `<div class="screen" data-screen="settings">
    ${topBar(tr("Profile and settings"))}
    ${course.profileCards()}
    <section class="card">
      <h3 class="card-title c-blacksea">${icon("globe", { size: 18 })}${esc(tr("Language"))}</h3>
      <div class="segmented">${seg("language", "en", lang, "🇬🇧 English")}${seg("language", "pl", lang, "🇵🇱 Polski")}</div>
      <p class="soft small">${esc(tr("Explanations, meanings and the app itself in your language. Your progress stays the same."))}</p>
    </section>
    <section class="card">
      <h3 class="card-title c-pomegranate">${icon("speaker", { size: 18 })}${esc(tr("Voice"))}</h3>
      <div class="voices">${["eka", "giorgi"].map((x) => `<div class="voice${x === v ? " on" : ""}">
        <button class="voice-pick" data-set="voice" data-value="${x}"><strong>${audio.voiceName(x)}</strong><small>${esc(x === "eka" ? tr("Female voice") : tr("Male voice"))}</small></button>
        <button class="listen" data-sample="${x}" aria-label="${esc(tr("Listen to {0}", audio.voiceName(x)))}">${icon("speaker", { size: 16 })}${esc(tr("Listen"))}</button>
      </div>`).join("")}</div>
      <p class="soft small">${esc(tr("“Hello, how are you?”"))} · ${esc(tr("Synthetic voice"))}</p>
    </section>
    <section class="card">
      <h3 class="card-title c-saperavi">${icon("moon", { size: 18 })}${esc(tr("Appearance"))}</h3>
      <div class="segmented">${seg("appearance", "system", appearance, esc(tr("System")))}${seg("appearance", "light", appearance, esc(tr("Light")))}${seg("appearance", "dark", appearance, esc(tr("Dark")))}</div>
    </section>
    <section class="card" id="offline-card">${offlineCard()}</section>
    ${isStandalone() ? "" : `<section class="card install-hint flat">
      <img src="icons/apple-touch-icon.png" alt="" width="48" height="48">
      <div><strong>${esc(tr("Keep Ara on your phone"))}</strong><small>${esc(isIOS() ? tr("In Safari, tap Share, then Add to Home Screen. Ara then opens like an app and works offline.") : tr("Use your browser's menu: Install app, or Add to Home screen. Ara then opens like an app and works offline."))}</small></div>
    </section>`}
    <section class="card">
      <h3 class="card-title c-tkemali">${icon("shield", { size: 18 })}${esc(tr("About"))}</h3>
      <p>${esc(tr("Ara is a Georgian companion for people living in or visiting Georgia: a course from the first letter, and a phrasebook for real situations."))}</p>
      ${checkNote()}
      <p class="soft small">${esc(tr("Nothing you do here leaves this device: no account, no tracking. Saved phrases and settings stay in this browser."))}</p>
      <p class="links"><a href="${PRIVACY_URL}" target="_blank" rel="noopener">${esc(tr("Privacy"))}</a> · <a href="${HOME_URL}" target="_blank" rel="noopener">aralearn.github.io</a></p>
      <p class="faint small" id="version"></p>
    </section>
    ${course.dangerCards()}
  </div>`;
}

function offlineCard() {
  const files = audio.allFiles();
  const mb = offlineSizeMB();
  const cached = offline.cached;
  const all = cached !== null && cached >= files.length;
  let status;
  if (offline.running) status = `<div class="progress"><span style="width:${Math.round((offline.done / Math.max(1, offline.total)) * 100)}%"></span></div><p class="soft small">${esc(tr("Keeping the audio: {0} of {1}", offline.done, offline.total))}</p>`;
  else if (all) status = `<p class="ok">${icon("check", { size: 16 })}${esc(tr("Every clip in {0}'s voice is on this device.", audio.voiceName()))}</p>`;
  else status = `<button class="chunky b-blacksea" data-act="offline"${"caches" in window ? "" : " disabled"}>${icon("download", { size: 18 })}${esc(tr("Keep all audio ({0} MB)", mb))}</button>`;
  return `<h3 class="card-title c-blacksea">${icon("download", { size: 18 })}${esc(tr("Offline"))}</h3>
    <p class="soft small">${esc(tr("Phrases and Show mode always work offline once Ara has opened. Audio plays offline once it has played here, or keep it all now."))}</p>
    ${status}`;
}

let audioSizes = null;
function offlineSizeMB() {
  const b = audioSizes && audioSizes[audio.currentVoice()];
  return b ? Math.round(b / 1e6) : 9;
}

async function countCached() {
  if (!("caches" in window)) return;
  try {
    const cache = await caches.open("ara-audio");
    const keys = new Set((await cache.keys()).map((r) => new URL(r.url).pathname.split("/").pop()));
    offline.cached = audio.allFiles().filter((f) => keys.has(f.split("/").pop())).length;
  } catch { offline.cached = null; }
  const card = $("#offline-card");
  if (card) card.innerHTML = offlineCard();
}

async function keepAudioOffline() {
  if (offline.running || !("caches" in window)) return;
  const files = audio.allFiles();
  const cache = await caches.open("ara-audio");
  const have = new Set((await cache.keys()).map((r) => new URL(r.url).pathname.split("/").pop()));
  const todo = files.filter((f) => !have.has(f.split("/").pop()));
  offline = { running: true, done: files.length - todo.length, total: files.length, cached: null };
  const card = () => { const el = $("#offline-card"); if (el) el.innerHTML = offlineCard(); };
  card();
  let failed = 0;
  const worker = async () => {
    while (todo.length) {
      const f = todo.shift();
      try {
        const res = await fetch(f, { cache: "no-store" });
        if (res.ok) await cache.put(new URL(f, location.href).href, res); else failed += 1;
      } catch { failed += 1; }
      offline.done += 1;
      if (offline.done % 10 === 0 || !todo.length) card();
    }
  };
  await Promise.all(Array.from({ length: 6 }, worker));
  offline.running = false;
  await countCached();
  if (failed) toast(tr("Some clips couldn't be kept. Try again with a connection."));
  else toast(tr("All audio kept on this device"));
}

function notFound() {
  return `<div class="screen">${topBar("")}<div class="empty"><img src="icons/mascot-think.svg" alt="" class="mascot"><h3>${esc(tr("Nothing here"))}</h3><a class="soft-button" href="#/phrasebook">${esc(tr("Phrasebook"))}</a></div></div>`;
}

// ---------------------------------------------------------------------------------------
// Sheets: small panels from the bottom (lists, a phrase's menu)

function openSheet(html) {
  const s = $("#sheet");
  s.innerHTML = `<div class="sheet-backdrop" data-act="close-sheet"></div><div class="sheet-panel" role="dialog" aria-modal="true">${html}</div>`;
  s.classList.add("on");
  const input = s.querySelector("input");
  if (input) setTimeout(() => input.focus(), 50);
}
function closeSheet() { const s = $("#sheet"); s.classList.remove("on"); s.innerHTML = ""; }

function listSheet(pid) {
  const current = store.listOf(pid);
  openSheet(`<h3>${esc(tr("Add to a list"))}</h3>
    <div class="sheet-list">
      ${current ? `<button class="sheet-item" data-move="" data-pid="${esc(pid)}">${icon("folder", { size: 18 })}${esc(tr("No list"))}</button>` : ""}
      ${store.lists().map((l) => `<button class="sheet-item${l === current ? " on" : ""}" data-move="${esc(l)}" data-pid="${esc(pid)}">${icon("folder", { size: 18 })}${esc(l)}${l === current ? icon("check", { size: 18 }) : ""}</button>`).join("")}
    </div>
    <form class="new-list" data-newlist="${esc(pid)}">
      <label>${esc(tr("New list"))}<input name="name" maxlength="40" placeholder="${esc(tr("For example: At the bazaar"))}"></label>
      <p class="soft small">${esc(tr("A list of your own in your phrasebook."))}</p>
      <div class="sheet-buttons"><button type="button" class="soft-button" data-act="close-sheet">${esc(tr("Cancel"))}</button><button class="chunky b-saperavi" type="submit">${esc(tr("Add"))}</button></div>
    </form>`);
}

function phraseMenu(pid) {
  const p = C.phraseByID.get(pid);
  if (!p) return;
  const learned = store.isLearned(pid);
  openSheet(`<h3 class="ka">${esc(p.ka)}</h3><p class="soft">${esc(p.en)}</p>
    <div class="sheet-list">
      <button class="sheet-item" data-act="learned" data-pid="${esc(pid)}" data-close>${icon("learned", { size: 18 })}${esc(learned ? tr("Not learned yet") : tr("Mark as learned"))}</button>
      <button class="sheet-item" data-act="list" data-pid="${esc(pid)}">${icon("folder", { size: 18 })}${esc(tr("Move to list"))}</button>
      <button class="sheet-item danger" data-act="unsave" data-pid="${esc(pid)}" data-close>${icon("trash", { size: 18 })}${esc(tr("Remove from my phrasebook"))}</button>
    </div>
    <div class="sheet-buttons"><button class="soft-button" data-act="close-sheet">${esc(tr("Cancel"))}</button></div>`);
}

// ---------------------------------------------------------------------------------------
// Navigation

let depth = 0;          // screens opened inside the app, so Back can go back
let pushed = false;     // the next address change came from a tap in the app
const scrolls = new Map();

function route() {
  const hash = location.hash.replace(/^#/, "") || "/";
  const parts = hash.split("?")[0].split("/").filter(Boolean);
  return { hash, parts };
}

const FULLSCREEN = ["show", "lesson", "session", "welcome"];

function tabFor(parts) {
  if (!parts.length || ["settings", "progress", "search"].includes(parts[0])) return "home";
  if (parts[0] === "alphabet") return "learn";
  if (parts[0] === "w") return "words";
  return { learn: "learn", words: "words", review: "review" }[parts[0]] || "phrasebook";
}

function render({ keepScroll = false } = {}) {
  const { parts } = route();
  const [a, b, , d] = parts;
  let html;
  const showing = FULLSCREEN.includes(a);
  if (a !== "welcome" && course.needsWelcome() && a !== "show") { location.replace("#/welcome/0"); return; }
  if ((a === "lesson" || a === "session") && !course.hasSession()) {
    if (!course.startSession(a === "lesson" ? "lesson" : "review", a === "lesson" ? b : parts.slice(1).join("/"))) {
      toast(tr("Nothing due"));
      location.replace(a === "lesson" ? "#/learn" : "#/review");
      return;
    }
    course.autoplay();
  }
  if (a === "welcome") html = course.welcomeScreen(+b || 0);
  else if (a === "lesson" || a === "session") html = course.playerScreen();
  else if (!a) html = course.homeScreen();
  else if (a === "phrasebook") html = homeScreen();
  else if (a === "learn") html = course.learnScreen();
  else if (a === "alphabet") html = course.alphabetScreen();
  else if (a === "review") html = course.reviewScreen();
  else if (a === "progress") html = course.progressScreen();
  else if (a === "w") html = course.wordScreen(b) || notFound();
  else if (a === "words") html = wordsTab();
  else if (a === "c") html = categoryScreen(b);
  else if (a === "p") html = phraseScreen(b);
  else if (a === "show") html = showScreen(b);
  else if (a === "d" && parts[2] === "as") html = practiceScreen(b, d === "1" ? 1 : 0);
  else if (a === "d") html = dialogueScreen(b);
  else if (a === "search") html = searchScreen();
  else if (a === "saved") html = savedScreen();
  else if (a === "settings") html = settingsScreen();
  else html = notFound();
  const y = window.scrollY;
  view().innerHTML = html;
  document.body.classList.toggle("showing", showing);
  const tab = tabFor(parts);
  document.querySelectorAll(".tab").forEach((t) => t.classList.toggle("on", t.dataset.tab === tab));
  if (a === "show") { fitShowText(); keepAwake(true); } else keepAwake(false);
  const answer = $("#answer");
  if (answer && !keepScroll) answer.focus({ preventScroll: true });
  if (keepScroll) window.scrollTo(0, y);
  if (a === "search") {
    const q = $("#q");
    if (q && !keepScroll && !("ontouchstart" in window && searchQuery)) q.focus({ preventScroll: true });
  }
  if (a === "d" && parts[2] === "as") answerBack();
  if (a === "settings") { countCached(); const v = $("#version"); if (v) v.textContent = tr("Version {0}", window.ARA_VERSION || "dev"); }
}

function navigate(href) {
  pushed = true;
  location.hash = href.replace(/^#/, "");
}

window.addEventListener("hashchange", (e) => {
  const old = (e.oldURL || "").split("#")[1] || "/";
  scrolls.set(old, window.scrollY);
  const back = !pushed;
  if (pushed) depth += 1; else depth = Math.max(0, depth - 1);
  pushed = false;
  audio.stop();
  if (old.startsWith("/d/") && old.includes("/as/") && !route().hash.includes("/as/")) practice = null;
  if (/^\/(lesson|session)\//.test(old) || /^\/(lesson|session)\//.test(route().hash)) course.endSession();
  render();
  const key = route().hash;
  window.scrollTo(0, back && scrolls.has(key) ? scrolls.get(key) : 0);
});

function goBack() {
  if (depth > 0) { history.back(); return; }
  const { parts } = route();
  let parent = ["c", "d", "saved"].includes(parts[0]) ? "/phrasebook" : "/";
  if (parts[0] === "p" || parts[0] === "show") {
    const p = C.phraseByID.get(parts[1]);
    parent = parts[0] === "show" ? `/p/${parts[1]}` : p ? `/c/${p.category}` : "/phrasebook";
  } else if (parts[0] === "d" && parts[2] === "as") parent = `/d/${parts[1]}`;
  else if (parts[0] === "lesson") parent = "/learn";
  else if (["session", "progress", "settings", "search"].includes(parts[0])) parent = parts[1] === "letters" ? "/alphabet" : "/";
  else if (parts[0] === "alphabet") parent = "/learn";
  else if (parts[0] === "w") parent = "/words";
  location.replace(`#${parent}`);
}

// ---------------------------------------------------------------------------------------
// Taps

document.addEventListener("click", async (e) => {
  const el = e.target.closest("a, button, [data-act]");
  if (!el) return;
  const ds = el.dataset;
  const where = route().parts[0];
  if ((where === "lesson" || where === "session") && course.playerTap(el)) { e.preventDefault(); return; }
  const handled = course.courseTap(el);
  if (handled === "lesson") { course.lessonSheet(ds.lesson, openSheet); return; }
  if (handled) { e.preventDefault(); return; }

  if (el.tagName === "A") {
    const href = el.getAttribute("href") || "";
    if (href.startsWith("#")) {
      e.preventDefault();
      if (ds.act === "restart") practice = null;
      closeSheet();
      if (href === location.hash || (href === "#/" && !location.hash)) { window.scrollTo({ top: 0, behavior: "smooth" }); return; }
      navigate(href);
    }
    return;
  }
  if ("back" in ds) { goBack(); return; }
  if (ds.say !== undefined) { audio.toggle(ds.say); return; }
  if (ds.saySlow !== undefined) { audio.play(ds.saySlow, { slow: true }); return; }
  if (ds.sample) { audio.play(audio.SAMPLE, { v: ds.sample }); return; }
  if (ds.pick !== undefined) { pick(ds.pick); return; }
  if (ds.sub !== undefined) { categorySub[ds.cat] = ds.sub || null; render({ keepScroll: true }); return; }
  if (ds.dtoggle) { dialogueState[ds.dtoggle] = !dialogueState[ds.dtoggle]; render({ keepScroll: true }); return; }
  if (ds.filter) { savedFilter = { kind: ds.filter, list: ds.list || "" }; render({ keepScroll: true }); return; }
  if (ds.suggest) { searchQuery = ds.suggest; render(); return; }
  if (ds.menu) { phraseMenu(ds.menu); return; }
  if (ds.move !== undefined) {
    store.move(ds.pid, ds.move);
    closeSheet();
    toast(ds.move ? tr("Added to {0}", ds.move) : tr("Kept in your phrasebook"));
    render({ keepScroll: true });
    return;
  }
  if (ds.set) { await applySetting(ds.set, ds.value); return; }

  const pid = ds.pid;
  switch (ds.act) {
    case "show": navigate(`#/show/${pid}`); break;
    case "save": {
      const on = store.toggleSaved(pid);
      toast(on ? tr("Saved to your phrasebook") : tr("Removed from your phrasebook"));
      render({ keepScroll: true });
      break;
    }
    case "unsave": store.setSaved(pid, false); closeSheet(); toast(tr("Removed from your phrasebook")); render({ keepScroll: true }); break;
    case "learned": {
      const on = !store.isLearned(pid);
      store.setLearned(pid, on);
      if ("close" in ds) closeSheet();
      toast(on ? tr("Marked as learned") : tr("Not marked as learned"));
      render({ keepScroll: true });
      break;
    }
    case "copy": {
      const p = C.phraseByID.get(pid);
      try { await navigator.clipboard.writeText(p.ka); toast(tr("Georgian copied")); } catch { toast(tr("Couldn't copy")); }
      break;
    }
    case "share": {
      const p = C.phraseByID.get(pid);
      try { await navigator.share({ text: `${p.ka}\n${p.lat}\n${p.en}` }); } catch { /* cancelled */ }
      break;
    }
    case "list": listSheet(pid); break;
    case "practise":
      if (store.isPractising(pid)) { store.stopPractising(pid); toast(tr("Taken out of your review")); }
      else { store.practise(pid); toast(tr("Added to your review")); }
      render({ keepScroll: true });
      break;
    case "close-sheet": closeSheet(); break;
    case "show-english": showState.english = !showState.english; render(); break;
    case "show-flip": showState.flipped = !showState.flipped; render(); break;
    case "practice-again": practice = null; render(); window.scrollTo(0, 0); break;
    case "clear-search": searchQuery = ""; render(); break;
    case "hide-install": store.setSetting("hideInstall", true); render({ keepScroll: true }); break;
    case "offline": keepAudioOffline(); break;
    case "more-words": wordsMore = true; render({ keepScroll: true }); break;
    default: break;
  }
});

document.addEventListener("submit", (e) => {
  const form = e.target.closest("[data-newlist]");
  if (!form) return;
  e.preventDefault();
  const name = new FormData(form).get("name").toString().trim();
  if (!name) return;
  store.move(form.dataset.newlist, name);
  closeSheet();
  toast(tr("Added to {0}", name));
  render({ keepScroll: true });
});

let searchTimer = null;
document.addEventListener("change", (e) => { course.courseChange(e); });

document.addEventListener("input", (e) => {
  if (course.playerInput(e)) return;
  if (e.target.id === "ob-name") { course.courseChange(e); return; }
  if (e.target.id === "wq") {
    wordsQuery = e.target.value;
    clearTimeout(searchTimer);
    searchTimer = setTimeout(() => { const r = $("#wresults"); if (r) r.innerHTML = wordsQuery.trim() ? resultsFor(wordsQuery) : ""; if (!wordsQuery.trim()) render({ keepScroll: true }); }, 120);
    return;
  }
  if (e.target.id !== "q") return;
  searchQuery = e.target.value;
  clearTimeout(searchTimer);
  searchTimer = setTimeout(() => {
    const r = $("#results");
    if (r) r.innerHTML = searchResults();
    const clear = $(".search-field .clear");
    if (clear) clear.hidden = !searchQuery;
  }, 120);
});

document.addEventListener("keydown", (e) => {
  if (course.playerKey(e)) { e.preventDefault(); return; }
  if (e.key === "Escape") {
    if ($("#sheet").classList.contains("on")) closeSheet();
    else if (route().parts[0] === "show") goBack();
  }
});

window.addEventListener("resize", () => { if (route().parts[0] === "show") fitShowText(); });
document.addEventListener("visibilitychange", () => {
  if (document.visibilityState === "visible" && route().parts[0] === "show") keepAwake(true);
});

// The speaker buttons follow what's playing.
audio.onChange((text) => {
  document.querySelectorAll("[data-say]").forEach((b) => b.classList.toggle("playing", b.dataset.say === text));
});

// ---------------------------------------------------------------------------------------
// Settings

function applyAppearance() {
  const a = store.setting("appearance") || "system";
  if (a === "system") delete document.documentElement.dataset.theme;
  else document.documentElement.dataset.theme = a;
  const dark = a === "dark" || (a === "system" && window.matchMedia("(prefers-color-scheme: dark)").matches);
  $('meta[name="theme-color"]').setAttribute("content", dark ? "#120E18" : "#FFF7EF");
}

async function applySetting(name, value) {
  if (name === "language" && value !== lang) {
    store.setSetting("language", value);
    await loadContent(value);
    labelTabs();
    render({ keepScroll: true });
  } else if (name === "voice") {
    store.setSetting("voice", value);
    await audio.loadVoice(value);
    offline.cached = null;
    render({ keepScroll: true });
    audio.play(audio.SAMPLE);
  } else if (name === "appearance") {
    store.setSetting("appearance", value);
    applyAppearance();
    render({ keepScroll: true });
  }
}

// The tab bar, as on the iPhone: Home · Learn · Phrasebook · Words · Review.
const TABS = [["home", "#/", "house"], ["learn", "#/learn", "map"], ["phrasebook", "#/phrasebook", "bubbles"],
  ["words", "#/words", "book"], ["review", "#/review", "review"]];

function labelTabs() {
  const names = { home: tr("Home"), learn: tr("Learn"), phrasebook: tr("Phrasebook"), words: tr("Words"), review: tr("Review") };
  const tab = tabFor(route().parts);
  $(".tabbar").innerHTML = `<div class="tabbar-inner">${TABS.map(([id, href, ic]) =>
    `<a class="tab${id === tab ? " on" : ""}" data-tab="${id}" href="${href}">${icon(ic, { size: 24 })}<span>${esc(names[id])}</span></a>`).join("")}</div>`;
}

// ---------------------------------------------------------------------------------------
// Start

async function start() {
  store.load();
  applyAppearance();
  window.matchMedia("(prefers-color-scheme: dark)").addEventListener("change", applyAppearance);
  const code = store.setting("language") || preferredLanguage();
  try {
    await Promise.all([loadContent(code), audio.loadVoice(store.setting("voice") || "eka")]);
  } catch (err) {
    view().innerHTML = `<div class="empty"><img src="icons/mascot-think.svg" alt="" class="mascot"><h3>Ara couldn't load</h3><p class="soft">Check the connection and open the page again.</p></div>`;
    throw err;
  }
  fetch("audio/sizes.json").then((r) => r.json()).then((s) => { audioSizes = s; }).catch(() => {});
  fetch("version.json").then((r) => r.json()).then((v) => { window.ARA_VERSION = v.version; }).catch(() => {});
  labelTabs();
  render();
  document.body.classList.add("ready");
  if ("serviceWorker" in navigator && location.protocol !== "file:") {
    navigator.serviceWorker.register("sw.js").catch(() => {});
  }
}

export { C, esc, $, speaker, sectionTitle, topBar, toast, render, navigate, checkNote, miniCard, applySetting, goBack };

start();
