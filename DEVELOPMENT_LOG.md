# Development log

Concise record of each work session: what was built, how it was tested, what was found and
fixed. Newest first.

## KART #3 · 17/11/26 · Brand identity, icon (branch `claude/busy-franklin-eua7bv`)

The owner's brief: a sophisticated, minimal app icon plus an expressive macaw mascot, one
identity; at least five concepts, critical selection, three or more refinements, vector
production assets, integration without redesigning the app, Simulator check.

### Audit
SwiftUI app with a warm-paper/aubergine look, five brand colours (Palette), SF Rounded, the
borjgali emblem, gradient cards. The old icon and mascot were one raster parrot (Pillow
circles) on a turquoise-purple gradient; the beak read badly and it didn't hold up small.
The welcome screen already explains the name ("you'll be saying კი: yes!").

### Decisions
- Six directions drawn and compared at 260, 120, 60 and 29 px on light and dark
  (`brand/exploration`): parrot, ა lettermark (real Noto Sans Georgian glyph), two
  bubbles, feather quill, speaking parrot, ა-bird. Chosen: the **speaking parrot** (head =
  speech bubble, beak = its tail). Why, and the trade-offs: docs/brand.md.
- Five refinement rounds: beak geometry (three tries), centring and tilt, backgrounds, the
  gold-and-blue neck curl, the one-colour outline.
- Mascot rebuilt in the same geometry; moods change only the eye, tilt and wing.
- Artwork in code (`tools/brand/ara.py`, `make_brand.py`): SVG masters, PDF vectors in the
  app, PNG icons. No AI images. Wordmark in Nunito Black outlines (OFL). The ა connection
  stays in the story, not in a bent letter.

### Built
- AppIcon light, dark and tinted; LaunchMark (the symbol); AraSymbol; Parrot, ParrotBlink,
  ParrotCheer, ParrotThink, ParrotSleep (vector PDFs). The old `tools/art` is gone.
- `ParrotView(mood:)` with blinking; the mascot on the ready page and Lesson complete (cheer),
  "Nothing saved yet" (hello), "Nothing found" and the start-up problem screen (think),
  Review's "All caught up" (sleep); the symbol above the version line in Profile.
- QA also photographs the home screen (light, dark) and a search with no results.

### Runs and refinement cycles

## KART #2 · 16/11/26 · Use in Georgia (branch `claude/use-in-georgia`, from `claude/full-app`)

The owner's brief: keep the design, but turn the app from a Duolingo-style game into a
Georgian companion: **Learn** plus **Use in Georgia** (a practical phrasebook), connected.

### What existed (inspected first)
A polished SwiftUI + SwiftData course app: 5 tabs (Home, Learn, Words, Review, Progress),
one exercise engine (15 kinds), SM-2 review, XP/streak/levels/achievements, 209 words and
phrases (some of them already situational: taxi, groceries, doctor), Eka audio for 516 texts,
a design system (five brand colours, gradient cards, chunky buttons, borjgali, parrot).
Home was mostly gamification (streak, XP, level tiles, goal, path, challenge).

### Decisions
- **Information architecture:** Home · Learn · Phrasebook · Search · Review. Words and
  Progress moved inside Learn (toolbar), the daily challenge into Progress: the learning tools
  stay, the score is quieter. Search gets its own tab because "find it now" must be one tap.
  Personal phrases live in the Phrasebook (My phrasebook), and reach Review when practised.
- **Content separate from UI:** `tools/curriculum/content_phrasebook.py` → `phrasebook.json`,
  checked by `build_curriculum.py` (script, duplicates, subcategories, keywords, links).
  Latin spelling and the English sound guide are generated, never typed.
- **Phrases join learning through the existing engine:** a phrase is a `Word` with a `pb-`
  id, so "Practise" creates the same `MasteryRecord` and Review handles it (mixed with other
  phrases, built from tiles instead of typed in English). A dialogue becomes a conversation
  `Lesson`, so practice reuses the lesson player. No new exercise screens.
- **Saved data:** `PhraseRecord` (saved, list, learned, last opened) in SwiftData schema 2,
  with a lightweight step from schema 1 (and a fallback that lets SwiftData infer it), so
  progress on the owner's phone survives. CloudKit-ready like the rest.
- **No stress marks in the sound guide.** Georgian stress is weak and its placement is
  debated; capital-letter stress (gah-mar-JOH-bah) would teach something wrong. The guide
  says so instead.
- **Honesty about checking:** the phrasebook says it was checked by Claude (an AI), not yet
  by a native speaker (`PHRASEBOOK_STATUS`), in the Phrasebook, Search and Profile.
- **Search** (`PhraseSearch`, Foundation only, tested): English words whole, by prefix, with
  one typo, through synonyms and simple stems; keywords and situation names; Georgian
  anywhere; Latin without apostrophes. Ranked by words matched, then wording, then length.
  Before writing it in Swift, a Python port was run on the real data to tune the weights
  (situation names had outranked keywords: "taxi" returned "Turn left" first).

### Built
- 302 phrases in 11 situations (52 subcategories), 13 dialogues, synonyms and suggestions;
  354 new Eka clips (870 in all, 15 MB), so every phrase, variant, reply and dialogue line
  plays offline.
- Screens: Phrasebook tab (search bar, emergency strip with 112, My phrasebook, situation
  tiles, conversations), situation pages with subcategory chips, the phrase card (sound guide,
  usage, polite/informal forms, replies, course words, grammar links, review status; Show,
  Save, Practise, Learned, Copy, lists), Show to someone (white on black, sized so no word
  breaks, English optional, upside-down for the person opposite, screen kept on, play and
  slow), Search tab (suggestions, recent searches, recently used; results by phrases,
  situations, conversations, course words), dialogue pages (bubbles, English/Latin toggles,
  useful expressions, practise either side), My phrasebook (filters, lists, practise all).
- Home: greeting with a small streak/XP line, search bar, Learn / Use in Georgia tiles,
  "Right now I need…" situations, recently used phrases, continue learning, review, goal.
- Onboarding: "I just need phrases now" on the welcome screen goes straight to the phrasebook.
- Links both ways: a phrase shows its course words and grammar; a course word card shows the
  everyday phrases it appears in.
- docs/content-quality.md: the checklist, and the points a native speaker should look at first.

### Tests
- `build_curriculum.py` (here): passes, 302 phrases, 13 dialogues.
- Logic tests (Mac): every phrase's Latin, sound guide, situation, keywords, links; every
  dialogue practisable from both sides with three distinct options; phrases in review; and
  search for the six scenarios in the brief plus typos, synonyms, Latin and Georgian.
- UI tests (Simulator): new `testPhrasebookScenarios` (search "stop here" → Show to someone →
  flip and hide English → close; search "I don't eat meat" → card → Save → Practise; open
  Transport), `testDialoguePractice` (the taxi dialogue as the driver, to the end),
  `testStraightToThePhrasebook`; the old tests updated for the new tabs.

### Runs and refinement cycles
- **Run 11** (QA 1): GitHub had no Mac for 15 minutes; the job was dropped before it began.
  Re-run: the app compiled first time with 0 warnings, but my new logic tests didn't
  compile (a closure mixing `$0` and a named argument; the step is continue-on-error, so
  only the log showed it), and the UI tests hung 56 minutes in the Simulator without
  starting a test, so the job's time limit took the screenshots too. → The workflow now takes
  the pictures first and gives the UI tests 30 minutes.
- **Run 12** (QA 1b): 75 pictures; UI tests 4 of 5 passed. Logic tests: a duplicate `rr`.
  **Cycle 1** (from the pictures): the design carried over (palette, gradient cards, light
  and dark). Found: (1) Show to someone split words at 76 pt (გამიჩერე / თ); (2) the slow
  button and voice tag were invisible on coloured cards (also on the course's word card);
  (3) quick-situation labels cut off at the largest text size; (4) the keyboard's first-use
  tip covered the search screenshot; (5) the scenario test looked for a tile not yet created
  by the lazy grid. → Fixed: text sized from the widest word (`GeorgianFit`,
  `FittedGeorgianText`), white audio controls on colour, wrapping labels, no keyboard in the
  screenshot run, the test opens Transport.
- **Run 13** (QA 2): logic tests **142/142**, 0 warnings, 75 pictures, UI tests 4 of 5.
  **Cycle 2:** Show to someone keeps every word whole in light, dark and the largest text
  size; the card's audio controls read on colour; the search screenshot is clean. Found:
  the quick-situation labels now hyphenated at the largest size (Shop-ping); Words and
  Progress, no longer tabs, were icons only in Learn's toolbar. → One-line shrinking labels;
  text buttons "Words" and "Progress". The scenario test still missed the Transport tile:
  the tile merged its accessibility element inside the link → removed.
- **Run 14** (QA 3): 142/142, 0 warnings, 75 pictures, UI tests 4 of 5. **Cycle 3:** the
  toolbar buttons and labels look right in light and dark; no regressions on Home, the
  situations, search or lesson complete. The scenario test still couldn't find the tile even
  by any element type, so the likely cause is the test itself: it tapped the tab bar while
  the phrase card was still closing. → The test now waits for the card to go and checks the
  Phrasebook tab opened first.
- **Run 15** (QA 4): 142/142, 0 warnings, 75 pictures, UI tests 4 of 5. The new checks found
  the cause: the card had closed, but the search keyboard was still up and covered the tab
  bar. A real snag too (back from a phrase, the keyboard hid half the results). → Opening a
  search result now puts the keyboard away.
- **Run 16** (QA 5): everything green: logic tests **142/142**, UI tests **5/5** (onboarding
  and a first lesson with a restart; the demo review and course words; the phrasebook
  scenarios; dialogue practice; straight to the phrasebook), 0 compiler warnings, 75 pictures.

### The brief's scenarios, checked
| Scenario | How it was checked | Result |
| --- | --- | --- |
| A tourist asks a taxi driver to stop | Logic test: "stop here", "taxi stop" find აქ გამიჩერეთ, თუ შეიძლება. UI test: Home search bar → "stop here" → Show to someone → flip, hide English → close. Screenshots of the card and Show mode. | Search: passes. UI steps: pass (run 16, all five UI tests green). |
| Price at the bazaar | Logic test: "how much is this", "price". Screenshot of the bazaar dialogue. | Passes |
| Telling a waiter "I don't eat meat" | Logic test: "I don't eat meat", "vegetarian", "vegan" (simulated). UI test: search → card → Save → Practise → "In review". | Passes |
| The nearest pharmacy | Logic test: "where is the nearest pharmacy", "pharmacy", "pharmcy", "chemist". | Passes |
| Introducing yourself to a neighbour | Logic test: "my name is", "neighbour", "neighbor". Screenshot: neighbour dialogue in the Phrasebook. | Passes |
| Gym membership | Logic test: "gym membership". | Passes |
| Practising a conversation | UI test: the taxi dialogue played as the driver, to the end. | Passes |
| Straight to the phrasebook | UI test: welcome → "I just need phrases now" → Phrasebook. | Passes |

Not tested: audio playback itself (the Simulator run has no ears; clips exist for every
text, and the files were checked to be MP3s), VoiceOver, an upgrade from schema 1 on a phone
that has old progress (needs the owner's phone: install over the current build).


## KART #1 · 16/11/26 · The full app (branch `claude/full-app`)

### Decisions
- **Native SwiftUI + SwiftData, iOS 17.0+.** SwiftData, the Observation framework,
  `phaseAnimator`/`symbolEffect`/`sensoryFeedback`-era APIs and Swift Charts all need iOS 17;
  iOS 17 still covers almost every iPhone in use. Built with the newest Xcode 26 SDK, Swift 5
  language mode (Swift 6 strict concurrency would add noise without catching real bugs here).
- **Five tabs** (Home, Learn, Words, Review, Progress) and **Profile** as a sheet from the
  avatar on Home: iOS shows at most five tabs before "More".
- **Content as versioned JSON**, written in Python (`tools/curriculum`) so it can be checked
  automatically and the Latin spelling generated, never typed.
- **No fabricated audio:** recordings by item id, or a real Georgian system voice; otherwise
  hidden. Listening exercises exist in the engine and appear only with audio.
- **Models ready for CloudKit:** defaults on every property, no unique constraints, a
  `courseID` on records for more courses later, a versioned schema with a migration plan.

### Built
- Course: 5 modules, 53 lessons, 209 words and phrases, 33 letters, 9 grammar notes sets,
  6 dialogues.
- Engine: 15 exercise kinds on 9 content shapes; answer checking with typo tolerance and
  alternatives; sessions with retries; SM-2 review; XP, levels, streaks, 15 achievements,
  daily challenge, path states.
- Screens: onboarding (7 steps, first lesson), Home, Learn path + lesson preview + alphabet
  chart, lesson player + completion, Words + word card, Review, Progress (charts), Profile.
- Design system: palette (light/dark), type, motion (Reduce Motion aware), haptics, chunky
  buttons, cards, rings, bars, borjgali emblem, confetti, flow layout, speaker button.
- App icon and launch mark drawn from the borjgali.

### Tests
- `build_curriculum.py` (here, free): content checks pass (see the script for the list).
- Logic tests (Mac): content, every lesson × 5 seeds makes sound exercises, answer checking,
  sessions, spaced repetition, streaks, levels, achievements, challenge, path.
- UI tests (Simulator): onboarding → first lesson to the end → tabs → restart keeps
  progress; demo learner: profile, a review session to the end, search.

### Runs and refinement cycles
- **Run 1** (#3): logic tests 95/95 passed; the app and UI tests compiled first time
  ("TEST BUILD SUCCEEDED"); the job then failed on the workflow's own warning count (a grep
  with no matches). Fixed.
- **Run 3** (#5): everything green: 95/95 logic checks, both UI tests passed (onboarding →
  first lesson to the end → tabs → restart keeps progress, 6 min; demo learner's review and
  search, 2.5 min), 0 compiler warnings in the app, 22 screenshots. Artifacts can't be
  downloaded from a cloud session (blocked host), so the run also pushes them to the
  `qa-screenshots` branch.
- **Cycle 1** (from run 3's screenshots): light mode looked right; problems found:
  1. Dark mode: brand colours turned pastel, so white text on gradient cards and buttons
     was faint (Continue card, Review hero, word card, Get started). → Surfaces now use
     fixed saturated fills (`BrandColor.fill`) in both modes; only text and tints adapt.
  2. The selected "All" chip in Words was white on white in dark mode. → Fixed.
  3. "7 days streak". → "day streak" everywhere.
  4. Lesson subtitles were a lowercase English list. → Georgian words ("მადლობა · გმადლობთ").
  5. No screenshots of exercises in progress. → `-screen exercise -lesson -kind` and 13 more
     shots per appearance; the path also got a dotted trail between stones.
- **Cycle 2** (#8, screenshots only, after #6 hung on a simulator boot and got time limits):
  the borjgali now swirls; exercises have a kind badge, tinted question cards and answers
  near the thumb; dark mode reads well. Build #7 (IPA with all of this) given to the owner,
  who found it "really good" with small things to correct (to come).
  Found for the next cycle: a long Georgian option wraps mid-word in the 2×2 grid
  (ხაჭაპური → "ხაჭაპურ / ი"); at the largest text size the Home tiles wrap "day streak".
- **Fixes after cycle 2** (owner confirmed both): Georgian answers use the 2×2 grid only up
  to 6 letters and stay on one line that shrinks; Home's stat labels stay on one line at
  large text sizes. Not built yet (owner: build when asked).
- **Audio:** 516 clips in Azure's Eka voice (owner's choice), labelled "Synthetic voice";
  `AudioService` reads `audio.json`. Letter and reading prompts offer the speaker only after
  answering.
- **Ara:** the app is renamed Ara (owner's idea; Claude's review: strong, with "parroting",
  the Duolingo bird and findability as risks, answered by an ა-shaped Georgian parrot and
  "Ara: Learn Georgian"). New icon, mascot (`ParrotView`) on welcome, ready and completion
  screens, launch mark, the welcome joke. Developer switch to open all lessons.
