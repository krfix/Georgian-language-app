# TODO

Genuinely unfinished work, most important first. Done items move to DEVELOPMENT_LOG.md.

## Needs the owner
- [ ] Web app (KART #9): live at https://aralearn.github.io/app. Try it on the iPhone (Safari ›
      Share › Add to Home Screen; audio; offline after "Keep all audio") and on the PC. The website's
      home page links to it (KART #9). Republish after content changes (web.yml publish, or
      from a chat: web/build.py, copy web/dist to the website repo's app/).
- [ ] Test the app on the iPhone (Feather install) and say what to change.
- [ ] Native audio: every Georgian text has synthetic clips in Eka's and Giorgi's voices
      (1,460 each, KART #1, #2, #5). A native speaker's recordings can replace them one by
      one: same file name in `Georgian/Resources/Audio`, `"source": "native"` in audio.json
      (a native clip plays whichever voice is chosen); the app labels them "Native recording".
- [ ] Try 0.2.1 on the iPhone: the voice step on a fresh start, Profile › Voice, and Learn ›
      Words › More words (გული, heart). The UI tests for these haven't run (no qa run yet).
- [ ] A native speaker's check of the course and the phrasebook (`tools/curriculum/content_*.py`).
      Every word and sentence was checked by Claude and by the build script, but a native
      read-through is the real test. docs/content-quality.md lists what to look at first.
      Then set `PHRASEBOOK_STATUS = "native"` in content_phrasebook.py.
      Ask in particular (KART #8, docs/explanations-review.md): plural things with a singular
      verb (სახლები დიდია, g11); the melody of yes/no questions (g5); the "tight pop" letter tips.
- [ ] Try the phrasebook in real life (a taxi, the bazaar, a café) and say what was missing
      or slow to find.
- [ ] Name: "Ara" chosen (KART #1). Before the App Store: check "Ara: Learn Georgian" is free
      there and in a trademark search. Hide Profile › Developer.
- [ ] Look at the new identity (docs/brand.md, brand/png) and the icon on the iPhone; say
      what to change. A trademark search should cover the symbol too.
- [ ] App Store screenshots are ready (`brand/app-store`); a short App Store preview video
      and the description text are still to write.
- [ ] TestFlight (KART #7): build #39 uploaded. Internal test by the owner, then an external
      group with a public link (Beta App Review). Privacy/support: aralearn.github.io.
      Before the App Store: hide Profile › Developer, age rating, App Privacy ("no data").

## Next
- [ ] Web app, what the iPhone has and the web doesn't yet: reminders
      (a web page can't remind reliably on iPhone), the phrasebook's conversation practice in
      the lesson player (the web has its own Practise screen for them).
- [ ] Before April 2027: build with Xcode 27 (iOS 27 SDK), Apple's warning ITMS-90725 on build #39.
      The workflow picks the newest Xcode 26 on `macos-15`; Xcode 27 likely needs the `macos-26`
      runner. Try it on a branch with one IPA build, then the TestFlight build.
- [ ] Polish (KART #4): a Polish speaker reads the app and the course; Polish App Store text
      and screenshots; the c2 conversation and some phrases still say "from England".
- [ ] Busuu-like direction, next (KART #4 did quieter XP, tappable words, why cards and
      grammar g10–g13): tappable words in the phrasebook's conversations (their lines are play
      buttons now); more past tense (he/she, the -მ ending); a native check of the new grammar.
- [ ] Icon Composer (on a Mac): a layered `.icon` for iOS 26's Liquid Glass from the
      symbol's parts; the PNG icons work meanwhile.
- [ ] More mascot poses from the same parts (pointing for tips, holding a phrase card for
      Show mode) and perhaps a small animated version.
- [ ] More phrasebook: banking and documents in more depth, the doctor's (body parts),
      renting (viewing a flat). (Trainer, post office, hairdresser dialogues: done in KART #4.)
- [ ] Phrases with a gap for your own word (a street, a number, a name), shown to someone
      with the word filled in.
- [ ] A home-screen widget or a Siri/Shortcuts action for "Show: please stop here".
- [ ] Audio packs to download (the app is ~45 MB of clips now: two voices, More words included); native recordings first.
- [ ] The owner's list of small corrections from testing build #7.
- [ ] Listening exercises are built only when audio exists, so they can't be tried yet on
      phones without a Georgian voice.
- [ ] More content: Module 2 has ~10 words per theme; Modules 3–5 could each take a second
      round (A1 level).
- [ ] Words in the vocabulary that belong to no lesson (none now; the build script checks).
      Words seen in the app but outside the lessons are listed as More words (528, KART #5);
      the most useful could become lesson words later.
- [ ] Widgets and a lock-screen streak.
- [ ] iCloud sync (the models are ready for CloudKit: defaults everywhere, nothing unique).
