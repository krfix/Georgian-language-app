# TODO

Genuinely unfinished work, most important first. Done items move to DEVELOPMENT_LOG.md.

## Needs the owner
- [ ] Test the app on the iPhone (Feather install) and say what to change.
- [ ] Native audio: every Georgian text has a synthetic Eka clip (870, KART #1 and #2). A
      native speaker's recordings can replace them one by one: same file name in
      `Georgian/Resources/Audio`, `"source": "native"` in audio.json; the app then labels
      them "Native recording".
- [ ] A native speaker's check of the course and the phrasebook (`tools/curriculum/content_*.py`).
      Every word and sentence was checked by Claude and by the build script, but a native
      read-through is the real test. docs/content-quality.md lists what to look at first.
      Then set `PHRASEBOOK_STATUS = "native"` in content_phrasebook.py.
- [ ] Try the phrasebook in real life (a taxi, the bazaar, a café) and say what was missing
      or slow to find.
- [ ] Name: "Ara" chosen (KART #1). Before the App Store: check "Ara: Learn Georgian" is free
      there and in a trademark search. Hide Profile › Developer.
- [ ] Look at the new identity (docs/brand.md, brand/png) and the icon on the iPhone; say
      what to change. A trademark search should cover the symbol too.
- [ ] App Store screenshots are ready (`brand/app-store`); a short App Store preview video
      and the description text are still to write.
- [ ] App Store: an Apple Developer account, signed builds, privacy policy and support URLs.

## Next
- [ ] Icon Composer (on a Mac): a layered `.icon` for iOS 26's Liquid Glass from the
      symbol's parts; the PNG icons work meanwhile.
- [ ] More mascot poses from the same parts (pointing for tips, holding a phrase card for
      Show mode) and perhaps a small animated version.
- [ ] More phrasebook: banking and documents in more depth, the doctor's (body parts),
      renting (viewing a flat), and more dialogues (gym trainer, post office, hairdresser).
- [ ] Phrases with a gap for your own word (a street, a number, a name), shown to someone
      with the word filled in.
- [ ] A home-screen widget or a Siri/Shortcuts action for "Show: please stop here".
- [ ] Audio packs to download (the app is 15 MB of clips now); native recordings first.
- [ ] The owner's list of small corrections from testing build #7.
- [ ] Listening exercises are built only when audio exists, so they can't be tried yet on
      phones without a Georgian voice.
- [ ] More content: Module 2 has ~10 words per theme; Modules 3–5 could each take a second
      round (A1 level).
- [ ] Words in the vocabulary that belong to no lesson (none now; the build script checks).
- [ ] Widgets and a lock-screen streak.
- [ ] iCloud sync (the models are ready for CloudKit: defaults everywhere, nothing unique).
