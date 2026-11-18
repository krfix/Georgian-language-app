# Ara: brand identity

The identity designed in KART #3 (17/11/26). The artwork is drawn in code by
`tools/brand/make_brand.py` from the geometry in `tools/brand/ara.py`. That one script writes
the vector masters in `brand/svg`, the previews in `brand/png` and the app's assets. Change
the numbers there, run the script, and every file changes together. Never edit an exported
file by hand. The exploration that led here is in `brand/exploration`.

## The idea

**Learn Georgian. Live Georgian.** Ara is a companion for living in Georgia, not only a
course. The symbol is **Ara's head speaking**: a round head whose hooked macaw beak is also the
tail of a speech bubble. In one colour it reads as a speech bubble; in colour it is a parrot
looking up, curious, with one bright eye. Under the chin a short gold-and-blue curl of neck
feathers carries the scarlet macaw's wing colours. On the mascot those same colours become the
wing.

- The parrot stands for speaking, listening and repeating, which is how a language is learned.
- The speech bubble stands for real conversations: a taxi, the bazaar, a neighbour.
- The name: არა means "no" in Georgian. The app already turns this into a joke on the welcome
  screen ("By the end, you'll be saying კი: yes!"). The logo doesn't spell out არა: the Latin
  wordmark "Ara" and the parrot carry the name, so no one sees a logo that says "No".

## Concepts considered (brand/exploration/1-five-directions.jpg)

| | Direction | Strengths | Weaknesses | Verdict |
| --- | --- | --- | --- | --- |
| A | Whole geometric macaw | Friendly, clear | A generic "cartoon parrot"; detail lost at 29 px | Became the mascot |
| B | Lettermark ა (real Noto Sans Georgian glyph) | Bold, beautiful, true to the script, the first letter learned | To foreigners it reads as "J" or "3"; a font glyph is hard to own | Kept as a story, not the mark |
| C | Two speech bubbles | Clearly "communication" | The generic language-app symbol the brief rules out | Rejected |
| D | Macaw feather as a quill (writing) | Elegant, colourful | Reads as a leaf or a rainbow; thin at small sizes | Rejected |
| E | **Speaking parrot: head = speech bubble** | One silhouette, two meanings; distinctive; strong at 29 px; friendly but not childish; ties straight to the mascot | The beak needed careful geometry | **Chosen** |
| F | ა drawn as a bird | Clever | Bends a real letter (the content rules forbid that) | Rejected |

## Refinement (brand/exploration/2–5)

1. **Beak, first try**: free curves gave a cleaver, not a hook. Rebuilt from circle geometry.
2. **Crescent beak**: precise, but read as a moon behind a ball.
3. **Sickle beak**: an outer arc, a tighter inner arc and a point hanging down like a speech
   bubble's tail; it starts and ends on the head's edge, so there is no seam.
4. **Balance and colour**: the mark is centred by its ink box and fills 64 % of the icon. The
   head is tilted 8° up (curious). Backgrounds tried: turquoise, purple, ink, paper, gold.
   Paper loses the beak and gold flattens the red; Black Sea → Saperavi (the old icon's
   gradient, made brighter with a blue midpoint) gives the most contrast with the red.
5. **Neck curl**: two short bands, gold and deep blue, under the chin. Red, gold and blue
   make it unmistakably a scarlet macaw, and the curl links the symbol to the mascot.
6. **One colour**: the beak stays joined to the head, so the outline is a speech bubble;
   the eye is a hole with the pupil inside.

## The system (brand/svg, brand/png)

| File | Use |
| --- | --- |
| `ara-symbol` | The symbol in colour on any light or dark background |
| `ara-symbol-black`, `-white` | One colour: stamps, embossing, partner pages, small print |
| `ara-app-icon`, `-dark`, `-tinted` | iOS icon (light, dark and tinted home-screen styles) |
| `ara-logo-horizontal` (+ `-dark`, `-black`, `-white`, `-tagline`) | Symbol + "Ara": website header, App Store page, social |
| `ara-logo-stacked` (+ `-dark`) | Symbol above "Ara" and the tagline: posters, splash, presentations |
| `ara-mascot-hello`, `-blink`, `-cheer`, `-think`, `-sleep` | The mascot's poses |
| `ara-app-icon-sizes.png` | The three icons from 300 px down to 58 px on light and dark |

Rules:
- Clear space around the symbol: at least half the head's width on every side.
- Smallest sizes: symbol 16 px; horizontal logo 80 px wide.
- Don't recolour the head, stretch it, add outlines or shadows, or put the colour symbol on a
  red or busy background (use the one-colour version there).
- Inside the app the identity is quiet: the icon, the launch mark, the mascot at key moments
  and the small symbol in Profile. The app's own design system is unchanged.

## Colour

Primary (the app's brand colours, `DesignSystem/Palette.swift`):

| Name | Light | Dark | Role |
| --- | --- | --- | --- |
| Pomegranate | `#E23B4E` | `#FF5D6E` | Ara's red, main accent, buttons |
| Black Sea | `#1592AD` | `#3FC6E0` | Turquoise: icon background, phrasebook |
| Saperavi | `#7A3BC2` | `#B07CF0` | Wine purple: icon background, Learn |
| Gold | `#F5B731` (fill `#F5A623`) | `#FFC25C` | Neck curl, wing band, rewards |
| Tkemali | `#2FA45A` | `#5AD585` | Success, right answers |

Supporting:

| Name | HEX | Role |
| --- | --- | --- |
| Macaw blue | `#1E5FC8` (dark icon `#3C86F0`, on gradient `#16449C`) | Flight feathers, neck curl |
| Horn | `#F7DDAE` | The beak |
| Ink | `#24182A` | Text on light, the pupil |
| Paper | `#FFF7EF` | Light background, the eye |
| Night | `#120E18` / raised `#2B1B3D` | Dark background, dark icon |

Combinations that work: Ink or Pomegranate text on Paper; Paper text on Night; white text
on Pomegranate, Saperavi, Black Sea and Tkemali fills; Ink text on Gold. Avoid Gold text on
Paper (too faint) and red on purple.

## Typography

- **Wordmark**: "Ara" in Nunito Black (SIL Open Font License, `tools/brand/fonts`), set tight
  and turned into outlines, so no font file is needed to show it. Nunito is the closest open
  match to the app's SF Pro Rounded.
- **In the app**: SF Pro Rounded (the system font, rounded design) for Latin text, as now; the
  system Georgian font for Georgian (`DesignSystem/Typography.swift`).
- **Marketing** (website, App Store screenshots): Nunito Black/ExtraBold for headings, Nunito
  for text, Noto Sans Georgian for Georgian. Never fake Georgian with a Latin font or redraw
  its letters.

## The mascot

Ara the macaw: the symbol's head on a scarlet-macaw body (red, a folded wing with a gold
band and blue flight feathers, a long red-and-blue tail). Personality: friendly, curious,
quick, encouraging; a local friend, not a cheerleader.

- **Same head, always.** Moods change only the eye (open, smiling arc, closed), the head's
  tilt and the wing. That keeps Ara recognisable and stops it from becoming a sticker set.
- **Where it appears** (`ParrotView(mood:)`): hello (blinks now and then) on the welcome
  screen and "Nothing saved yet"; cheer on "You're all set" and Lesson complete; think on
  "Nothing found" and the start-up problem screen; sleep on Review's "All caught up".
- **Quiet by design**: once per screen at most, never in the middle of an exercise, never
  talking in speech bubbles of its own. Still with Reduce Motion.
- **Growing the character later**: new poses come from the same parts in `ara.py` (a wing
  pointing for tips, a perch for streaks, holding a phrase card for Show mode). A small
  animated version (Rive or SwiftUI shapes) can reuse the same geometry.

## App Store screenshots (brand/app-store)

Redesigned in KART #6. Made by `tools/appstore/make_screens.py` from the QA run's Simulator
screenshots (Ana, the invented demo learner), at 1320 × 2868 (the 6.9-inch iPhone size App
Store Connect asks for; it scales them for smaller iPhones): ten in English
(`brand/app-store/en`), seven in Polish (`brand/app-store/pl`, for the Polish listing; the
screens whose app text is English only are left out). The order tells the story; the first
three show in search results, so they carry the strongest features:

| # | Headline | Screen | Callout | Colour |
| --- | --- | --- | --- | --- |
| 1 | Learn Georgian. Live Georgian. | Home (dark), with Ara | your level | the icon's gradient |
| 2 | Just show the driver | Show mode, tilted | Taxi · Café · Pharmacy chips | Pomegranate |
| 3 | Type what you want to say | Words, search "water" | the first result | Black Sea |
| 4 | 302 phrases for real life | Use in Georgia | emergency phrases, 112 | Gold |
| 5 | Hear it. Say it. | Phrase card | the sound guide | Tkemali → Black Sea |
| 6 | Practise real conversations | At the bazaar | "How much are the tomatoes?" | Saperavi → Black Sea |
| 7 | From Just landed to Tamada | Progress | the road of six stages | Saperavi → Gold |
| 8 | Read Georgian from day one | Alphabet, tilted | | Pomegranate → Saperavi |
| 9 | Short lessons that stick | Exercise + Review | | Saperavi → Pomegranate |
| 10 | Your Georgia, in your pocket | My phrasebook (dark) | | Night |

The design: one headline (one phrase highlighted in gold), a short line, the real screen in
a phone that runs off the bottom, and a **callout**: a piece of that screen lifted out where
it sits, enlarged 1.2× and tilted, so it reads at thumbnail size. One wave and the borjgali
run across the seams, so the set reads as one strip when swiped. Chips never cover the app's
text.

Rules kept: real screens only; every number read from the content when the script runs;
no claim of native audio ("spoken aloud", "do odsłuchania", not "recorded") or of a native
speaker's check; big headlines that read as thumbnails. When the app changes, run a QA
build, then the script again (callout positions are in screenshot pixels: check them).

## Still to do
- iOS 26 Liquid Glass icon: the PNG icons work, but Icon Composer (Mac only) can turn the
  layers (background, head, beak, curl) into a `.icon` file with real glass depth.
- Before the App Store: a trademark search for "Ara" and the symbol (see TODO.md).
