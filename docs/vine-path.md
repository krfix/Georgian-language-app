# Learn path as a grapevine (idea, KART #14, 24/11/26)

Owner: the Learn path (round stones swinging left and right) looks a bit like Duolingo's;
idea: a tree the parrot climbs from the bottom up, revealing new lessons. Owner loved the
grapevine version below; to start in the next chat. Nothing is built yet.

## Why
- Not a legal problem (a winding path of lessons is a common pattern; nothing of Duolingo's
  is copied), but at a glance it still says "Duolingo", against the KART #2 brief ("not a
  Duolingo clone").
- A grapevine is Georgia's own climbing plant (8,000 years of wine, St Nino's vine cross,
  the vine over every Tbilisi courtyard), and climbing ties Ara, the mascot, to progress.
  A palm tree (Batumi) was the alternative: less unique, a straight trunk with little room.

## The design (first sketch)
- The vine grows **from the bottom up**; Learn opens at the bottom, scrolled to the lesson
  up next. Ara perches beside it.
- Lessons are along the vine: **done** = a ripe purple grape bunch, **up next** = a fresh
  green leaf (gently alive), **open** = a leaf, **locked** = a small bud. Titles and the
  Georgian words stay beside each, as now.
- After a lesson, Ara hops up to the next leaf and it unfolds (Reduce Motion: a fade).
- Each **module is a level** of the vine, its card on a wooden trellis bar, in the module's
  colour (as the ribbon is now).
- At the top, after the last module: a full vine over a supra table (the Tamada stage).
- Grapes on a vine aren't drinking: the age rating (13+, from the wine phrases) is unchanged.

## How to build it
1. **Pictures first:** draw the vine, leaf, grape bunch, bud, trellis bar and Ara perching
   in `tools/brand/make_brand.py` (all artwork comes from there), light and dark; show the
   owner still mock-ups of the Learn screen before any app code changes.
2. Then `Features/Learn/LearnView.swift`: the vine replaces `LessonRibbon` and `PathNode`;
   the path states (`CourseProgress`) stay as they are. Scroll from the bottom. VoiceOver
   still reads the lessons in order as a simple list. Check larger text.
3. The web app's Learn (`web/js/course.js`, `app.css`) the same way.
4. UI tests (Learn, the first lesson) and the qa screenshots; App Store screenshot
   `09-lessons` (and `07-lessons` in Polish) to redo afterwards.
- A cheaper middle step if wanted: keep today's ribbon, but stones become leaves and grapes,
  with Ara perched on the next one.
- Planned for **0.5.0**, after the 0.4.0 App Store launch.
