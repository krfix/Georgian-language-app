#!/usr/bin/env python3
"""Builds the web app into web/dist/, ready to put on any web server:

    python3 web/build.py            # build
    python3 web/build.py --serve    # build, then serve it at http://localhost:8000

The web app's own files (web/index.html, app.css, js/, fonts/, icons/) are copied as they
are. The content comes straight from the iPhone app's checked files, so both apps always say
the same thing:
- Georgian/Resources/Curriculum: the phrasebook, the course, the words, the letters and the
  word glossary (English and Polish);
- Georgian/Resources/Localization/ui-pl.json: the Polish for the app's own words;
- Georgian/Resources/Audio: every clip, in both voices, with a small index per voice.
The service worker (sw.js) gets a version made from everything it serves, so a new build
replaces the old one on people's phones, and the list of files to keep for offline use.
Fails if a text on screen has no Polish (tools/l10n/check_strings.py).
"""
import hashlib
import http.server
import json
import os
import shutil
import subprocess
import sys

WEB = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(WEB)
RES = os.path.join(ROOT, "Georgian", "Resources")
DIST = os.path.join(WEB, "dist")
OWN = ["index.html", "app.css", "manifest.webmanifest", "js", "fonts", "icons"]


def load(*parts):
    with open(os.path.join(RES, *parts), encoding="utf-8") as f:
        return json.load(f)


def dump(obj, *parts):
    path = os.path.join(DIST, *parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(obj, f, ensure_ascii=False, separators=(",", ":"))


def main():
    check = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "l10n", "check_strings.py")],
                           capture_output=True, text=True)
    if check.returncode != 0:
        print(check.stdout)
        sys.exit("Some texts have no Polish: add them to tools/l10n/ui_pl.py, run it, then build again.")

    shutil.rmtree(DIST, ignore_errors=True)
    os.makedirs(DIST)
    for name in OWN:
        src = os.path.join(WEB, name)
        if os.path.isdir(src):
            shutil.copytree(src, os.path.join(DIST, name))
        else:
            shutil.copy2(src, os.path.join(DIST, name))

    # Content, in both languages: the phrasebook, the course, the words (with "More words"),
    # the letters and the word glossary, exactly as the iPhone app has them.
    for suffix in ("", "-pl"):
        for name in ("phrasebook", "course", "vocabulary", "letters", "glossary"):
            dump(load("Curriculum", f"{name}{suffix}.json"), "data", f"{name}{suffix}.json")
    dump(load("Localization", "ui-pl.json"), "data", "ui-pl.json")

    # Audio: every clip, in both voices (letters, words, examples, phrases, conversations).
    os.makedirs(os.path.join(DIST, "audio"))
    copied = set()
    sizes = {}
    # Only the voices in the app (Eka is off for now, KART #18: web/js/audio.js VOICES).
    for voice, index in (("giorgi", "audio-giorgi.json"),):
        clips = load("Audio", index)["clips"]
        out = {}
        total = 0
        for t, c in sorted(clips.items()):
            src = os.path.join(RES, "Audio", c["file"])
            # The published name carries a fingerprint of the sound: a clip whose sound changes
            # (a new voice, a native recording) gets a new name, so a browser never plays a
            # copy it kept of the old one (KART #18: Luka replaced Giorgi under the same names).
            with open(src, "rb") as f:
                tag = hashlib.sha1(f.read()).hexdigest()[:8]
            name = c["file"][:-4] + "-" + tag + ".mp3"
            out[t] = [name, c.get("source", "synthetic")]
            total += os.path.getsize(src)
            if name not in copied:
                shutil.copy2(src, os.path.join(DIST, "audio", name))
                copied.add(name)
        dump(out, "audio", f"{voice}.json")
        sizes[voice] = total
    dump(sizes, "audio", "sizes.json")

    # The service worker: a version from every file it serves, and the files to keep offline
    # (everything but the clips, which are kept as they're played or all at once from Settings).
    digest = hashlib.sha256()
    shell = []
    for folder, _, files in sorted(os.walk(DIST)):
        for fn in sorted(files):
            path = os.path.join(folder, fn)
            rel = os.path.relpath(path, DIST).replace(os.sep, "/")
            with open(path, "rb") as f:
                digest.update(rel.encode() + f.read())
            if not rel.endswith(".mp3") and not rel.startswith("fonts/OFL") and not rel.endswith("-64.png"):
                shell.append(rel)
    version = digest.hexdigest()[:10]
    shell = ["./"] + [r for r in shell if r != "index.html"]
    with open(os.path.join(WEB, "sw.js"), encoding="utf-8") as f:
        sw = (f.read().replace("__VERSION__", version).replace("__SHELL__", json.dumps(shell))
              .replace("__AUDIO_INDEXES__", json.dumps([f"audio/{v}.json" for v in sizes])))
    with open(os.path.join(DIST, "sw.js"), "w", encoding="utf-8") as f:
        f.write(sw)
    with open(os.path.join(DIST, "version.json"), "w") as f:
        json.dump({"version": version}, f)

    mb = sum(os.path.getsize(os.path.join(DIST, "audio", f)) for f in copied) / 1e6
    print(f"web/dist: version {version}, {len(shell)} files kept offline, {len(copied)} clips ({mb:.1f} MB)")

    if "--serve" in sys.argv:
        os.chdir(DIST)
        print("Serving at http://localhost:8000 (Ctrl+C to stop)")
        http.server.ThreadingHTTPServer(("", 8000), http.server.SimpleHTTPRequestHandler).serve_forever()


if __name__ == "__main__":
    main()
