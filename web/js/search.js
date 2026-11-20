// Search across the phrasebook and the course words, in English, Polish, Georgian or Latin
// letters. A line-by-line port of the iPhone app's PhraseSearch.swift, so both apps find the
// same things (web/tests/search_test.mjs runs the iPhone app's search checks against it):
// - words are matched whole, by their start ("expens" → expensive), with one typo allowed in
//   longer words ("pharmcy"), through synonyms ("cab" → taxi) and simple plurals;
// - little words (the, a, I, please…) are ignored unless they are all there is;
// - every phrase also matches its keywords, its situation and its subcategory;
// - Georgian is matched anywhere in the text; Latin ignores apostrophes ("tsqali" → ts'q'ali).
// No DOM here: Node runs it in the tests.

export const STOPWORDS = new Set(["a", "an", "the", "to", "of", "is", "are", "am", "i", "im", "me", "my", "it",
  "its", "please", "for", "and", "or", "be", "some", "any",
  // Polish (without accents, as plain() leaves them)
  "ja", "jest", "sa", "w", "we", "na", "z", "ze", "do", "o", "u",
  "sie", "mi", "mnie", "prosze", "poprosze", "czy", "jak", "ten", "ta"]);

const LETTER_OR_DIGIT = /[\p{L}\p{N}]/u;

export function withoutAccents(s) {
  return s.normalize("NFD").replace(/[̀-ͯ]/g, "").replace(/ł/g, "l").replace(/Ł/g, "L").normalize("NFC");
}

/** Lower case, no apostrophes or accents, letters and digits only, single spaces. */
export function plain(s) {
  let t = withoutAccents(String(s).toLowerCase());
  t = t.replace(/['’‘ʼ`´]/g, "");
  let mapped = "";
  for (const ch of t) mapped += LETTER_OR_DIGIT.test(ch) ? ch : " ";
  return mapped.split(" ").filter(Boolean).join(" ");
}

export function tokens(s) { return plain(s).split(" ").filter(Boolean); }

export function hasGeorgian(s) { return /[ა-ჿ]/.test(s); }

/** A plain English stem: phones → phone, pharmacies → pharmacy, training → train. */
export function stem(t, lang = "en") {
  if (lang === "pl") return polishStem(t);
  const n = [...t].length;
  if (n > 4 && t.endsWith("ies")) return t.slice(0, -3) + "y";
  if (n > 5 && t.endsWith("ing")) return t.slice(0, -3);
  if (n > 3 && t.endsWith("s") && !t.endsWith("ss")) return t.slice(0, -1);
  return t;
}

/** A rough Polish stem: "apteki", "aptece" and "apteka" meet at "aptek". */
export function polishStem(t) {
  const n = [...t].length;
  if (n <= 4) return t;
  for (const ending of ["ami", "ach", "owi", "iem", "om", "em", "ow", "ie", "ia", "y", "i", "a", "e", "u", "o"]) {
    if (t.endsWith(ending) && n - ending.length >= 4) return t.slice(0, -ending.length);
  }
  return t;
}

/** Edit distance (insertions, deletions, substitutions). */
export function distance(a, b) {
  const x = [...a], y = [...b];
  let prev = Array.from({ length: y.length + 1 }, (_, j) => j);
  for (let i = 1; i <= x.length; i++) {
    const cur = [i];
    for (let j = 1; j <= y.length; j++) {
      cur[j] = Math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (x[i - 1] === y[j - 1] ? 0 : 1));
    }
    prev = cur;
  }
  return prev[y.length];
}

const PUNCT = /^[.,?!]+|[.,?!]+$/g;
const len = (s) => [...s].length;

export class PhraseSearch {
  /**
   * @param pb the phrasebook file (phrasebook.json or phrasebook-pl.json)
   * @param words course words [{id, ka, lat, en, alt, category}] (may be empty)
   * @param wordCategories [{id, title}]
   * @param lang "en" or "pl" (for stems)
   */
  constructor(pb, words = [], wordCategories = [], lang = "en") {
    this.lang = lang;
    this.synonyms = new Map();
    for (const [k, v] of Object.entries(pb.synonyms || {})) {
      const key = plain(k);
      if (!this.synonyms.has(key)) this.synonyms.set(key, v.map(plain));
    }
    const cats = new Map(pb.categories.map((c) => [c.id, c]));
    const set = (s) => new Set(tokens(s));
    this.phrases = pb.phrases;
    this.phraseDocs = pb.phrases.map((p) => {
      const c = cats.get(p.category);
      const forms = p.variants || [];
      const sub = c ? (c.subs.find((s) => s.id === p.sub) || {}).title || "" : "";
      return {
        english: set([p.en, p.lit || "", ...forms.map((f) => f.en)].join(" ")),
        keywords: new Set(p.keywords.flatMap(tokens)),
        context: set(((c && c.title) || "") + " " + sub),
        latin: set([p.lat, ...forms.map((f) => f.lat)].join(" ")),
        georgian: [p.ka, ...forms.map((f) => f.ka)],
        sentence: plain(p.en),
        length: len(p.en),
      };
    });
    this.words = words;
    const wordCats = new Map(wordCategories.map((c) => [c.id, c.title]));
    this.wordDocs = words.map((w) => ({
      english: set([w.en, ...(w.alt || [])].join(" ")),
      keywords: new Set(),
      context: set(wordCats.get(w.category) || ""),
      latin: set(w.lat),
      georgian: [w.ka],
      sentence: plain(w.en),
      length: len(w.en),
    }));
    this.dialogues = pb.dialogues;
    this.dialogueDocs = pb.dialogues.map((d) => ({
      english: set(d.title + " " + d.lines.map((l) => l.en).join(" ")),
      keywords: set(d.roles.join(" ") + " dialogue conversation"),
      context: set((cats.get(d.category) || {}).title || ""),
      latin: set(d.lines.map((l) => l.lat).join(" ")),
      georgian: d.lines.map((l) => l.ka),
      sentence: plain(d.title),
      length: 40,
    }));
    this.categories = pb.categories;
    this.categoryDocs = pb.categories.map((c) => ({
      english: set(c.title + " " + c.subs.map((s) => s.title).join(" ")),
      keywords: set(c.blurb),
      context: new Set(),
      latin: set(c.lat),
      georgian: [c.ka],
      sentence: plain(c.title),
      length: len(c.title),
    }));
  }

  search(query, limit = 40) {
    const empty = { phrases: [], words: [], dialogues: [], categories: [], isEmpty: true };
    const q = String(query).trim();
    if (!q) return empty;
    let r;
    if (hasGeorgian(q)) {
      r = {
        phrases: this.georgian(q, this.phrases, this.phraseDocs, limit),
        words: this.georgian(q, this.words, this.wordDocs, 12),
        dialogues: this.georgian(q, this.dialogues, this.dialogueDocs, 4),
        categories: this.georgian(q, this.categories, this.categoryDocs, 3),
      };
    } else {
      let terms = tokens(q).filter((t) => !STOPWORDS.has(t));
      if (!terms.length) terms = tokens(q);
      if (!terms.length) return empty;
      const sentence = plain(q);
      r = {
        phrases: this.rank(terms, sentence, this.phrases, this.phraseDocs, limit),
        words: this.rank(terms, sentence, this.words, this.wordDocs, 12),
        dialogues: this.rank(terms, sentence, this.dialogues, this.dialogueDocs, 4, true),
        categories: this.rank(terms, sentence, this.categories, this.categoryDocs, 3, true),
      };
    }
    r.isEmpty = !r.phrases.length && !r.words.length && !r.dialogues.length && !r.categories.length;
    return r;
  }

  /** The best phrases for a query (tests and quick answers). */
  top(query, n = 3) { return this.search(query, n).phrases.slice(0, n); }

  rank(terms, sentence, items, docs, limit, strict = false) {
    const scored = [];
    docs.forEach((doc, i) => {
      let matched = 0, score = 0;
      for (const t of terms) {
        const s = this.termScore(t, doc);
        if (s > 0) { matched += 1; score += s; }
      }
      const needed = strict ? terms.length : Math.max(1, Math.floor((terms.length + 1) / 2));
      if (matched < needed) return;
      if (sentence && doc.sentence.includes(sentence)) score += doc.sentence.startsWith(sentence) ? 6 : 4;
      score -= doc.length * 0.01;
      scored.push({ i, matched, score });
    });
    scored.sort((a, b) => (a.matched !== b.matched ? b.matched - a.matched : a.score !== b.score ? b.score - a.score : a.i - b.i));
    return scored.slice(0, limit).map((s) => items[s.i]);
  }

  /** How well one search word matches a document: 0 for not at all. */
  termScore(term, doc) {
    let best = this.match(term, doc, 1);
    const st = stem(term, this.lang);
    if (st !== term) best = Math.max(best, this.match(st, doc, 0.95));
    const alts = this.synonyms.get(term) || this.synonyms.get(st) || [];
    for (const alt of alts) if (alt !== term) best = Math.max(best, this.match(alt, doc, 0.8));
    return best;
  }

  match(t, doc, weight) {
    if (doc.english.has(t) || doc.latin.has(t) || doc.keywords.has(t)) return 3 * weight;
    if (doc.context.has(t)) return 1.5 * weight;
    const n = len(t);
    const some = (s, f) => { for (const x of s) if (f(x)) return true; return false; };
    if (n >= 3) {
      const pre = (x) => x.startsWith(t);
      if (some(doc.english, pre) || some(doc.latin, pre)) return 1.6 * weight;
      if (some(doc.keywords, pre)) return 1.4 * weight;
      if (some(doc.context, pre)) return 0.9 * weight;
    }
    if (n >= 5) {
      const close = (x) => Math.abs(len(x) - n) <= 1 && distance(x, t) <= 1;
      if (some(doc.english, close) || some(doc.keywords, close) || some(doc.latin, close)) return 1.0 * weight;
      if (some(doc.context, close)) return 0.6 * weight;
    }
    return 0;
  }

  georgian(q, items, docs, limit) {
    const needle = q.replace(PUNCT, "");
    const scored = [];
    docs.forEach((doc, i) => {
      let best = 0;
      for (const g of doc.georgian) {
        const bare = g.replace(PUNCT, "");
        if (bare === needle) best = Math.max(best, 10);
        else if (bare.startsWith(needle)) best = Math.max(best, 7);
        else if (g.includes(needle)) best = Math.max(best, 5);
      }
      if (best > 0) scored.push([i, best - len(doc.georgian[0] || "") * 0.01]);
    });
    scored.sort((a, b) => (a[1] !== b[1] ? b[1] - a[1] : a[0] - b[0]));
    return scored.slice(0, limit).map((s) => items[s[0]]);
  }
}
