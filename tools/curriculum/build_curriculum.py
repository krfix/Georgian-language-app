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
        if L["id"] in getattr(C, "INTROS", {}):
            it, ix = C.INTROS[L["id"]]
            out["intro"] = {"title": it, "text": ix, "table": []}
        lessons.append(out)
    modules.append({"id": m["id"], "title": m["title"], "subtitle": m["subtitle"], "symbol": m["symbol"],
                    "color": m["color"], "intro": m["intro"], "lessons": lessons})

for lid in getattr(C, "INTROS", {}):
    if lid not in seen_lessons:
        fail(f"intro for unknown lesson {lid}")
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

# ---- Polish (content_pl.py): the same content for Polish speakers. The Georgian, its Latin
# spelling and every id stay the same; the meanings, explanations and the sound guide are
# Polish. Grammar notes and pronunciation are written for Polish speakers (comparisons with
# Polish), not translated word for word. Anything without a Polish text stops the build.
import copy  # noqa: E402

try:
    import content_pl as PL  # noqa: E402
except ImportError:
    PL = None

missing = {}
DUMP = "--missing" in sys.argv

POLISH_SOUND = {
    "ა": "a", "ბ": "b", "გ": "g", "დ": "d", "ე": "e", "ვ": "w", "ზ": "z", "თ": "t", "ი": "i",
    "კ": "k", "ლ": "l", "მ": "m", "ნ": "n", "ო": "o", "პ": "p", "ჟ": "ż", "რ": "r", "ს": "s",
    "ტ": "t", "უ": "u", "ფ": "p", "ქ": "k", "ღ": "gh", "ყ": "k", "შ": "sz", "ჩ": "cz", "ც": "c",
    "ძ": "dz", "წ": "c", "ჭ": "cz", "ხ": "ch", "ჯ": "dż", "ჰ": "h",
}


def sound_word_pl(word):
    letters = [ch for ch in word if ch in LATIN]
    if not letters:
        return word
    vowels = [i for i, ch in enumerate(letters) if ch in VOWELS]
    if not vowels:
        return "".join(POLISH_SOUND[ch] for ch in letters)
    cuts = []
    for a, b in zip(vowels, vowels[1:]):
        gap = b - a - 1
        cuts.append(a + 1 if gap <= 1 else a + 2)
    parts, start = [], 0
    for c in cuts + [len(letters)]:
        parts.append(letters[start:c])
        start = c
    return "-".join("".join(POLISH_SOUND[ch] for ch in p) for p in parts)


def sound_pl(ka):
    out = []
    for tok in ka.split():
        core = tok.strip(".,?!—–:;\"«»…")
        if not core:
            continue
        if any(ch in LATIN for ch in core):
            out.append("-".join(sound_word_pl(piece) for piece in core.split("-") if piece))
        else:
            out.append(core)
    return " ".join(out)


def t(en, where):
    """The Polish for an English text (content_pl.T)."""
    if en is None or en == "" or not re.search(r"[A-Za-z]", en):
        return en
    if PL is not None and en in getattr(PL, "T", {}):
        return PL.T[en]
    missing.setdefault("T", {})[en] = where
    return en


def is_english(text):
    return bool(re.search(r"[A-Za-z]", text)) or not letters_of(text)


def polish_letters():
    out = copy.deepcopy(letters)
    for l in out:
        pl = getattr(PL, "LETTERS", {}).get(l["char"]) if PL else None
        if not pl:
            missing.setdefault("LETTERS", {})[l["char"]] = (l["sound"], l["meaning"], l["tip"])
            continue
        l["sound"], l["meaning"], l["tip"] = pl
    return out


def polish_words():
    out = copy.deepcopy(words)
    for w in out:
        pl = PL.WORDS.get(w["ka"]) if PL else None
        if not pl:
            missing.setdefault("WORDS", {})[w["ka"]] = (w["en"], w["alt"], w["example"]["en"], w.get("note"))
            continue
        en, alt, ex, note = pl
        w["en"], w["alt"], w["example"]["en"] = en, alt, ex
        if note:
            w["note"] = note
        elif "note" in w:
            missing.setdefault("WORDS", {})[w["ka"]] = (w["en"], w["alt"], w["example"]["en"], w.get("note"))
        w.pop("pron", None)
    return out


def polish_course():
    out = copy.deepcopy(modules)
    for m in out:
        where = "module " + m["id"]
        for k in ("title", "subtitle", "intro"):
            m[k] = t(m[k], where)
        for L in m["lessons"]:
            where = "lesson " + L["id"]
            L["title"] = t(L["title"], where)
            if is_english(L["subtitle"]) and L["kind"] not in ("contrast",):
                L["subtitle"] = t(L["subtitle"], where)
            if L.get("note"):
                L["note"] = t(L["note"], where)
            if L.get("intro"):
                L["intro"]["title"] = t(L["intro"]["title"], where)
                L["intro"]["text"] = t(L["intro"]["text"], where)
            for g in L.get("read", []):
                g["en"] = t(g["en"], where)
            for n in L.get("notes", []):
                n["title"] = t(n["title"], where)
                n["text"] = t(n["text"], where)
                for row in n["table"]:
                    row["en"] = t(row["en"], where)
            for e in L.get("exercises", []):
                for k in ("prompt", "explanation", "translation", "english"):
                    if e.get(k):
                        e[k] = t(e[k], where)
                if e.get("options") and e["type"] == "choice":
                    e["options"] = [t(o, where) if is_english(o) else o for o in e["options"]]
            if L.get("dialogue"):
                d = L["dialogue"]
                d["partner"] = t(d["partner"], where)
                for line in d["lines"]:
                    line["en"] = t(line["en"], where)
                    if line["speaker"] != "You":
                        line["speaker"] = t(line["speaker"], where)
    return out


def polish_phrasebook():
    cats = copy.deepcopy(list(pb_cats.values()))
    for c in cats:
        where = "phrasebook category " + c["id"]
        c["title"] = t(c["title"], where)
        c["blurb"] = t(c["blurb"], where)
        for s in c["subs"]:
            s["title"] = t(s["title"], where)
    phrases = copy.deepcopy(pb_phrases)
    for p in phrases:
        where = "phrase " + p["ka"]
        pl = getattr(PL, "PHRASES", {}).get(p["ka"]) if PL else None
        if not pl:
            missing.setdefault("PHRASES", {})[p["ka"]] = (p["en"], " ".join(p["keywords"]))
        else:
            p["en"], kw = pl
            p["keywords"] = [k.lower() for k in kw.split()]
        p["sound"] = sound_pl(p["ka"])
        for k in ("lit", "note"):
            if p.get(k):
                p[k] = t(p[k], where)
        for v in p.get("variants", []):
            v["label"] = t(v["label"], where)
            v["en"] = t(v["en"], where)
        for r in p.get("replies", []):
            r["en"] = t(r["en"], where)
        for g in p.get("grammar", []):
            g["why"] = t(g["why"], where)
    dialogues = copy.deepcopy(pb_dialogues)
    for d in dialogues:
        where = "dialogue " + d["id"]
        d["title"] = t(d["title"], where)
        d["roles"] = [t(r, where) for r in d["roles"]]
        for line in d["lines"]:
            line["en"] = t(line["en"], where)
        for n in d["notes"]:
            n["en"] = t(n["en"], where)
            n["why"] = t(n["why"], where)
    synonyms = getattr(PL, "SYNONYMS", {})
    suggestions = getattr(PL, "SUGGESTIONS", [])
    for k, targets in synonyms.items():
        if k != k.lower() or any(x != x.lower() for x in targets):
            fail(f"Polish synonym {k}: use lower case")
    return cats, phrases, dialogues, synonyms, suggestions


# ---- Tappable words (content_glossary.py): every word in examples, conversations and phrases.
import content_glossary as G  # noqa: E402

TOKEN_SPLIT = re.compile(r"[\s,.?!—–:;\"«»…]+")


def tokens(text):
    out = []
    for x in TOKEN_SPLIT.split(text):
        x = x.strip("-")
        if x and any(ch in LATIN for ch in x):
            out.append(x)
    return out


gloss_sentences = []
for w in words:
    gloss_sentences += [w["ka"], w["example"]["ka"]]
for m in modules:
    for L in m["lessons"]:
        for line in (L.get("dialogue") or {}).get("lines", []):
            gloss_sentences.append(line["ka"])
        for g in L.get("read", []):
            gloss_sentences.append(g["ka"])
for p in pb_phrases:
    gloss_sentences.append(p["ka"])
    gloss_sentences += [f["ka"] for f in p.get("variants", []) + p.get("replies", [])]
for d in pb_dialogues:
    gloss_sentences += [line["ka"] for line in d["lines"]]
    gloss_sentences += [n["ka"] for n in d["notes"]]

# Dictionary words: course words (one word only) and BASES; meanings in both languages.
pl_word_by_ka = {}
if PL is not None:
    for ka, val in getattr(PL, "WORDS", {}).items():
        pl_word_by_ka[ka] = val[0]
dictionary = {}
for w in words:
    bare_ka = w["ka"].strip("?.!")
    if " " not in bare_ka and bare_ka not in dictionary:
        dictionary[bare_ka] = (w["en"], pl_word_by_ka.get(w["ka"], w["en"]))
for ka, (en, pl) in G.BASES.items():
    check_georgian(ka, "glossary base")
    dictionary.setdefault(ka, (en, pl))


def analyse(t):
    """(base, [notes as (en, pl)]) or None."""
    if t in dictionary:
        return t, []
    for e_ka, e_en, e_pl in G.ENDINGS:
        if t.endswith(e_ka) and len(t) > len(e_ka) + 1:
            stem = t[: -len(e_ka)]
            for b in (stem, stem + "ი", stem + "ა", stem + "ე", stem + "ო"):
                if b in dictionary:
                    return b, [(e_en, e_pl)]
    if t.endswith("ც") and len(t) > 2:
        r = analyse(t[:-1])
        if r:
            return r[0], r[1] + [G.ALSO]
    if t.endswith("ა") and len(t) > 2:
        if t[:-1] + "ი" in dictionary:
            return t[:-1] + "ი", [G.COPULA]
        r = analyse(t[:-1])
        if r:
            return r[0], r[1] + [G.COPULA]
    if t + "ი" in dictionary:
        return t + "ი", [G.DROPPED_I]
    return None


glossary_en, glossary_pl, unexplained = {}, {}, []


def explain(tok):
    """Adds the word to the glossary; False if it can't be explained."""
    if tok in glossary_en:
        return True
    if tok in G.FORMS:
        base, en, pl, note_en, note_pl = G.FORMS[tok]
        check_georgian(re.sub(r"[0-9]", "", tok), "glossary form")
        e_en = {"lat": latin(tok), "meaning": en}
        e_pl = {"lat": latin(tok), "meaning": pl}
        if base:
            e_en["base"] = e_pl["base"] = base
            e_en["baseLat"] = e_pl["baseLat"] = latin(base)
            if base in dictionary:
                e_en["baseMeaning"], e_pl["baseMeaning"] = dictionary[base]
        if note_en:
            e_en["note"], e_pl["note"] = note_en, note_pl
        glossary_en[tok], glossary_pl[tok] = e_en, e_pl
        return True
    r = analyse(tok)
    if not r:
        return False
    base, notes = r
    en, pl = dictionary[base]
    e_en = {"lat": latin(tok)}
    e_pl = {"lat": latin(tok)}
    if base != tok:
        e_en["base"] = e_pl["base"] = base
        e_en["baseLat"] = e_pl["baseLat"] = latin(base)
        e_en["baseMeaning"], e_pl["baseMeaning"] = en, pl
    else:
        e_en["meaning"], e_pl["meaning"] = en, pl
    if notes:
        e_en["note"] = "\n".join(n[0] for n in notes)
        e_pl["note"] = "\n".join(n[1] for n in notes)
    glossary_en[tok], glossary_pl[tok] = e_en, e_pl
    return True


for s_ in gloss_sentences:
    for tok in tokens(s_):
        if not any(ch in LATIN for ch in tok):
            continue
        if not explain(tok):
            unexplained.append(tok)
unexplained = sorted(set(unexplained), key=lambda x: (-sum(s_.count(x) for s_ in gloss_sentences), x))
if "--glossary" in sys.argv:
    print(f"# {len(glossary_en)} explained, {len(unexplained)} not")
    print(" ".join(unexplained))
    sys.exit(0)
for t in unexplained[:20]:
    fail(f"glossary: no explanation for {t!r} (add it to content_glossary.py)")
if len(unexplained) > 20:
    fail(f"glossary: … and {len(unexplained) - 20} more (run with --glossary to list them)")

pl_letters = polish_letters()
pl_words = polish_words()
pl_categories = [{**c, "title": t(c["title"], "category " + c["id"])} for c in categories]
pl_modules = polish_course()
pl_pb = polish_phrasebook()

# Words in "Before you start" cards and grammar notes (KART #6) can be tapped too. Pieces
# written with a hyphen (-ში, წა-ვ-ედი) and single letters are about spelling, not words:
# the app doesn't make them tappable, and they need no explanation.
NOTE_SPLIT = re.compile(r"[\s,.?!—–:;\"«»…()„”“]+")


def note_tokens(text):
    for x in NOTE_SPLIT.split(text):
        if x and "-" not in x and len(x) > 1 and all(ch in LATIN for ch in x):
            yield x


note_unexplained = []
for mods in (modules, pl_modules):
    for m in mods:
        for L in m["lessons"]:
            texts = [n["text"] for n in L.get("notes", [])]
            if L.get("intro"):
                texts.append(L["intro"]["text"])
            for x in texts:
                for tok in note_tokens(x):
                    if not explain(tok):
                        note_unexplained.append(tok)
note_unexplained = sorted(set(note_unexplained))
if "--notes" in sys.argv:
    print(f"# words in notes not explained: {len(note_unexplained)}")
    print(" ".join(note_unexplained))
    sys.exit(0)
for t_ in note_unexplained[:20]:
    fail(f"note words: no explanation for {t_!r} (add it to content_glossary.py)")

# ---- More words (KART #5): every Georgian word the app shows anywhere (letters, examples,
# conversations, phrases, grammar tables, exercises) is in the Words tab. Words outside the
# course's own vocabulary go into the "more" list of vocabulary.json, each with a sentence
# where it appears (or, for a letter's example word, the word itself).
def visible_texts():
    """(Georgian, English, Polish) for every Georgian text on screen; translations may be None."""
    out = []
    for w, wp in zip(words, pl_words):
        out.append((w["ka"], w["en"], wp["en"]))
        out.append((w["example"]["ka"], w["example"]["en"], wp["example"]["en"]))
    for m, mp in zip(modules, pl_modules):
        for L, Lp in zip(m["lessons"], mp["lessons"]):
            if not is_english(L["subtitle"]):
                out.append((L["subtitle"], None, None))
            for g, gp in zip(L.get("read", []), Lp.get("read", [])):
                out.append((g["ka"], g["en"], gp["en"]))
            for n, np_ in zip(L.get("notes", []), Lp.get("notes", [])):
                for row, rowp in zip(n["table"], np_["table"]):
                    out.append((row["ka"], row["en"], rowp["en"]))
            for e in L.get("exercises", []):
                # The right answer and the sentence tiles; wrong options can be made-up forms.
                opts = e.get("options") or []
                right = [opts[e["answer"]]] if isinstance(e.get("answer"), int) and e["answer"] < len(opts) else []
                for o in right + (e.get("tiles") or []):
                    if not is_english(o) and "___" not in o:
                        out.append((o, None, None))
                if e.get("sentence") and right:
                    out.append((e["sentence"].replace("___", right[0]), e.get("translation"), None))
            if L.get("dialogue"):
                for line, linep in zip(L["dialogue"]["lines"], Lp["dialogue"]["lines"]):
                    out.append((line["ka"], line["en"], linep["en"]))
    for p, pp in zip(pb_phrases, pl_pb[1]):
        out.append((p["ka"], p["en"], pp["en"]))
        for f, fp in zip(p.get("variants", []) + p.get("replies", []), pp.get("variants", []) + pp.get("replies", [])):
            out.append((f["ka"], f["en"], fp["en"]))
    for d, dp in zip(pb_dialogues, pl_pb[2]):
        for line, linep in zip(d["lines"], dp["lines"]):
            out.append((line["ka"], line["en"], linep["en"]))
        for n, np_ in zip(d["notes"], dp["notes"]):
            out.append((n["ka"], None, None))
    return out


def explain(tok):
    """(dictionary word, english, polish) for a word form, or None."""
    if tok in G.FORMS:
        base, en, pl, _, _ = G.FORMS[tok]
        if base and base in dictionary:
            return (base,) + dictionary[base]
        return tok, en, pl
    r = analyse(tok)
    if r:
        return (r[0],) + dictionary[r[0]]
    return None


course_ka = {w["ka"].strip("?.!") for w in words}
more_by_ka, more_unexplained = {}, []
pl_letter_meaning = {l["char"]: l["meaning"] for l in pl_letters}
for l in letters:
    if l["word"] not in course_ka:
        more_by_ka.setdefault(l["word"], {"en": l["meaning"], "pl": pl_letter_meaning[l["char"]],
                                          "letter": l["char"], "seen": []})
texts_ = visible_texts()
for ka, en, pl in texts_:
    for tok in tokens(ka):
        if re.search(r"[0-9/_]", tok) or len(tok) < 2:
            continue
        r = explain(tok)
        if not r:
            more_unexplained.append(tok)
            continue
        base, b_en, b_pl = r
        # A shortened form before a noun (ერთ, კარგ, ახალ): the full word is the one to list.
        if base[-1] not in VOWELS and base + "ი" in dictionary:
            base, b_en, b_pl = (base + "ი",) + dictionary[base + "ი"]
        if base in course_ka:
            continue
        entry = more_by_ka.setdefault(base, {"en": b_en, "pl": b_pl, "seen": []})
        if en and pl:
            entry["seen"].append((ka, en, pl))
more_unexplained = sorted(set(more_unexplained))
if "--more" in sys.argv:
    print(f"# {len(more_by_ka)} more words; {len(more_unexplained)} not explained")
    print(" ".join(more_unexplained))
    sys.exit(0)
for tok in more_unexplained[:20]:
    fail(f"more words: no explanation for {tok!r} (add it to content_glossary.py)")
if len(more_unexplained) > 20:
    fail(f"more words: … and {len(more_unexplained) - 20} more (run with --more to list them)")

MORE_CATEGORY = {"id": "more", "title": "More words", "symbol": "text.book.closed.fill", "color": "blacksea"}
MORE_CATEGORY_PL = {**MORE_CATEGORY, "title": "Więcej słów"}
more_words, more_words_pl = [], []
used_ids = {w["id"] for w in words}
for ka in sorted(more_by_ka, key=latin):
    e = more_by_ka[ka]
    wid = "x-" + slug(ka)
    n = 2
    while wid in used_ids:
        wid = f"x-{slug(ka)}-{n}"
        n += 1
    used_ids.add(wid)
    if e["seen"]:
        # The shortest real sentence: more than the word itself, if there is one.
        ex_ka, ex_en, ex_pl = min(e["seen"], key=lambda s_: (len(tokens(s_[0])) < 2, len(s_[0]), s_[0]))
    else:
        ch = e.get("letter") or ka[0]
        ex_ka, ex_en, ex_pl = ka, f"{e['en']}: the example word for the letter {ch}", f"{e['pl']}: przykładowe słowo dla litery {ch}"
    base_ = {"id": wid, "ka": ka, "lat": latin(ka), "alt": [], "category": "more"}
    more_words.append({**base_, "en": e["en"], "example": {"ka": ex_ka, "lat": latin(ex_ka), "en": ex_en}})
    more_words_pl.append({**base_, "en": e["pl"], "example": {"ka": ex_ka, "lat": latin(ex_ka), "en": ex_pl}})

if DUMP:
    import pprint
    for section, items in missing.items():
        print(f"# ---- {section} ({len(items)})")
        pprint.pprint(items, width=160, sort_dicts=False)
    sys.exit(0)
for section, items in missing.items():
    for k in list(items)[:15]:
        fail(f"Polish: no {section} text for {k!r} ({items[k]!r:.80})")
    if len(items) > 15:
        fail(f"Polish: … and {len(items) - 15} more in {section} (run with --missing to list them)")

if errors:
    print("\n".join("ERROR " + e for e in errors))
    sys.exit(1)

os.makedirs(OUT, exist_ok=True)


def write(name, data):
    with open(os.path.join(OUT, name), "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
        f.write("\n")


write("letters.json", {"version": VERSION, "letters": letters, "lookalikes": C.LOOKALIKES})
write("vocabulary.json", {"version": VERSION, "categories": categories + [MORE_CATEGORY], "words": words,
                          "more": more_words})
write("course.json", {"id": "georgian-a0", "version": VERSION, "title": "Georgian from zero", "modules": modules})
write("phrasebook.json", {"version": VERSION, "checkedBy": PB.PHRASEBOOK_STATUS,
                         "categories": list(pb_cats.values()), "phrases": pb_phrases, "dialogues": pb_dialogues,
                         "synonyms": PB.SYNONYMS, "suggestions": PB.SUGGESTIONS})
# Polish: the same files with "-pl" (the field names stay: "en" holds the learner's language).
write("glossary.json", {"version": VERSION, "words": glossary_en})
write("glossary-pl.json", {"version": VERSION, "words": glossary_pl})
write("letters-pl.json", {"version": VERSION, "letters": pl_letters, "lookalikes": C.LOOKALIKES})
write("vocabulary-pl.json", {"version": VERSION, "categories": pl_categories + [MORE_CATEGORY_PL], "words": pl_words,
                             "more": more_words_pl})
write("course-pl.json", {"id": "georgian-a0", "version": VERSION, "title": "Gruziński od zera", "modules": pl_modules})
write("phrasebook-pl.json", {"version": VERSION, "checkedBy": PB.PHRASEBOOK_STATUS,
                            "categories": pl_pb[0], "phrases": pl_pb[1], "dialogues": pl_pb[2],
                            "synonyms": pl_pb[3], "suggestions": pl_pb[4]})
lesson_count = sum(len(m["lessons"]) for m in modules)
print(f"OK: {len(letters)} letters, {len(words)} words and phrases, {len(modules)} modules, {lesson_count} lessons")
print(f"OK: phrasebook with {len(pb_cats)} categories, {len(pb_phrases)} phrases, {len(pb_dialogues)} dialogues")
print("OK: Polish for all of it")
print(f"OK: {len(glossary_en)} tappable words explained")
print(f"OK: {len(more_words)} more words in the Words tab (seen in the app, outside the lessons)")
