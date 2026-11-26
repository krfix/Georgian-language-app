import SwiftUI

/// The Words tab (KART #6: it took over from Search). One field searches everything:
/// phrases first, then situations, conversations and words. With nothing typed it lists
/// every word, by theme, with how many the learner knows. Works offline: it searches the
/// phrasebook and course bundled in the app.
struct WordsView: View {
    @Environment(LearningStore.self) private var store
    @Environment(Navigator.self) private var navigator
    @State private var query = ""
    @State private var openWord: Word?
    @State private var allWords = false
    /// Words or the 33 letters (KART #20); the tab remembers the last one.
    @AppStorage("wordsShelf") private var shelf = "words"
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                // Lazy: only the rows on screen are built (750 words).
                LazyVStack(alignment: .leading, spacing: 10) {
                    Picker(tr("Show"), selection: $shelf) {
                        Text(tr("Words")).tag("words")
                        Text(tr("Letters")).tag("letters")
                    }
                    .pickerStyle(.segmented)
                    .padding(.top, 4)
                    .accessibilityIdentifier("words-shelf")
                    if shelf == "letters" {
                        AlphabetGrid { letters in navigator.review(letters, title: tr("Letter practice")) }
                            .padding(.top, 6)
                    } else {
                        field
                        if query.trimmingCharacters(in: .whitespaces).isEmpty {
                            WordBrowser(open: $openWord)
                        } else {
                            results(store.phrasebook.search.search(query))
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AmbientBackground(tint: .tkemali))
            .navigationTitle(tr("Words"))
            .sheet(item: $openWord) { w in
                WordDetailView(word: w)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .navigationDestination(for: PhrasebookRoute.self) { route in
                switch route {
                case .category(let id):
                    if let c = store.phrasebook.category(id) { CategoryView(category: c) }
                case .dialogue(let id):
                    if let d = store.phrasebook.dialogue(id) { DialogueView(dialogue: d) }
                case .saved:
                    MyPhrasebookView()
                }
            }
        }
        .onChange(of: navigator.searchRequest) { _, request in apply(request) }
        .onChange(of: query) { _, _ in allWords = false }
        .onAppear {
            apply(navigator.searchRequest)
            if LaunchOptions.current.screen != nil { shelf = "words" }
            if LaunchOptions.current.screen == "word", openWord == nil { openWord = store.curriculum.word("w-khachapuri") }
        }
    }

    private func apply(_ request: Navigator.SearchRequest?) {
        guard let request else { return }
        navigator.searchRequest = nil
        shelf = "words"
        query = request.query
        // The screenshot run doesn't open the keyboard (its first-use tip would cover the screen).
        guard LaunchOptions.current.screen != "search" else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { focused = request.query.isEmpty }
    }

    private var field: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Palette.pomegranate)
            TextField(tr("Words and phrases: English, ქართული, Latin"), text: $query)
                .font(.bodyRounded)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($focused)
                .accessibilityIdentifier("search-field")
            if !query.isEmpty {
                Button {
                    query = ""
                    focused = true
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.inkFaint)
                }
                .accessibilityLabel(tr("Clear"))
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
        .background(Capsule().fill(Palette.surface))
        .overlay(Capsule().strokeBorder(focused ? Palette.pomegranate : Palette.pomegranate.opacity(0.25), lineWidth: focused ? 2 : 1.5))
        .padding(.top, 4)
        .padding(.bottom, 6)
    }

    // MARK: Results

    @ViewBuilder private func results(_ r: PhraseSearch.Results) -> some View {
        if r.isEmpty {
            ContentUnavailableView {
                Label {
                    Text(tr("Nothing found"))
                } icon: {
                    ParrotView(height: 110, mood: .think)
                }
            } description: {
                Text(tr("Try one simple word, like \"taxi\", \"price\" or \"doctor\"."))
            }
            .padding(.top, 20)
        }
        // Words first (this is the Words tab), a few at a time so the phrases stay in view.
        if !r.words.isEmpty {
            let shown = allWords ? r.words : Array(r.words.prefix(4))
            Text(tr("Words")).font(.captionBold).textCase(.uppercase).foregroundStyle(Palette.inkSoft)
            ForEach(shown) { w in
                Button {
                    Haptics.tap()
                    focused = false
                    openWord = w
                } label: { WordRow(word: w, status: store.status(of: w.id)) }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("word-\(w.id)")
            }
            if shown.count < r.words.count {
                Button {
                    Haptics.tap()
                    withMotion { allWords = true }
                } label: {
                    Label(tr("Show all {0} words", r.words.count), systemImage: "chevron.down")
                        .font(.calloutRounded.weight(.semibold))
                        .foregroundStyle(Palette.tkemali)
                        .frame(minHeight: 44)
                }
            }
        }
        if !r.categories.isEmpty {
            FlowLayout(spacing: 8, alignment: .leading) {
                ForEach(r.categories) { c in
                    NavigationLink(value: PhrasebookRoute.category(c.id)) {
                        Label(c.title, systemImage: c.symbol)
                            .font(.calloutRounded.weight(.semibold))
                            .foregroundStyle(c.brand.onColor)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(Capsule().fill(c.brand.fill))
                    }
                    .buttonStyle(.pressable)
                }
            }
        }
        if !r.phrases.isEmpty {
            Text(plural(r.phrases.count, "phrase", "phrases", pl: ("zwrot", "zwroty", "zwrotów")))
                .font(.captionBold).textCase(.uppercase).foregroundStyle(Palette.inkSoft)
            ForEach(r.phrases) { p in
                PhraseRow(phrase: p, showsCategory: true)
                    .simultaneousGesture(TapGesture().onEnded {
                        // Opening a result puts the keyboard away: back from the card, the
                        // results (and the tab bar) are in view.
                        focused = false
                    })
            }
        }
        if !r.dialogues.isEmpty {
            Text(tr("Conversations")).font(.headlineRounded).foregroundStyle(Palette.ink).padding(.top, 6)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(r.dialogues) { d in
                        NavigationLink(value: PhrasebookRoute.dialogue(d.id)) { DialogueCard(dialogue: d) }
                            .buttonStyle(.pressable)
                    }
                }
                .padding(.vertical, 6)
            }
        }
    }

}
