# Georgian: notes for Claude

Read this first. README.md covers what the app does and how to install it; CHANGELOG.md covers
what each version changed. This file covers who the owner is, how we work, where things are in
the code, and what's open. Keep it about this length: finished work moves to CHANGELOG.md at
each release.

## First thing in every chat
Name the chat before answering: `KART #<n> · dd/mm/yy · <2–3 words>`, e.g.
`KART #2 · 17/11/26 · Words, audio`. KART is short for Kartuli, Georgian's name for itself.
The date is the owner's day (Asia/Tbilisi). <n> is one more than the highest "KART #" among the
owner's chats (`list_sessions`); if that can't be read, one more than the last number here:
KART #1 (16/11/26). The words come from the first request. Rename with `set_session_title`
(load both tools with ToolSearch if needed); at the end, rename again if the work went
elsewhere. Without those tools, suggest the name instead. The owner's other app, Logbook, uses
"HOVR #<n>": don't count those.

## Owner and rules
- The owner has no coding experience, an iPhone only and no Mac (Windows). Claude writes all
  the code. Explain in plain words; no jargon without saying what it means.
- Goal: a small, clean iPhone app for learning the basics of Georgian: the alphabet first,
  then reading, sounds and everyday words. Maybe the App Store later.
- Still to ask the owner: their own level and why they're learning (a trip, family, living in
  Georgia), which decides the words that come first.
- New screens or big UI changes: show a mockup first (a claude.ai Design artifact works well).
- "What do you think?" means give an opinion and options. Don't build until asked.
- Georgian text must be right: check every word, spelling and Latin transliteration before
  adding it. Latin spelling follows Georgia's national system (2002): an apostrophe for the
  tight (ejective) sounds, k' p' t' q' ts' ch'.
- The look follows the Logbook app's (`krfix/Logbook-app-store`, `docs/ui-style.md`): dark
  only on pure black, cards with corners of 20, tiles 16, buttons 12; text through
  `Font.app(size)` on the sizes 11/13/15/17/20 and 24/32/40/56 (and the letters themselves,
  which may be bigger); the accent (Georgian red) kept for the one main action and progress;
  two speeds, `Motion.standard` 0.7 s and `Motion.quick` 0.3 s.

## Workflow
1. Work on a branch (the session's own branch), never straight on `main`. Tell the owner the
   branch name when starting work and again at the end, with the build number to install.
2. Push (a push to a branch never builds). When the owner asks for an IPA, start the build
   by hand: `gh workflow run build-ipa.yml --repo krfix/Georgian-language-app --ref <branch>
   -f title="<latest commit's subject>"` (the `gh` CLI works in cloud sessions; or
   `actions_run_trigger` where the GitHub tools exist). Watch it with `gh run view <id>`.
   Tests, then the IPA attached to the run (about 2 minutes; build #1 took 1½). The workflow
   must also be on `main` for this to work, so keep it there.
3. The owner installs that IPA and tests on the iPhone.
4. "Merge": put the branch into `main` (a fast-forward when `main` hasn't moved; no pull request
   unless asked). "Go back": undo the change on the branch, or revert it on `main` if merged.
5. "Release": raise `MARKETING_VERSION` in `project.yml` (0.1.x, 0.2.0 … until the App Store)
   and add a `## [x.y.z] - yyyy-MM-dd` section to `CHANGELOG.md` listing everything since the
   last release tag. On `main` the workflow then publishes GitHub Release `v<version>` with that
   section as its description and the IPA attached. A version without its CHANGELOG section
   never builds on `main`. Only release when the owner says "release".
- Builds cost Mac minutes, shared with the Logbook app. **Never start a build unless the owner
  asks for one in that message** ("build", "IPA", "test this"). Finishing a change is not a
  reason to build: push, say what changed and what to check, and say it's ready for a build.
- The build number is the GitHub run number. Never set it by hand.
- Commits: a short `Area: what changed` subject, an optional body, and end with the
  Co-Authored-By line (plus a Claude-Session line when the session gives one).

## Checking a change
- Nothing compiles locally: cloud sessions are Linux, with no Swift. Review the code carefully,
  push, then read the run (on failure, the job log; errors are also annotations).
- `.github/workflows/build-ipa.yml` (macos-15, newest Xcode 26; started by hand, or a release on
  `main`): tests first, then an unsigned `Georgian-<version>-<build>.ipa`. A failed test still
  uploads the IPA but blocks the release and turns the run red. The build also fails if
  `PrivacyInfo.xcprivacy` is missing from the app.
- Tests: `tools/Tests/main.swift`, plain `check(label, got, want)` calls, compiled with
  `xcrun swiftc` together with the app files listed in the workflow (and at the top of
  main.swift). Those files can't use SwiftUI or UIKit, so rules worth testing go in their own
  small file (like `Quiz.swift`). Every check must pass.
- Installed with Feather and an ArcticSign certificate, like the Logbook. Always sign with the
  same identifier (`com.krfix.georgian`), or the phone treats it as a new app and progress is
  lost. No entitlements (iCloud, App Groups) with this signing.

## Code map
| What | Where |
| --- | --- |
| App start, shared `ProgressStore` | `App/GeorgianApp.swift` |
| Colours, `Caption`, `.card()`, `Motion` | `App/Theme.swift` |
| Text size (`Font.app`), copied from the Logbook | `App/TextScale.swift` |
| The 33 letters (name, Latin, sound, a word), look-alike groups | `Models/Letter.swift` |
| Quiz rules: boxes 0–4, which letter next, wrong answers (tested) | `Services/Quiz.swift` |
| Progress kept on the phone (UserDefaults `letterBoxes`) | `Services/ProgressStore.swift` |
| Tabs, `ScreenHeader` | `Views/RootView.swift` |
| Alphabet grid and one letter's page | `Views/AlphabetView.swift` |
| The quiz | `Views/PracticeView.swift` |

## How the app works (and patterns to keep)
- SwiftUI, iOS 17+, iPhone only, XcodeGen (`project.yml`, no committed `.xcodeproj`), dark
  only, Swift 5 language mode. No account, no server, no tracking: progress stays on the phone.
- Quiz: each letter sits in a box from 0 to 4; right moves it up one, wrong sends it to 0;
  box 4 is "known". Lower boxes come up more often (weight (5 − box)²), never the same letter
  twice in a row. Five letters are being learned at a time; new ones join in alphabetical
  order. A letter from box 2 up is asked both ways (letter → Latin, Latin → letter). Wrong
  answers are look-alikes first (`Alphabet.lookalikes`: კ/ქ/ყ, პ/ფ, ტ/თ, ც/წ/ძ …).

## Open
- 0.1.0, not released yet (KART #1): the repo set-up, Alphabet (grid, letter pages) and the
  letter quiz. Build #1 (16/11/26) passed, 92 checks; waiting for the owner's test on the phone.
- Ideas, in a likely order: sounds (iOS has no Georgian voice, so audio means recorded clips);
  reading whole words; the tight/puff pairs as their own drill; first phrases (hello, thank
  you, numbers 1–20, counted in twenties); a proper icon and name.

## Repos and branches
- `krfix/Georgian-language-app` (private): this app; `main` is what's tested and accepted.
- `krfix/Logbook-app-store`: the owner's Logbook app, the model for this set-up. Don't change
  it from a Georgian chat.
