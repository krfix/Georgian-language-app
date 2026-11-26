#!/usr/bin/env python3
"""Makes the app's Georgian audio (synthetic speech), once.

    python3 tools/audio/make_audio.py                 # both voices, only the clips still missing
    python3 tools/audio/make_audio.py --voice giorgi  # one voice (eka or giorgi)
    python3 tools/audio/make_audio.py --list          # just count what would be made

The male voice ("giorgi" inside the code, files "kam-…") is ElevenLabs' Luka since KART #18
(model eleven_v4, the owner's choice; key added by the proxy for api.elevenlabs.io). Each clip
records who made it ("by"); a clip made by another voice is made again, so changing a voice
here remakes its clips, and a run that stopped carries on where it left off. Clips a person
recorded ("native", "converted") are never touched. Eka is Azure's (off in the app since KART
#18, its clips kept in the repo).

Two voices, chosen by the learner (onboarding and Profile, KART #5): Eka (female, the
owner's choice in KART #1) and Giorgi (male). Every Georgian text the app can play gets one
MP3 per voice in Georgian/Resources/Audio, named after a hash of the text ("ka-…" for Eka,
"kam-…" for Giorgi), and an index maps text -> file: audio.json (Eka), audio-giorgi.json. The app reads
that index (AudioService) and labels these clips "Synthetic voice". Native recordings can
replace any clip later: same file name, and "native" for it in the index.

The key: in a cloud session the network proxy adds it (saved with request_credential); on
another machine set AZURE_SPEECH_KEY. AZURE_SPEECH_REGION defaults to northeurope.
"""
import hashlib
import json
import os
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor
import urllib.error
import urllib.request
from xml.sax.saxutils import escape

HERE = os.path.dirname(os.path.abspath(__file__))
CUR = os.path.join(HERE, "..", "..", "Georgian", "Resources", "Curriculum")
OUT = os.path.join(HERE, "..", "..", "Georgian", "Resources", "Audio")
# name -> (Azure voice, file prefix, index file, label in the index)
VOICES = {
    "eka": ("ka-GE-EkaNeural", "ka-", "audio.json", "Eka (Azure neural, ka-GE)"),
    "giorgi": ("elevenlabs:NkleFxaKTmzKRWhuoRqb", "kam-", "audio-giorgi.json", "Luka (ElevenLabs eleven_v4, ka)"),
}
ELEVEN_MODEL = "eleven_v4"
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
    vocabulary = load("vocabulary.json")
    for w in vocabulary["words"] + vocabulary.get("more", []):
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


def file_name(text, prefix="ka-"):
    return prefix + hashlib.sha1(text.encode("utf-8")).hexdigest()[:12] + ".mp3"


def speak(spoken, voice):
    ssml = (f'<speak version="1.0" xml:lang="ka-GE"><voice name="{voice}">'
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


def speak_eleven(spoken, voice_id):
    """ElevenLabs text to speech, then the same MP3 format as the other clips (24 kHz mono)."""
    body = json.dumps({"text": spoken, "model_id": ELEVEN_MODEL, "language_code": "ka"}).encode()
    req = urllib.request.Request(
        f"https://api.elevenlabs.io/v1/text-to-speech/{voice_id}?output_format=mp3_44100_128",
        data=body, method="POST",
        headers={"Content-Type": "application/json", "xi-api-key": "proxy-injected",
                 "User-Agent": "georgian-app-audio"})
    for attempt in range(6):
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                raw = r.read()
            break
        except urllib.error.HTTPError as e:
            if e.code == 429 or e.code >= 500:
                time.sleep(10 * (attempt + 1))
                continue
            raise RuntimeError(f"ElevenLabs {e.code}: {e.read()[:300]!r} for {spoken}")
    else:
        raise RuntimeError("ElevenLabs kept refusing: " + spoken)
    out = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", "pipe:0", "-ac", "1", "-ar", "24000",
                          "-b:a", "48k", "-f", "mp3", "pipe:1"], input=raw, capture_output=True, check=True)
    return out.stdout


def make(items, name):
    voice, prefix, index_file, label = VOICES[name]
    os.makedirs(OUT, exist_ok=True)
    index_path = os.path.join(OUT, index_file)
    index = {"version": 1, "voice": label, "clips": {}}
    if os.path.exists(index_path):
        with open(index_path, encoding="utf-8") as f:
            index = json.load(f)
    old_clips = index["clips"]

    def needed(t):
        old = old_clips.get(t, {})
        if old.get("source", "synthetic") != "synthetic":
            return False  # a person's recording: never replaced here
        if not os.path.exists(os.path.join(OUT, file_name(t, prefix))):
            return True
        # Clips from before "by" existed were made by Azure: kept for an Azure voice.
        return old.get("by", "" if voice.startswith("elevenlabs:") else voice) != voice

    missing = [t for t in items if needed(t)]
    print(f"{name}: {len(items)} texts, {len(missing)} to make ({sum(len(items[t]) for t in missing)} characters)")
    if "--list" in sys.argv:
        return

    def save():
        clips = {}
        for text in sorted(items):
            old = old_clips.get(text, {})
            clip = {"file": file_name(text, prefix), "source": old.get("source", "synthetic")}
            if "by" in old:
                clip["by"] = old["by"]
            clips[text] = clip
        index["clips"] = clips
        index["voice"] = label
        with open(index_path, "w", encoding="utf-8") as f:
            json.dump(index, f, ensure_ascii=False, indent=1)
            f.write("\n")
        return clips

    def one(text):
        if voice.startswith("elevenlabs:"):
            audio = speak_eleven(items[text], voice.split(":", 1)[1])
        else:
            audio = speak(items[text], voice)
            time.sleep(0.4)
        with open(os.path.join(OUT, file_name(text, prefix)), "wb") as f:
            f.write(audio)
        return text

    workers = 3 if voice.startswith("elevenlabs:") else 1
    with ThreadPoolExecutor(workers) as pool:
        for n, text in enumerate(pool.map(one, missing), 1):
            old_clips.setdefault(text, {"source": "synthetic"})["by"] = voice
            if n % 25 == 0:
                save()
                print(f"  {n}/{len(missing)}", flush=True)
    clips = save()
    total = sum(os.path.getsize(os.path.join(OUT, c["file"])) for c in clips.values())
    print(f"{name} done: {len(clips)} clips, {total / 1e6:.1f} MB")


def main():
    items = texts()
    names = list(VOICES)
    if "--voice" in sys.argv:
        names = [sys.argv[sys.argv.index("--voice") + 1]]
    for name in names:
        make(items, name)


if __name__ == "__main__":
    main()
