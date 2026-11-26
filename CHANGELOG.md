# Changelog

What changed in each version, newest first. Versions are 0.x.y (owner, KART #14: the first App
Store version too); the version in App Store Connect must match the one here.

## [0.4.2] - 2026-11-26

One voice, Luka, and the alphabet from a native speaker.

- Every Georgian word and phrase is now spoken by Luka, a new, more natural male voice
- The 33 letters are a native speaker's recording, changed into Luka's voice, and labelled
  "Native recording, voice changed"; the letter card now shows who says the letter
- Eka, the female voice, is off for now, which makes the app less than half the size;
  if you had chosen Eka or Giorgi, you now hear Luka
- Report a mistake from a phrase, a word or a lesson (the flag at the top): it opens your
  own email app with what you were looking at; the app sends nothing
- The daily reminder now comes only on days you haven't practised yet
- Your progress is kept safer: if it ever can't be opened, it's set aside instead of lost,
  and a save that fails tells you so

## [0.4.1] - 2026-11-25

Learn grows like a Georgian grapevine.

- The lesson path now grows from the bottom up: the first lessons at the bottom, the supra
  table at the top, and Learn opens on the lesson you're on
- A grapevine runs from stone to stone instead of the ribbon: old brown wood below your
  lesson, a young green shoot above it. Lessons done hang purple grapes, your current lesson
  green ones, and the lessons ahead have leaves and curling tendrils
- Ara sits on the vine beside the lesson you're on
- At the top, a supra table under a vine: it stays green until you finish the whole course,
  then the grapes ripen
- The path no longer jumps about when it opens

## [0.4.0] - 2026-11-24

Ready for the App Store: free, with no ads, no account and no tracking.

- Profile › About: the privacy policy and help and support pages, in English or Polish
- Every English and Polish explanation in the course read again and tightened
- Learn: the next lesson has a ribbon; the stages line up on Progress; the welcome screen
  fits on one screen in both languages
- Phrases now say they were prepared "with the help of AI", and that a native speaker's
  check is still to come
- Profile shows the build number under the version
- The testing tools (Profile › Developer) are only in test builds, never on the App Store
- New app identifier for the App Store (com.aralearn.ge): an older test install is a
  separate app

## [0.3.0] - 2026-11-18

Simpler to find your way: five clear tabs, a calmer Home, and levels with a story.

- New tab layout: Home · Learn · Phrasebook · Words · Review. Words is a tab of its own:
  every word by theme, with one search over words, phrases, situations and conversations.
  Learn is only the lesson path. Progress opens from Home
- Home, in a new order: search, your progress, Learn and Use in Georgia, Continue learning,
  Right now I need…, review (only when something is waiting), your phrases
- Levels with a story instead of exam levels (A0, A1 are official levels the app can't
  give): ✈️ Just landed, 🪧 Sign reader, 🍇 Bazaar regular, 🍷 Supra guest, 🥂 Tamada's
  apprentice, 🏆 Tamada. Progress shows what yours means, the whole road, and what's next
- Words opens at once (it used to pause), and shows how many words the course teaches
  (226) and how many more you'll meet (528, one tap to see them)
- Tap any Georgian word in "Before you start" cards and grammar notes for its meaning
- A lesson's Start button is always on screen in its preview
- Smoother: the Learn title no longer jumps when you come back; the welcome screen's last
  line fits on one line in English and Polish

## [0.2.1] - 2026-11-17

- Words has every Georgian word the app shows: besides the course's words, "More words"
  lists 528 others (the letters' example words like გული, heart; words from examples,
  conversations, phrases and grammar tables), each with a sentence where it appears, its
  meaning in English or Polish, audio in both voices, and practice. Search finds them too

## [0.2.0] - 2026-11-17

The full app, now called Ara.

- Choose the voice: Eka (female) or Giorgi (male), with a sample to listen to, on the
  welcome steps and in Profile › Voice. Every Georgian text has a clip in both voices
- Learning first: no XP or levels on screen. Home shows words known and a gentle streak;
  Progress shows what you can do now ("Order in a café", "Ask the way"); milestones replace
  the XP achievements; the daily goal is a share of the day
- Tap any Georgian word in examples and lesson conversations: a bubble explains it (its
  dictionary form, the ending or person, the polite -თ), in English or Polish; phrase cards
  have a Word by word section
- A short "why" card opens every word, phrase and conversation lesson (34 of them)
- Four new grammar lessons: things and people (მაქვს / მყავს), plurals, the polite you,
  and the past (ვიყავი, წავედი, ვჭამე…, and why the object changes)
- Polski: the whole app in Polish or English, chosen on the welcome screen or in Profile;
  pronunciation and grammar explained for Polish speakers, with comparisons to Polish;
  Polish search and answers that forgive missing ą, ł, ż…
- Numbers: every number from 0 to 21, then 30, 40, 50 and 100, and a new lesson on how
  numbers are built (the teens, counting in twenties, 21, 22, 31…)
- Eight more conversations in the phrasebook: post office, hairdresser, changing money,
  marshrutka, dinner at a friend's, buying clothes, a mountain trail, a personal trainer
- Use in Georgia: a phrasebook of 302 phrases in 11 real-life situations and 21
  conversations, all usable at once and offline, with Eka audio
- Phrase cards with a sound guide, usage notes, polite and informal forms, replies you may
  hear, and links to the course's words and grammar
- Show to someone: a phrase full screen, white on black, to hold up to a driver or a seller
- Search in English, Georgian or Latin, with synonyms, plurals and typos
- My phrasebook: saved phrases, your own lists, learned marks; saved phrases join Review
- Conversations to read, hear and practise from either side
- New tabs: Home, Learn (with Words and Progress), Phrasebook, Search, Review; a calmer Home
  that shows both learning and using Georgian; "I just need phrases now" on the welcome screen
- The name Ara and its identity: a speaking-parrot symbol (a head whose hooked beak is a
  speech bubble's tail), app icons for light, dark and tinted home screens, a new launch
  mark, and Ara the macaw mascot with moods (hello and blinking, cheer, think, sleep) on the
  welcome screen, lesson complete, Review and empty states
- Georgian audio everywhere in Azure's Eka voice (synthetic, labelled), slower playback, listening exercises
- Developer switch: open all lessons
- A course from zero: 5 modules, 55 lessons, 218 words and phrases, all 33 letters
- 15 exercise kinds on one engine, with instant feedback and retries
- Spaced repetition, difficult words and recent mistakes in Review
- XP, levels, streaks, a daily goal, a daily challenge and 15 achievements
- Onboarding with a first lesson, Home dashboard, a winding learning path, a searchable
  word library, charts in Progress, Profile settings and a daily reminder
- A new look: light and dark, five Georgian colours, the borjgali emblem, springy motion
  that respects Reduce Motion, VoiceOver labels throughout
- Progress saved with SwiftData; audio only from real recordings or a real Georgian voice
- UI tests and Simulator screenshots in the workflow

## [0.1.0] - not released on its own
- The project set-up: XcodeGen project, build workflow with tests, privacy manifest
- Alphabet: the 33 letters in a grid, each with a page (name, Latin spelling, sound, a word)
- Practice: the letter quiz, five new letters at a time, missed letters come back more often
