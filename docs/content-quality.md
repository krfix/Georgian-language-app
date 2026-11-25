# Content quality checklist

The app teaches Georgian, so every Georgian word in it must be right. This is the checklist
for the course (`tools/curriculum/content_words.py`, `content_course.py`) and the phrasebook
(`tools/curriculum/content_phrasebook.py`). Content lives in those files only, never in the
Swift code; `python3 tools/curriculum/build_curriculum.py` turns it into the JSON the app reads
and stops on any mechanical mistake.

## Checked automatically (build_curriculum.py, and the logic tests on the Mac)
- Only Mkhedruli letters and ordinary punctuation in Georgian text (digits allowed in the
  phrasebook, for 112).
- Latin spelling is generated from the Georgian (national system, 2002), never typed, so it
  always matches. The sound guide ("gah-mahr-joh-bah") is generated the same way.
- No phrase twice; ids stable across versions (below); every phrase in a real situation and subcategory; every
  subcategory has phrases; every situation at least five.
- Every phrase has search keywords; register is only "polite" or "informal".
- Links to course words and grammar lessons point at things that exist.
- Every dialogue has both sides speaking and can be practised from either side.
- Search finds the right phrase for the real-life scenarios (tools/Tests/main.swift).

## Checked by a person, for every new or changed phrase
1. **Natural, not translated.** Is this what a Georgian would actually say in that
   situation? Prefer the everyday form (ვერ გავიგე, "I didn't catch it") over a word-for-word
   rendering of the English.
2. **Polite by default.** With strangers, shop staff, drivers, officials and older people,
   use the თქვენ forms (-თ endings: გმადლობთ, გამიჩერეთ). Mark them `reg="polite"`; give the
   friendly form as a variant where it's commonly needed, and mark friend-only phrases
   `reg="informal"`.
3. **Context.** If a phrase only fits some situations, or a word has two meanings (ანგარიში:
   bill and account; ახალი: new and fresh), say so in `note`.
4. **Literal meaning** (`lit`) only when it helps understanding (გამარჯობა, "victory").
5. **English** is natural English for the same situation, with its own punctuation.
6. **Spelling** checked letter by letter, especially the look-alikes კ/ქ/ყ, პ/ფ, ტ/თ,
   ც/წ/ძ, ჩ/ჭ.
7. **Health and emergencies:** words to describe a problem, never advice. No doses, no
   diagnoses, nothing that sounds like a recommendation. Emergency phrases go in the
   `emergency` situation (shown in red, with 112).
8. **Facts in notes** (prices, customs, how things work in Georgia) are stated carefully
   ("usually", "many") and kept few; anything that changes quickly is left out.
9. **Audio:** after a change, `python3 tools/audio/make_audio.py` makes the missing clips in
   both voices, Eka and Giorgi (labelled "Synthetic voice" in the app). Listen to a few new ones.
10. **Every word on screen is in Words:** the build lists words outside the lessons as More
   words and stops if one has no explanation (`build_curriculum.py --more` lists them).

## Ids: correcting or removing without losing anyone's progress (tools/curriculum/ids.json)
Learners' progress (lessons done, review schedules, saved phrases and lists) is saved by id.
`ids.json` records every id ever released with the Georgian it belongs to; the build reuses it,
adds new items to it (commit it with the content), and stops if a released id would vanish.
- **Spelling corrected** (a word or phrase): the build stops and names the old id and the new
  text. Write the new Georgian next to the old id in `ids.json`; build again. The id, and so
  everyone's progress, stays with the corrected phrase. Change the key in `content_pl.py` and
  the glossary too, as for any new text.
- **Removed for good:** add the id to `"retired"` in `ids.json` with a short note. It is never
  given to anything else.
- **Lessons** keep their hand-written ids; a released lesson id can't disappear either.
- "More words" (`x-…`) may come and go with the sentences they're from; their ids stay
  registered, so a word that comes back gets its old id.
- Never edit an id itself. The Mac build checks that ids.json and the JSON are up to date.

## Polish (content_pl.py)
- Every course and phrasebook text has a Polish version; the build stops otherwise.
- Pronunciation by Polish words (ch, sz, cz, ż are Polish sounds); grammar compared with
  Polish where it helps. Gender: give both forms where Polish needs one ("zrozumiałem(-am)").
- Status: written by Claude; not yet read by a Polish speaker.

## Status
- Course and phrasebook: written and checked by Claude (an AI). Not yet checked by a native
  speaker. The app says so (Phrasebook footer, Profile › Phrasebook), from
  `PHRASEBOOK_STATUS = "claude"` in content_phrasebook.py.
- When a native speaker has read through the phrasebook, set `PHRASEBOOK_STATUS = "native"`
  and rebuild: the app's wording changes by itself.

## Points worth a native speaker's attention first
These are correct as far as Claude can tell, but are the most likely to have a more natural
alternative:
- Gym talk: მიდგომა for "a set", ტრენაჟორი for "a machine".
- Admin and phone shops: ინტერნეტის შეყვანა ("having internet installed"),
  ბარათი დამებლოკა ("my card has been blocked").
- Renting: კომუნალურები for utility bills (colloquial).
- The dialogues' wording as a whole, especially the 112 call.
