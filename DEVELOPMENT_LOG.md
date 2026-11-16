# Development log

Concise record of each work session: what was built, how it was tested, what was found and
fixed. Newest first.

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

### Runs
- (filled in below as the Mac runs come back)
