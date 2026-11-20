# Development log

Concise record of each work session: what was built, how it was tested, what was found and
fixed. Newest first.

## KART #11 · 20/11/26 · Web lessons like the iPhone (branch `claude/compassionate-brahmagupta-q2dvau`)

Owner, from a "Nowa litera" screenshot of the web next to the iPhone: "possible to make it more
alike?" Compared 23 screens side by side with the iPhone screenshots of QA run #44 (the
TestFlight code): phrasebook, Home, Words and Learn were already close; lessons and the
lesson-complete screen were clearly behind. Owner: do those two.

### Built
- Every exercise drawn from its iPhone view (`Features/Lesson/*.swift`): a coloured badge per
  exercise kind beside the instruction (new icons in `icons.js`), the question on a card tinted
  with the lesson's colour, Georgian sized by length (a letter huge), short answers as a 2×2
  grid of big tiles pushed to the bottom (rows otherwise), speaker plus slow-turtle everywhere
  (`speaker(…, { slow: true })`), the listening circle with "Slower".
- New letter: the gradient tile on the turning borjgali sun (`sun()` ports `BorjgaliShape`),
  name and Latin pills, the "Sounds like" card with lips, the example word as a row. New word:
  a gradient card in its theme's colour, "Say it", the Example card, the note.
- Typing, tiles (dashed answer box, Latin under spelling letters, places kept in the bank),
  matching, flashcards (gradient faces, buttons under the card), conversation turns (avatar,
  bubbles, divider), grammar tables (striped, framed), the feedback panel (rounded, tinted).
- Lesson complete: the cheering parrot (`mascot-cheer.svg`, made by `make_brand.py --web`) on
  the sun, a crown when flawless, framed stat tiles, the daily goal as a ring, milestones.
- Fixed on the way: the speaker on a letter-recognition or reading question gave the answer
  away (now only after answering, as on the iPhone); the combo flame shows from 3 in a row.

### Tested
- Every exercise kind screenshotted (dark English, light Polish) and compared with the iPhone's.
  Found and fixed: the flashcard's back side collapsed (its class `back` was the round back
  button's), the goal ring's class `ring` moved the welcome screen's flying letters.
- `audit.mjs` full run: what's left is text scrolling under the bars that stay put (a lesson's
  bottom button, the feedback panel, the title bar), as before. `screens.mjs` all fine;
  `engine_test.mjs` (21) and `search_test.mjs` (38) pass; `check_strings.py` 0 missing.

### Published (owner: "publish")
- `web.yml` with publish from the branch: run #3 failed twice before any step (no machine
  started: Actions minutes or spending limit). The owner accepted new billing; run #4 built,
  tested, photographed and published to aralearn.github.io/app; then merged to `main`.

### Updates didn't reach the phone (owner: "it doesn't seem to update the app")
- Two causes: a new version's files were fetched through the browser's HTTP cache (GitHub Pages
  allows 10 minutes), so the new version could be stored with the old files; and a Home Screen
  app is mostly resumed, not restarted, so it rarely looked for a new version.
- `sw.js` now fetches every file fresh on install (`cache: "reload"`). `app.js`
  (`watchForUpdates`) checks at start, on coming back to the screen and every half hour; a new
  version in the first 5 seconds reloads at once (outside a lesson), later a bar "A new version
  of Ara is ready · Update" appears (EN/PL).
- Tested in Chromium with a server that allows 10-minute caching: published while open → bar →
  Update → new files; published while closed → new files on the first open.

## KART #10 · 20/11/26 · Web app polish, text size (branch `claude/epic-galileo-1bdun4`)

Owner, from iPhone screenshots of the live web app: an old icon on a lesson, "Opanow…" cut on
the phrase card, Home's icons off-centre and a line wrapping. Then: "go through the whole web
app… centred icons, no cutting items… add a toggle for bigger text", "rather similar but very
good than exactly the same but buggy".

### Built
- Profile › Appearance › Text size: Normal or Larger (`textSize`, `html[data-text="large"]`,
  every rem about 15% bigger; body text in rem now). Polish in `ui_pl.py`.
- `web/tests/audit.mjs`: every screen and exercise kind for a seeded learner, EN/PL, normal and
  larger text, 320/360/390/440 wide; lists cut, clamped, off-screen, off-centre and overlapping
  items and saves full-page screenshots (about 7 minutes, `--quick` about 1).
- Fixes it and the screenshots found: fixed-pixel cards (conversations, recent phrases, situation
  tiles, lesson subtitles) now grow in rem and wrap instead of "…"; topbar titles wrap; the
  matching grid splits the width evenly; Home's section links wrap under long titles; shortcut
  labels wrap in their tile; tab labels always fit; Home's Learn / Use in Georgia icons centred
  (a stray margin); the Learn path swings less on narrow screens and with larger text; the
  daily-goal menu shows the plan's name with its description below; the save-all-audio button's
  size is a quieter second part; chunky buttons have room for two lines; letters icon "Aa", the
  reading lesson's stone the book, a real puzzle piece for grammar; no double-tap zoom.
- Bug: a sheet stayed open over the next screen after Safari's swipe back; it now closes.

### Tested
- The audit went from 284 findings to 18, all text scrolling under the bars that stay put (the
  title bar, a lesson's bottom button), which is expected. Looked at every screen normal and
  larger side by side; bottoms of pages clear the tab bar; sheets checked at screen size.
- `search_test.mjs` (38) and `engine_test.mjs` (21) pass; `screens.mjs` all fine.

### Published (owner: "publish and merge")
- Merged to `main` (fast-forward, 0e02156). `web.yml` with publish failed at the last step: the
  `WEBSITE_TOKEN` secret isn't set. Published from the chat instead (owner: "yes, add the
  website repo"): web/dist (version 90fe36da19) copied to the website repo's `app/`. The privacy
  page needed no change (the text size stays in the browser like the other settings).
- The owner then added the `WEBSITE_TOKEN` secret; a `web.yml` publish run succeeded ("Nothing
  new to publish"), so publishing works from GitHub too.

## KART #9 · 20/11/26 · Web app, phrasebook (branch `claude/happy-carson-cc03jn`)

Owner (after KART #8's recommendation): "start the web app, phrasebook first". The code lives in
`web/`, reads the iPhone app's content, and is published to aralearn.github.io/app only on say-so.

### Built
- `web/`: the phrasebook as a web app (plain HTML/CSS/JS modules, no framework). Phrasebook home,
  situations, the phrase card (word by word, sound guide, forms, replies, course words, grammar),
  Show mode (fitted text, flip, English on/off, slow play, screen kept on), conversations and
  playing either side, search, My phrasebook with lists, Settings (English/Polish, Eka/Giorgi,
  light/dark/system, all audio offline). Tab bar: Phrasebook · Search · My phrasebook · Settings.
- `js/search.js`: PhraseSearch.swift ported line by line (stems, typos, synonyms, Polish).
- Offline: `sw.js` keeps the app and content on install, each clip as it plays (Safari's byte
  ranges cut from the whole file), or all of one voice from Settings (~16 MB).
- `web/build.py`: content, slim word list, lesson titles and the clips for every phrase, line
  and course word (both voices) into `web/dist/`, with the offline version; fails without Polish.
- `tools/brand/make_brand.py --web`: home-screen icons, favicon and two mascot poses.
- `tools/l10n/check_strings.py` reads `web/js/*.js`; 31 new Polish texts in `ui_pl.py`.
- `.github/workflows/web.yml` (Linux, by hand): build, checks, screenshots, the app as an
  artifact, optional publish. `build-ipa.yml` ignores `web/` on main.

### Tested
- `web/tests/search_test.mjs`: the iPhone app's 38 search checks (English and Polish) pass, and
  every phrase and conversation line has a clip in both voices.
- `web/tests/screens.mjs` (Chromium, 390×844, light/dark, EN/PL, plus 1280 and 320 wide): every
  screen loads with a clean console, saving and lists survive a reload, Show mode text ≥ 40 px,
  a whole conversation can be played, search finds pharmacies, no sideways scrolling. Screenshots
  looked at: a turtle icon that read as a car redrawn; the offline button's text shortened.
- Not yet on a real iPhone (Add to Home Screen, audio in Safari, offline).

### Published (owner: "publish")
- aralearn.github.io: `app/` = web/dist (version 9bc7d58123); privacy page gained "The web
  version" / "Wersja w przeglądarce" (browser-only storage, GitHub Pages hosting), dated 20/11/26.
  Pages deployment succeeded. The home page doesn't link to /app yet.

### Owner's first test, and the iPhone's tab bar
- Settings › Listen was silent: the voice sample had no clip in the web build (now included).
- No Ara logo on the Phrasebook (the iPhone app has none there).
- Tab bar as on the iPhone: Home · Learn · Phrasebook · Words · Review, drawn as a floating
  frosted-glass bar (iOS gives web apps no tab bar of its own). Home for now: greeting, the
  profile button (top right) to Settings, search, Learn | Use in Georgia, situations, recent
  phrases. Words: the word list with search over everything. Learn and Review: "coming next".
  My phrasebook, Search and Settings open with a back button. SF Rounded on Apple devices.

### The whole app on the web (owner: "the web app is the reflection of the iPhone app")
- `web/js/engine.js`: ExerciseBuilder, AnswerEvaluator, LessonSession, SpacedRepetition,
  CourseProgress and CourseStage ported; `store.js` keeps the profile, finished lessons, review
  schedules and daily activity (XP inside only, for the daily goal, as on the iPhone).
- `web/js/course.js`: the welcome steps, Home in the owner's order, Learn (module cards, stones,
  preview sheet, alphabet chart), the lesson player (every shape, feedback panel, retries, combo,
  quick pass in developer mode) and completion, Review, a word's card, Progress, profile settings.
  The phrase card gained Practise (into review), as on the iPhone. Build ships the course,
  vocabulary and all 2,920 clips (41.6 MB; one voice offline ≈ 21 MB).
- Fixed on the way: leaving a lesson opened from the welcome steps left the site (Back now
  never leaves Ara); bigger single letters as questions; red wrong picks; progress bars on Progress.
- Tested: `engine_test.mjs` (every lesson in English and Polish builds and its right answers
  check; retries; typos; review timing 1/3/8 days and 10 minutes; the path; stages), 21 checks;
  the browser test now walks every welcome step and a whole first lesson in light/dark, EN/PL,
  and checks progress survives a reload; words (v1), grammar (g1) and conversation (c1) lessons
  played to the end by hand. Not yet on a real iPhone.
- Published to aralearn.github.io/app (owner: "publish"), privacy page first (lessons, review
  and a name stay in the browser too). Merged to `main` (owner: "merge"); web build 43's code
  checked: the web started from `main` after TestFlight build 43 (commit 186d123).
- Then: tappable words (dotted underline, a bubble with Latin, meaning, dictionary form and why)
  in lesson examples, notes, tips, conversation lines and word cards; the ribbon on the Learn
  path; the 16 milestones on Progress; "Practise these" in My phrasebook.
- Published that (owner: "publish and continue"). Then the lesson-complete screen as on the
  iPhone: "ყოჩაღ! (well done!)", Accuracy / Words you know / Day streak, a milestone just
  reached, and today's goal. The daily challenge isn't shown on the iPhone any more, so not here.
- Website: "Try Ara in your browser" on the home page (English, Polish). Published.
- Owner's iPhone test: the alphabet card's icon is now the book (as on the iPhone and the Words
  tab); nothing plays by itself any more (teaching cards, listening, answers, matching, the
  voice choice): sound only from a tap; taps play at once: every clip on screen is decoded
  ahead and started through Web Audio (an <audio> element only for slow play or a clip not
  ready), and Safari's audio session is set to "playback" so the silent switch doesn't mute it.

## KART #8 · 19/11/26 · Explanations review (branch `claude/eager-johnson-9ccb2m`)

Friends and family are testing on TestFlight. Owner asked for a linguistic check of every English
and Polish explanation (module intros, "why" cards, letter tips, grammar notes, answer feedback,
word notes).

### Built
- `docs/explanations-review.md`: the findings, then every explanation in English and Polish side by side.
- Fixed: the instrumental -ით/-თი rule (v9), the teens (თ melts into ს/შ/ც: 13, 17, 19; 18 swaps
  -რვ-), the food-words card (ჩაი and ყავას were wrong examples), შეიძლება has no "me" (g9),
  Polish "w mianowniku" after numbers, 50 = two twenties and ten, tapped r, ჩემი (v16), "you'll
  say მოუხვიეთ in a taxi", tetri, amount before thing (e2), -იდან/-დან (v4), the რა exclamation.
- Clearer: tight-sound tips (p in spin "plus a pop"), ყ without "click", "dz as in adds", the
  contrast note, g3 (no mark for "you", pronoun dropped), g6 (what არ, ვერ, ნუ mean), ის = "that",
  Mtavruli on signs, ჰ for Poles, a g11 note on plural things with a singular verb.
- Polish: dropped the "gdzieś" and "polska wieś" comparisons and "მაქვს = mi jest"; "kawy" throughout;
  Russian czaj and неделя phrased correctly. Male forms stay (owner).

### Tested
- build_curriculum.py and check_strings.py pass; no new audio needed (0 clips to make).

### Built (second batch, owner's iPhone 13 test)
- Learn: the dotted trail is now one ribbon (`LessonRibbon`, stones report their centres with
  `StoneCentres`): a soft 40 pt band and a thin line weaving across it, each piece bowing to
  alternate sides like the App Store wave, in the module's colour up to the next lesson, and
  running on under the module cards.
- Progress: the six-stage row hangs from the top (a two-line Polish name pushed its stop out of
  line), the line runs through the stops' centres, and the stops are solid so it can't show
  through. (A drawn twin-engine plane replaced ✈️ in build #41; the owner preferred the emoji back.)
- Welcome: no scrolling; `ViewThatFits` shows the largest of three sizes (1, 0.8, 0.62) that fits,
  and scrolls only with very large text. Slogan kept (owner).
- Developer mode: one switch in Profile › Developer reveals Open all lessons and Quick pass. Quick
  pass puts a dashed gold Pass button in the lesson's top bar: tap counts the exercise as right
  and moves on (`passCorrect`), hold finishes the lesson (`passAll`), VoiceOver actions for both.
- v1 card: the time-of-day greetings named (morning, evening, night), and Polish „pokoju” made
  clear as peace, not a room.

## KART #7 · 18/11/26 · TestFlight (branch `claude/dazzling-cray-izaxbp`)

Owner's developer account is active; goal: Ara on TestFlight for friends and family.

### Built
- Bundle ID `com.aralearn.ge` (was `com.krfix.georgian`; the owner didn't want the GitHub
  name in it). Registered at developer.apple.com; app record "Ara: Learn Georgian" in App
  Store Connect (English (U.K.), SKU ara-001).
- Workflow option `testflight`: logic tests, an unsigned archive, then `xcodebuild
  -exportArchive` with the App Store Connect API key (Admin), which signs with Apple's
  cloud-managed distribution certificate and uploads. Secrets: `ASC_KEY_ID`,
  `ASC_ISSUER_ID`, `ASC_KEY_P8`, `APPLE_TEAM_ID`.
- Website `aralearn/aralearn.github.io` (GitHub organisation `aralearn`): home, privacy,
  support, English and Polish, Ara's colours, light and dark. Contact ara.learn.app@gmail.com.
- On screen, "with the help of AI" instead of naming Claude (phrase note, Profile › Checked by).

### Tested
- Build #39 (0.3.0): 192/192 logic tests, archive and upload succeeded on the first try
  (about 2 minutes on the Mac). Pages checked at iPhone width in light and dark (Playwright).

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
  15 new tappable words, no existing explanation changed. Run #32 (IPA): logic tests passed,
  app built; UI tests not run.

### Then (owner: the welcome screen's last line is two lines in English, one in Polish, so the buttons shift)
- Shorter English ("No account needed. Stays on your iPhone, works offline."), held to one
  line (shrinks slightly if a language needs it). Run #33 (IPA): built, logic tests passed.

### Then (owner: Words and Progress were hidden in Learn; simpler Home; no A0/A1 levels)
- Tabs: Home · Learn · Phrasebook · **Words** · Review. Words (`WordsView`) replaces Search:
  one field searches everything (words first, four at a time with "Show all", then phrases,
  situations, conversations); empty, it lists every word (`WordBrowser`: the two counts, the
  themes, lazy rows). Recent searches and suggestions dropped (Home has the situations and
  recent phrases). Learn has only the path. The search bars on Home and in the Phrasebook
  open Words with the keyboard up.
- Home, in order: greeting (no stats line), `HomeProgressCard` (stage emoji and name, % of
  the course, week dots, streak; opens Progress), Learn | Use in Georgia as low tiles (title
  left, icon right, one line, thin bar; Learn shows the next lesson and opens its preview),
  review only when due, search, situations, phrases. Continue card and Daily goal removed.
- Levels: `CourseStage` (Engine, logic-tested): ✈️ Just landed, 🪧 Sign reader, 🍇 Bazaar
  regular, 🍷 Supra guest, 🥂 Tamada's apprentice, 🏆 Tamada, one per finished module ("I can
  read" starts as Sign reader). Progress opens with the stage card: name, what you can do, a
  short story of what it means, the six stages as a road, the next one with lessons to go,
  and "Not an official exam level". English and Polish.
- UI tests: tab names, Progress from Home's card, the Words tab's search.
- Run #34 (IPA): 192/192 logic checks passed (8 new for the stages), app built. UI tests
  not run yet (the qa run before merging).

### Then (owner, on build #34: search first, the Continue card back, Learn tile just opens Learn)
- Home: greeting, search, progress card, Learn | Use in Georgia, Continue learning (the big
  card, back), Right now I need…, review (when due), phrases. The Learn tile opens the Learn
  tab ("Your course, step by step"). Run #35 (IPA): built, logic checks passed.

### Then (owner: App Store screenshots, designed properly)
- `tools/appstore/make_screens.py` redesigned: callouts (a piece of the screen lifted where it
  sits, 1.2×, tilted), one wave and borjgali across the seams, gold highlight in each
  headline, tilted and paired phones, chips beside (never on) the text. Ten English slides
  (new: "From Just landed to Tamada"; the new Home; Words search) in `brand/app-store/en`,
  seven Polish ones in `brand/app-store/pl`. Numbers read from the content (302 phrases, 11
  situations, 21 conversations, 59 lessons, 33 letters). From the QA run #36 screenshots;
  its light English Home came out as the iPhone's home screen (a launch that didn't open in
  time), so slide 1 uses the dark Home.

### Released
- Run #36 (qa, the branch): 192/192 logic checks, 5/5 UI tests (welcome steps with the voice
  step, a first lesson, the tabs, review, Words search, phrasebook scenarios), screenshots
  looked at (Home in Polish, Progress, Words). Merged to `main` (fast-forward); run #37
  published GitHub Release v0.3.0 with Georgian-0.3.0.ipa.

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
