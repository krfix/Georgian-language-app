// The iPhone app's search checks (tools/Tests/main.swift), run against the web app's search,
// so both apps find the same phrases. Run after building: node web/tests/search_test.mjs
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { PhraseSearch, stem, plain } from "../js/search.js";

const dist = fileURLToPath(new URL("../dist/data/", import.meta.url));
const read = (f) => JSON.parse(readFileSync(dist + f, "utf8"));
let failed = 0, passed = 0;
function check(label, got, want) {
  const ok = JSON.stringify(got) === JSON.stringify(want);
  if (ok) passed++; else { failed++; console.log(`FAIL ${label}: got ${JSON.stringify(got)}, want ${JSON.stringify(want)}`); }
}

const pb = read("phrasebook.json"), words = read("words.json");
const s = new PhraseSearch(pb, words.words, words.categories, "en");
const topIDs = (q, n = 3) => s.top(q, n).map((p) => p.id);
const finds = (q, id, n = 3) => check(`search "${q}" finds ${id}`, topIDs(q, n).includes(id), true);

finds("stop here", "pb-ak-gamicheret-tu-sheidzleba");
finds("taxi stop", "pb-ak-gamicheret-tu-sheidzleba");
finds("how much is this", "pb-es-ra-ghirs");
finds("price", "pb-es-ra-ghirs", 4);
finds("I don't eat meat", "pb-khortss-ar-vcham");
finds("vegetarian", "pb-khortss-ar-vcham");
finds("where is the nearest pharmacy", "pb-ak-akhlos-aptiaki-aris");
finds("pharmacy", "pb-aptiaki-sad-aris");
finds("my name is", "pb-me-joni-mkvia");
finds("neighbour", "pb-akhali-mezobeli-var");
finds("neighbor", "pb-akhali-mezobeli-var");
finds("gym membership", "pb-abonementi-ra-ghirs");
finds("I don't understand", "pb-ver-gavige");
finds("expensive", "pb-dzalian-dzviria");
finds("pharmcy", "pb-aptiaki-sad-aris");
finds("chemist", "pb-aptiaki-sad-aris");
finds("gamarjoba", "pb-gamarjoba", 1);
finds("გამარჯობა", "pb-gamarjoba", 1);
finds("ვერ გავ", "pb-ver-gavige", 1);
check('"taxi" starts with transport', s.top("taxi", 1)[0]?.category, "transport");
check('"cab" starts with transport', s.top("cab", 1)[0]?.category, "transport");
const water = new Set(s.search("water", 12).phrases.map((p) => p.category));
check('"water" finds phrases in shopping, restaurants and home', ["shopping", "food", "home"].every((c) => water.has(c)), true);
check('"water" also finds the course word', s.search("water").words.some((w) => w.id === "w-tsqali"), true);
check('"heart" finds გული', s.search("heart").words.some((w) => w.id === "x-guli"), true);
check('"emergency" finds the situation', s.search("emergency").categories[0]?.id, "emergency");
check('"taxi" finds the taxi dialogue', s.search("taxi").dialogues.some((d) => d.id === "pd-taxi"), true);
check("nothing for nonsense", s.search("zzqxw").isEmpty, true);
check("nothing for an empty query", s.search("   ").isEmpty, true);
check("stem of pharmacies", stem("pharmacies"), "pharmacy");
check("plain removes apostrophes", plain("Ts'q'ali, don't!"), "tsqali dont");

// Polish
const ppb = read("phrasebook-pl.json"), pwords = read("words-pl.json");
const p = new PhraseSearch(ppb, pwords.words, pwords.categories, "pl");
const plTop = (q) => p.top(q, 3).map((x) => x.id);
check("Polish search: apteka", plTop("apteka").includes("pb-aptiaki-sad-aris"), true);
check("Polish search: taksowka without accents", p.top("taksowka", 1)[0]?.category, "transport");
check("Polish search: toaleta", plTop("gdzie jest toaleta").includes("pb-sad-aris-tualeti"), true);
check("Polish search: rachunek", plTop("rachunek").includes("pb-angarishi-tu-sheidzleba"), true);
check("Polish search: Georgian still works", plTop("გამარჯობა")[0], "pb-gamarjoba");
check("Polish: same phrases", ppb.phrases.map((x) => x.id), pb.phrases.map((x) => x.id));

// Every phrase and conversation line has a clip in both voices.
for (const v of ["eka", "giorgi"]) {
  const idx = JSON.parse(readFileSync(fileURLToPath(new URL(`../dist/audio/${v}.json`, import.meta.url)), "utf8"));
  const missing = [...pb.phrases.map((x) => x.ka), ...pb.dialogues.flatMap((d) => d.lines.map((l) => l.ka))].filter((t) => !idx[t]);
  check(`every phrase and line has a ${v} clip`, missing, []);
}

console.log(`${passed} passed, ${failed} failed`);
process.exit(failed ? 1 : 0);
