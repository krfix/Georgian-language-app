import SwiftUI

/// Search everything: phrases first, then situations, conversations and course words.
/// Empty, it offers suggestions, recent searches and recently used phrases. Works offline:
/// it searches the phrasebook and course bundled in the app.
struct SearchView: View {
    @Environment(LearningStore.self) private var store
    @Environment(Navigator.self) private var navigator
    @State private var query = ""
    @State private var openWord: Word?
    @State private var recent: [String] = RecentSearches.load()
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    field
                    if query.trimmingCharacters(in: .whitespaces).isEmpty {
                        idle
                    } else {
                        results(store.phrasebook.search.search(query))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AmbientBackground(tint: .pomegranate))
            .navigationTitle("Search")
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
        .onAppear { apply(navigator.searchRequest) }
    }

    private func apply(_ request: Navigator.SearchRequest?) {
        guard let request else { return }
        navigator.searchRequest = nil
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
            TextField("English, ქართული or Latin", text: $query)
                .font(.bodyRounded)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($focused)
                .onSubmit { remember(query) }
                .accessibilityIdentifier("search-field")
            if !query.isEmpty {
                Button {
                    query = ""
                    focused = true
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.inkFaint)
                }
                .accessibilityLabel("Clear")
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
        .background(Capsule().fill(Palette.surface))
        .overlay(Capsule().strokeBorder(focused ? Palette.pomegranate : Palette.pomegranate.opacity(0.25), lineWidth: focused ? 2 : 1.5))
        .padding(.top, 4)
    }

    // MARK: Nothing typed yet

    @ViewBuilder private var idle: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Try").font(.headlineRounded).foregroundStyle(Palette.ink)
            FlowLayout(spacing: 8, alignment: .leading) {
                ForEach(store.phrasebook.suggestions, id: \.self) { s in
                    Button {
                        Haptics.tap()
                        query = s
                        remember(s)
                    } label: {
                        Text(s)
                            .font(.calloutRounded.weight(.semibold))
                            .foregroundStyle(Palette.pomegranate)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Palette.pomegranate.opacity(0.12)))
                    }
                    .buttonStyle(.pressable)
                    .accessibilityIdentifier("suggestion-\(s)")
                }
            }
        }
        if !recent.isEmpty {
            HStack {
                Text("Recent searches").font(.headlineRounded).foregroundStyle(Palette.ink)
                Spacer()
                Button("Clear") { RecentSearches.clear(); recent = [] }
                    .font(.calloutRounded.weight(.semibold))
                    .foregroundStyle(Palette.pomegranate)
            }
            .padding(.top, 6)
            ForEach(recent, id: \.self) { r in
                Button {
                    query = r
                } label: {
                    Label(r, systemImage: "clock.arrow.circlepath")
                        .font(.bodyRounded)
                        .foregroundStyle(Palette.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                }
            }
        }
        let used = store.recentPhrases
        if !used.isEmpty {
            Text("Recently used").font(.headlineRounded).foregroundStyle(Palette.ink).padding(.top, 6)
            ForEach(used.prefix(6)) { p in PhraseRow(phrase: p, showsCategory: true) }
        }
        ContentCheckNote()
    }

    // MARK: Results

    @ViewBuilder private func results(_ r: PhraseSearch.Results) -> some View {
        if r.isEmpty {
            ContentUnavailableView {
                Label {
                    Text("Nothing found")
                } icon: {
                    ParrotView(height: 110, mood: .think)
                }
            } description: {
                Text("Try one simple word, like \"taxi\", \"price\" or \"doctor\".")
            }
            .padding(.top, 20)
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
            Text(r.phrases.count == 1 ? "1 phrase" : "\(r.phrases.count) phrases")
                .font(.captionBold).textCase(.uppercase).foregroundStyle(Palette.inkSoft)
            ForEach(r.phrases) { p in
                PhraseRow(phrase: p, showsCategory: true)
                    .simultaneousGesture(TapGesture().onEnded {
                        // Opening a result puts the keyboard away: back from the card, the
                        // results (and the tab bar) are in view.
                        remember(query)
                        focused = false
                    })
            }
        }
        if !r.dialogues.isEmpty {
            Text("Conversations").font(.headlineRounded).foregroundStyle(Palette.ink).padding(.top, 6)
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
        if !r.words.isEmpty {
            Text("Words in the course").font(.headlineRounded).foregroundStyle(Palette.ink).padding(.top, 6)
            ForEach(r.words) { w in
                Button {
                    Haptics.tap()
                    remember(query)
                    focused = false
                    openWord = w
                } label: { WordRow(word: w, status: store.status(of: w.id)) }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("word-\(w.id)")
            }
        }
    }

    private func remember(_ q: String) {
        RecentSearches.add(q)
        recent = RecentSearches.load()
    }
}

/// The last few searches, kept on this iPhone only (a convenience, not progress).
enum RecentSearches {
    private static let key = "recentSearches"

    static func load() -> [String] { UserDefaults.standard.stringArray(forKey: key) ?? [] }

    static func add(_ query: String) {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= 2 else { return }
        var list = load().filter { $0.caseInsensitiveCompare(q) != .orderedSame }
        list.insert(q, at: 0)
        UserDefaults.standard.set(Array(list.prefix(8)), forKey: key)
    }

    static func clear() { UserDefaults.standard.removeObject(forKey: key) }
}
