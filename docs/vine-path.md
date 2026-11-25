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

## Round 3: painted (KART #15)
Owner tried build #56: the path jumped up and down by itself (the scroll view started at
the bottom with `defaultScrollAnchor(.bottom)` while the lazy rows above were still being
measured, and fought the scroll to the next lesson), and the vector look felt "too gamey".
Owner's reference: a watercolour vine. Asked whether a long raster that loops could be
generated: `tools/brand/watercolour.py` paints in code (wobbly edges, mottled washes,
pigment pooling at the edges, glazes multiplied over each other, rendered by Playwright's
Chromium) a strip `TILE_H` = 8 lessons tall that repeats seamlessly (the overflow is faded
into its top), in two versions with the same shape: old twisted cane and green shoot, for
the app to fade between at the next lesson. Parts painted the same way: bunches (green,
blushing, ripe), the leaf up next, a bud; Ara painted with the same filter in the mock-up.
`make_brand.py --paint` → `brand/paint/` (pictures removed again, in git history). **Owner: no,
back to the vector vine.** Fixed the jumping instead: no bottom anchor, the first scroll to the
next lesson without animation, and the leaf's breathing scoped to its scale (an endless
`withAnimation` started in `onAppear` also animated the row settling in the lazy list).

## Round 4: the original path, reversed, with a vine (owner, KART #15) — built
Owner: keep the original design (stones, icons, titles, swing, cards), reverse it to grow
from the bottom up, and replace the ribbon with a beautiful vine: purple grapes for lessons
done, green grapes for the current one, leaves, twigs and spirals ahead. Completed stones stay
gold; the supra table stays at the top, faded until the end. LearnView is the KART #8 view
again, reversed (cards below their lessons, 76 points of room for the first lesson's grapes),
with `VineRibbon` (VinePath.swift) in place of LessonRibbon: the stem through the stone
centres, bowing between them like the ribbon, woody below the next lesson and green above;
in the gap below each stone a bunch (purple done, green up next) with a leaf opposite, or
leaves and tendrils ahead. A plain VStack again (no lazy rows, so nothing to jump).

Build #58, owner: "not bad". Fixed: leaves hung off their stalks (turned about their
centre, the wrong way round): `VineGrowth.leaf` now turns the blade away from the stem and
places the leaf so its notch sits on the stalk's end; tendril forks curl away from each
other (they curled into a knot); no coiled-spring tendril. The climb to the supra table is a
young green shoot with green leaves, tendrils and unripe bunches (`VineRibbon.climb`), up the
left past the table into the pergola's beam; the picture is at full strength and its words
are above it.

Build #59, owner: much better; the Tamada vine should pass in front of the table and join
the beam, with a vine wound round the beam; nothing cut at the screen's edges; more variety.
Done: the old vine in `VineTop` winds round the whole beam (turns behind and in front of it)
and drops to a woody stub at the left; `VineClimb` draws the climb again over the picture
(in front of the table and jug), turning woody to meet the stub (`VinePoint.wood/width`
overrides). The vine's layers reach the screen's edges (they were cut at the path's 20-point
margins) and `VineGrower` keeps every leaf and tendril inside them (other side, or smaller).
Ten leaf shapes (`leaf_shape_wide`), six tendrils (forked and single); each gap picks its
own number of leaves, sizes, angles, sides and tendrils from a repeatable random number.

Build #61, owner: "well done". Then: the Tamada vine green with green grapes until the
course is done (`VineTop`; done: `VineTopRipe`, brown wood and ripe grapes); the join to the
stub was about 20 points off (measured on the VineTop block, narrower than its picture: now
the picture's own corners); the jug and pomegranates moved right, clear of the climbing vine
(the bread is gone, there was no room).

After 0.4.1 (owner): Ara blended into the light paper (the pale beak), so Ara on the vine is
its own picture, `VinePerchAra` (make_brand.py `perch_parrot`), with a thin deep-plum outline
in light mode (none in dark); Ara is bigger, 84 points (72 where there is no room). The join
to the Tamada vine is now hidden: no stub under the beam and no turns round its left end; the
climb goes up behind the beam and ends in the middle of it (`VineClimb` draws only below the
beam).

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
