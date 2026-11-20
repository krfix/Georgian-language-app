# Ara on the web

The whole of Ara as a web app, drawn like the iPhone app: it opens in any browser, on an
iPhone, an Android phone or a computer, and can be added to the Home Screen, where it opens
like an app and works offline. Tabs as on the iPhone: Home · Learn · Phrasebook · Words · Review
(a floating glass bar: iOS gives web apps no tab bar of its own); Settings from Home's top-right
button.

- **Welcome steps**: English or Polish, meet Georgian, how you'll learn, the voice, how much you
  know, a daily goal, your name, then the first lesson (or straight to the phrasebook).
- **Home**: greeting, search, your stage and week, Learn | Use in Georgia, continue learning,
  "Right now I need…", review when due, recent and saved phrases.
- **Learn**: the five parts of the course, lessons as stones that open in order, a preview of
  each, the alphabet chart. **Lessons**: every exercise of the iPhone app (teaching cards, choice,
  listening, reading, matching, letter tiles, sentence building, typing, flashcards, conversation
  replies), drawn like the iPhone's (KART #11: a badge per exercise kind, the question on a
  tinted card, short answers as a 2×2 grid, speaker and slow-turtle, the letter tile on the
  borjgali sun); a wrong answer comes back at the end; the completion screen (cheering parrot
  on the sun, framed stat tiles, the daily-goal ring).
- **Review**: what's due (1, 3, 8… days; a miss in 10 minutes), letter workout, difficult words.
  Phrases join it with Practise on the phrase card. **Words**: every word, search, a word's card.
  **Progress** from Home's card. **Settings**: profile, language, voice, look, text size, offline,
  developer.

It reads the iPhone app's own content (`Georgian/Resources`): the same phrases, conversations,
word explanations, Polish and audio, checked by the same tools. Nothing is copied by hand, so a
fix to a phrase reaches both apps.

## What's in it

- **Phrasebook**: search, emergencies (with 112 to call), My phrasebook, recently used phrases,
  every situation as a colourful tile, the conversations. Nothing to unlock.
- **A situation**: its phrases by subcategory (chips filter them), its conversations.
- **The phrase card**: the Georgian large with the Latin spelling and meaning, normal and slow
  audio; Show, Save, Learned, Copy, Share; lists of your own; how to say it (the sound guide and
  the tricky letters), word by word, when to use it, other ways to say it, replies you may hear,
  the course words and the grammar behind it.
- **Show mode**: the Georgian huge, white on black, to hold up to a driver or a shopkeeper:
  English on or off, turned upside down for the person opposite, play and play slowly; the
  screen stays on.
- **Conversations**: read and hear them line by line (English and Latin letters on or off),
  useful expressions explained, then play either side: choose each of your lines among three,
  the other side answers aloud.
- **Search**: English, Polish, Georgian or Latin letters, typos and synonyms, over phrases,
  situations, conversations and the course words (the iPhone app's search, ported line by line).
- **My phrasebook**: saved phrases by situation, filtered by your lists or what's learned;
  ⋯ moves a phrase to a list, marks it learned or removes it.
- **Settings**: English or Polish, Eka's or Giorgi's voice, light, dark or the system's look,
  normal or larger text (every screen's text about 15% bigger, for easier reading), keeping all the audio offline, how to add Ara to the Home Screen, privacy.

Everything the learner keeps (profile, finished lessons, review schedules, daily activity, saved
phrases, lists, learned, recents, settings) stays in that browser (`localStorage`); nothing is
sent anywhere. Progress doesn't move between devices.

## Build and try

```bash
python3 web/build.py --serve
```

builds `web/dist/` and serves it at http://localhost:8000. The build fails if a text on screen
has no Polish (`tools/l10n/check_strings.py` reads `web/js/*.js` too). Then:

```bash
node web/tests/search_test.mjs
```

```bash
node web/tests/engine_test.mjs
```

```bash
NODE_PATH="$(npm root -g)" node web/tests/screens.mjs
```

The first runs the iPhone app's search checks against the web search, the second the lesson
engine's; the third walks through
every screen in Chromium at iPhone size (light and dark, English and Polish, a computer and a
small phone), checks saving, lists, Show mode, a whole conversation and search work, and saves
screenshots in `web/dist-screens/`.

```bash
NODE_PATH="$(npm root -g)" node web/tests/audit.mjs [folder] [--quick]
```

is the layout audit (about 7 minutes; `--quick` about 1): every screen and every kind of
exercise for a learner part-way through the course, in English and Polish, with normal and
larger text, at 320, 360, 390 and 440 points wide. It lists any text cut off or clipped,
anything past the screen's edge, an icon off the middle of its circle or tile, and text on top
of other text, and saves full-page screenshots at 390 in `web/dist-audit/`. Overlaps with the
bars that stay put (the title bar, a lesson's Check button) are text scrolling under them,
which is expected.

On GitHub: **Actions › Web app › Run workflow** (`.github/workflows/web.yml`, a Linux machine,
no Mac minutes) does all three and attaches the screenshots and the finished app. Ticking
**publish** puts it live at https://aralearn.github.io/app (only on the owner's say-so).

## How it's made

Plain HTML, CSS and JavaScript modules: no framework and no build tools beyond `build.py`.

| File | What |
| --- | --- |
| `index.html` | the page: the screen area, the tab bar, the sheet and the toast |
| `app.css` | the look: the iPhone app's colours (light and dark), cards, chunky buttons, motion |
| `js/app.js` | the screens and navigation (the address after `#` names the screen) |
| `js/course.js` | the learning screens: welcome, Home, Learn, the lesson player, Review, word card, Progress, profile |
| `js/engine.js` | the course rules, a port of `Georgian/Engine` (exercises, answers, review timing, path, stages) |
| `js/search.js` | search, a port of `Georgian/Curriculum/PhraseSearch.swift` |
| `js/audio.js` | the clips in two voices; no clip, no speaker button |
| `js/store.js` | what the learner keeps, in this browser |
| `js/i18n.js` | `tr()` and `plural()`, like the iPhone app's |
| `js/icons.js` | line icons standing in for SF Symbols |
| `sw.js` | offline: keeps the app and content on install, audio as it plays |
| `manifest.webmanifest` | name, icons and colours for the Home Screen |
| `fonts/` | Nunito and Noto Sans Georgian (SIL Open Font License) |
| `icons/` | made by `tools/brand/make_brand.py --web`; never by hand |

Screens: `#/` Home, `#/welcome/<step>`, `#/learn`, `#/alphabet`, `#/lesson/<id>`,
`#/session/<review|letters|difficult|word:<id>>`, `#/review`, `#/words`, `#/w/<word>`, `#/progress`,
`#/phrasebook`, `#/c/<situation>`, `#/p/<phrase>`, `#/show/<phrase>`,
`#/d/<conversation>`, `#/d/<conversation>/as/<0|1>`, `#/search`, `#/saved`, `#/settings`.
