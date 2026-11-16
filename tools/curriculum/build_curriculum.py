#!/usr/bin/env python3
"""Builds the course data the app reads, and checks it.

The content lives in content_words.py and content_course.py. Run this after changing them:

    python3 tools/curriculum/build_curriculum.py

It writes Georgian/Resources/Curriculum/{letters,vocabulary,course}.json and stops with an
error if anything is wrong: a word used but never defined, a reading word with a letter not
taught yet, a Georgian string with non-Georgian letters, an answer missing from its options.
Latin spelling is made here from the Georgian (national system, 2002), so it can't be mistyped.
"""
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import content_course as C  # noqa: E402
import content_words as W  # noqa: E402

OUT = os.path.join(HERE, "..", "..", "Georgian", "Resources", "Curriculum")
VERSION = 1

LATIN = {
    "ა": "a", "ბ": "b", "გ": "g", "დ": "d", "ე": "e", "ვ": "v", "ზ": "z", "თ": "t", "ი": "i",
    "კ": "k'", "ლ": "l", "მ": "m", "ნ": "n", "ო": "o", "პ": "p'", "ჟ": "zh", "რ": "r", "ს": "s",
    "ტ": "t'", "უ": "u", "ფ": "p", "ქ": "k", "ღ": "gh", "ყ": "q'", "შ": "sh", "ჩ": "ch", "ც": "ts",
    "ძ": "dz", "წ": "ts'", "ჭ": "ch'", "ხ": "kh", "ჯ": "j", "ჰ": "h",
}
ALLOWED_OTHER = set(" .,?!—–-:;\"'«»…")

errors = []


def fail(msg):
    errors.append(msg)


def latin(ka):
    return "".join(LATIN.get(ch, ch) for ch in ka)


def check_georgian(text, where):
    odd = sorted({ch for ch in text if ch not in LATIN and ch not in ALLOWED_OTHER})
    if odd:
        fail(f"{where}: unexpected characters {''.join(odd)!r} in {text!r}")
    if not any(ch in LATIN for ch in text):
        fail(f"{where}: no Georgian letters in {text!r}")


def letters_of(ka):
    return {ch for ch in ka if ch in LATIN}


def slug(ka):
    s = latin(ka).replace("'", "")
    s = re.sub(r"[^a-z]+", "-", s).strip("-")
    return s


# ---- Letters
if len(C.LETTERS) != 33:
    fail(f"letters: {len(C.LETTERS)}, want 33")
letters = []
for (ch, name, lat, sound, word, meaning, tip) in C.LETTERS:
    if LATIN.get(ch) != lat:
        fail(f"letter {ch}: Latin {lat!r} but the table says {LATIN.get(ch)!r}")
    if not word.startswith(ch):
        fail(f"letter {ch}: example {word} doesn't start with it")
    check_georgian(word, f"letter {ch}")
    letters.append({"char": ch, "name": name, "latin": lat, "sound": sound, "word": word,
                    "wordLatin": latin(word), "meaning": meaning, "tip": tip})
order = [l["char"] for l in letters]
if order != sorted(order):
    fail("letters are not in alphabetical (Unicode) order")
for group in C.LOOKALIKES:
    for ch in group:
        if ch not in LATIN:
            fail(f"look-alike {ch!r} is not a letter")

# ---- Vocabulary
words = []
by_ka = {}
cat_ids = [c[0] for c in W.CATEGORIES]


def add_word(entry, category, situation=None):
    ka, en, alt, ex_ka, ex_en, extra = entry
    where = f"word {ka}"
    check_georgian(ka, where)
    check_georgian(ex_ka, where + " example")
    prefix = "p" if situation else "w"
    wid = f"{prefix}-{slug(ka)}"
    if any(w["id"] == wid for w in words):
        fail(f"{where}: id {wid} used twice")
    if ka in by_ka:
        fail(f"{where}: defined twice")
    if not en or en != en.strip():
        fail(f"{where}: English missing or with spaces around")
    w = {"id": wid, "ka": ka, "lat": latin(ka), "en": en, "alt": alt, "category": category,
         "example": {"ka": ex_ka, "lat": latin(ex_ka), "en": ex_en}}
    if situation:
        w["situation"] = situation
    if extra.get("note"):
        w["note"] = extra["note"]
    if extra.get("pron"):
        w["pron"] = extra["pron"]
    words.append(w)
    by_ka[ka] = w


for cat, entries in W.WORDS.items():
    if cat not in cat_ids:
        fail(f"category {cat} not listed")
    for e in entries:
        add_word(e, cat)
for situation, entries in W.PHRASES.items():
    for e in entries:
        add_word(e, "phrases", situation)
for e in W.GRAMMAR_WORDS:
    add_word(e, "grammar")

categories = [{"id": i, "title": t, "symbol": s, "color": c} for (i, t, s, c) in W.CATEGORIES]

# ---- Course
COLORS = {"pomegranate", "saperavi", "gold", "tkemali", "blacksea"}
KINDS = {"letters", "contrast", "vocabulary", "phrases", "grammar", "conversation"}
modules = []
taught = set()
seen_lessons = set()
used_words = set()


def ref(ka, where):
    w = by_ka.get(ka)
    if not w:
        fail(f"{where}: word {ka!r} is not in the vocabulary")
        return None
    used_words.add(w["id"])
    return w["id"]


def table(rows, where):
    out = []
    for (ka, en) in rows:
        check_georgian(ka, where)
        out.append({"ka": ka, "lat": latin(ka), "en": en})
    return out


def exercise(spec, where):
    kind = spec[0]
    if kind == "choice":
        _, prompt, options, answer, explanation = spec
        if len(set(options)) != len(options) or not 0 <= answer < len(options) or len(options) < 2:
            fail(f"{where}: bad options {options}")
        for o in options:
            if letters_of(o) and not re.search(r"[A-Za-z]", o):
                check_georgian(o, where)
        return {"type": "choice", "prompt": prompt, "options": options, "answer": answer,
                "explanation": explanation}
    if kind == "fill":
        _, sentence, translation, options, answer, explanation = spec
        if sentence.count("___") != 1:
            fail(f"{where}: {sentence!r} needs one ___")
        check_georgian(sentence.replace("___", ""), where)
        for o in options:
            check_georgian(o, where)
        if len(set(options)) != len(options) or not 0 <= answer < len(options):
            fail(f"{where}: bad options {options}")
        return {"type": "fill", "sentence": sentence, "translation": translation,
                "options": options, "answer": answer, "explanation": explanation}
    if kind == "build":
        _, english, tiles, extra = spec
        for t in tiles + extra:
            check_georgian(t, where)
        if set(tiles) & set(extra):
            fail(f"{where}: a tile is both right and extra")
        return {"type": "build", "english": english, "tiles": tiles, "extra": extra,
                "tilesLatin": [latin(t) for t in tiles]}
    fail(f"{where}: unknown exercise {kind}")
    return None


for m in C.MODULES:
    if m["color"] not in COLORS:
        fail(f"module {m['id']}: colour {m['color']}")
    lessons = []
    for L in m["lessons"]:
        where = f"lesson {L['id']}"
        if L["id"] in seen_lessons:
            fail(f"{where}: id used twice")
        seen_lessons.add(L["id"])
        if L["kind"] not in KINDS:
            fail(f"{where}: kind {L['kind']}")
        out = {"id": L["id"], "kind": L["kind"], "title": L["title"]}
        if L["kind"] == "letters":
            for ch in L["letters"]:
                if ch in taught:
                    fail(f"{where}: {ch} taught twice")
                taught.add(ch)
            out["letters"] = L["letters"]
            out["subtitle"] = " ".join(L["letters"]) if L["letters"] else "All 33 letters"
        if L["kind"] == "contrast":
            out["pairs"] = L["pairs"]
            out["note"] = L["note"]
            out["subtitle"] = "  ".join("/".join(p) for p in L["pairs"][:3]) + " …"
        if "read" in L:
            for (ka, en) in L["read"]:
                check_georgian(ka, where)
                extra = letters_of(ka) - taught
                if extra:
                    fail(f"{where}: reading word {ka} uses letters not taught yet: {''.join(sorted(extra))}")
            out["read"] = [{"ka": ka, "lat": latin(ka), "en": en} for (ka, en) in L["read"]]
        if L["kind"] == "vocabulary":
            out["words"] = [r for r in (ref(k, where) for k in L["words"]) if r]
            for k in L["words"]:
                w = by_ka.get(k)
                if w and w["category"] != L["category"]:
                    fail(f"{where}: {k} is in {w['category']}, lesson is {L['category']}")
            out["category"] = L["category"]
            out["subtitle"] = ", ".join(by_ka[k]["en"] for k in L["words"][:3] if k in by_ka)
        if L["kind"] == "phrases":
            ids = [w["id"] for w in words if w.get("situation") == L["situation"]]
            if len(ids) < 4:
                fail(f"{where}: only {len(ids)} phrases")
            used_words.update(ids)
            out["words"] = ids
            out["situation"] = L["situation"]
            out["subtitle"] = next(w["en"] for w in words if w["id"] == ids[0])
        if L["kind"] == "grammar":
            out["words"] = [r for r in (ref(k, where) for k in L["words"]) if r]
            out["notes"] = [{"title": t, "text": x, "table": table(rows, where)} for (t, x, rows) in L["notes"]]
            out["exercises"] = [e for e in (exercise(s, where) for s in L["exercises"]) if e]
            out["subtitle"] = L["notes"][0][0]
            if len(out["exercises"]) < 4:
                fail(f"{where}: too few exercises")
        if L["kind"] == "conversation":
            lines = []
            for (who, ka, en, wrong) in L["lines"]:
                check_georgian(ka, where)
                line = {"speaker": who, "ka": ka, "lat": latin(ka), "en": en, "isLearner": who == "You"}
                if wrong:
                    for w in wrong:
                        check_georgian(w, where)
                    if ka in wrong:
                        fail(f"{where}: the right line is among the wrong ones")
                    line["wrong"] = wrong
                elif who == "You":
                    fail(f"{where}: a line of yours with no choices")
                lines.append(line)
            if not any(l["isLearner"] for l in lines):
                fail(f"{where}: the learner never speaks")
            out["dialogue"] = {"partner": L["partner"], "lines": lines}
            out["exercises"] = [e for e in (exercise(("build",) + b, where) for b in L.get("build", [])) if e]
            out["subtitle"] = "With " + (L["partner"] if L["partner"] in ("Giorgi", "Nino") else "a " + L["partner"].lower())
        lessons.append(out)
    modules.append({"id": m["id"], "title": m["title"], "subtitle": m["subtitle"], "symbol": m["symbol"],
                    "color": m["color"], "intro": m["intro"], "lessons": lessons})

if taught != set(LATIN):
    fail(f"alphabet lessons leave out: {''.join(sorted(set(LATIN) - taught))}")
unused = [w["ka"] for w in words if w["id"] not in used_words]
if unused:
    fail(f"words in no lesson: {unused}")

if errors:
    print("\n".join("ERROR " + e for e in errors))
    sys.exit(1)

os.makedirs(OUT, exist_ok=True)


def write(name, data):
    with open(os.path.join(OUT, name), "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
        f.write("\n")


write("letters.json", {"version": VERSION, "letters": letters, "lookalikes": C.LOOKALIKES})
write("vocabulary.json", {"version": VERSION, "categories": categories, "words": words})
write("course.json", {"id": "georgian-a0", "version": VERSION, "title": "Georgian from zero", "modules": modules})
lesson_count = sum(len(m["lessons"]) for m in modules)
print(f"OK: {len(letters)} letters, {len(words)} words and phrases, {len(modules)} modules, {lesson_count} lessons")
