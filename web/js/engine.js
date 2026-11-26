// The course engine, ported from the iPhone app's Engine/ (ExerciseBuilder, AnswerEvaluator,
// LessonSession, SpacedRepetition, CourseProgress, CourseStage). No DOM: Node runs it in the
// tests. Same rules as on the iPhone: one exercise engine for every lesson kind, a wrong
// answer comes back once at the end, right answers space a word out (1, 3, 8… days), a miss
// brings it back in 10 minutes.

import { tr } from "./i18n.js";

// ---------------------------------------------------------------------------------------
// Random numbers from a seed (the same seed gives the same lesson).

export function rng(seed = Math.floor(Math.random() * 2 ** 31)) {
  let s = seed >>> 0;
  return () => {
    s = (s + 0x6D2B79F5) >>> 0;
    let t = s;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
const shuffled = (a, r) => {
  const out = [...a];
  for (let i = out.length - 1; i > 0; i--) { const j = Math.floor(r() * (i + 1)); [out[i], out[j]] = [out[j], out[i]]; }
  return out;
};
const pick = (a, r) => (a.length ? a[Math.floor(r() * a.length)] : undefined);
const chars = (s) => [...s];

// ---------------------------------------------------------------------------------------
// The course: modules, lessons, letters, words, look-ups.

export class Course {
  constructor({ course, letters, vocabulary, phrasebook }) {
    this.modules = course.modules;
    this.lessons = course.modules.flatMap((m) => m.lessons);
    this.letters = letters.letters;
    this.lookalikeGroups = letters.lookalikes || [];
    this.categories = vocabulary.categories;
    this.words = vocabulary.words;
    this.moreWords = vocabulary.more || [];
    this.pb = phrasebook;
    this.letterBy = new Map(this.letters.map((l) => [l.char, l]));
    this.wordBy = new Map([...this.words, ...this.moreWords].map((w) => [w.id, w]));
    this.lessonBy = new Map(this.lessons.map((l) => [l.id, l]));
    this.moduleOf = new Map();
    for (const m of this.modules) for (const l of m.lessons) this.moduleOf.set(l.id, m);
    this.phraseBy = new Map(phrasebook.phrases.map((p) => [p.id, p]));
  }
  letter(c) { return this.letterBy.get(c); }
  word(id) { return this.wordBy.get(id) || (id.startsWith("pb-") ? this.phraseWord(this.phraseBy.get(id)) : undefined); }
  lesson(id) { return this.lessonBy.get(id); }
  module(lessonID) { return this.moduleOf.get(lessonID); }
  wordsIn(lesson) { return (lesson.words || []).map((id) => this.word(id)).filter(Boolean); }
  lookalikes(c) {
    const out = [];
    for (const g of this.lookalikeGroups) if (g.includes(c)) for (const x of g) if (x !== c && !out.includes(x)) out.push(x);
    return out;
  }
  latin(ka) { return chars(ka).map((c) => (this.letterBy.get(c) || {}).latin ?? c).join(""); }
  lettersTaught(through) {
    const out = [];
    for (const l of this.lessons) {
      for (const c of l.letters || []) { const info = this.letter(c); if (info) out.push(info); }
      if (l.id === through) break;
    }
    return out;
  }
  /** A letter ("letter-ა") or a word or phrase, for review. */
  item(id) {
    if (id.startsWith("letter-")) { const l = this.letter(id.slice(7)); return l ? { kind: "letter", id, letter: l, ka: l.char, lat: l.latin, en: l.sound } : null; }
    const w = this.word(id);
    return w ? { kind: "word", id, word: w, ka: w.ka, lat: w.lat, en: w.en } : null;
  }
  /** A phrase as a word, for review (Phrasebook.word(for:)). */
  phraseWord(p) {
    if (!p) return undefined;
    const plainEn = p.en.replace(/[.!?]+$/, "");
    const alt = [plainEn];
    for (const v of p.variants || []) { const e = v.en.replace(/[.!?]+$/, ""); if (!alt.includes(e)) alt.push(e); }
    return { id: p.id, ka: p.ka, lat: p.lat, en: p.en, alt, category: p.category, example: { ka: p.ka, lat: p.lat, en: p.en },
      note: p.note || (p.lit ? tr("Literally: {0}", p.lit) : null) };
  }
  wordsNear(w) {
    const same = this.pb.phrases.filter((p) => p.category === w.category && p.id !== w.id);
    const rest = this.pb.phrases.filter((p) => p.category !== w.category);
    return [...same, ...rest].map((p) => this.phraseWord(p));
  }
}

const isSingleWord = (w) => !w.ka.includes(" ");
const bare = (w) => w.ka.replace(/^[.?!]+|[.?!]+$/g, "");
const stripPunct = (s) => s.replace(/^[.,?!—:;"]+|[.,?!—:;"]+$/g, "");
export const isGeorgian = (s) => /[ა-ჿ]/.test(s) && !/[A-Za-zÀ-ɏ]/.test(s);
const letterID = (l) => `letter-${l.char}`;

// ---------------------------------------------------------------------------------------
// Building exercises. Each exercise: { id, kind, instruction, itemID, shape, ...content }.
// Shapes: teachLetter, teachWord, note, choice, typing, matching, tiles, flashcard, dialogue.

const GRADED = new Set(["choice", "typing", "matching", "tiles", "flashcard", "dialogue"]);
export const isGraded = (ex) => GRADED.has(ex.shape);

export class Builder {
  constructor(course, hasAudio = () => false) { this.c = course; this.hasAudio = hasAudio; }

  exercises(lesson, r) {
    const body = this.body(lesson, r);
    if (!lesson.intro) return body;
    return [{ id: `${lesson.id}.intro`, kind: "note", instruction: tr("Before you start"), itemID: null, shape: "note", note: lesson.intro }, ...body];
  }

  body(lesson, r) {
    switch (lesson.kind) {
      case "letters": return this.letterLesson(lesson, r);
      case "contrast": return this.contrastLesson(lesson, r);
      case "vocabulary": case "phrases": return this.wordLesson(lesson, r);
      case "grammar": return this.grammarLesson(lesson, r);
      case "conversation": return this.conversationLesson(lesson, r);
      default: return [];
    }
  }

  letterLesson(lesson, r) {
    const c = this.c;
    const fresh = (lesson.letters || []).map((x) => c.letter(x)).filter(Boolean);
    const known = c.lettersTaught(lesson.id);
    const out = [];
    fresh.forEach((l, i) => {
      out.push({ id: `${lesson.id}.teach.${l.char}`, kind: "teachLetter", instruction: tr("New letter"), itemID: letterID(l), shape: "teachLetter", letter: l });
      out.push(this.letterToLatin(l, known, `${lesson.id}.rec.${l.char}`, r));
      if (i > 0) out.push(this.latinToLetter(fresh[i - 1], known, `${lesson.id}.back.${fresh[i - 1].char}`, r));
    });
    const last = fresh[fresh.length - 1];
    if (last) out.push(this.latinToLetter(last, known, `${lesson.id}.back.${last.char}`, r));
    if (fresh.length >= 3) out.push(this.matching(this.letterPairs(fresh), `${lesson.id}.match`, tr("Match each letter to its sound")));
    const read = lesson.read || [];
    const newChars = new Set(fresh.map((l) => l.char));
    read.slice(0, 3).forEach((g, i) => {
      const ex = this.missingLetter(g, newChars.size ? newChars : new Set(known.map((l) => l.char)), known, `${lesson.id}.missing.${i}`, r);
      if (ex) out.push(ex);
    });
    read.forEach((g, i) => out.push(this.reading(g, `${lesson.id}.read.${i}`, r)));
    read.forEach((g, i) => { if (i % 2 === 0 || !fresh.length) out.push(this.meaning(g, read, `${lesson.id}.mean.${i}`, r)); });
    if (!fresh.length) {
      for (let n = 0; n < 3 && n * 6 < known.length; n++) {
        out.push(this.matching(this.letterPairs(shuffled(known.slice(n * 6, n * 6 + 6), r)), `${lesson.id}.match.${n}`, tr("Match each letter to its sound")));
      }
      read.slice(0, 2).forEach((g, i) => out.push(this.spelling(g, null, `${lesson.id}.spell.${i}`, r)));
    }
    const heard = read.find((g) => this.hasAudio(g.ka));
    if (heard) out.push(this.listening(heard.ka, heard.en, read.map((g) => g.en), null, `${lesson.id}.listen`, r));
    return out;
  }

  contrastLesson(lesson, r) {
    const c = this.c;
    const out = [];
    const pairs = (lesson.pairs || []).map((p) => p.map((x) => c.letter(x)).filter(Boolean)).filter((p) => p.length === 2);
    const table = pairs.flat().map((l) => ({ ka: l.char, lat: l.latin, en: l.sound }));
    out.push({ id: `${lesson.id}.note`, kind: "note", instruction: tr("Listen with your eyes"), itemID: null, shape: "note", note: { title: lesson.title, text: lesson.note || "", table } });
    pairs.forEach((p, i) => {
      const target = p[i % 2];
      const options = shuffled(p, r);
      out.push({ id: `${lesson.id}.pair.${i}`, kind: "letterRecognition", instruction: tr("Tight or with air?"), itemID: letterID(target), shape: "choice",
        prompt: tr("Which letter is {0}?", target.latin), promptIsGeorgian: false, promptDetail: target.sound,
        options: options.map((l) => ({ text: l.char })), optionsAreGeorgian: true, answer: options.indexOf(target),
        explanation: `${tr("{0} is {1}: {2}.", p[0].char, p[0].latin, p[0].sound)} ${tr("{0} is {1}: {2}.", p[1].char, p[1].latin, p[1].sound)}` });
    });
    out.push(this.matching(this.letterPairs(pairs.flat().slice(0, 6)), `${lesson.id}.match`, tr("Match each letter to its sound")));
    const read = lesson.read || [];
    read.forEach((g, i) => out.push(i % 2 === 0 ? this.reading(g, `${lesson.id}.read.${i}`, r) : this.meaning(g, read, `${lesson.id}.mean.${i}`, r)));
    return out;
  }

  wordLesson(lesson, r) {
    const c = this.c;
    const words = c.wordsIn(lesson);
    let pool = c.words.filter((w) => w.category === (words[0] || {}).category);
    if (pool.length < 6) pool = c.words;
    const both = [...words, ...pool];
    const out = [];
    words.forEach((w, i) => {
      out.push({ id: `${lesson.id}.teach.${w.id}`, kind: "teachWord", instruction: tr("New word"), itemID: w.id, shape: "teachWord", word: w });
      if (i >= 1) {
        const prev = words[i - 1];
        out.push(i % 2 === 1 ? this.kaToEn(prev, both, `${lesson.id}.ke.${prev.id}`, r) : this.enToKa(prev, both, `${lesson.id}.ek.${prev.id}`, r));
      }
    });
    const last = words[words.length - 1];
    if (last) out.push(this.enToKa(last, both, `${lesson.id}.ek.${last.id}`, r));
    out.push(this.matching(this.wordPairs(shuffled(words, r).slice(0, 5)), `${lesson.id}.match`, tr("Tap the pairs")));
    const mixed = shuffled(words, r);
    let fills = 0;
    for (const w of mixed) {
      if (fills >= 2) break;
      const ex = this.fillBlank(w, both, `${lesson.id}.fill.${w.id}`, r);
      if (ex) { out.push(ex); fills += 1; }
    }
    const sp = mixed.find((w) => isSingleWord(w) && chars(bare(w)).length >= 2 && chars(bare(w)).length <= 7);
    if (sp) out.push(this.spelling({ ka: bare(sp), lat: sp.lat, en: sp.en }, sp.id, `${lesson.id}.spell`, r));
    for (const w of mixed.slice(-2)) out.push(this.translation(w, `${lesson.id}.type.${w.id}`));
    let builds = 0;
    const phrases = lesson.kind === "phrases";
    for (const w of [...mixed].reverse()) {
      if (builds >= (phrases ? 2 : 1)) break;
      const sentence = phrases ? { ka: w.ka, lat: w.lat, en: w.en } : w.example;
      const ex = sentence && this.sentenceBuilder(sentence, words.map((x) => (phrases ? x.ka : (x.example || {}).ka || "")), w.id, `${lesson.id}.build.${w.id}`, r);
      if (ex) { out.push(ex); builds += 1; }
    }
    const heard = mixed.find((w) => this.hasAudio(w.ka));
    if (heard) out.push(this.listening(heard.ka, heard.en, both.map((w) => w.en), heard.id, `${lesson.id}.listen`, r));
    return out;
  }

  grammarLesson(lesson, r) {
    const out = (lesson.notes || []).map((n, i) => ({ id: `${lesson.id}.note.${i}`, kind: "note", instruction: tr("Grammar"), itemID: null, shape: "note", note: n }));
    const words = this.c.wordsIn(lesson);
    for (const w of words.slice(0, 4)) out.push(this.flashcard(w, `${lesson.id}.card.${w.id}`));
    out.push(...this.authored(lesson, r));
    if (words.length >= 3) out.push(this.matching(this.wordPairs(words.slice(0, 5)), `${lesson.id}.match`, tr("Tap the pairs")));
    return out;
  }

  conversationLesson(lesson, r) {
    const d = lesson.dialogue;
    if (!d) return this.authored(lesson, r);
    const out = [];
    const history = [];
    d.lines.forEach((line, i) => {
      if (line.isLearner && line.wrong) {
        const options = shuffled([line.ka, ...line.wrong], r);
        out.push({ id: `${lesson.id}.turn.${i}`, kind: "dialogue", instruction: tr("Choose your reply"), itemID: null, shape: "dialogue",
          partner: d.partner, history: [...history], line, options, answer: options.indexOf(line.ka) });
      }
      history.push(line);
    });
    const partnerLines = d.lines.filter((l) => !l.isLearner);
    const others = d.lines.map((l) => ({ ka: l.ka, lat: l.lat, en: l.en }));
    partnerLines.forEach((line, i) => {
      if (i !== 0 && i !== Math.floor(partnerLines.length / 2)) return;
      if (this.hasAudio(line.ka)) out.push(this.listening(line.ka, line.en, others.map((g) => g.en), null, `${lesson.id}.listen.${i}`, r));
      else out.push(this.meaning(line, others, `${lesson.id}.mean.${i}`, r));
    });
    out.push(...this.authored(lesson, r));
    return out;
  }

  authored(lesson, r) {
    const out = [];
    (lesson.exercises || []).forEach((spec, i) => {
      const id = `${lesson.id}.x.${i}`;
      if (spec.type === "choice" && spec.options && spec.answer != null) {
        out.push(this.choiceEx(spec.prompt || "", false, null, spec.options, spec.answer, spec.options.every(isGeorgian), spec.explanation,
          "multipleChoice", tr("Choose the right answer"), null, id, r));
      } else if (spec.type === "fill" && spec.options && spec.answer != null && spec.sentence) {
        out.push(this.choiceEx(spec.sentence, true, spec.translation, spec.options, spec.answer, true, spec.explanation,
          "fillBlank", tr("Fill in the gap"), null, id, r));
      } else if (spec.type === "build" && spec.tiles) {
        out.push({ id, kind: "sentenceBuilder", instruction: tr("Build the sentence"), itemID: null, shape: "tiles",
          prompt: spec.english || "", promptDetail: null, answer: spec.tiles, bank: shuffled([...spec.tiles, ...(spec.extra || [])], r), joiner: " ", isSpelling: false });
      }
    });
    return out;
  }

  /** A review session: letters and words due, the exercise kinds mixed. */
  review(items, r) {
    const pool = this.c.words;
    return items.map((item, i) => {
      const id = `review.${i}.${item.id}`;
      if (item.kind === "letter") {
        const known = this.c.letters;
        return i % 2 === 0 ? this.letterToLatin(item.letter, known, id, r) : this.latinToLetter(item.letter, known, id, r);
      }
      const w = item.word;
      if (w.id.startsWith("pb-")) {
        const near = this.c.wordsNear(w);
        switch (i % 4) {
          case 0: return this.kaToEn(w, near, id, r);
          case 1: return this.enToKa(w, near, id, r);
          case 2: return this.sentenceBuilder(w, near.slice(0, 8).map((x) => x.ka), w.id, id, r) || this.kaToEn(w, near, id, r);
          default: return this.flashcard(w, id);
        }
      }
      const near = [...pool.filter((x) => x.category === w.category), ...pool];
      switch (i % 4) {
        case 0: return this.kaToEn(w, near, id, r);
        case 1: return this.enToKa(w, near, id, r);
        case 2: return this.translation(w, id);
        default: return this.flashcard(w, id);
      }
    });
  }

  // Pieces

  letterToLatin(l, known, id, r) {
    const options = shuffled([l, ...this.distractorLetters(l, known, r)], r);
    return { id, kind: "letterRecognition", instruction: tr("What sound does this letter make?"), itemID: letterID(l), shape: "choice",
      prompt: l.char, promptIsGeorgian: true, promptDetail: null, options: options.map((x) => ({ text: x.latin })), optionsAreGeorgian: false,
      answer: options.indexOf(l), explanation: tr("{0} sounds like {1}.", l.char, l.sound), audioText: null };
  }

  latinToLetter(l, known, id, r) {
    const options = shuffled([l, ...this.distractorLetters(l, known, r)], r);
    return { id, kind: "letterRecognition", instruction: tr("Which letter makes this sound?"), itemID: letterID(l), shape: "choice",
      prompt: l.latin, promptIsGeorgian: false, promptDetail: l.sound, options: options.map((x) => ({ text: x.char })), optionsAreGeorgian: true,
      answer: options.indexOf(l), explanation: tr("{0} is written {1}.", l.latin, l.char), audioText: null };
  }

  distractorLetters(l, known, r, count = 3) {
    const out = [];
    const add = (list) => { for (const x of shuffled(list, r)) if (out.length < count && x !== l && !out.includes(x)) out.push(x); };
    add(this.c.lookalikes(l.char).map((x) => this.c.letter(x)).filter((x) => x && known.includes(x)));
    add(known);
    add(this.c.letters);
    return out;
  }

  letterPairs(letters) { return letters.map((l) => ({ id: letterID(l), georgian: l.char, other: l.latin })); }
  wordPairs(words) {
    const seen = new Set();
    return words.filter((w) => !seen.has(w.en) && seen.add(w.en)).map((w) => ({ id: w.id, georgian: w.ka, other: w.en }));
  }
  matching(pairs, id, instruction) { return { id, kind: "matching", instruction, itemID: null, shape: "matching", pairs }; }

  missingLetter(g, preferring, known, id, r) {
    const cs = chars(g.ka);
    const positions = cs.map((_, i) => i).filter((i) => preferring.has(cs[i]));
    const pos = pick(positions, r);
    const target = pos != null && this.c.letter(cs[pos]);
    if (!target) return null;
    const shown = [...cs]; shown[pos] = "_";
    const options = shuffled([target, ...this.distractorLetters(target, known, r)], r);
    return { id, kind: "missingLetter", instruction: tr("Which letter is missing?"), itemID: letterID(target), shape: "choice",
      prompt: shown.join(""), promptIsGeorgian: true, promptDetail: `${g.lat} · ${g.en}`, options: options.map((x) => ({ text: x.char })),
      optionsAreGeorgian: true, answer: options.indexOf(target), explanation: tr("{0} is {1}.", g.ka, g.lat), audioText: null };
  }

  reading(g, id, r) {
    const c = this.c;
    const options = [g.lat];
    const cs = chars(g.ka);
    for (let attempts = 0; options.length < 4 && attempts < 30; attempts++) {
      const pos = Math.floor(r() * cs.length);
      const l = c.letter(cs[pos]);
      if (!l) continue;
      const changed = [...cs];
      changed[pos] = pick(c.lookalikes(l.char), r) || (pick(c.letters, r) || l).char;
      const lat = c.latin(changed.join(""));
      if (!options.includes(lat)) options.push(lat);
    }
    const mixed = shuffled(options, r);
    return { id, kind: "reading", instruction: tr("Read this word"), itemID: null, shape: "choice", prompt: g.ka, promptIsGeorgian: true,
      promptDetail: null, options: mixed.map((t) => ({ text: t })), optionsAreGeorgian: false, answer: mixed.indexOf(g.lat),
      explanation: tr("{0} reads {1}: {2}.", g.ka, g.lat, g.en), audioText: null };
  }

  meaning(g, others, id, r) {
    const options = [g.en];
    for (const o of shuffled(others, r)) if (options.length < 4 && !options.includes(o.en)) options.push(o.en);
    for (const w of shuffled(this.c.words, r)) if (options.length < 4 && !options.includes(w.en)) options.push(w.en);
    const mixed = shuffled(options, r);
    return { id, kind: "multipleChoice", instruction: tr("What does it mean?"), itemID: null, shape: "choice", prompt: g.ka, promptIsGeorgian: true,
      promptDetail: g.lat, options: mixed.map((t) => ({ text: t })), optionsAreGeorgian: false, answer: mixed.indexOf(g.en), explanation: null, audioText: null };
  }

  distractorWords(w, pool, r) {
    const out = [];
    for (const c of [...shuffled(pool, r), ...shuffled(this.c.words, r)]) {
      if (out.length >= 3) break;
      if (c.id !== w.id && c.en !== w.en && c.ka !== w.ka && !out.some((o) => o.en === c.en || o.ka === c.ka)) out.push(c);
    }
    return out;
  }

  kaToEn(w, pool, id, r) {
    const options = shuffled([w, ...this.distractorWords(w, pool, r)], r);
    return { id, kind: "multipleChoice", instruction: tr("What does it mean?"), itemID: w.id, shape: "choice", prompt: w.ka, promptIsGeorgian: true,
      promptDetail: w.lat, options: options.map((x) => ({ text: x.en })), optionsAreGeorgian: false, answer: options.indexOf(w), explanation: w.note || null, audioText: null };
  }

  enToKa(w, pool, id, r) {
    const options = shuffled([w, ...this.distractorWords(w, pool, r)], r);
    return { id, kind: "multipleChoice", instruction: tr("How do you say it in Georgian?"), itemID: w.id, shape: "choice", prompt: w.en, promptIsGeorgian: false,
      promptDetail: null, options: options.map((x) => ({ text: x.ka, detail: x.lat })), optionsAreGeorgian: true, answer: options.indexOf(w), explanation: w.note || null, audioText: null };
  }

  translation(w, id) {
    return { id, kind: "translation", instruction: tr("Type it in English"), itemID: w.id, shape: "typing", prompt: w.ka, promptLatin: w.lat,
      accepted: acceptedEnglish(w), display: w.en };
  }

  flashcard(w, id) {
    return { id, kind: "flashcard", instruction: tr("Do you remember it?"), itemID: w.id, shape: "flashcard", front: w.ka, frontLatin: w.lat, back: w.en, note: w.note || null };
  }

  fillBlank(w, pool, id, r) {
    if (!isSingleWord(w) || !w.example) return null;
    const target = bare(w);
    const tokens = w.example.ka.split(" ").filter(Boolean);
    const pos = tokens.findIndex((t) => stripPunct(t) === target);
    if (pos < 0) return null;
    const shown = [...tokens];
    shown[pos] = tokens[pos].replace(target, "___");
    const options = [target];
    for (const c of shuffled(pool, r)) if (options.length < 4 && isSingleWord(c) && !options.includes(bare(c))) options.push(bare(c));
    const mixed = shuffled(options, r);
    return { id, kind: "fillBlank", instruction: tr("Fill in the gap"), itemID: w.id, shape: "choice", prompt: shown.join(" "), promptIsGeorgian: true,
      promptDetail: w.example.en, options: mixed.map((t) => ({ text: t, detail: this.c.latin(t) })), optionsAreGeorgian: true,
      answer: mixed.indexOf(target), explanation: `${w.example.ka} — ${w.example.lat}`, audioText: null };
  }

  spelling(g, itemID, id, r) {
    const answer = chars(g.ka);
    const extra = [];
    for (const ch of new Set(answer)) {
      const l = this.c.letter(ch);
      if (!l) continue;
      const alike = this.c.lookalikes(l.char).find((x) => !answer.includes(x) && !extra.includes(x));
      if (alike) extra.push(alike);
      if (extra.length >= 3) break;
    }
    return { id, kind: "spelling", instruction: tr("Spell it in Georgian"), itemID, shape: "tiles", prompt: g.en, promptDetail: g.lat,
      answer, bank: shuffled([...answer, ...extra], r), joiner: "", isSpelling: true };
  }

  sentenceBuilder(g, sentences, itemID, id, r) {
    const tiles = g.ka.split(" ").filter((t) => t && t !== "—");
    if (tiles.length < 2 || tiles.length > 7) return null;
    const extra = [];
    for (const s of shuffled(sentences, r)) {
      for (const t of s.split(" ").filter(Boolean)) if (t !== "—" && !tiles.includes(t) && !extra.includes(t) && extra.length < 2) extra.push(t);
    }
    return { id, kind: "sentenceBuilder", instruction: tr("Build the sentence"), itemID, shape: "tiles", prompt: g.en, promptDetail: null,
      answer: tiles, bank: shuffled([...tiles, ...extra], r), joiner: " ", isSpelling: false };
  }

  listening(prompt, right, others, itemID, id, r) {
    const options = [right];
    for (const o of shuffled(others, r)) if (options.length < 4 && !options.includes(o)) options.push(o);
    const mixed = shuffled(options, r);
    return { id, kind: "listening", instruction: tr("What did you hear?"), itemID, shape: "choice", prompt, promptIsGeorgian: true, promptDetail: null,
      options: mixed.map((t) => ({ text: t })), optionsAreGeorgian: false, answer: mixed.indexOf(right), explanation: prompt, audioText: prompt };
  }

  choiceEx(prompt, promptIsGeorgian, detail, options, answer, optionsAreGeorgian, explanation, kind, instruction, itemID, id, r) {
    const right = options[Math.min(Math.max(answer, 0), options.length - 1)];
    const mixed = shuffled(options, r);
    return { id, kind, instruction, itemID, shape: "choice", prompt, promptIsGeorgian, promptDetail: detail || null,
      options: mixed.map((t) => ({ text: t, detail: optionsAreGeorgian ? this.c.latin(t) : null })), optionsAreGeorgian,
      answer: mixed.indexOf(right), explanation: explanation || null, audioText: null };
  }
}

// ---------------------------------------------------------------------------------------
// Automatic playback (Engine/AutoSpeech.swift, KART #18): what a lesson says by itself when
// "Play Georgian automatically" is on: the Georgian on screen as an exercise appears (not
// where that gives the answer away), every Georgian answer tapped, and after Check only a
// wrong answer, with the right Georgian. Listening plays itself whatever the setting.

const GIVES_AWAY = new Set(["letterRecognition", "reading", "listening"]);

export const autoSpeech = {
  /** The exercise appears. */
  onShow(ex) {
    switch (ex.shape) {
      case "teachLetter": return ex.letter.char;
      case "teachWord": return ex.word.ka;
      case "choice": return ex.promptIsGeorgian && !ex.prompt.includes("_") && !GIVES_AWAY.has(ex.kind) ? ex.prompt : null;
      case "typing": return ex.prompt;
      case "flashcard": return ex.front;
      case "dialogue": { const last = ex.history[ex.history.length - 1]; return last && !last.isLearner ? last.ka : null; }
      default: return null;
    }
  },
  /** The learner taps an answer (before Check), every time: the Georgian they tapped. */
  onPick(ex, before, now) {
    if (!now) return null;
    if (ex.shape === "choice" && now.choice !== undefined) return ex.optionsAreGeorgian && ex.options[now.choice] ? ex.options[now.choice].text : null;
    if (ex.shape === "dialogue" && now.choice !== undefined) return ex.options[now.choice] || null;
    if (ex.shape === "tiles" && now.tiles) {
      const had = (before && before.tiles) || [];
      return now.tiles.length > had.length ? now.tiles[now.tiles.length - 1] : null;
    }
    return null;
  },
  /** A Georgian tile tapped in matching. */
  onMatchTap(georgian) { return georgian; },
  /** After Check: right, nothing more; wrong, the right Georgian once. */
  onCheck(ex, given, correct) {
    if (correct) return null;
    if (ex.shape === "choice") {
      const opt = ex.options[ex.answer];
      if (!opt) return null;
      const right = opt.text;
      if (ex.promptIsGeorgian && ex.prompt.includes("_")) return ex.prompt.split(ex.prompt.includes("___") ? "___" : "_").join(right);
      if (ex.optionsAreGeorgian) return right;
      if (ex.audioText) return ex.audioText;
      return ex.promptIsGeorgian ? ex.prompt : null;
    }
    if (ex.shape === "tiles") return ex.answer.join(ex.joiner);
    if (ex.shape === "dialogue") return ex.line.ka;
    return null;
  },
};

// ---------------------------------------------------------------------------------------
// Checking answers. Answers: {choice: i} | {text: s} | {tiles: [..]} | {mistakes: n} | {recalled: bool}

export function evaluate(ex, a) {
  switch (ex.shape) {
    case "choice": return { verdict: a.choice === ex.answer ? "correct" : "wrong", correct: ex.options[ex.answer].text, explanation: ex.explanation };
    case "dialogue": return { verdict: a.choice === ex.answer ? "correct" : "wrong", correct: ex.line.ka, explanation: ex.line.en };
    case "typing": return { verdict: typed(a.text || "", ex.accepted), correct: ex.display, explanation: null };
    case "tiles": {
      const ok = a.tiles.join(ex.joiner) === ex.answer.join(ex.joiner);
      return { verdict: ok ? "correct" : "wrong", correct: ex.answer.join(ex.joiner), explanation: null };
    }
    case "matching": return { verdict: a.mistakes === 0 ? "correct" : "wrong", correct: "", explanation: null };
    case "flashcard": return { verdict: a.recalled ? "correct" : "wrong", correct: ex.back, explanation: ex.note };
    default: return { verdict: "correct", correct: "", explanation: null };
  }
}

const withoutAccents = (s) => s.normalize("NFD").replace(/[̀-ͯ]/g, "").replace(/ł/g, "l").replace(/Ł/g, "L").normalize("NFC");

export function plainAnswer(s) {
  let t = withoutAccents(String(s).toLowerCase()).replace(/[’‘ʼ`´]/g, "'");
  t = [...t].map((ch) => (/[\p{L}\p{N}']/u.test(ch) ? ch : " ")).join("");
  const words = t.split(" ").filter(Boolean);
  while (words.length > 1 && ["the", "a", "an", "to"].includes(words[0])) words.shift();
  return words.join(" ");
}

function distance(a, b) {
  const x = [...a], y = [...b];
  let prev = Array.from({ length: y.length + 1 }, (_, j) => j);
  for (let i = 1; i <= x.length; i++) {
    const cur = [i];
    for (let j = 1; j <= y.length; j++) cur[j] = Math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (x[i - 1] === y[j - 1] ? 0 : 1));
    prev = cur;
  }
  return prev[y.length];
}

export function typed(input, accepted) {
  const given = plainAnswer(input);
  if (!given) return "wrong";
  if (accepted.some((a) => plainAnswer(a) === given)) return "correct";
  for (const a of accepted.map(plainAnswer)) {
    if (!a) continue;
    const n = [...a].length;
    const allowed = n >= 8 ? 2 : n >= 4 ? 1 : 0;
    if (allowed > 0 && distance(a, given) <= allowed) return "almost";
  }
  return "wrong";
}

export function acceptedEnglish(w) {
  const noBrackets = w.en.replace(/\s*\([^)]*\)/g, "");
  const all = [w.en, noBrackets, ...noBrackets.split(";").map((s) => s.trim()), ...(w.alt || [])];
  const seen = new Set();
  return all.map(plainAnswer).filter((x) => x && !seen.has(x) && seen.add(x));
}

// ---------------------------------------------------------------------------------------
// One run through a lesson or review: the queue, first-try results, the retry at the end.

export class Session {
  constructor(exercises) { this.queue = exercises; this.index = 0; this.firstTry = {}; this.mistakes = []; }
  get current() { return this.queue[this.index]; }
  get finished() { return this.index >= this.queue.length; }
  get progress() { return this.queue.length ? this.index / this.queue.length : 1; }
  get gradedTotal() { return this.queue.filter((e) => isGraded(e) && !e.id.endsWith("+")).length; }
  record(evaluation, given) {
    const ex = this.current;
    if (!ex || !isGraded(ex)) return;
    const ok = evaluation.verdict !== "wrong";
    const base = ex.id.replace(/\+$/, "");
    if (!(base in this.firstTry)) this.firstTry[base] = ok;
    if (!ok) {
      this.mistakes.push({ ex, given, expected: evaluation.correct });
      if (!ex.id.endsWith("+")) this.queue.push({ ...ex, id: `${ex.id}+` });
    }
  }
  advance() { if (this.index < this.queue.length) this.index += 1; }
  get summary() {
    const graded = Object.keys(this.firstTry).length;
    const right = Object.values(this.firstTry).filter(Boolean).length;
    return { graded, right, mistakes: this.mistakes.length, accuracy: graded ? right / graded : 1, perfect: graded > 0 && right === graded };
  }
}

// ---------------------------------------------------------------------------------------
// Review timing (SM-2), as SpacedRepetition.swift.

export function startOfDay(t) { const d = new Date(t); d.setHours(0, 0, 0, 0); return d.getTime(); }
export function dayKey(t = Date.now()) {
  const d = new Date(t);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}

export function schedule(s, grade, now) {
  const n = { ...s };
  if (grade === "again") {
    n.repetitions = 0; n.interval = 0; n.lapses = (s.lapses || 0) + 1;
    n.ease = Math.max(1.3, s.ease - 0.2);
    n.due = now + 10 * 60 * 1000;
    return n;
  }
  if (grade === "hard") {
    n.ease = Math.max(1.3, s.ease - 0.15);
    n.interval = Math.max(1, Math.round(s.interval * 1.2));
  } else {
    n.interval = s.repetitions === 0 ? 1 : s.repetitions === 1 ? 3 : Math.max(s.interval + 1, Math.round(s.interval * s.ease));
  }
  n.repetitions = s.repetitions + 1;
  const d = new Date(startOfDay(now));
  d.setDate(d.getDate() + n.interval);
  n.due = d.getTime();
  return n;
}
export const gradeOf = (verdict) => (verdict === "correct" ? "good" : verdict === "almost" ? "hard" : "again");
export const isLearnedState = (m) => m.repetitions >= 2;
export const isDifficultState = (m) => (m.lapses || 0) >= 2 || m.ease < 2.0;

// ---------------------------------------------------------------------------------------
// The path and the stages.

export function lessonStates(ids, completed, startIndex = 0, openBefore = 0) {
  const out = {};
  const firstOpen = ids.findIndex((id, i) => i >= startIndex && !completed.has(id));
  ids.forEach((id, i) => {
    if (completed.has(id)) out[id] = "completed";
    else if (i === firstOpen) out[id] = "current";
    else if (i < openBefore) out[id] = "available";
    else if (firstOpen >= 0 && i < firstOpen) out[id] = "available";
    else out[id] = "locked";
  });
  return out;
}

export function stages() {
  return [
    { id: 0, emoji: "✈️", name: tr("Just landed"), canDo: tr("Everything is new, and that's the fun part."),
      story: tr("You've just stepped off the plane. Georgian is still a row of beautiful curls. Not for long: a few lessons, and those curls turn into sounds you can read."), moduleID: null },
    { id: 1, emoji: "🪧", name: tr("Sign reader"), canDo: tr("Read any sign, menu or street name aloud."),
      story: tr("The curls are letters now. Shop signs, menus, metro stations: you can sound them all out, even words you don't know yet. Most visitors never get this far."), moduleID: "alphabet" },
    { id: 2, emoji: "🍇", name: tr("Bazaar regular"), canDo: tr("Count, shop and name the things around you."),
      story: tr("You can walk through a Tbilisi bazaar, ask how much, understand the price and say what you want. Sellers notice when a visitor tries: expect a smile, maybe an extra peach."), moduleID: "vocabulary" },
    { id: 3, emoji: "🍷", name: tr("Supra guest"), canDo: tr("Greet, order, ask the way and say thanks."),
      story: tr("A supra is a Georgian feast, and you'd hold your own at one: greet the hosts, thank them, order in a café and find your way home. A welcome guest at any table."), moduleID: "everyday" },
    { id: 4, emoji: "🥂", name: tr("Tamada's apprentice"), canDo: tr("Build your own simple sentences."),
      story: tr("The tamada leads the toasts at a supra, and you're learning the craft. You know how Georgian sentences fit together, so you make your own instead of only repeating phrases."), moduleID: "grammar" },
    { id: 5, emoji: "🏆", name: tr("Tamada"), canDo: tr("Hold a simple conversation."),
      story: tr("You've finished the course. Like the tamada at the head of the table, you can lead a simple conversation in Georgian. Keep it fresh with a few minutes of review."), moduleID: "conversation" },
  ];
}

export function currentStage(modulesDone) {
  const all = stages();
  return [...all].reverse().find((s) => !s.moduleID || modulesDone.has(s.moduleID)) || all[0];
}

/** Days in a row with some practice, ending today or yesterday. */
export function streak(activeDays, today = Date.now()) {
  let d = new Date(startOfDay(today));
  if (!activeDays.has(dayKey(d))) d.setDate(d.getDate() - 1);
  let n = 0;
  while (activeDays.has(dayKey(d))) { n += 1; d.setDate(d.getDate() - 1); }
  return n;
}
