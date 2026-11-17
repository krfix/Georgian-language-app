#!/usr/bin/env python3
"""One-off helper (KART #4): wraps the English text in SwiftUI calls in tr(…).

    python3 tools/l10n/wrap_strings.py [--dry] files…

Text("Hello \\(name)") becomes Text(tr("Hello {0}", name)); markdown text gets
LocalizedStringKey(…) so ** still works. Text with no English letters is left alone.
"""
import re
import sys

CALLS = ["Text", "Button", "Label", "navigationTitle", "Section", "Picker", "Toggle", "LabeledContent",
         "TextField", "accessibilityLabel", "accessibilityHint", "accessibilityValue", "confirmationDialog",
         "alert", "DatePicker", "Stepper", "Link", "ContentUnavailableView"]
PARAMS = ["title", "subtitle", "text", "label", "detail", "message", "instruction", "caption", "hint",
          "placeholder", "header", "footer", "prompt", "action", "name", "value"]


def parse_literal(s, i):
    """s[i] == '"'. Returns (end index after closing quote, [pieces]) where pieces are str or ('expr', code)."""
    assert s[i] == '"'
    j = i + 1
    pieces, buf = [], ""
    while True:
        c = s[j]
        if c == "\\":
            if s[j + 1] == "(":
                # interpolation: find matching paren
                depth, k = 1, j + 2
                while depth:
                    if s[k] == "(":
                        depth += 1
                    elif s[k] == ")":
                        depth -= 1
                    elif s[k] == '"':
                        # nested string literal inside interpolation
                        k2, _ = parse_literal(s, k)
                        k = k2 - 1
                    k += 1
                pieces.append(buf)
                buf = ""
                pieces.append(("expr", s[j + 2:k - 1]))
                j = k
                continue
            buf += s[j:j + 2]
            j += 2
            continue
        if c == '"':
            pieces.append(buf)
            return j + 1, pieces
        if c == "\n":
            raise ValueError("multiline")
        buf += c
        j += 1


def english(pieces):
    text = "".join(p for p in pieces if isinstance(p, str))
    return re.search(r"[A-Za-z]{2,}", text) is not None


def build(pieces):
    key, args = "", []
    for p in pieces:
        if isinstance(p, str):
            key += p
        else:
            key += "{%d}" % len(args)
            args.append(p[1])
    call = 'tr("%s"%s)' % (key, "".join(", " + a for a in args))
    return call, key


def process(src):
    out, i, changes = [], 0, []
    pat = re.compile(r'\b(%s)\(\s*"|\b(%s):\s*"' % ("|".join(CALLS), "|".join(PARAMS)))
    while True:
        m = pat.search(src, i)
        if not m:
            out.append(src[i:])
            break
        q = m.end() - 1
        # skip if already tr(
        try:
            end, pieces = parse_literal(src, q)
        except (ValueError, IndexError):
            out.append(src[i:m.end()])
            i = m.end()
            continue
        if not english(pieces):
            out.append(src[i:end])
            i = end
            continue
        call, key = build(pieces)
        if "**" in key or "](" in key:
            call = "LocalizedStringKey(%s)" % call
        out.append(src[i:q])
        out.append(call)
        changes.append(key)
        i = end
    return "".join(out), changes


if __name__ == "__main__":
    dry = "--dry" in sys.argv
    for f in [a for a in sys.argv[1:] if not a.startswith("--")]:
        s = open(f, encoding="utf-8").read()
        new, changes = process(s)
        print(f"{f}: {len(changes)}")
        if not dry and new != s:
            open(f, "w", encoding="utf-8").write(new)
