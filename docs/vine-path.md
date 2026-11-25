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

## Pictures (KART #15, 25/11/26): drawn twice, waiting for the owner's verdict
`python3 tools/brand/make_brand.py --vine` draws them from `tools/brand/vine.py` (the parts:
leaf, grape bunch, bud, tendril, tapering stem, trellis bar, Ara perched on a branch; light
and dark colours in `VINE_COLOURS`) and `vine_screens.py` (still mock-ups with the real course
text) into `brand/vine/`:
- `vine-parts-light/-dark`: every part with its name.
- `vine-learn-light/-dark`: Learn with the Alphabet and three Vocabulary lessons done; "Where
  are you from?" up next (a glowing leaf, Ara on a branch beside it), the locked lessons as buds on a
  young green shoot (the vine is old wood only as far as the learner has grown), the
  Vocabulary card hanging from its trellis bar on two ropes, the stem winding once round the bar.
- `vine-top-light/-dark`: the top once everything is done: a leafy pergola with grapes over a
  supra table (clay jug, pomegranates, shoti bread, khachapuri), Ara cheering on it, "Tamada".
- `vine-hop`: after a lesson, the leaf turns into a green bunch, Ara hops up, the bud above
  opens into the new leaf.
Second round (owner: "beautiful", but the brown stem just turned into a green one; study real
vines; more cartoon, more variety, more anatomy, green grapes, more leaves). Drawn from how a
grapevine grows (extension and viticulture sources): one stem tapering from trunk to tip that
turns woody from the bottom up, green to yellow straw to cane to shaggy bark, with brown
patches where the bark is forming; nodes (slight swellings) with a leaf each, and opposite the
leaf a bunch (lower down) or a forked tendril (two nodes with one, the third without), curling
or coiled like a spring, some wound round the trellis bar; young bronze-edged leaves higher
up; a growing tip bent like a shepherd's crook; the stem zig-zags a little at each node.
Every leaf is a little different (lobes, teeth, shade). **Grapes ripen**: a lesson just done
is a green bunch (like Rkatsiteli), then it blushes, then turns Saperavi purple. In the
mock-ups that follows how recently the lesson was done; in the app it could follow how well
its words are remembered (their review), so a learner sees the vine ripen as they review. To
decide when building.
Choices made in drawing: the module colour stays on the card, not the grapes; titles sit in one straight column (easier to read, also with larger text);
the stem sways gently instead of the stones swinging. The tab bar in the mock-ups is
simplified (no icons). "Every lesson done: the table is yours." is placeholder text.

## In the app (KART #15, first test build)
`Features/Learn/VinePath.swift` draws the stem live (the same rules as vine.py: width and
woodiness from the lesson's place and the next lesson) and places the pictures from
`Assets.xcassets/Vine` (made by `make_brand.py --vine`, light and dark). LearnView is a lazy
list from the top down: the supra table (`VineTop`), then each module from the last to the
first, its lessons from the last to the first, then its trellis bar and card
(`VineModuleBase`). Every row draws its own slice of the stem from the module's list of
points (`VineMetrics.points`), so the stem runs on unbroken. It opens at the bottom and
scrolls to the next lesson; Ara hops to the new leaf a moment after the path shows again
(`matchedGeometryEffect`). Rows grow with larger text; VoiceOver reads the lessons in
course order (sort priority). Grapes ripen by recency for now (just done green, then
blushing, then purple). Not yet: the web app, UI tests and screenshots for the new path.

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
- Planned for **0.4.1** (owner, KART #15), after the 0.4.0 App Store launch.
