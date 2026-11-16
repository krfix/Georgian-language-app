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
