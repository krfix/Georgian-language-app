// The web course engine: every lesson builds, every exercise has a right answer that checks
// as right, a wrong answer comes back once, and review timing follows the iPhone app's rules.
// Run after building: node web/tests/engine_test.mjs
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { Course, Builder, Session, evaluate, typed, acceptedEnglish, schedule, lessonStates, rng, isGraded, currentStage } from "../js/engine.js";

const dist = fileURLToPath(new URL("../dist/", import.meta.url));
const read = (f) => JSON.parse(readFileSync(dist + f, "utf8"));
let failed = 0, passed = 0;
const check = (label, got, want) => {
  if (JSON.stringify(got) === JSON.stringify(want)) passed++;
  else { failed++; console.log(`FAIL ${label}: got ${JSON.stringify(got)}, want ${JSON.stringify(want)}`); }
};

for (const sfx of ["", "-pl"]) {
  const course = new Course({ course: read(`data/course${sfx}.json`), letters: read(`data/letters${sfx}.json`),
    vocabulary: read(`data/vocabulary${sfx}.json`), phrasebook: read(`data/phrasebook${sfx}.json`) });
  const clips = read("audio/eka.json");
  const b = new Builder(course, (t) => !!clips[t]);
  let bad = [];
  for (const lesson of course.lessons) {
    const exs = b.exercises(lesson, rng(7));
    if (exs.filter(isGraded).length < 3) bad.push(`${lesson.id}: only ${exs.filter(isGraded).length} graded`);
    for (const ex of exs) {
      let answer;
      if (ex.shape === "choice" || ex.shape === "dialogue") {
        if (!(ex.answer >= 0)) { bad.push(`${ex.id}: no right option`); continue; }
        answer = { choice: ex.answer };
      } else if (ex.shape === "typing") answer = { text: ex.display };
      else if (ex.shape === "tiles") {
        if (!ex.answer.every((t) => ex.bank.includes(t))) bad.push(`${ex.id}: tile missing from the bank`);
        answer = { tiles: ex.answer };
      } else if (ex.shape === "matching") { if (ex.pairs.length < 2) bad.push(`${ex.id}: ${ex.pairs.length} pairs`); answer = { mistakes: 0 }; }
      else if (ex.shape === "flashcard") answer = { recalled: true };
      else continue;
      if (evaluate(ex, answer).verdict !== "correct") bad.push(`${ex.id}: the right answer isn't right`);
      if (ex.shape === "choice" && new Set(ex.options.map((o) => o.text)).size !== ex.options.length) bad.push(`${ex.id}: repeated options`);
    }
  }
  check(`every lesson builds and checks (${sfx || "en"})`, bad.slice(0, 5), []);
  const first = b.exercises(course.lessons[0], rng(1));
  check("the first lesson starts by teaching a letter", first.find((e) => e.shape !== "note").shape, "teachLetter");
  // Review of words, letters and a phrase.
  const items = ["letter-ა", "w-gamarjoba", "pb-gamarjoba", "w-madloba"].map((id) => course.item(id)).filter(Boolean);
  check("review items found", items.length, 4);
  check("a review exercise per item", b.review(items, rng(3)).map((e) => e.itemID), items.map((i) => i.id));
}

// The session: a wrong answer comes back once at the end.
const s = new Session([{ id: "a", shape: "choice", answer: 0, options: [{ text: "x" }, { text: "y" }] }, { id: "b", shape: "note" }]);
s.record(evaluate(s.current, { choice: 1 }), "y");
s.advance(); s.advance();
check("a mistake comes back", s.current && s.current.id, "a+");
s.record(evaluate(s.current, { choice: 0 }), "x"); s.advance();
check("finished after the retry", s.finished, true);
check("first try counts", s.summary, { graded: 1, right: 0, mistakes: 1, accuracy: 0, perfect: false });

// Typed answers.
check("typo allowed", typed("helo", acceptedEnglish({ en: "hello", alt: [] })), "almost");
check("brackets optional", typed("hello", acceptedEnglish({ en: "hello (in reply)", alt: [] })), "correct");
check("Polish without ł", typed("nie zrozumialem", ["nie zrozumiałem"]), "correct");

// Review timing: 1 day, 3 days, then longer; a miss: 10 minutes.
const now = new Date(2026, 10, 20, 12).getTime();
let st = { ease: 2.5, interval: 0, repetitions: 0, lapses: 0, due: now };
st = schedule(st, "good", now); check("first right: 1 day", st.interval, 1);
st = schedule(st, "good", now); check("second right: 3 days", st.interval, 3);
st = schedule(st, "good", now); check("third right: 8 days", st.interval, 8);
st = schedule(st, "again", now); check("a miss: 10 minutes", st.due - now, 600000);

// The path.
const ids = ["l1", "l2", "l3", "l4"];
check("path from zero", lessonStates(ids, new Set()), { l1: "current", l2: "locked", l3: "locked", l4: "locked" });
check("I can read: starts later, the start stays open", lessonStates(ids, new Set(), 2, 2), { l1: "available", l2: "available", l3: "current", l4: "locked" });
check("stage after the alphabet", currentStage(new Set(["alphabet"])).id, 1);

console.log(`${passed} passed, ${failed} failed`);
process.exit(failed ? 1 : 0);
