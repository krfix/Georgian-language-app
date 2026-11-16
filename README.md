# Georgian

A colourful native iPhone app (SwiftUI, iOS 17+) for learning Georgian from zero: the
alphabet, everyday words and phrases, first grammar and short conversations. No account, no
server: everything stays on the phone.

## What's in it

- **Onboarding:** a welcome, a short introduction to Georgian and to the method, your level
  (brand new / a few letters / can read), a daily goal, your name (optional), then straight
  into the first lesson.
- **Home:** greeting in Georgian, streak, XP and level, the daily goal ring with the week,
  the next lesson, the path ahead, today's challenge and what's due for review.
- **Learn:** five modules as a winding path of lessons (done, up next, open, locked), each
  with a preview; the 33-letter alphabet chart, coloured by how well each letter is known.
- **Lessons:** 15 exercise kinds on one engine: new-letter and new-word cards, grammar notes,
  letter recognition, reading, missing letter, meaning, Georgian ↔ English, fill in the gap,
  typing the meaning, matching pairs, building sentences from tiles, spelling with letter
  tiles, flashcards, conversations, and listening (only where real audio exists). Instant
  feedback with the right answer and why; mistakes come back at the end; a completion
  screen with XP, accuracy, streak, goal, level-ups and achievements.
- **Words:** all 209 words and phrases, searchable in Georgian, English or Latin letters,
  by theme, each with Latin spelling, pronunciation help, an example sentence and your status.
- **Review:** spaced repetition (each word and letter on its own schedule), difficult words,
  recent mistakes with what you answered, and a letter workout.
- **Progress:** level, XP, streak, lessons, words and letters learned, accuracy, a week or
  month chart against the goal, modules, 15 achievements and the lesson history.
- **Profile:** name, daily goal, starting point, slower audio, daily reminder, haptics,
  appearance (system, light, dark), and Start over.

## The course

| Module | Lessons | What |
| --- | --- | --- |
| The Georgian Alphabet | 10 | All 33 letters, 4–5 at a time, reading real words with only the letters met so far; the tight and puffed sound pairs |
| Essential Vocabulary | 20 | Greetings, introductions, numbers (counting in twenties), food and drinks, transport, directions, shopping, family, everyday objects, time and dates |
| Everyday Georgian | 8 | Ordering food, groceries, taxis, directions, neighbours, the doctor's, work, small talk |
| Grammar | 9 | Pronouns, "to be", the present tense, want/love/have, questions, negation, case endings, place endings, handy patterns |
| Conversation | 6 | Café, meeting someone, market, taxi, asking the way, plans for tomorrow |

The content is written in `tools/curriculum/` and built into `Georgian/Resources/Curriculum/*.json`
by `build_curriculum.py`, which also checks it (see CLAUDE.md).

## Audio

iOS doesn't have a Georgian voice on every iPhone, and no recordings are included yet, so the
app plays Georgian only where it really can: a native recording in the app, or the iPhone's
own Georgian voice (labelled "Synthetic voice"). Recordings can be added later without code
changes (TODO.md).

## Install

[`.github/workflows/build-ipa.yml`](.github/workflows/build-ipa.yml) runs on a macOS runner:
tests, then an unsigned `Georgian-<version>-<build>.ipa`. Run it by hand (**Actions → Build
unsigned IPA → Run workflow**, choose the branch); tick **qa** for the Simulator run with UI
tests and screenshots instead. Download the IPA from the run's **Artifacts** and sign it with
Feather, always as `com.krfix.georgian` so your progress is kept.

## Layout

```
Georgian/
  App/            start, launch options
  Curriculum/     course types and loading (no UI)
  Engine/         exercises, answers, sessions, review schedule, XP, streaks (no UI)
  Data/           SwiftData models and the store
  Audio/          audio and reminders
  DesignSystem/   colours, type, motion, components
  Features/       the screens
  Resources/      the course as JSON
GeorgianUITests/  UI tests
tools/            course builder, logic tests
project.yml       XcodeGen project
```
