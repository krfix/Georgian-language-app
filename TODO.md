# TODO

Genuinely unfinished work, most important first. Done items move to DEVELOPMENT_LOG.md.

## Needs the owner
- [ ] Test the app on the iPhone (Feather install) and say what to change.
- [ ] Audio (KART #1): the owner chose Azure's **Eka** voice to start. Waiting for the
      owner's Azure Speech resource (free F0) key, to be given through request_credential,
      never in chat. Plan: generate every clip once (letters, words, examples, dialogue
      lines), bundle them, label them "Synthetic voice"; native recordings can replace
      them file by file later. Native audio: recordings by a native speaker, one `.m4a` per word or letter, named
      by its id (for example `w-gamarjoba.m4a`, `letter-ა.m4a`), in `Georgian/Audio/` added
      to the app's resources. No code change is needed. Until then audio plays only on an
      iPhone that has a Georgian system voice.
- [ ] A native speaker's check of the course (`tools/curriculum/content_*.py`). Every word
      and sentence was checked by Claude and by the build script, but a native read-through
      is the real test.
- [ ] Name: "Ara" chosen (KART #1). Before the App Store: check "Ara: Learn Georgian" is free
      there and in a trademark search. Hide Profile › Developer.
- [ ] App Store: an Apple Developer account, signed builds, privacy policy and support URLs.

## Next
- [ ] The owner's list of small corrections from testing build #7.
- [ ] Listening exercises are built only when audio exists, so they can't be tried yet on
      phones without a Georgian voice.
- [ ] More content: Module 2 has ~10 words per theme; Modules 3–5 could each take a second
      round (A1 level).
- [ ] Words in the vocabulary that belong to no lesson (none now; the build script checks).
- [ ] Widgets and a lock-screen streak.
- [ ] iCloud sync (the models are ready for CloudKit: defaults everywhere, nothing unique).
