import SwiftUI

/// Every word and phrase in the course, then every other word the app shows (letters'
/// example words, examples, conversations, phrases: "More words"): search, filter, tap.
struct VocabularyView: View {
    @Environment(LearningStore.self) private var store
    @State private var query = ""
    @State private var category: String?
    @State private var open: Word?

    private var results: [Word] {
        let q = AnswerEvaluator.plain(query)
        let raw = query.trimmingCharacters(in: .whitespaces)
        let qLat = q.replacingOccurrences(of: "'", with: "")
        let pool = category == "more" ? store.curriculum.moreWords
            : category == nil ? store.curriculum.words + store.curriculum.moreWords
            : store.curriculum.words
        return pool.filter { w in
            (category == nil || w.category == category) &&
            (q.isEmpty || w.ka.contains(raw) || AnswerEvaluator.plain(w.en).contains(q)
             || w.lat.replacingOccurrences(of: "'", with: "").contains(qLat))
        }
    }

    var body: some View {
        // Worked out once per change, not once per use. The list is lazy: only the rows on
        // screen are built, so the screen opens at once even with 750 words.
        let found = results
        let groups = Dictionary(grouping: found, by: \.category)
        let sections = store.curriculum.categories.filter { groups[$0.id] != nil }
        Group {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    summary
                    categoryChips
                        .padding(.top, 6)
                    ForEach(sections) { cat in
                        Label(cat.title, systemImage: cat.symbol)
                            .font(.headlineRounded)
                            .foregroundStyle(BrandColor(named: cat.color).color)
                            .padding(.top, 12)
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
                    if found.isEmpty {
                        ContentUnavailableView.search(text: query)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .background(AmbientBackground(tint: .tkemali))
            .navigationTitle(tr("Words"))
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: tr("Georgian, English or Latin"))
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

    /// Two numbers that answer "how much is there?": the course's words (and how many of
    /// them the learner knows), and the other words the app shows, one tap away.
    private var summary: some View {
        let words = store.curriculum.words
        let more = store.curriculum.moreWords.count
        let learned = words.filter { store.status(of: $0.id) == .learned }.count
        let learning = words.filter { [.learning, .difficult].contains(store.status(of: $0.id)) }.count
        let moreOn = category == "more"
        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(words.count)").font(.title2Bold).foregroundStyle(Palette.ink)
                    Text(countLabel(words.count, "word in the course", "words in the course",
                                    pl: ("słowo w kursie", "słowa w kursie", "słów w kursie")))
                        .font(.calloutRounded).foregroundStyle(Palette.inkSoft)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
                ProgressBar(progress: Double(learned) / Double(max(1, words.count)), color: Palette.success, height: 8)
                Text(tr("{0} learned · {1} learning", learned, learning))
                    .font(.caption).foregroundStyle(Palette.inkSoft)
                    .contentTransition(.numericText())
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .card(padding: 14, cornerRadius: 20)
            .layoutPriority(1)
            .accessibilityElement(children: .combine)

            Button {
                Haptics.select()
                withMotion { category = moreOn ? nil : "more" }
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("+\(more)").font(.title2Bold).foregroundStyle(Palette.saperavi)
                    Text(countLabel(more, "more from examples and phrases", "more from examples and phrases",
                                    pl: ("słowo z przykładów i zwrotów", "słowa z przykładów i zwrotów", "słów z przykładów i zwrotów")))
                        .font(.caption).foregroundStyle(Palette.inkSoft)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxHeight: .infinity, alignment: .top)
                .card(padding: 14, cornerRadius: 20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Palette.saperavi, lineWidth: moreOn ? 2 : 0)
                )
            }
            .buttonStyle(.pressable)
            .frame(width: 128)
            .accessibilityAddTraits(moreOn ? .isSelected : [])
            .accessibilityIdentifier("words-more")
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    /// A count's label without the number (the number is drawn bigger beside it), in the
    /// right Polish form for that number.
    private func countLabel(_ n: Int, _ one: String, _ other: String, pl: (String, String, String)) -> String {
        switch AppLanguage.current {
        case .pl: return PolishPlural.form(n, pl.0, pl.1, pl.2)
        case .en: return n == 1 ? one : other
        }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: tr("All"), symbol: "square.grid.2x2.fill", id: nil, color: Palette.ink)
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
        case .new: Pill(text: tr("New"), color: Palette.inkFaint)
        case .learning: Pill(text: tr("Learning"), color: Palette.gold, symbol: "circle.lefthalf.filled")
        case .learned: Pill(text: tr("Learned"), color: Palette.success, symbol: "checkmark")
        case .difficult: Pill(text: tr("Difficult"), color: Palette.error, symbol: "exclamationmark.triangle.fill")
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
                    Label(tr("No audio for this one yet. Use the pronunciation help above."), systemImage: "speaker.slash.fill")
                        .font(.caption)
                        .foregroundStyle(Palette.inkSoft)
                        .card(padding: 14, cornerRadius: 16)
                }
                progressCard
                let phrases = store.phrasebook.phrases.filter { ($0.words ?? []).contains(word.id) && $0.id != word.id }
                if !phrases.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(tr("In everyday phrases"), systemImage: "bubble.left.and.text.bubble.right.fill")
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
                        Text(tr("Find them all in the Phrasebook.")).font(.caption).foregroundStyle(Palette.inkFaint)
                    }
                    .card()
                }
                Button {
                    Haptics.tap()
                    navigator.sheetOpen = true
                    dismiss()
                    navigator.review([.word(word)], title: word.ka)
                } label: { Label(tr("Practise this word"), systemImage: "play.fill") }
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
                Text(tr("Your progress")).font(.headlineRounded).foregroundStyle(Palette.ink)
                if let m {
                    Text(tr("Right {0} times, missed {1}. Next review {2}.", m.correctCount, m.wrongCount, m.due.relativeInAppLanguage))
                        .font(.calloutRounded).foregroundStyle(Palette.inkSoft)
                } else {
                    Text(tr("Not practised yet.")).font(.calloutRounded).foregroundStyle(Palette.inkSoft)
                }
            }
            Spacer()
            StatusBadge(status: store.status(of: word.id))
        }
        .card()
    }
}
