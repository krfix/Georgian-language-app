#!/usr/bin/env python3
"""Lists string literals in the app that look like English shown to the learner but are not
inside tr(…). Run after changing screens:  python3 tools/l10n/untranslated.py"""
import re, sys, glob
SKIP_CALL = re.compile(r'(systemName|systemImage|accessibilityIdentifier|forKey|forResource|withExtension|named|tag|Image|subdirectory|identifier|category|id|symbol|color|appending|path|contains|hasPrefix|hasSuffix|arguments|value\(|firstIndex\(of|font|DateFormat|dateFormat|setLocalizedDateFormatFromTemplate)\s*[:(]\s*$')
lit = re.compile(r'"((?:[^"\\\n]|\\.)*)"')
files = sys.argv[1:] or [f for f in glob.glob("Georgian/**/*.swift", recursive=True)]
n = 0
for f in sorted(files):
    for ln, line in enumerate(open(f, encoding="utf-8"), 1):
        s = line.strip()
        if s.startswith("//") or s.startswith("///") or s.startswith("case ") and "return" not in s and '"' not in s:
            continue
        for m in lit.finditer(line):
            text = m.group(1)
            if not re.search(r"[A-Za-z]{2,}", text):
                continue
            if re.fullmatch(r"[a-z0-9._\-]+(\.[a-z0-9.]+)*", text):   # symbols, ids, keys
                continue
            if re.fullmatch(r"[a-z][A-Za-z0-9]*", text):  # camelCase keys
                continue
            before = line[:m.start()]
            if re.search(r'tr\(\s*$', before) or SKIP_CALL.search(before):
                continue
            n += 1
            print(f"{f}:{ln}: {text}")
print(n, "found", file=sys.stderr)
