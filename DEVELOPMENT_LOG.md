# Development log

Concise record of each work session: what was built, how it was tested, what was found and
fixed. Newest first.

## KART #6 · 18/11/26 · Words lag, Learn title (branch `claude/vigilant-franklin-583csk`)

Owner's report: Learn › Words opens with a short lag; coming back from Words or Progress the
path scrolls to the next lesson and the big "Learn" title stutters; Words should say how many
words there are beyond the course (226 in the course, 528 more).

### Built
- Words: the list is a `LazyVStack` (only rows on screen are built; before, all 754 cards,
  each with a shadow, were laid out on opening), and the search/filter runs once per change
  instead of twice. With the "More words" theme picked, only those 528 are searched.
- Words summary: two cards instead of three tiles. Left: "226 words in the course" with a
  bar and "12 learned · 5 learning". Right: "+528 more from examples and phrases", a button
  that shows just those (same as the "More words" chip; tap again for all). Polish plural forms.
- Learn: the path scrolls to the next lesson only the first time it opens and when the next
  lesson changes, not on every return (`scrolledTo`), so the title no longer jumps.

### Then (owner: Start below the screen's edge in a lesson's preview; tappable words in "Before you start")
- Lesson preview: Start is pinned to the bottom of the sheet (`safeAreaInset`), so it is on
  screen whether the sheet is half or fully open and however many words the lesson lists.
- "Before you start" cards and grammar notes (`NoteView`) draw their text with
  `TappableProse`: Georgian words in bold purple with a dotted line; a tap opens the same
  bubble as in examples (Georgian, Latin, meaning, dictionary form, why). Hyphenated pieces
  (-ში, წა-ვ-ედი) and single letters stay plain. A small "Tap a Georgian word…" hint.
- Build: the words of intros and notes (English and Polish texts) go into the glossary; the
  build stops if one has no explanation (`--notes` lists them). Added მეტი and გამარჯვება;
  15 new tappable words, no existing explanation changed.

### Tested
- `check_strings.py`: 471 texts, none missing. Run #31 (IPA): logic tests passed, app built. UI tests not run.

## KART #5 · 17/11/26 · Voice choice, release 0.2.0 (branch `claude/bold-mendel-napy3u`)

Owner's request: a male voice to choose on the start screen, with examples to hear, and a
way to change it in settings; then release straight away (one build, the release itself).

### Built
- **Giorgi**, Azure's male Georgian voice (`ka-GE-GiorgiNeural`), next to Eka: 964 new clips
  (`kam-…mp3`, index `audio-giorgi.json`). `make_audio.py` now makes both voices
  (`--voice eka|giorgi` for one).
- `AudioService.Voice` (eka, giorgi), saved in UserDefaults `audioVoice`; a clip is looked
  up in the chosen voice, then the other; a native recording in either wins.
- `VoicePicker` (DesignSystem): two cards, each with Listen ("გამარჯობა, როგორ ხარ?").
  On a new onboarding step after "How you'll learn", and in Profile › Audio › Voice in the app.
- The phrasebook's note and Profile's footer name the chosen voice. Polish for every new text.
- UI test: one more step in onboarding, and the voice cards are there.

### Then (owner: every word seen on screen should be in Words, e.g. გული from the letters)
- `build_curriculum.py` collects every Georgian text on screen (letters' example words,
  course words and examples, reading, dialogues, grammar tables, exercise answers and
  tiles, phrases, replies, conversations), finds each word's dictionary form (the glossary's
  forms and endings; ერთ → ერთი) and lists those outside the course as `more` in
  vocabulary(-pl).json: 528 words, id `x-<latin>`, category "more" ("More words" / „Więcej
  słów”), with the shortest sentence they appear in (or the letter's word itself). The build
  stops if a word on screen has no explanation (`--more` lists them); 20 added to
  content_glossary.py (numbers 22–99 from the tables, write and want forms, ნუ, მოიცადე…).
- `Curriculum.moreWords`; `word(id)` finds them, so a card's "Practise this word" and Review
  work; Words lists them after the course's themes; Search finds them ("heart" → გული).
  Logic tests: every letter's word is in Words, გული in English and Polish, ids, Latin.
- Audio for them in both voices (make_audio.py now includes `more`).
- Released as 0.2.1 (run #30): 184/184 logic checks passed, app built, GitHub Release
  v0.2.1 with Georgian-0.2.1.ipa. UI tests not run (Simulator job only).

### Released
- Run #29 on `main`: 174/174 logic checks passed, app built (Xcode 26.3), GitHub Release
  v0.2.0 published with Georgian-0.2.0.ipa. The UI tests (new voice step) weren't run: they
  run only in the Simulator (qa) job.
- The app is about 17 MB bigger with the second voice.

## KART #4 · 17/11/26 · Numbers, Polish, more conversations (branch `claude/charming-hopper-rw555g`)

Owner's requests: a richer numbers lesson (all teens with the rule, examples like 21, 22,
31; words 0–21, 30, 40, 50, 100); the whole app in Polish, chosen at welcome and in
settings, with Polish explanations of pronunciation and grammar; more phrasebook
conversations. Also asked for an opinion (not a build) on a Busuu-like direction: less XP,
more explanation, tappable grammar bubbles.

### Built
- **Numbers:** 13–19, 21 and 50 added (9 new words, each teen with a note on how it's
  built); lessons v6 "Eleven to nineteen", v6b "Twenty to a hundred" and the grammar lesson
  v6c "How numbers are built" (teens, twenties, "twenty and…", numbers with nouns; 8 exercises).
- **Polish (`AppLanguage`, `tr()`):** the app's own words go through `tr("English")`, looked up
  in `Resources/Localization/ui-pl.json` (465 texts, written in `tools/l10n/ui_pl.py`); the
  course and phrasebook load from `*-pl.json`, made by `build_curriculum.py` from
  `content_pl.py`. Choosing: a switch on the welcome screen and Profile › Language; the app
  reloads in place (`AppModel.setLanguage`), progress kept. A Polish iPhone starts in Polish.
- **Written for Polish speakers, not translated:** letter sounds by Polish words (ხ = ch in
  „chleb”, ჟ = ż, ჩ = cz…), the aspiration pairs explained against Polish p/t/k, the soft-i
  trap (სი is „si” as in „taxi”), a Polish sound guide in the phrasebook (ga-mar-dżo-ba);
  grammar compared with Polish (teens like „jede-naście”, cases and the narzędnik for -ით,
  verbs like „podoba mi się”, no he/she, numbers with nouns simpler than Polish).
- **Polish search and answers:** accents optional (zrozumialem = zrozumiałem), Polish
  keywords and synonyms for all 302 phrases, Polish stop words and a rough stem.
- **Phrasebook:** 8 new dialogues (21 in all), each in English and Polish with notes; 80 new
  Eka clips (950 in all).
- **Checks:** `build_curriculum.py` stops on any text without Polish;
  `tools/l10n/check_strings.py` stops on any `tr()` without Polish or with wrong {0}
  placeholders; `tools/l10n/untranslated.py` lists English left outside `tr()`. New logic
  tests: the Polish course loads with the same ids and Georgian, Polish search, answers
  without accents, plurals. The QA run also takes 20 Polish screenshots.

### Then (owner: "Merge, go ahead")
- Merged to `main` (fast-forward, build #23's code).
- **Learning first:** XP and levels off every screen (kept inside for the daily goal);
  Progress's level card became "What you can do"; the activity chart counts answers; three
  XP achievements became milestones (Count to a hundred, Order in a café, Your own sentences).
- **Tappable words:** `content_glossary.py` (BASES: dictionary words; FORMS: verbs and
  irregular forms with notes) plus an ending analyser in `build_curriculum.py` explain all
  834 word forms in examples, conversations and phrases, in English and Polish
  (`glossary.json`, `glossary-pl.json`). `TappableGeorgian` (DesignSystem) shows a bubble;
  phrase cards have "Word by word". The build and a logic test fail if a word has none.

### Then (owner: "Merge and continue"; bug: tapping words sometimes closed the lesson)
- Merged build #25's code to `main`.
- **Bug fixed:** the word bubble was a system popover inside the lesson's full-screen cover;
  dismissing it could dismiss the cover too. The explanation now unfolds under the sentence.
- **"Why" cards:** `INTROS` in content_course.py (34 lessons, Polish versions compare with
  Polish), shown first by `ExerciseBuilder`.
- **Grammar g10–g13:** have (things/people), plurals, polite you, the past; 8 new words, 14 clips.

### Not checked yet
- Nothing compiled here (no Swift on Linux): the Mac run is the first compile.
- The Polish was written by Claude: a Polish speaker's read-through is the real test.
- The new dialogues' Georgian needs the same native check as the rest.

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
- **QA run** (#44031006043, iPhone 17 Pro, Xcode 26.3): compiled first time, 0 warnings,
  142/142 logic checks, 5/5 UI tests, 79 pictures. Looked at: the icon on the real home
  screen (light and dark wallpaper; iOS 26 adds its glass edge; it stays the light icon
  unless the owner picks the Dark style), welcome (hello), Lesson complete (cheer), "Nothing
  found" (think), Review, Profile. All drawn crisp from the vector PDFs.
- **Cycle 1** (from those pictures): the raised wing's red shoulder looked like a stubby arm
  on Lesson complete. → Removed in the cheer pose (checked in the rendered master).

### App Store screenshots (same chat, after the merge)
Nine 1320 × 2868 screens from the QA pictures (`tools/appstore/make_screens.py`, HTML
rendered by Playwright, Nunito and Noto Sans Georgian). Three refinement rounds: (1) tiny
Georgian corner words dropped (unreadable as thumbnails), the parrot moved off the captions,
phones made bigger and bleeding off the bottom on purpose, bigger headlines, a shorter
headline for Show mode; (2) the half-empty matching exercise swapped for "What does it
mean?"; (3) the last slide changed from a second Home to My phrasebook in dark mode, and the
files saved without an alpha channel (App Store Connect refuses one).

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
