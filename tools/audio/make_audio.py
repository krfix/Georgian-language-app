#!/usr/bin/env python3
"""Makes the app's Georgian audio with Azure's Eka voice (synthetic speech), once.

    python3 tools/audio/make_audio.py            # only the clips still missing
    python3 tools/audio/make_audio.py --list     # just count what would be made

Every Georgian text the app can play gets one MP3 in Georgian/Resources/Audio, named after
a hash of the text, and Georgian/Resources/Audio/audio.json maps text -> file. The app reads
that index (AudioService) and labels these clips "Synthetic voice". Native recordings can
replace any clip later: same file name, and "native" for it in the index.

The key: in a cloud session the network proxy adds it (saved with request_credential); on
another machine set AZURE_SPEECH_KEY. AZURE_SPEECH_REGION defaults to northeurope.
"""
import hashlib
import json
import os
import sys
import time
import urllib.error
import urllib.request
from xml.sax.saxutils import escape

HERE = os.path.dirname(os.path.abspath(__file__))
CUR = os.path.join(HERE, "..", "..", "Georgian", "Resources", "Curriculum")
OUT = os.path.join(HERE, "..", "..", "Georgian", "Resources", "Audio")
VOICE = "ka-GE-EkaNeural"
REGION = os.environ.get("AZURE_SPEECH_REGION", "northeurope")
KEY = os.environ.get("AZURE_SPEECH_KEY", "proxy-injected")


def load(name):
    with open(os.path.join(CUR, name), encoding="utf-8") as f:
        return json.load(f)


def texts():
    """Every Georgian text with a speaker button, and what to say for it."""
    out = {}
    letters = load("letters.json")["letters"]
    vowels = set("აეიოუ")
    for l in letters:
        # A letter alone is read oddly; its sound is clearest in a syllable (კ → კა).
        out[l["char"]] = l["char"] if l["char"] in vowels else l["char"] + "ა"
        out[l["word"]] = l["word"]
    for w in load("vocabulary.json")["words"]:
        out[w["ka"]] = w["ka"]
        out[w["example"]["ka"]] = w["example"]["ka"]
    for m in load("course.json")["modules"]:
        for lesson in m["lessons"]:
            for g in lesson.get("read", []):
                out[g["ka"]] = g["ka"]
            d = lesson.get("dialogue")
            if d:
                for line in d["lines"]:
                    out[line["ka"]] = line["ka"]
    # The phrasebook: phrases, their other forms, replies you may hear, dialogue lines.
    pb = load("phrasebook.json")
    for ph in pb["phrases"]:
        out[ph["ka"]] = ph["ka"]
        for v in ph.get("variants", []) + ph.get("replies", []):
            out[v["ka"]] = v["ka"]
    for d in pb["dialogues"]:
        for line in d["lines"]:
            out[line["ka"]] = line["ka"]
    return {k: v for k, v in out.items() if "___" not in k}


def file_name(text):
    return "ka-" + hashlib.sha1(text.encode("utf-8")).hexdigest()[:12] + ".mp3"


def speak(spoken):
    ssml = (f'<speak version="1.0" xml:lang="ka-GE"><voice name="{VOICE}">'
            f'<prosody rate="-8%">{escape(spoken)}</prosody></voice></speak>')
    req = urllib.request.Request(
        f"https://{REGION}.tts.speech.microsoft.com/cognitiveservices/v1",
        data=ssml.encode("utf-8"), method="POST",
        headers={"Ocp-Apim-Subscription-Key": KEY, "Content-Type": "application/ssml+xml",
                 "X-Microsoft-OutputFormat": "audio-24khz-48kbitrate-mono-mp3",
                 "User-Agent": "georgian-app-audio"})
    for attempt in range(6):
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                return r.read()
        except urllib.error.HTTPError as e:
            if e.code == 429 or e.code >= 500:
                time.sleep(10 * (attempt + 1))
                continue
            raise
    raise RuntimeError("Azure kept refusing: " + spoken)


def main():
    items = texts()
    os.makedirs(OUT, exist_ok=True)
    index_path = os.path.join(OUT, "audio.json")
    index = {"version": 1, "voice": "Eka (Azure neural, ka-GE)", "clips": {}}
    if os.path.exists(index_path):
        with open(index_path, encoding="utf-8") as f:
            index = json.load(f)
    missing = [t for t in items if not os.path.exists(os.path.join(OUT, file_name(t)))]
    print(f"{len(items)} texts, {len(missing)} to make")
    if "--list" in sys.argv:
        return
    for n, text in enumerate(missing, 1):
        audio = speak(items[text])
        with open(os.path.join(OUT, file_name(text)), "wb") as f:
            f.write(audio)
        if n % 25 == 0:
            print(f"  {n}/{len(missing)}", flush=True)
        time.sleep(0.4)
    clips = {}
    for text in sorted(items):
        old = index["clips"].get(text, {})
        clips[text] = {"file": file_name(text), "source": old.get("source", "synthetic")}
    index["clips"] = clips
    with open(index_path, "w", encoding="utf-8") as f:
        json.dump(index, f, ensure_ascii=False, indent=1)
        f.write("\n")
    total = sum(os.path.getsize(os.path.join(OUT, c["file"])) for c in clips.values())
    print(f"done: {len(clips)} clips, {total / 1e6:.1f} MB")


main()
