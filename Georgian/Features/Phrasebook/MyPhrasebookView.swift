import SwiftUI

/// The learner's own phrasebook: every saved phrase, filtered by their lists, by what's in
/// review or marked learned, grouped by situation, with one button to practise them.
struct MyPhrasebookView: View {
    @Environment(LearningStore.self) private var store
    @Environment(Navigator.self) private var navigator
    @State private var filter: Filter = .all

    enum Filter: Hashable {
        case all, practising, learned
        case list(String)
    }

    private var phrases: [Phrase] {
        store.savedPhrases.filter { p in
            switch filter {
            case .all: return true
            case .practising: return store.isPractising(p.id)
            case .learned: return store.isLearned(p.id)
            case .list(let name): return store.list(of: p.id) == name
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                summary
                if !store.savedPhrases.isEmpty { chips }
                let list = phrases
                if store.savedPhrases.isEmpty {
                    ContentUnavailableView {
                        Label("Nothing saved yet", systemImage: "star")
                    } description: {
                        Text("Open any phrase and tap Save. It stays here, ready to show or practise.")
                    } actions: {
                        Button("Browse situations") { navigator.phrasebookPath = NavigationPath() }
                            .buttonStyle(ChunkyButtonStyle(color: .gold))
                    }
                    .padding(.top, 30)
                } else if list.isEmpty {
                    Text("No phrases here yet.").font(.calloutRounded).foregroundStyle(Palette.inkSoft).padding(.top, 10)
                } else {
                    Button {
                        Haptics.tap()
                        navigator.review(store.studyItems(list), title: "My phrasebook")
                    } label: {
                        Label("Practise these \(list.count)", systemImage: "play.fill")
                    }
                    .buttonStyle(ChunkyButtonStyle(color: .blacksea))
                    .accessibilityIdentifier("practise-saved")
                    let groups = Dictionary(grouping: list, by: \.category)
                    ForEach(store.phrasebook.categories.filter { groups[$0.id] != nil }) { c in
                        Label(c.title, systemImage: c.symbol)
                            .font(.headlineRounded)
                            .foregroundStyle(c.brand.color)
                            .padding(.top, 6)
                            .accessibilityAddTraits(.isHeader)
                        ForEach(groups[c.id] ?? []) { p in
                            PhraseRow(phrase: p)
                                .contextMenu { menu(for: p) }
                        }
                    }
                    Text("Touch and hold a phrase to move it to a list or remove it.")
                        .font(.caption).foregroundStyle(Palette.inkFaint)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .background(AmbientBackground(tint: .gold))
        .navigationTitle("My phrasebook")
        .navigationBarTitleDisplayMode(.large)
    }

    private var summary: some View {
        HStack(spacing: 12) {
            StatTile(symbol: "star.fill", value: "\(store.savedPhrases.count)", label: "saved", color: Palette.gold, singleLine: true)
            StatTile(symbol: "arrow.triangle.2.circlepath", value: "\(store.practisingPhraseCount)", label: "in review",
                     color: Palette.blacksea, singleLine: true)
            StatTile(symbol: "checkmark.seal.fill", value: "\(store.savedPhrases.filter { store.isLearned($0.id) }.count)",
                     label: "learned", color: Palette.tkemali, singleLine: true)
        }
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("All", symbol: "square.grid.2x2.fill", .all)
                chip("In review", symbol: "arrow.triangle.2.circlepath", .practising)
                chip("Learned", symbol: "checkmark.seal.fill", .learned)
                ForEach(store.phraseLists, id: \.self) { name in chip(name, symbol: "folder.fill", .list(name)) }
            }
            .padding(.vertical, 4)
        }
    }

    private func chip(_ title: String, symbol: String, _ f: Filter) -> some View {
        let selected = filter == f
        return Button {
            Haptics.select()
            withMotion { filter = f }
        } label: {
            Label(title, systemImage: symbol)
                .font(.calloutRounded.weight(.semibold))
                .foregroundStyle(selected ? Color.white : Palette.saperavi)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Capsule().fill(selected ? AnyShapeStyle(BrandColor.saperavi.fill) : AnyShapeStyle(Palette.saperavi.opacity(0.12))))
        }
        .buttonStyle(.pressable)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder private func menu(for p: Phrase) -> some View {
        if store.isPractising(p.id) {
            Button("Take out of review", systemImage: "arrow.uturn.backward") { store.stopPractising(p) }
        } else {
            Button("Practise in review", systemImage: "arrow.triangle.2.circlepath") { store.practiseLater(p) }
        }
        Button(store.isLearned(p.id) ? "Not learned yet" : "Mark as learned", systemImage: "checkmark.seal") {
            store.setLearned(p, !store.isLearned(p.id))
        }
        Menu("Move to list") {
            Button("No list") { store.move(p, toList: "") }
            ForEach(store.phraseLists, id: \.self) { name in Button(name) { store.move(p, toList: name) } }
        }
        Button("Remove from my phrasebook", systemImage: "star.slash", role: .destructive) { store.setSaved(p, false) }
    }
}
