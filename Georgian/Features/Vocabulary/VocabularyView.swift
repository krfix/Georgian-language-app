import SwiftUI

/// The Words tab's list, when nothing is typed in its search (KART #20): every word in one
/// list, course words and the others alike. On top, how many the learner has seen, practises
/// and knows; filters by step; ordered by the lesson that shows it, by theme, or A–Z. Sits
/// inside the tab's lazy stack, so only the rows on screen are built.
struct WordBrowser: View {
    @Binding var open: Word?
    @Environment(LearningStore.self) private var store
    /// nil: "All" (every word seen so far), or "Ahead" for someone who hasn't seen a word.
    @State private var filter: Filter?
    @State private var order: Order = .lesson

    enum Filter: String, CaseIterable {
        case all, known, practising, seen, notSeen
    }

    enum Order: String, CaseIterable {
        case lesson, theme, az
        var title: String {
            switch self {
            case .lesson: return tr("By lesson")
            case .theme: return tr("By theme")
            case .az: return tr("A–Z")
            }
        }
    }

    private struct WordSection: Identifiable {
        let id: String
        let title: String?
        let caption: String?
        let words: [Word]
    }

    var body: some View {
        let counts = store.wordCounts
        let met = counts.seen + counts.practising + counts.known
        let current = filter ?? (met > 0 ? .all : .notSeen)
        let pool = (store.curriculum.words + store.curriculum.moreWords).filter { matches(store.status(of: $0.id), current) }
        summary(counts, met: met)
        filterChips(current, counts: counts, met: met)
            .padding(.top, 4)
        Picker(tr("Order"), selection: $order) {
            ForEach(Order.allCases, id: \.self) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
        .padding(.vertical, 4)
        if pool.isEmpty {
            Text(current == .all ? tr("Finish a lesson and its words appear here.") : tr("No words here yet."))
                .font(.calloutRounded)
                .foregroundStyle(Palette.inkSoft)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
        }
        ForEach(sections(pool)) { sec in
            if let title = sec.title {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headlineRounded)
                        .foregroundStyle(Palette.saperavi)
                    if let caption = sec.caption {
                        Text(caption).font(.caption).foregroundStyle(Palette.inkSoft)
                    }
                }
                .padding(.top, 12)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
            }
            ForEach(sec.words) { w in
                Button {
                    Haptics.tap()
                    open = w
                } label: { WordRow(word: w, status: store.status(of: w.id)) }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("word-\(w.id)")
            }
        }
        if current == .all, counts.all - met > 0 {
            Button {
                Haptics.select()
                withMotion { filter = .notSeen }
            } label: {
                HStack {
                    Text(plural(counts.all - met, "word ahead", "words ahead", pl: ("słowo przed tobą", "słowa przed tobą", "słów przed tobą")))
                    Spacer()
                    Image(systemName: "chevron.down")
                }
                .font(.calloutRounded.weight(.semibold))
                .foregroundStyle(Palette.inkSoft)
                .padding(16)
                .frame(minHeight: 50)
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Palette.line, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
            }
            .buttonStyle(.pressable)
            .padding(.top, 10)
            .accessibilityIdentifier("words-not-seen")
        }
    }

    private func matches(_ s: ItemStatus, _ f: Filter) -> Bool {
        switch f {
        case .all: return s != .new
        case .known: return s == .learned
        case .practising: return s.isPractising
        case .seen: return s == .seen
        case .notSeen: return s == .new
        }
    }

    private func sections(_ pool: [Word]) -> [WordSection] {
        let c = store.curriculum
        switch order {
        case .az:
            return [WordSection(id: "az", title: nil, caption: nil, words: pool.sorted { $0.ka < $1.ka })]
        case .theme:
            let groups = Dictionary(grouping: pool, by: \.category)
            return c.categories.compactMap { cat in
                groups[cat.id].map { WordSection(id: cat.id, title: cat.title, caption: nil, words: $0) }
            }
        case .lesson:
            // The lesson where the learner saw it, else the first lesson that will show it.
            let index = Dictionary(c.lessons.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { a, _ in a })
            let groups = Dictionary(grouping: pool) { w in store.seenWords[w.id] ?? store.firstLesson[w.id] ?? "" }
            let ids = groups.keys.sorted { (index[$0] ?? .max) < (index[$1] ?? .max) }
            return ids.map { id in
                guard let l = c.lesson(id) else {
                    return WordSection(id: "outside", title: tr("In phrases and examples"),
                                   caption: tr("Not in a lesson yet"), words: groups[id] ?? [])
                }
                return WordSection(id: id, title: l.title, caption: c.module(of: id)?.title, words: groups[id] ?? [])
            }
        }
    }

    /// How many words the learner has seen, and how far along they are, in one bar.
    private func summary(_ c: (seen: Int, practising: Int, known: Int, all: Int), met: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(met)").font(.title2Bold).foregroundStyle(Palette.ink).contentTransition(.numericText())
                Text(countLabel(met, "word so far", "words so far",
                                pl: ("słowo do tej pory", "słowa do tej pory", "słów do tej pory")))
                    .font(.calloutRounded).foregroundStyle(Palette.inkSoft)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            WordStepsBar(counts: c, height: 12)
            FlowLayout(spacing: 14, rowSpacing: 6, alignment: .leading) {
                legend(Palette.success, plural(c.known, "known", "known", pl: ("znane", "znane", "znanych")))
                legend(Palette.gold, plural(c.practising, "practising", "practising", pl: ("ćwiczone", "ćwiczone", "ćwiczonych")))
                legend(Palette.blacksea, plural(c.seen, "seen", "seen", pl: ("napotkane", "napotkane", "napotkanych")))
                legend(Palette.line, plural(c.all - met, "ahead", "ahead", pl: ("przed tobą", "przed tobą", "przed tobą")))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 16, cornerRadius: 20)
        .accessibilityElement(children: .combine)
    }

    private func legend(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 9, height: 9)
            Text(text).font(.caption.weight(.semibold)).foregroundStyle(Palette.inkSoft)
        }
    }

    /// A count's label without the number (the number is drawn bigger beside it), in the
    /// right Polish form for that number.
    private func countLabel(_ n: Int, _ one: String, _ other: String, pl: (String, String, String)) -> String {
        switch AppLanguage.current {
        case .pl: return PolishPlural.form(n, pl.0, pl.1, pl.2)
        case .en: return n == 1 ? one : other
        }
    }

    private func filterChips(_ current: Filter, counts: (seen: Int, practising: Int, known: Int, all: Int), met: Int) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(tr("All"), .all, current, color: Palette.saperavi)
                chip(tr("Known"), .known, current, color: Palette.success)
                chip(tr("Practising"), .practising, current, color: Palette.gold)
                chip(tr("Seen"), .seen, current, color: Palette.blacksea)
                chip(tr("Ahead"), .notSeen, current, color: Palette.inkSoft)
            }
            .padding(.vertical, 4)
        }
    }

    private func chip(_ title: String, _ f: Filter, _ current: Filter, color: Color) -> some View {
        let selected = current == f
        return Button {
            Haptics.select()
            withMotion { filter = f }
        } label: {
            Text(title)
                .font(.calloutRounded.weight(.semibold))
                .foregroundStyle(selected ? .white : color)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Capsule().fill(selected ? AnyShapeStyle(color) : AnyShapeStyle(color.opacity(0.12))))
        }
        .buttonStyle(.pressable)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("words-filter-\(f.rawValue)")
    }
}

/// Known, practising, seen and not seen yet, as one bar (Words tab, lesson completion).
struct WordStepsBar: View {
    let counts: (seen: Int, practising: Int, known: Int, all: Int)
    var height: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            let total = CGFloat(max(1, counts.all))
            HStack(spacing: 0) {
                Rectangle().fill(Palette.success).frame(width: geo.size.width * CGFloat(counts.known) / total)
                Rectangle().fill(Palette.gold).frame(width: geo.size.width * CGFloat(counts.practising) / total)
                Rectangle().fill(Palette.blacksea).frame(width: geo.size.width * CGFloat(counts.seen) / total)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.line)
            .clipShape(Capsule())
        }
        .frame(height: height)
        .accessibilityHidden(true)
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
        case .new: Pill(text: status.title, color: Palette.inkSoft)
        case .seen: Pill(text: status.title, color: Palette.blacksea, symbol: "eye.fill")
        case .learning: Pill(text: status.title, color: Palette.gold, symbol: "circle.lefthalf.filled")
        case .learned: Pill(text: status.title, color: Palette.success, symbol: "checkmark")
        case .difficult: Pill(text: status.title, color: Palette.error, symbol: "exclamationmark.triangle.fill")
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
    /// Said once when the card opens (automatic playback), not again on coming back to it.
    @State private var spoke = false

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
                if store.mastery[word.id] == nil {
                    Text(tr("It joins your reviews."))
                        .font(.caption)
                        .foregroundStyle(Palette.inkSoft)
                        .frame(maxWidth: .infinity)
                }
                ReportMistakeButton {
                    ReportSubject(title: tr("the word {0}", word.ka),
                                  lines: [word.ka, word.lat, word.en, "\(word.example.ka) — \(word.example.en)"], id: word.id)
                }
            }
            .padding(20)
        }
        .background(Palette.background.ignoresSafeArea())
        .onAppear {
            guard !spoke else { return }
            spoke = true
            audio.autoSay(word.ka)
        }
    }

    private var progressCard: some View {
        let m = store.mastery[word.id]
        let c = store.curriculum
        let seenIn = store.seenWords[word.id].flatMap(c.lesson)
        let comesIn = store.firstLesson[word.id].flatMap(c.lesson)
        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(tr("Your progress")).font(.headlineRounded).foregroundStyle(Palette.ink)
                if let m {
                    Text(m.state.isLearned
                         ? tr("Right {0} times, missed {1}. Next review {2}.", m.correctCount, m.wrongCount, m.due.relativeInAppLanguage)
                         : tr("Right {0} times, missed {1}. Next review {2}. Known after 4 right in a row, on different days.",
                              m.correctCount, m.wrongCount, m.due.relativeInAppLanguage))
                        .font(.calloutRounded).foregroundStyle(Palette.inkSoft)
                } else {
                    Text(tr("Not practised yet.")).font(.calloutRounded).foregroundStyle(Palette.inkSoft)
                }
                if let l = seenIn {
                    Text(tr("You saw it in: {0} ({1})", l.title, c.module(of: l.id)?.title ?? ""))
                        .font(.calloutRounded).foregroundStyle(Palette.inkSoft)
                } else if let l = comesIn, m == nil {
                    Text(tr("It comes in: {0} ({1})", l.title, c.module(of: l.id)?.title ?? ""))
                        .font(.calloutRounded).foregroundStyle(Palette.inkSoft)
                }
            }
            Spacer()
            StatusBadge(status: store.status(of: word.id))
        }
        .card()
    }
}
