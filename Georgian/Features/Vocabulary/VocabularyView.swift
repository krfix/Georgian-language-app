import SwiftUI

/// Every word and phrase in the course: search, filter by theme, tap for the full card.
struct VocabularyView: View {
    @Environment(LearningStore.self) private var store
    @State private var query = ""
    @State private var category: String?
    @State private var open: Word?

    private var results: [Word] {
        let q = AnswerEvaluator.plain(query)
        return store.curriculum.words.filter { w in
            (category == nil || w.category == category) &&
            (q.isEmpty || w.ka.contains(query.trimmingCharacters(in: .whitespaces)) || AnswerEvaluator.plain(w.en).contains(q)
             || w.lat.replacingOccurrences(of: "'", with: "").contains(q.replacingOccurrences(of: "'", with: "")))
        }
    }

    var body: some View {
        Group {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    summary
                    categoryChips
                    let groups = Dictionary(grouping: results, by: \.category)
                    ForEach(store.curriculum.categories.filter { groups[$0.id] != nil }) { cat in
                        VStack(alignment: .leading, spacing: 10) {
                            Label(cat.title, systemImage: cat.symbol)
                                .font(.headlineRounded)
                                .foregroundStyle(BrandColor(named: cat.color).color)
                                .padding(.top, 6)
                                .accessibilityAddTraits(.isHeader)
                            ForEach(groups[cat.id] ?? []) { w in
                                Button {
                                    Haptics.tap()
                                    open = w
                                } label: { WordRow(word: w, status: store.status(of: w.id)) }
                                .buttonStyle(.pressable)
                                .accessibilityIdentifier("word-\(w.id)")
                            }
                        }
                    }
                    if results.isEmpty {
                        ContentUnavailableView.search(text: query)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .background(AmbientBackground(tint: .tkemali))
            .navigationTitle("Words")
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Georgian, English or Latin")
            .sheet(item: $open) { w in
                WordDetailView(word: w)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .onAppear {
                if LaunchOptions.current.screen == "word", open == nil { open = store.curriculum.word("w-khachapuri") }
            }
        }
    }

    private var summary: some View {
        let words = store.curriculum.words
        let learned = words.filter { store.status(of: $0.id) == .learned }.count
        let learning = words.filter { [.learning, .difficult].contains(store.status(of: $0.id)) }.count
        return HStack(spacing: 12) {
            StatTile(symbol: "checkmark.seal.fill", value: "\(learned)", label: "learned", color: Palette.success)
            StatTile(symbol: "brain.head.profile", value: "\(learning)", label: "learning", color: Palette.gold)
            StatTile(symbol: "books.vertical.fill", value: "\(words.count)", label: "in the course", color: Palette.saperavi)
        }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: "All", symbol: "square.grid.2x2.fill", id: nil, color: Palette.ink)
                ForEach(store.curriculum.categories) { c in
                    chip(title: c.title, symbol: c.symbol, id: c.id, color: BrandColor(named: c.color).color)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func chip(title: String, symbol: String, id: String?, color: Color) -> some View {
        let selected = category == id
        return Button {
            Haptics.select()
            withMotion { category = id }
        } label: {
            Label(title, systemImage: symbol)
                .font(.calloutRounded.weight(.semibold))
                .foregroundStyle(selected ? (id == nil ? Palette.background : .white) : color)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Capsule().fill(selected ? AnyShapeStyle(color) : AnyShapeStyle(color.opacity(0.12))))
        }
        .buttonStyle(.pressable)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct WordRow: View {
    let word: Word
    let status: ItemStatus

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(word.ka).font(.system(.title3, weight: .bold)).foregroundStyle(Palette.ink)
                Text(word.lat).font(.caption.italic()).foregroundStyle(Palette.inkSoft)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 6) {
                Text(word.en)
                    .font(.calloutRounded.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.trailing)
                StatusBadge(status: status)
            }
        }
        .card(padding: 14, cornerRadius: 18)
        .accessibilityElement(children: .combine)
    }
}

struct StatusBadge: View {
    let status: ItemStatus

    var body: some View {
        switch status {
        case .new: Pill(text: "New", color: Palette.inkFaint)
        case .learning: Pill(text: "Learning", color: Palette.gold, symbol: "circle.lefthalf.filled")
        case .learned: Pill(text: "Learned", color: Palette.success, symbol: "checkmark")
        case .difficult: Pill(text: "Difficult", color: Palette.error, symbol: "exclamationmark.triangle.fill")
        }
    }
}

/// A word's full card: spelling, sound, meaning, example and progress.
struct WordDetailView: View {
    let word: Word
    @Environment(LearningStore.self) private var store
    @Environment(Navigator.self) private var navigator
    @Environment(AudioService.self) private var audio
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                TeachWordView(word: word)
                if audio.source(for: word.ka) == nil {
                    Label("No audio for this one yet. Use the pronunciation help above.", systemImage: "speaker.slash.fill")
                        .font(.caption)
                        .foregroundStyle(Palette.inkSoft)
                        .card(padding: 14, cornerRadius: 16)
                }
                progressCard
                let phrases = store.phrasebook.phrases.filter { ($0.words ?? []).contains(word.id) && $0.id != word.id }
                if !phrases.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("In everyday phrases", systemImage: "bubble.left.and.text.bubble.right.fill")
                            .font(.headlineRounded).foregroundStyle(Palette.pomegranate)
                        ForEach(phrases.prefix(5)) { p in
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(p.ka).font(.system(.headline, weight: .bold)).foregroundStyle(Palette.ink)
                                    Text(p.en).font(.caption).foregroundStyle(Palette.inkSoft)
                                }
                                Spacer(minLength: 8)
                                PlayButton(text: p.ka, size: 34)
                            }
                            .accessibilityElement(children: .combine)
                        }
                        Text("Find them all in the Phrasebook.").font(.caption).foregroundStyle(Palette.inkFaint)
                    }
                    .card()
                }
                Button {
                    Haptics.tap()
                    navigator.sheetOpen = true
                    dismiss()
                    navigator.review([.word(word)], title: word.ka)
                } label: { Label("Practise this word", systemImage: "play.fill") }
                .buttonStyle(ChunkyButtonStyle(color: .tkemali))
            }
            .padding(20)
        }
        .background(Palette.background.ignoresSafeArea())
    }

    private var progressCard: some View {
        let m = store.mastery[word.id]
        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Your progress").font(.headlineRounded).foregroundStyle(Palette.ink)
                if let m {
                    Text("Right \(m.correctCount) times, missed \(m.wrongCount). Next review \(m.due.formatted(.relative(presentation: .named))).")
                        .font(.calloutRounded).foregroundStyle(Palette.inkSoft)
                } else {
                    Text("Not practised yet.").font(.calloutRounded).foregroundStyle(Palette.inkSoft)
                }
            }
            Spacer()
            StatusBadge(status: store.status(of: word.id))
        }
        .card()
    }
}
