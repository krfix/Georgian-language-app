# Ara (Georgian): notes for Claude

Read this first. README.md covers what the app does; CHANGELOG.md what each version changed;
DEVELOPMENT_LOG.md what was built, tested and found in each work session; TODO.md what is
genuinely unfinished. This file covers who the owner is, how we work, where things are in the
code, and the rules to keep. Keep it about this length.

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
- Goal (owner's brief, KART #1, 16/11/26): a premium, colourful, playful native iOS app for
  learning Georgian from zero (A0), able to stand next to the big language apps. Work
  autonomously: decide, build, test, look at the screenshots, improve; don't ask about small
  things. Never submit or publish anywhere without the owner's say-so.
- Georgian text must be right: every word and sentence goes into
  `tools/curriculum/content_*.py` and through `build_curriculum.py`, which checks it. Latin
  spelling is generated (national system, 2002: k' p' t' q' ts' ch' for the tight sounds).
- Audio: never fabricate, always label. The owner chose Azure's **Eka** voice (KART #1):
  every Georgian text with a speaker button has a clip made once by
  `tools/audio/make_audio.py` (key saved in the environment for
  northeurope.tts.speech.microsoft.com, added by the proxy; never in code or chat), indexed
  in `Resources/Audio/audio.json` and labelled "Synthetic voice". A native recording can
  replace a clip (same file, `"source": "native"`). New or changed Georgian text → run the
  script again (it only makes missing clips). No clip and no iPhone voice → no speaker
  button and no listening exercise for that text.
- "What do you think?" means give an opinion and options. Don't build until asked.
- Name: **Ara** (owner, KART #1): a macaw, and არა, "no" in Georgian. On the home screen
  "Ara"; in the App Store "Ara: Learn Georgian" (check the name and trademark first). The
  mascot is a parrot whose body curls into ა (`tools/art/parrot.py`, `ParrotView`). Inside the
  code and repo it is still "Georgian" (target, bundle ID `com.krfix.georgian`): don't rename.
- Developer switch: Profile › Developer › Open all lessons (UserDefaults
  `devUnlockAllLessons`). Hide it before an App Store release.
- Test data is always invented (Ana, the demo learner, `LearningStore.seedDemo`).

## Workflow
1. Work on a branch, never straight on `main`. Tell the owner the branch name and the build
   number to install.
2. Push (a push to a branch never builds). Start builds by hand:
   `gh workflow run build-ipa.yml --repo krfix/Georgian-language-app --ref <branch> -f title="<subject>"`
   for the IPA, or add `-f qa=true` for the Simulator run (logic tests, UI tests, then 22
   screenshots of every main screen in light and dark, in the run's "screenshots" artifact:
   `gh run download <id> -n screenshots`). Watch with `gh run view <id>`.
3. The owner installs the IPA with Feather and tests on the iPhone.
4. "Merge": the branch into `main` (fast-forward when possible; no pull request unless asked).
5. "Release": raise `MARKETING_VERSION` in `project.yml` and add a `## [x.y.z] - yyyy-MM-dd`
   section to `CHANGELOG.md`; on `main` the workflow then publishes the GitHub Release with
   the IPA. A version without its CHANGELOG section never builds on `main`.
- Mac minutes cost money (shared with the Logbook app). Build when the owner asks, or when the
  owner's brief asks for build-and-inspect cycles (as in KART #1). Let several changes ride on
  one run; cancel a run whose code is already out of date.
- The build number is the GitHub run number. Never set it by hand.
- Commits: a short `Area: what changed` subject, an optional body, and end with the
  Co-Authored-By line (plus a Claude-Session line when the session gives one).

## Checking a change
- Nothing compiles here: cloud sessions are Linux, with no Swift (installing one was refused).
  Review carefully, then let the Mac run compile and test.
- `python3 tools/curriculum/build_curriculum.py` runs here and checks the whole course.
- Logic tests: `tools/Tests/main.swift` (plain `check(label, got, want)`), compiled with every
  file in `Georgian/Curriculum` and `Georgian/Engine`, which therefore must not use SwiftUI,
  UIKit or SwiftData. Run in both jobs.
- UI tests: `GeorgianUITests/` (onboarding, a whole first lesson, the tabs, restart keeps
  progress; the demo learner's review and search). Accessibility identifiers are the hooks:
  `option-<n>`, `tile-<n>`, `match-ka-<id>`/`match-other-<id>`, `lesson-check`,
  `lesson-continue`, `complete-continue`, `onboarding-next`, …
- Launch arguments (`App/LaunchOptions.swift`): `-uiTesting` (store in memory), `-resetData`,
  `-seedDemo`, `-screen <home|learn|alphabet|lesson|complete|words|word|review|progress|profile|onboarding>`.
- Installed with Feather; always the same identifier, `com.krfix.georgian`.

## Code map
| What | Where |
| --- | --- |
| Course content (source) and its checker | `tools/curriculum/content_words.py`, `content_course.py`, `build_curriculum.py` → `Georgian/Resources/Curriculum/*.json` |
| Content types, loading, look-ups, Latin spelling, pronunciation help | `Curriculum/` |
| Exercises: kinds and shapes, building them from lessons, checking answers, the session | `Engine/Exercise.swift`, `ExerciseBuilder.swift`, `AnswerEvaluator.swift`, `LessonSession.swift` |
| Spaced repetition (SM-2), XP, streaks, levels, achievements, challenge, path states | `Engine/SpacedRepetition.swift`, `Engine/Gamification.swift` |
| Saved data (SwiftData, CloudKit-ready) and everything worked out from it | `Data/Models.swift`, `Data/LearningStore.swift` |
| Audio (bundled clips via `audio.json`, or the iPhone's Georgian voice), reminders | `Audio/`; clips made by `tools/audio/make_audio.py` |
| Design system: colours (light and dark), type, motion, haptics, components | `DesignSystem/` (Borjgali emblem, ChunkyButton, cards, rings, confetti, FlowLayout, SpeakerButton) |
| App start, launch options | `App/GeorgianApp.swift` (`AppModel`), `App/LaunchOptions.swift` |
| Tabs, navigation, presenting lessons | `Features/Root/RootView.swift` (`Navigator`) |
| Screens | `Features/Onboarding`, `Home`, `Learn` (path, preview, alphabet chart), `Lesson` (player, one view per content shape, completion), `Vocabulary`, `Review`, `Progress`, `Profile` |

## How the app works (and patterns to keep)
- SwiftUI + SwiftData, iOS 17+ (for SwiftData, Observation and the newer animation APIs;
  built with the newest Xcode 26 SDK), iPhone only, portrait, light and dark, XcodeGen, Swift 5
  language mode.
- One exercise engine: `ExerciseBuilder` turns a lesson into `Exercise`s; each has a content
  shape (`choice`, `typing`, `matching`, `tiles`, `flashcard`, `dialogue`, teaching cards)
  drawn by one reusable view; `LessonPlayerModel` checks, records and moves on for all of them.
  A wrong answer comes back once at the end. New kinds: add a shape or reuse one, never a
  separate screen.
- Review: every letter and word has a `MasteryRecord`; right answers space it out (1, 3, 8…
  days), a miss brings it back in 10 minutes. Same-day repeats don't push it further.
- Path: lessons open in order (`CourseProgress`); "I know a few letters" opens the alphabet,
  "I can read" starts at Module 2.
- Look: warm paper (light) or deep aubergine (dark), five brand colours named after Georgia
  (`Palette`), the borjgali sun symbol as the emblem, raised "chunky" buttons, rounded cards,
  springy motion that turns into fades with Reduce Motion (`Motion`, `withMotion`).

## Open
- 0.2.0 in progress on branch `claude/full-app` (KART #1): the full app. See
  DEVELOPMENT_LOG.md for its state and TODO.md for what's left.

## Repos and branches
- `krfix/Georgian-language-app` (private): this app; `main` is what's tested and accepted.
- `krfix/Logbook-app-store`: the owner's Logbook app, the model for the set-up. Don't change
  it from a Georgian chat.
