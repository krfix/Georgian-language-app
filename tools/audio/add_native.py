#!/usr/bin/env python3
"""Puts a native speaker's recordings into the app (docs/native-recordings.md).

    python3 tools/audio/add_native.py <folder with recordings>

Each recording is named after the exact Georgian text it says, as in audio.json: for a
letter, the letter itself (კ.m4a, even though it's said as კა), for a word or phrase the
whole text (გამარჯობა.m4a, ეს რა ღირს?.m4a). Any format ffmpeg reads (m4a from the iPhone's
Voice Memos, wav, mp3). Each is cleaned up (silence trimmed at both ends, loudness evened
out, mono MP3 like the other clips), takes the place of Eka's synthetic clip for that text,
and is marked "native" in audio.json: the app and the web then label it "Native recording"
and play it whichever voice the learner chose. Giorgi's synthetic clip stays as a spare.
Recordings whose name isn't a text in the app are listed and left out.
Options: --audio <dir> works on another copy of Resources/Audio (for trying it out).
  --voice giorgi --converted: a native recording changed into another voice (ElevenLabs'
  Voice Changer, for a speaker who doesn't want to be recognised). It replaces only that
  voice's clip, is marked "converted" and labelled "Native recording, voice changed"; the
  other voice keeps its own clip.
"""
import json
import os
import subprocess
import sys
import unicodedata

HERE = os.path.dirname(os.path.abspath(__file__))
AUDIO = os.path.join(HERE, "..", "..", "Georgian", "Resources", "Audio")


def main():
    args = sys.argv[1:]
    audio_dir = AUDIO
    index_name, source = "audio.json", "native"
    if "--voice" in args:
        i = args.index("--voice")
        index_name = {"eka": "audio.json", "giorgi": "audio-giorgi.json"}[args[i + 1]]
        del args[i:i + 2]
    if "--converted" in args:
        args.remove("--converted")
        source = "converted"
    if "--audio" in args:
        i = args.index("--audio")
        audio_dir = args[i + 1]
        del args[i:i + 2]
    if len(args) != 1:
        sys.exit(__doc__)
    folder = args[0]
    index_path = os.path.join(audio_dir, index_name)
    with open(index_path, encoding="utf-8") as f:
        index = json.load(f)
    clips = index["clips"]
    done, unknown = [], []
    for name in sorted(os.listdir(folder)):
        if name.startswith("."):
            continue
        text = unicodedata.normalize("NFC", os.path.splitext(name)[0]).strip()
        if text not in clips:
            unknown.append(name)
            continue
        out = os.path.join(audio_dir, clips[text]["file"])
        subprocess.run(
            ["ffmpeg", "-loglevel", "error", "-y", "-i", os.path.join(folder, name),
             "-af", "silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.08,"
                    "areverse,silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.15,areverse,"
                    "loudnorm=I=-18:TP=-2:LRA=7",
             "-ac", "1", "-ar", "24000", "-b:a", "48k", out],
            check=True)
        clips[text]["source"] = source
        done.append(text)
    with open(index_path, "w", encoding="utf-8") as f:
        json.dump(index, f, ensure_ascii=False, indent=1)
        f.write("\n")
    print(f"{source} recordings in place: {len(done)}" + (f" ({', '.join(done)})" if len(done) <= 40 else ""))
    if unknown:
        print(f"not a text in the app, left out: {', '.join(unknown)}")
    counts = {}
    for c in clips.values():
        counts[c.get("source", "synthetic")] = counts.get(c.get("source", "synthetic"), 0) + 1
    print(f"{index_name}: " + ", ".join(f"{n} {k}" for k, n in sorted(counts.items())))


if __name__ == "__main__":
    main()
