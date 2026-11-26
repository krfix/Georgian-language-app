# App Store: listing and Apple's forms

Everything to paste or tick in App Store Connect (appstoreconnect.apple.com › Apps › Ara:
Learn Georgian) for the first release. Decided in KART #14 (24/11/26): **free, no in-app
purchases, no ads**; the repo stays private. Keep this file true to the app: when the app
changes (iCloud sync, for example), change the answers here and on the website first.

## Checklist

- [x] App record "Ara: Learn Georgian" exists (KART #7), so the name is reserved.
- [x] Profile › Developer hidden in TestFlight and App Store builds (KART #14: only the Feather
      IPA and Simulator runs have it, `LearningStore.devToolsAvailable`).
- [x] Privacy policy and support linked inside the app: Profile › About (KART #14). Apple
      asks for the privacy policy in the app as well as on the listing.
- [x] Export compliance: answered in the app itself (`ITSAppUsesNonExemptEncryption: false`
      in project.yml), so App Store Connect doesn't ask.
- [x] Screenshots: `brand/app-store/en` (10) and `brand/app-store/pl` (7), 6.9" iPhone.
- [ ] Owner: paste the texts below (English, then add Polish as a second language).
- [ ] Owner: App Privacy, Age Rating, Pricing, the EU trader question (below).
- [ ] Version **0.4.0** in project.yml and CHANGELOG.md (owner, KART #14: not 1.0 yet). Owner:
      change the version on App Store Connect's version page from 1.0 to 0.4.0 to match. Then a
      TestFlight build (owner's say-so), then "Add for Review" with that build.

## Listing, English (primary language)

**Name** (30): `Ara: Learn Georgian`

**Subtitle** (30): `Phrasebook for life in Georgia` (no word repeated from the name: both count for search)

**Category:** Education (secondary: Travel)

**Promotional text** (170, can change any time without a new version):
> Read Georgian letters in your first week, then use real phrases in a taxi, at the bazaar or a
> supra. Free, offline, no account.

**Keywords** (100, commas, no spaces; the name and category already count):
`kartuli,tbilisi,batumi,alphabet,mkhedruli,vocabulary,words,letters,language,travel,speak,expat`

**Description** (4000):
> Ara is a Georgian companion for people living in or visiting Georgia. Two halves, one app:
>
> LEARN: a course from zero
> • The 33 letters of the Georgian alphabet, a few at a time, with sounds compared to ones you know
> • 59 short lessons in five modules: reading, everyday words, numbers, first grammar, conversations
> • Every Georgian word can be tapped: its meaning and why it looks that way
> • Review at the right moment: what you know comes back less often, what you miss comes back soon
>
> USE IN GEORGIA: a phrasebook for real situations
> • 302 phrases in 11 situations: taxis, the bazaar, cafés, the pharmacy, landlords, the gym,
>   offices, emergencies (112) and more
> • 21 everyday conversations: hear both sides, then play either one
> • Show mode: a phrase full screen for a driver or a shopkeeper, upside down for the person opposite
> • Search in English or Georgian, with typos and synonyms: "cab", "chemist"
> • Nothing to unlock: every phrase works from the first minute
>
> HEAR IT
> • Every Georgian word and phrase has audio, normal and slow, in Luka's voice. It is a
>   synthetic voice, and the app says so. The alphabet is a native speaker's recording,
>   changed into his voice.
>
> PRIVATE AND OFFLINE
> • No account, no ads, no tracking. Everything stays on your iPhone and works without internet.
>
> IN ENGLISH OR POLISH
> • The whole app, the course and the phrasebook in English or Polish. Polish explanations
>   compare Georgian with Polish.
>
> Ara's lessons and phrases were prepared with the help of AI and checked carefully, and a
> native speaker's check is still to come. Found a mistake or a better way to say something?
> Write to ara.learn.app@gmail.com: every correction makes Ara better.
>
> Ara (არა) means "no" in Georgian, and it's a macaw: parrots are great language learners.

**Support URL:** `https://aralearn.github.io/support`
**Privacy Policy URL:** `https://aralearn.github.io/privacy`
**Marketing URL** (optional): `https://aralearn.github.io`
**Copyright:** `2026 ` + the name on the developer account (Apple shows the seller's name anyway).

**What's New** (not shown for the first version).

## Listing, Polish (App Store Connect › add language › Polish)

**Name** (30): `Ara: Nauka gruzińskiego` (Polish searches find "gruziński")

**Subtitle** (30): `Rozmówki na co dzień w Gruzji`

**Promotional text:**
> Czytaj gruzińskie litery już w pierwszym tygodniu, a potem używaj prawdziwych zwrotów w
> taksówce, na bazarze i przy suprze. Za darmo, offline, bez konta.

**Keywords:** `kartuli,tbilisi,batumi,alfabet,słówka,słowa,litery,język,podróż,gruzja,mówić,rozmówki`

**Description:**
> Ara to gruziński towarzysz dla tych, którzy mieszkają w Gruzji albo do niej jadą. Dwie
> połowy, jedna aplikacja:
>
> UCZ SIĘ: kurs od zera
> • 33 litery gruzińskiego alfabetu, po kilka naraz, z dźwiękami porównanymi do polskich
> • 59 krótkich lekcji w pięciu modułach: czytanie, codzienne słowa, liczby, pierwsza
>   gramatyka, rozmowy
> • Każde gruzińskie słowo można stuknąć: co znaczy i dlaczego tak wygląda
> • Powtórki we właściwym momencie: to, co umiesz, wraca rzadziej, a to, co ci umknęło, szybko
>
> UŻYWAJ W GRUZJI: rozmówki na prawdziwe sytuacje
> • 302 zwroty w 11 sytuacjach: taksówka, bazar, kawiarnia, apteka, wynajem mieszkania,
>   siłownia, urzędy, nagłe wypadki (112) i więcej
> • 21 codziennych rozmów: posłuchaj obu stron, a potem zagraj jedną z nich
> • Tryb Pokaż: zwrot na cały ekran dla kierowcy albo sprzedawcy, odwrócony dla osoby naprzeciwko
> • Wyszukiwanie po polsku, angielsku i gruzińsku, mimo literówek
> • Nic do odblokowania: każdy zwrot działa od pierwszej minuty
>
> POSŁUCHAJ
> • Każde gruzińskie słowo i zwrot ma nagranie, normalne i wolne, głosem kobiecym (Eka) albo
>   męskim (Giorgi). To głosy syntetyczne i aplikacja o tym mówi.
>
> PRYWATNIE I OFFLINE
> • Bez konta, bez reklam, bez śledzenia. Wszystko zostaje na twoim iPhonie i działa bez internetu.
>
> PO POLSKU LUB PO ANGIELSKU
> • Cała aplikacja, kurs i rozmówki po polsku albo po angielsku. Wyjaśnienia dla Polaków
>   porównują gruziński z polskim.
>
> Lekcje i zwroty Ary przygotowano z pomocą sztucznej inteligencji i starannie sprawdzono;
> sprawdzenie przez rodzimego użytkownika jeszcze przed nami. Widzisz błąd albo znasz lepszy
> sposób, żeby coś powiedzieć? Napisz na ara.learn.app@gmail.com: każda poprawka ulepsza Arę.
>
> Ara (არა) to po gruzińsku „nie”, a do tego ara, czyli papuga: papugi świetnie uczą się języków.

**Support / Privacy URLs:** `https://aralearn.github.io/pl/support`, `https://aralearn.github.io/pl/privacy`

## App Privacy

App Store Connect › App Privacy › Get Started:
- "Do you or your third-party partners collect data from this app?" → **No, we do not collect
  data from this app.** The label then reads **Data Not Collected**.
- Why that's true: no account, no server, no analytics, no ads; progress stays on the iPhone;
  reminders are local notifications made by the phone itself; the two links open Safari.
- When iCloud sync comes (KART #14 plan, version 1.1): data in the learner's own private
  iCloud space that the developer can't see still counts as not collected, but the privacy
  page gets a sentence about it first.

## Age Rating

App Store Connect › App Information › Age Rating › Edit. Honest answers:
- Alcohol, tobacco or drug use or references: **Infrequent** (the word for wine, a toast at a
  supra, "Shall I pour you some wine?"). Everything else in the content list: **None**.
- Medical or treatment information: **None** (pharmacy phrases are a phrasebook, not advice).
- Unrestricted web access: **No** (two links open Safari, no browser inside the app).
- User-generated content, messaging or chat, advertising: **No**.
- Gambling, contests, loot boxes: **No**. Parental controls / age assurance: **No**.
- Made for Kids: **No**.

Result (KART #14, 24/11/26): **13+**, from the alcohol answer. Override: Not Applicable; Age
Suitability URL empty. (Social media, location, dating, contests, loot boxes: all No/None.)

## App Accessibility

iPhone only. Claimed (KART #14): **Dark Interface**, **Reduced Motion**. Not yet: Larger Text,
VoiceOver, Voice Control, Differentiate Without Colour Alone, Sufficient Contrast (untested
across whole tasks; TODO.md). Captions and Audio Descriptions: no video.

## Pricing and availability

- Price: **Free** (price tier 0). No in-app purchases.
- Availability: all countries and regions **except China mainland** (needs an ICP licence).

## EU trader status (Digital Services Act)

App Store Connect asks whether you are a **trader**. A trader's address, phone and email are
shown on the App Store in the EU. An individual who publishes a free app with no in-app
purchases, ads or other income can usually say **not a trader**, so those details stay private.
It's the owner's own declaration, and it has to be redone if Ara ever earns money (a tip jar
or paid extras would make you a trader). If unsure, Apple's help page "Manage European Union
Digital Services Act trader requirements" explains it.

Done (KART #14, 24/11/26): **not a trader**, Digital Services Act status Active (27 EU
countries). Account-wide, so it covers Logbook too: switch to trader before either app earns
money. Free Apps Agreement active to 18 Nov 2027; the Paid Apps Agreement is left unsigned.
App Compliance's China rows (security assessment, AI content): not filled; China mainland is
left out in Pricing and Availability instead (it needs a Chinese licence).

## App Review notes (App Store Connect › version › App Review Information)

- Sign-in required: **No**.
- Notes:
  > Ara works fully offline with no account. To try it: pick English, step through the short
  > welcome, then do the first lesson or open the Phrasebook tab (everything there is unlocked).
  > Audio is bundled synthetic speech (an ElevenLabs voice), labelled "Synthetic voice" in the
  > app; the 33 letters are a native speaker's recording changed into that voice, labelled
  > "Native recording, voice changed". Reminders are optional local notifications.
- Contact: the owner's name, ara.learn.app@gmail.com, and a phone number (Apple only).
