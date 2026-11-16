# Georgian

A small, dark SwiftUI app for learning the basics of Georgian on iPhone (iOS 17+).

> **Status:** early work in progress.

## Features

- **Alphabet:** all 33 letters of Mkhedruli in a grid, each with its name, its Latin spelling, how it sounds in plain English and a word that starts with it. Dots under each letter show how well you know it.
- **Practice:** a letter and four answers. New letters join five at a time, in alphabetical order; letters you miss come back more often, and the wrong answers are the letters people really mix up (კ/ქ/ყ, პ/ფ, ტ/თ …). Letters you know well are also asked the other way round.
- Works offline. No account; progress stays on the phone.

## Install

[`.github/workflows/build-ipa.yml`](.github/workflows/build-ipa.yml) runs on a macOS runner: first the tests, then an unsigned `Georgian-<version>-<build>.ipa`. To save build minutes it runs only when started by hand (**Actions → Build unsigned IPA → Run workflow**, choose the branch) or when a release is due on `main`. Releases (with the IPA) are under **Releases**.

**Actions → latest run → Artifacts → `Georgian-<version>-<build>.ipa`** → import it into a sideloading app (e.g. Feather) and sign it. Sign with the same identifier every time (`com.krfix.georgian`), or the phone treats it as a new app and your progress starts over.

## Layout

```
Georgian/
  App/        start, colours, text size
  Models/     the alphabet
  Services/   quiz rules, saved progress
  Views/      screens
tools/Tests/  automatic tests (run by the workflow)
project.yml   XcodeGen project (the .xcodeproj is generated on the build machine)
```
