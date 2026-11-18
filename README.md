# Ara: Learn Georgian

**Ara** (არა, "no" in Georgian, and a macaw: parrots are great language learners) is a colourful native iPhone app (SwiftUI, iOS 17+) with two halves:
**Learn**, a course in Georgian from zero (the alphabet, everyday words, first grammar and
short conversations), and **Use in Georgia**, a phrasebook for real life (taxis, the bazaar,
cafés, the pharmacy, landlords, the gym, offices, emergencies) that works at once, with no
lessons to finish first. No account, no server, no internet needed: everything is on the phone.
In English or Polish (chosen on the welcome screen or in Profile; Polish explanations compare
Georgian with Polish). Latest release: 0.2.1 (see CHANGELOG.md).

## What's in it

- **Onboarding:** a welcome (English or Polish), a short introduction to Georgian and to the
  method, the voice (Eka, female, or Giorgi, male, each with a sample to hear), your level
  (brand new / a few letters / can read), a daily goal, your name (optional), then straight
  into the first lesson, or straight to the phrasebook.
- **Home:** greeting in Georgian, a search bar, the two halves (Learn, Use in Georgia), the
  situations you need most in one tap, recently used phrases, the next lesson, what's due
  for review and the daily goal.
- **Phrasebook (Use in Georgia):** 302 phrases in 11 situations (essentials, transport,
  shopping and the bazaar, restaurants and cafés, home, gym and sport, health and pharmacy,
  friends and neighbours, work and admin, travel and outdoors, emergencies with 112), and 21
  everyday conversations. Each phrase has a card: large Georgian, Latin letters, an English
  sound guide, audio (normal and slow), when to use it, polite and informal forms, replies you
  may hear, word by word explanations, and the course words and grammar inside it. Save it, put it in a list, practise
  it in review, mark it learned, copy it, or **show it** full screen to a driver or a
  shopkeeper (white on black, the English optional, turned upside down for the person
  opposite, screen kept on).
- **Search** (at the top of Words, and from the search bars on Home and in the Phrasebook):
  English, Polish, Georgian or Latin letters, without exact wording: synonyms ("cab",
  "chemist"), plurals, typos; words first, then phrases, situations and conversations.
- **Conversations:** read and hear both sides, the useful expressions explained, then play
  either side in the lesson player.
- **My phrasebook:** saved phrases by situation, your own lists, what's in review or learned,
  and one button to practise them.
- **Learn:** five modules, 59 lessons, as a winding path (done, up next, open, locked), each
  with a preview and a short "why" card; the 33-letter alphabet chart, coloured by how well
  each letter is known.
- **Tappable words:** every Georgian word in examples, conversations and phrases can be
  tapped: its dictionary form, meaning, and why it looks that way (endings, person, polite -თ).
- **Lessons:** 15 exercise kinds on one engine: new-letter and new-word cards, grammar notes,
  letter recognition, reading, missing letter, meaning, Georgian ↔ English, fill in the gap,
  typing the meaning, matching pairs, building sentences from tiles, spelling with letter
  tiles, flashcards, conversations, and listening (only where real audio exists). Instant
  feedback with the right answer and why; mistakes come back at the end; a completion
  screen with words learned, accuracy, streak, goal and milestones (no XP or levels on screen).
- **Home:** search; your level (a playful stage name), the week and streak; Learn and Use
  in Georgia side by side; the next lesson to continue; the situations; review when
  something is due; recent and saved phrases.
- **Words** (a tab): all 226 course words and phrases by theme, then **More words**: the
  528 other words the app shows anywhere (the letters' example words, words in examples,
  conversations, phrases and grammar tables), each with the sentence it appears in. All
  searchable in Georgian, English, Polish or Latin letters, with Latin spelling,
  pronunciation help, audio, your status and practice.
- **Review:** spaced repetition (each word and letter on its own schedule), difficult words,
  recent mistakes with what you answered, and a letter workout.
- **Progress** (from Home's card): your stage on the journey from "Just landed" to "Tamada",
  what it means and what's next (no exam levels: the app gives none); what you can do now ("Order in a café", "Ask the way"), today's
  challenge, streak, lessons, words and letters learned, accuracy, a week or month chart of
  answers, modules, milestones and the lesson history.
- **Profile:** name, daily goal, starting point, voice (Eka or Giorgi), slower audio,
  language, daily reminder, haptics, appearance (system, light, dark), and Start over.

## The course

| Module | Lessons | What |
| --- | --- | --- |
| The Georgian Alphabet | 10 | All 33 letters, 4–5 at a time, reading real words with only the letters met so far; the tight and puffed sound pairs |
| Essential Vocabulary | 22 | Greetings, introductions, numbers 0–100 and how they're built (counting in twenties), food and drinks, transport, directions, shopping, family, everyday objects, time and dates |
| Everyday Georgian | 8 | Ordering food, groceries, taxis, directions, neighbours, the doctor's, work, small talk |
| Grammar | 13 | Pronouns, "to be", the present tense, want/love/have, questions, negation, case endings, place endings, handy patterns, things and people (მაქვს / მყავს), plurals, the polite you, the past |
| Conversation | 6 | Café, meeting someone, market, taxi, asking the way, plans for tomorrow |

The content is written in `tools/curriculum/` and built into `Georgian/Resources/Curriculum/*.json`
by `build_curriculum.py`, which also checks it, makes the Polish files, the tappable-word
glossary and the More words list (see CLAUDE.md).

## Audio

Every Georgian text with a speaker button has a clip in two synthetic voices from Microsoft
Azure, **Eka** (female) and **Giorgi** (male): 1,460 texts each, about 45 MB, made once by
`tools/audio/make_audio.py` and labelled "Synthetic voice". The learner picks the voice on
the welcome steps or in Profile. No native recordings are included yet; they can replace any
clip later without code changes and are labelled "Native recording" (TODO.md). Without a
clip, the iPhone's own Georgian voice is used if it has one; otherwise there's no speaker
button.

## Install

[`.github/workflows/build-ipa.yml`](.github/workflows/build-ipa.yml) runs on a macOS runner:
tests, then an unsigned `Georgian-<version>-<build>.ipa`. Run it by hand (**Actions → Build
unsigned IPA → Run workflow**, choose the branch); tick **qa** for the Simulator run with UI
tests and screenshots instead. Download the IPA from the run's **Artifacts** and sign it with
Feather, always as `com.aralearn.ge` so your progress is kept. Releases (a new version in
`project.yml` with its CHANGELOG.md section, merged to `main`) are built automatically and
published on the repository's Releases page with the IPA.

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
  Resources/      the course as JSON, audio clips, Polish texts, brand artwork
GeorgianUITests/  UI tests
tools/            course builder, audio maker, Polish checks, brand artwork, logic tests
project.yml       XcodeGen project
```
