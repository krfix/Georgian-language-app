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
KART #14 (24/11/26). The words come from the first request. Rename with `set_session_title`
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
- Evolved brief (KART #2, 16/11/26): not a Duolingo clone but a Georgian companion for
  people living in or visiting Georgia: **Learn** (the course) and **Use in Georgia** (a
  phrasebook for real situations, usable at once, offline, with no unlocking) as two equal
  halves, connected (save a phrase, practise it in review, learn its words and grammar).
  Keep the colourful design; gamification stays, but quieter.
- Two languages (KART #4): English and Polish, chosen on the welcome screen or in Profile.
  Screens write English inside `tr("…")` (placeholders `{0}`, counts with `plural()`); the
  Polish is in `tools/l10n/ui_pl.py` → `Resources/Localization/ui-pl.json`, checked by
  `tools/l10n/check_strings.py`. Course and phrasebook Polish: `content_pl.py`, checked by
  `build_curriculum.py`. New text needs both. Explanations for Polish speakers compare with
  Polish (sounds, cases, verbs), not word-for-word English.
- New Georgian text in examples, conversations or phrases: every word needs an explanation
  (`content_glossary.py`; the build lists the missing ones with `--glossary`). No XP or
  levels on screen (KART #4): show what the learner knows and can do.
- Georgian text must be right: every word and sentence goes into
  `tools/curriculum/content_*.py` and through `build_curriculum.py`, which checks it. Latin
  spelling is generated (national system, 2002: k' p' t' q' ts' ch' for the tight sounds).
  Follow `docs/content-quality.md`. Never claim a native speaker's check that hasn't
  happened (`PHRASEBOOK_STATUS` in content_phrasebook.py; the app shows it).
  On screen and on the website say "with the help of AI", never Claude by name (owner, KART #7).
- Audio: never fabricate, always label. The owner chose Azure's **Eka** voice (KART #1);
  learners can pick **Giorgi** (male) instead (KART #5: welcome steps, Profile › Voice;
  `AudioService.Voice`). Every Georgian text with a speaker button has a clip in each
  voice, made once by `tools/audio/make_audio.py` (key saved in the environment for
  northeurope.tts.speech.microsoft.com, added by the proxy; never in code or chat), indexed
  in `Resources/Audio/audio.json` (Eka) and `audio-giorgi.json`, labelled "Synthetic voice". A native recording can
  replace a clip (same file, `"source": "native"`). New or changed Georgian text → run the
  script again (it only makes missing clips). No clip and no iPhone voice → no speaker
  button and no listening exercise for that text.
- "What do you think?" means give an opinion and options. Don't build until asked.
- Name: **Ara** (owner, KART #1): a macaw, and არა, "no" in Georgian. On the home screen
  "Ara"; in the App Store "Ara: Learn Georgian" (check the name and trademark first).
  Identity (KART #3, `docs/brand.md`): the symbol is Ara's head, whose hooked beak is a
  speech bubble's tail; the mascot is the same head on a macaw body (`ParrotView(mood:)`).
  All artwork comes from `tools/brand/make_brand.py`: change it there, never by hand. Inside the
  code and repo it is still "Georgian" (the target). Bundle ID `com.aralearn.ge` (owner, KART #7,
  so the GitHub name isn't in it; GitHub organisation `aralearn`): fixed once uploaded to Apple.
- Developer mode (KART #8): Profile › Developer, one switch (`devMode`) that shows two tools:
  Open all lessons (`devUnlockAllLessons`) and Quick pass (`devQuickPass`: a Pass button in
  lessons, tap = right answer, hold = finish the lesson). Only in the Feather IPA (`DEV_TOOLS`)
  and Simulator runs (`DEBUG`); TestFlight and the App Store never show it (KART #14).
- Test data is always invented (Ana, the demo learner, `LearningStore.seedDemo`).
- Web app (KART #8–#9, `web/README.md`): the whole app for any browser, in `web/`, plain
  HTML/CSS/JS reading the iPhone app's content and audio (never copied by hand), drawn like
  the iPhone screens; `engine.js` ports `Engine/` (change both together); tr() keys share the
  Polish table. Live at https://aralearn.github.io/app (the
  website repo's `/app`, KART #9; the site's home has a "Try Ara in your browser" button);
  republish only on the owner's say-so, privacy page first.
- App Store (KART #14): free, no in-app purchases or ads; repo stays private. Listing texts
  and Apple's forms in `docs/app-store.md`; keep it true to the app.

## Workflow
1. Work on a branch, never straight on `main`. Tell the owner the branch name and the build
   number to install.
2. Push (a push to a branch never builds). Start builds by hand:
   `gh workflow run build-ipa.yml --repo krfix/Georgian-language-app --ref <branch> -f title="<subject>"`
   for the IPA, or add `-f qa=true` for the Simulator run (logic tests, UI tests, then 22
   screenshots of every main screen in light and dark, in the run's "screenshots" artifact:
   `gh run download <id> -n screenshots`). Watch with `gh run view <id>`. `-f testflight=true`
   signs and uploads to App Store Connect for TestFlight (KART #7; the privacy and support
   pages live in the public repo `aralearn/aralearn.github.io`; only on the owner's say-so,
   since it sends the app to Apple; secrets `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`,
   `APPLE_TEAM_ID`; API key with the Admin role, for Apple's cloud signing).
3. The owner installs the IPA with Feather and tests on the iPhone.
4. "Merge": the branch into `main` (fast-forward when possible; no pull request unless asked).
5. "Release": raise `MARKETING_VERSION` in `project.yml` (0.x.y, owner KART #14; the version in
   App Store Connect must match it) and add a `## [x.y.z] - yyyy-MM-dd` section to `CHANGELOG.md`; on `main` the workflow then publishes the GitHub Release with
   the IPA. A version without its CHANGELOG section never builds on `main`.
- Web app: `python3 web/build.py` (+ `--serve`), `node web/tests/search_test.mjs` and `engine_test.mjs`,
  `NODE_PATH="$(npm root -g)" node web/tests/screens.mjs` (screenshots), `audit.mjs` (layout: cut,
  off-screen, off-centre, overlapping; normal and larger text), all here on Linux;
  on GitHub `web.yml` (Linux, by hand; `-f publish=true` puts it live, needs `WEBSITE_TOKEN`;
  `-f quick=true` skips its screen walk-through, ~1–2 min instead of ~10: use it after `screens.mjs` ran here).
- Mac minutes cost money (private repo, shared with the Logbook app). Build when the owner asks, or when the
  owner's brief asks for build-and-inspect cycles (as in KART #1). Let several changes ride on
  one run; cancel a run whose code is already out of date.
- Rhythm (owner, KART #6): on a branch, quick IPA builds only (no `qa`); the owner tests on
  the iPhone between them. One `qa=true` run (tests and screenshots) before merging to `main`.
- Actions storage is limited (owner, KART #12): a run's attached files are kept 7 days, IPAs 30
  (`retention-days`); releases keep their IPA. The newest QA screenshots also stay on the branch
  `qa-screenshots` (`git fetch origin qa-screenshots`). Delete old attached files when storage fills.
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
  `-seedDemo`, `-screen <home|learn|alphabet|lesson|complete|words|word|review|progress|profile|onboarding|
  phrasebook|category|emergency|saved|dialogue|practice|phrase|show|search>` with `-item <id>` or
  `-query <text>` for the phrasebook screens.
- Installed with Feather, or TestFlight; always the same identifier, `com.aralearn.ge` (until
  KART #7 it was `com.krfix.georgian`, which the iPhone treats as a different app).

## Code map
| What | Where |
| --- | --- |
| Course and phrasebook content (source) and the checker | `tools/curriculum/content_words.py`, `content_course.py`, `content_phrasebook.py`, `build_curriculum.py` → `Georgian/Resources/Curriculum/*.json` |
| Every word on screen in Words: "More words" (`more` in vocabulary.json, ids `x-…`), made by the build from all visible Georgian | `build_curriculum.py` (`--more`), `Curriculum.moreWords` |
| Content types, loading, look-ups, Latin spelling, pronunciation help | `Curriculum/` |
| Tappable words: glossary of every word form (EN + PL), the bubble | `tools/curriculum/content_glossary.py` → `glossary*.json`; `DesignSystem/Components/TappableGeorgian.swift` |
| Languages: `AppLanguage`, `tr()`, `plural()`, Polish table; checks | `Curriculum/Localization.swift`, `Resources/Localization/`, `tools/l10n/` |
| Phrasebook types, lookups, phrases as review words, dialogue practice, search (tested) | `Curriculum/PhrasebookModels.swift`, `Phrasebook.swift`, `PhraseSearch.swift` |
| Exercises: kinds and shapes, building them from lessons, checking answers, the session | `Engine/Exercise.swift`, `ExerciseBuilder.swift`, `AnswerEvaluator.swift`, `LessonSession.swift` |
| Spaced repetition (SM-2), XP, streaks, levels, achievements, challenge, path states | `Engine/SpacedRepetition.swift`, `Engine/Gamification.swift` |
| Saved data (SwiftData, CloudKit-ready) and everything worked out from it | `Data/Models.swift`, `Data/LearningStore.swift` |
| Audio (bundled clips in two voices via `audio.json` / `audio-giorgi.json`, or the iPhone's Georgian voice), the voice picker, reminders | `Audio/`, `DesignSystem/Components/VoicePicker.swift`; clips made by `tools/audio/make_audio.py` |
| Brand: symbol, app icons, logos, mascot poses (vector masters in `brand/`, assets in the catalog) | `tools/brand/ara.py` (geometry), `make_brand.py`; `docs/brand.md` |
| Design system: colours (light and dark), type, motion, haptics, components | `DesignSystem/` (Borjgali emblem, ChunkyButton, cards, rings, confetti, FlowLayout, SpeakerButton) |
| App start, launch options | `App/GeorgianApp.swift` (`AppModel`), `App/LaunchOptions.swift` |
| Tabs, navigation, presenting lessons and phrases | `Features/Root/RootView.swift` (`Navigator`, `PhrasebookRoute`, `HomeRoute`) |
| Web app: phrasebook screens, course screens, engine port, search port, audio, saved data, offline worker, build | `web/js/app.js`, `course.js`, `engine.js`, `search.js`, `audio.js`, `store.js`, `web/sw.js`, `web/build.py` |
| Screens | `Features/Onboarding`, `Home`, `Learn` (path, preview, alphabet chart), `Lesson` (player, one view per content shape, completion), `Phrasebook` (tab, situation, phrase card, Show mode, dialogue, my phrasebook), `Vocabulary` (the Words tab: list, search over everything, word card), `Review`, `Progress` (pushed from Home's card), `Profile` |

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
- Tabs (KART #6): Home · Learn · Phrasebook · Words · Review. Words is the word list with
  search over everything (words, phrases, situations, conversations); Learn is only the path;
  Progress opens from Home's card. Home's order (owner): greeting, search, progress card, Learn |
  Use in Georgia, Continue learning, situations, review (when due), phrases. The phrasebook never locks anything.
- Levels: no A0/A1 (official exam levels). `CourseStage` (Engine) names six stages by finished
  module: Just landed, Sign reader, Bazaar regular, Supra guest, Tamada's apprentice, Tamada.
  A phrase (`pb-…` id) becomes a `Word` for review (`Phrasebook.word(for:)`), so saving it
  for practice uses the same `MasteryRecord` schedule; a dialogue becomes a conversation
  `Lesson` for the player (`practiceLesson`). The learner's saved phrases, lists, "learned"
  marks and recents are `PhraseRecord`s (SwiftData schema 2).
- Look: warm paper (light) or deep aubergine (dark), five brand colours named after Georgia
  (`Palette`), the borjgali sun symbol as the emblem, raised "chunky" buttons, rounded cards,
  springy motion that turns into fades with Reduce Motion (`Motion`, `withMotion`).

## Open
- Released from `main` (KART #5): 0.2.0 (build #29) with the full app (KART #1), the
  phrasebook (KART #2), the brand identity (KART #3), KART #4 (numbers, Polish, eight
  dialogues, learning-first, tappable words, why cards, grammar g10–g13) and the voice choice;
  0.2.1 (build #30): More words, every word on screen in Words; 0.3.0 (KART #6): the Words
  tab, Home's new order, stage names instead of levels, tappable notes, smoother Learn and
  Words. See DEVELOPMENT_LOG.md and TODO.md.

## Repos and branches
- `krfix/Georgian-language-app` (private again, KART #7; never commit keys or personal
  details, secrets live in GitHub's Actions secrets): this app; `main` is what's tested and accepted.
- `aralearn/aralearn.github.io` (public, KART #7): the website, https://aralearn.github.io:
  home, `/privacy`, `/support` in English and the same under `/pl/` in Polish (KART #13), plain
  HTML in Ara's colours; the home pages come from its `tools/make_home.py` (phones in the owner's
  `frame.webp`, screens in `shots/`). Contact
  email for Apple and the pages: ara.learn.app@gmail.com. Keep the privacy page true to the
  app (no data collected, no network); change it before the app changes.
- `krfix/Logbook-app-store`: the owner's Logbook app, the model for the set-up. Don't change
  it from a Georgian chat.
