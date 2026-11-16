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
import content_phrasebook as PB  # noqa: E402
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
            out["subtitle"] = " · ".join(k.rstrip("?") for k in L["words"][:3])
        if L["kind"] == "phrases":
            ids = [w["id"] for w in words if w.get("situation") == L["situation"]]
            if len(ids) < 4:
                fail(f"{where}: only {len(ids)} phrases")
            used_words.update(ids)
            out["words"] = ids
            out["situation"] = L["situation"]
            out["subtitle"] = next(w["ka"] for w in words if w["id"] == ids[0])
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

# ---- Phrasebook (content_phrasebook.py): Georgian for real situations, outside the course.
SOUND = {"ა": "ah", "ე": "eh", "ი": "ee", "ო": "oh", "უ": "oo"}
VOWELS = set(SOUND)


def sound_word(word):
    """An English-style sound guide for one word, split into syllables: გამარჯობა → gah-mahr-joh-bah.
    Between vowels a single consonant starts the next syllable; of two or more, the first
    closes the syllable before. Stress is not marked: in Georgian it is light."""
    letters = [ch for ch in word if ch in LATIN]
    if not letters:
        return word
    vowels = [i for i, ch in enumerate(letters) if ch in VOWELS]
    if not vowels:
        return latin("".join(letters))
    cuts = []
    for a, b in zip(vowels, vowels[1:]):
        gap = b - a - 1
        cuts.append(a + 1 if gap <= 1 else a + 2)
    parts, start = [], 0
    for c in cuts + [len(letters)]:
        parts.append(letters[start:c])
        start = c
    return "-".join("".join(SOUND.get(ch, LATIN[ch]) for ch in p) for p in parts)


def sound(ka):
    out = []
    for tok in ka.split():
        core = tok.strip(".,?!—–:;\"«»…")
        if not core:
            continue
        if any(ch in LATIN for ch in core):
            out.append("-".join(sound_word(piece) for piece in core.split("-") if piece))
        else:
            out.append(core)
    return " ".join(out)


def check_phrase_text(text, where):
    check_georgian(re.sub(r"[0-9]", "", text), where)


pb_cats = {}
for (cid, title, ka, symbol, color, blurb, subs) in PB.CATEGORIES:
    if color not in COLORS:
        fail(f"phrasebook category {cid}: colour {color}")
    check_georgian(ka, f"phrasebook category {cid}")
    pb_cats[cid] = {"id": cid, "title": title, "ka": ka, "lat": latin(ka), "symbol": symbol, "color": color,
                    "blurb": blurb, "subs": [{"id": i, "title": t} for (i, t) in subs]}
if set(PB.PHRASES) != set(pb_cats):
    fail(f"phrasebook: categories without phrases or phrases without a category: {set(PB.PHRASES) ^ set(pb_cats)}")

word_by_bare = {w["ka"].strip("?.!"): w for w in words}
grammar_ids = {L["id"] for m in modules for L in m["lessons"] if L["kind"] == "grammar"}
pb_phrases, pb_ka = [], set()
for cid, entries in PB.PHRASES.items():
    if len(entries) < 5:
        fail(f"phrasebook {cid}: only {len(entries)} phrases")
    subs = {s["id"] for s in pb_cats.get(cid, {"subs": []})["subs"]}
    used_subs = set()
    for e in entries:
        ka, en = e["ka"], e["en"]
        where = f"phrase {ka}"
        check_phrase_text(ka, where)
        if ka in pb_ka:
            fail(f"{where}: in the phrasebook twice")
        pb_ka.add(ka)
        if not en or en != en.strip():
            fail(f"{where}: English missing or with spaces around")
        if e["sub"] not in subs:
            fail(f"{where}: unknown subcategory {e['sub']}")
        used_subs.add(e["sub"])
        if not e["kw"]:
            fail(f"{where}: no keywords")
        if e.get("reg") not in (None, "polite", "informal"):
            fail(f"{where}: register {e['reg']}")
        unknown = set(e) - {"ka", "en", "sub", "kw", "reg", "lit", "note", "var", "rep"}
        if unknown:
            fail(f"{where}: unknown fields {unknown}")
        pid = "pb-" + slug(ka)
        if any(p["id"] == pid for p in pb_phrases):
            fail(f"{where}: id {pid} used twice")
        p = {"id": pid, "ka": ka, "lat": latin(ka), "sound": sound(ka), "en": en, "category": cid,
             "sub": e["sub"], "keywords": [k.lower() for k in e["kw"]], "urgent": cid == "emergency"}
        for key in ("reg", "lit", "note"):
            if e.get(key):
                p[key] = e[key]
        if e.get("var"):
            p["variants"] = []
            for (label, vka, ven) in e["var"]:
                check_phrase_text(vka, where + " variant")
                p["variants"].append({"label": label, "ka": vka, "lat": latin(vka), "en": ven})
        if e.get("rep"):
            p["replies"] = []
            for (rka, ren) in e["rep"]:
                check_phrase_text(rka, where + " reply")
                p["replies"].append({"ka": rka, "lat": latin(rka), "en": ren})
        # Course words in the phrase, for "Learn the words".
        linked = []
        bare = ka.strip(".?!")
        for tok in re.split(r"[ ,]+", bare):
            w = word_by_bare.get(tok.strip(".?!,"))
            if w and w["id"] not in linked:
                linked.append(w["id"])
        for wka, w in word_by_bare.items():
            if " " in wka and wka in bare and w["id"] not in linked:
                linked.append(w["id"])
        if linked:
            p["words"] = linked[:6]
        gram = []
        for (pattern, lesson, why) in PB.GRAMMAR_LINKS:
            if lesson not in grammar_ids:
                fail(f"grammar link to unknown lesson {lesson}")
            if re.search(pattern, ka + " ") and len(gram) < 2 and all(g["lesson"] != lesson for g in gram):
                gram.append({"lesson": lesson, "why": why})
        if gram:
            p["grammar"] = gram
        pb_phrases.append(p)
    if subs - used_subs:
        fail(f"phrasebook {cid}: subcategories with no phrases: {subs - used_subs}")

pb_dialogues = []
for d in PB.DIALOGUES:
    where = f"dialogue {d['id']}"
    if d["category"] not in pb_cats:
        fail(f"{where}: unknown category")
    if len(d["lines"]) < 5:
        fail(f"{where}: too short")
    if {who for (who, _, _) in d["lines"]} != {0, 1}:
        fail(f"{where}: both sides must speak")
    lines = []
    for (who, ka, en) in d["lines"]:
        check_phrase_text(ka, where)
        lines.append({"who": who, "ka": ka, "lat": latin(ka), "en": en})
    notes = []
    for (ka, en, why) in d.get("notes", []):
        check_phrase_text(ka, where + " note")
        notes.append({"ka": ka, "lat": latin(ka), "en": en, "why": why})
    pb_dialogues.append({"id": "pd-" + d["id"], "category": d["category"], "title": d["title"],
                         "roles": list(d["roles"]), "lines": lines, "notes": notes})
if len({d["id"] for d in pb_dialogues}) != len(pb_dialogues):
    fail("dialogue ids used twice")

for k, targets in PB.SYNONYMS.items():
    if k != k.lower() or any(t != t.lower() for t in targets):
        fail(f"synonym {k}: use lower case")
if PB.PHRASEBOOK_STATUS not in ("claude", "native"):
    fail("PHRASEBOOK_STATUS must be claude or native")

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
write("phrasebook.json", {"version": VERSION, "checkedBy": PB.PHRASEBOOK_STATUS,
                         "categories": list(pb_cats.values()), "phrases": pb_phrases, "dialogues": pb_dialogues,
                         "synonyms": PB.SYNONYMS, "suggestions": PB.SUGGESTIONS})
lesson_count = sum(len(m["lessons"]) for m in modules)
print(f"OK: {len(letters)} letters, {len(words)} words and phrases, {len(modules)} modules, {lesson_count} lessons")
print(f"OK: phrasebook with {len(pb_cats)} categories, {len(pb_phrases)} phrases, {len(pb_dialogues)} dialogues")
