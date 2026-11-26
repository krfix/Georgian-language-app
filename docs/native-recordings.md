# Native recordings

Every Georgian text in Ara has a synthetic clip (ElevenLabs' Luka since KART #18; Azure's Eka is off for now; labelled "Synthetic
voice"). A native speaker's recording can replace any of them, one at a time: the app and the
web then label it "Native recording" and play it whichever voice the learner chose. Start
with the 33 letters (owner, KART #16): few, short, and the first sounds every learner hears.

## For the speaker
- A quiet room, the phone 20–30 cm away, the iPhone's **Voice Memos** app is fine.
- One recording per letter, said as below: a vowel alone, a consonant followed by **ა**
  (კა, not კ alone, which is how the app plays it). Clear and natural, not slow.
- About half a second of silence before and after (the script trims it).
- Name each file after the letter (`კ.m4a`), or just keep them in this order and say so.
- The speaker's name is shown only if they agree (as Kargi does); say "with the help of a
  native speaker" otherwise. Only their voice goes into the app.

| # | Letter | Latin | Say | File |
| --- | --- | --- | --- | --- |
| 1 | ა | a | ა | `ა.m4a` |
| 2 | ბ | b | ბა | `ბ.m4a` |
| 3 | გ | g | გა | `გ.m4a` |
| 4 | დ | d | და | `დ.m4a` |
| 5 | ე | e | ე | `ე.m4a` |
| 6 | ვ | v | ვა | `ვ.m4a` |
| 7 | ზ | z | ზა | `ზ.m4a` |
| 8 | თ | t | თა | `თ.m4a` |
| 9 | ი | i | ი | `ი.m4a` |
| 10 | კ | k' | კა | `კ.m4a` |
| 11 | ლ | l | ლა | `ლ.m4a` |
| 12 | მ | m | მა | `მ.m4a` |
| 13 | ნ | n | ნა | `ნ.m4a` |
| 14 | ო | o | ო | `ო.m4a` |
| 15 | პ | p' | პა | `პ.m4a` |
| 16 | ჟ | zh | ჟა | `ჟ.m4a` |
| 17 | რ | r | რა | `რ.m4a` |
| 18 | ს | s | სა | `ს.m4a` |
| 19 | ტ | t' | ტა | `ტ.m4a` |
| 20 | უ | u | უ | `უ.m4a` |
| 21 | ფ | p | ფა | `ფ.m4a` |
| 22 | ქ | k | ქა | `ქ.m4a` |
| 23 | ღ | gh | ღა | `ღ.m4a` |
| 24 | ყ | q' | ყა | `ყ.m4a` |
| 25 | შ | sh | შა | `შ.m4a` |
| 26 | ჩ | ch | ჩა | `ჩ.m4a` |
| 27 | ც | ts | ცა | `ც.m4a` |
| 28 | ძ | dz | ძა | `ძ.m4a` |
| 29 | წ | ts' | წა | `წ.m4a` |
| 30 | ჭ | ch' | ჭა | `ჭ.m4a` |
| 31 | ხ | kh | ხა | `ხ.m4a` |
| 32 | ჯ | j | ჯა | `ჯ.m4a` |
| 33 | ჰ | h | ჰა | `ჰ.m4a` |

Then, if they're willing: each letter's example word (the alphabet chart shows them), and
the phrasebook's most used phrases (docs/content-quality.md lists what to check first).

## Putting them in (Claude)
1. Put the files in one folder, each named after the exact text (for letters, the letter).
2. `python3 tools/audio/add_native.py <folder>`: trims silence, evens out the loudness,
   converts to the clips' MP3 format, replaces Luka's clip for that text and marks it
   `"source": "native"` in `Resources/Audio/audio-giorgi.json`. Names it doesn't know are listed.
3. Listen to a few, build (`python3 web/build.py` for the web too), and update the wording
   that says the voices are synthetic where it's no longer true for everything.

## A speaker who doesn't want to be recognised (KART #18)
A recording can be changed into another voice with ElevenLabs' Voice Changer (speech to
speech: the speaker's timing and pronunciation, another voice's sound). It is labelled "Native
recording, voice changed" ("source": "converted") and plays only in the voice it was put
into. Don't name the speaker or where the recording came from anywhere in this public repo.

What was done for the letters, with the account connected to the cloud session (Starter plan,
which allows published use):
1. The speaker's one recording of the 33 letters (said as ა, ბა, გა…) was converted whole, so all
   letters sound alike: `POST /v1/speech-to-speech/<voice id>`, `model_id`
   `eleven_multilingual_sts_v2`. The timing doesn't change, so the letters were cut at the
   pauses found in the original (ffmpeg `silencedetect`, −40 dB, 0.12 s).
2. Voices compared by ear (the account's Georgian voices: Nina, female; Giorgi, Georgie and
   Luka, male). First Giorgi (`Nv45676mL9ReG4hX7uGA`; its წ had a far too loud hiss, fixed
   by converting ც to ჭ again with `remove_background_noise=true`). Then the owner chose
   **Luka** (`NkleFxaKTmzKRWhuoRqb`) for everything, letters included. His ფ sounded like a k
   and his ჰ was a blast of noise: უ to ქ and ხ to the end were converted again six ways
   (seeds 1–6, 4–6 with noise removal); the owner chose ფ 1 and ჰ 6.
3. `python3 tools/audio/add_native.py --voice giorgi --converted <folder>` put them in
   `audio-giorgi.json`.
Breathy sounds (ჰ, ფ, the tight sounds' bursts) are where voice changing goes wrong: listen to
those first.
