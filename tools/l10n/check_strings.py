#!/usr/bin/env python3
"""Checks the Polish table of the app's own words.

    python3 tools/l10n/check_strings.py            # check (exit 1 if anything is missing)
    python3 tools/l10n/check_strings.py --missing  # print the missing keys as JSON to fill in

Every tr("English…") in Georgian/**/*.swift must have an entry in
Georgian/Resources/Localization/ui-pl.json with the same {0}, {1}… placeholders.
Entries no screen uses any more are listed too (not an error).
"""
import glob
import json
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
TABLE = os.path.join(ROOT, "Georgian", "Resources", "Localization", "ui-pl.json")
CALL = re.compile(r'(?:\btr\(\s*|\b(?:titleEN|detailEN):\s*)"((?:[^"\\\n]|\\.)*)"')


def unescape(s):
    s = re.sub(r"\\u\{([0-9A-Fa-f]+)\}", lambda m: chr(int(m.group(1), 16)), s)
    return s.replace('\\"', '"').replace("\\\\", "\\").replace("\\n", "\n")


def keys():
    out = {}
    for f in glob.glob(os.path.join(ROOT, "Georgian", "**", "*.swift"), recursive=True):
        for ln, line in enumerate(open(f, encoding="utf-8"), 1):
            for m in CALL.finditer(line):
                out.setdefault(unescape(m.group(1)), f"{os.path.relpath(f, ROOT)}:{ln}")
    return out


def main():
    used = keys()
    table = json.load(open(TABLE, encoding="utf-8")) if os.path.exists(TABLE) else {}
    missing = {k: v for k, v in used.items() if k not in table}
    if "--missing" in sys.argv:
        print(json.dumps({k: "" for k in missing}, ensure_ascii=False, indent=1))
        return 0
    bad = []
    for k, v in table.items():
        if k in used and sorted(re.findall(r"\{\d\}", k)) != sorted(re.findall(r"\{\d\}", v)):
            bad.append(k)
        if k in used and not v.strip():
            bad.append(k)
    for k, where in missing.items():
        print(f"MISSING {where}: {k!r}")
    for k in bad:
        print(f"PLACEHOLDERS OR EMPTY: {k!r} -> {table[k]!r}")
    unused = [k for k in table if k not in used]
    for k in unused:
        print(f"unused: {k!r}")
    print(f"{len(used)} texts, {len(missing)} missing, {len(bad)} wrong, {len(unused)} unused")
    return 1 if missing or bad else 0


if __name__ == "__main__":
    sys.exit(main())
