import SwiftUI

/// All 33 letters in a grid, coloured by how well each is known. Tap one for its card.
struct AlphabetChartView: View {
    @Environment(LearningStore.self) private var store
    @Environment(Navigator.self) private var navigator
    @Environment(\.dismiss) private var dismiss
    @State private var open: LetterInfo?

    private let columns = [GridItem(.adaptive(minimum: 72), spacing: 10)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Mkhedruli: 33 letters, no capitals, one sound each.")
                        .font(.calloutRounded)
                        .foregroundStyle(Palette.inkSoft)
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(store.curriculum.letters) { l in
                            Button {
                                Haptics.tap()
                                open = l
                            } label: { tile(l) }
                            .buttonStyle(.pressable)
                            .accessibilityLabel("\(l.name), \(l.latin), \(store.status(of: l.itemID).rawValue)")
                        }
                    }
                    legend
                    let letters = store.curriculum.letters.map { StudyItem.letter($0) }
                    Button {
                        Haptics.tap()
                        navigator.sheetOpen = true
                        dismiss()
                        navigator.review(Array(letters.shuffled().prefix(12)), title: "Letter practice")
                    } label: {
                        Label("Practise 12 letters", systemImage: "shuffle")
                    }
                    .buttonStyle(ChunkyButtonStyle(color: .pomegranate))
                }
                .padding(20)
            }
            .background(AmbientBackground(tint: .pomegranate))
            .navigationTitle("ანბანი · Alphabet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .sheet(item: $open) { l in
                ScrollView { TeachLetterView(letter: l).padding(20) }
                    .background(Palette.background.ignoresSafeArea())
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private func tile(_ l: LetterInfo) -> some View {
        let status = store.status(of: l.itemID)
        let color: Color = switch status {
        case .learned: Palette.success
        case .learning: Palette.gold
        case .difficult: Palette.error
        case .new: Palette.line
        }
        return VStack(spacing: 2) {
            Text(l.char).font(.system(size: 34, weight: .semibold)).foregroundStyle(Palette.ink)
            Text(l.latin).font(.caption.weight(.semibold)).foregroundStyle(Palette.inkSoft)
        }
        .frame(maxWidth: .infinity, minHeight: 82)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.surface))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(color, lineWidth: status == .new ? 1.5 : 3))
    }

    private var legend: some View {
        HStack(spacing: 14) {
            legendItem("New", Palette.line)
            legendItem("Learning", Palette.gold)
            legendItem("Learned", Palette.success)
            legendItem("Difficult", Palette.error)
        }
        .font(.caption)
        .foregroundStyle(Palette.inkSoft)
        .accessibilityElement(children: .combine)
    }

    private func legendItem(_ text: String, _ color: Color) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(text)
        }
    }
}
