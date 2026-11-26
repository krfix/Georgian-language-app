import SwiftUI

/// All 33 letters in a grid, coloured by how well each is known, as a sheet (Learn: the
/// alphabet module's button and the ა shortcut at the top).
struct AlphabetChartView: View {
    @Environment(Navigator.self) private var navigator
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                AlphabetGrid { letters in
                    navigator.sheetOpen = true
                    dismiss()
                    navigator.review(letters, title: tr("Letter practice"))
                }
                .padding(20)
            }
            .background(AmbientBackground(tint: .pomegranate))
            .navigationTitle(tr("ანბანი · Alphabet"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button(tr("Done")) { dismiss() } }
            }
        }
    }
}

/// The 33 letters (KART #20): tap one to hear it, hold it for its card. How many are known,
/// the colours' key and a practice button. In the alphabet sheet and in Words › Letters.
struct AlphabetGrid: View {
    /// Starts a practice with these letters.
    let practise: ([StudyItem]) -> Void
    @Environment(LearningStore.self) private var store
    @Environment(AudioService.self) private var audio
    @State private var open: LetterInfo?
    /// The letter under the finger, drawn a little smaller while pressed.
    @State private var pressing: String?

    private let columns = [GridItem(.adaptive(minimum: 72), spacing: 10)]

    var body: some View {
        let letters = store.curriculum.letters
        let known = letters.filter { store.status(of: $0.itemID) == .learned }.count
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(tr("{0} of {1} letters known", known, letters.count))
                    .font(.headlineRounded)
                    .foregroundStyle(Palette.ink)
                Text(tr("Mkhedruli: 33 letters, no capitals, one sound each."))
                    .font(.calloutRounded)
                    .foregroundStyle(Palette.inkSoft)
                Label(tr("Tap a letter to hear it, hold it for its card."), systemImage: "hand.tap.fill")
                    .font(.caption)
                    .foregroundStyle(Palette.inkSoft)
            }
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(letters) { l in
                    tile(l)
                        .scaleEffect(pressing == l.char ? 0.92 : 1)
                        .motion(Motion.spring, value: pressing == l.char)
                        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        // A light tap the moment the finger lands; a firmer one when the hold
                        // opens the card. A short tap plays the letter.
                        .onTapGesture { audio.play(l.char) }
                        .onLongPressGesture(minimumDuration: 0.35) {
                            Haptics.press()
                            pressing = nil
                            open = l
                        } onPressingChanged: { down in
                            if down { Haptics.tap() }
                            pressing = down ? l.char : (pressing == l.char ? nil : pressing)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(l.name), \(l.latin), \(store.status(of: l.itemID).title)")
                        .accessibilityAddTraits(.isButton)
                        .accessibilityHint(tr("Plays the letter"))
                        .accessibilityAction { audio.play(l.char) }
                        .accessibilityAction(named: tr("Open its card")) { open = l }
                        .accessibilityIdentifier("letter-\(l.char)")
                }
            }
            legend
            Button {
                Haptics.tap()
                practise(Array(letters.map { StudyItem.letter($0) }.shuffled().prefix(12)))
            } label: {
                Label(tr("Practise 12 letters"), systemImage: "shuffle")
            }
            .buttonStyle(ChunkyButtonStyle(color: .pomegranate))
        }
        .sheet(item: $open) { l in
            ScrollView { TeachLetterView(letter: l).padding(20) }
                .background(Palette.background.ignoresSafeArea())
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private func tile(_ l: LetterInfo) -> some View {
        let status = store.status(of: l.itemID)
        let color: Color = switch status {
        case .learned: Palette.success
        case .learning: Palette.gold
        case .difficult: Palette.error
        case .new, .seen: Palette.line
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
            legendItem(tr("Not yet"), Palette.line)
            legendItem(tr("Practising"), Palette.gold)
            legendItem(tr("Known"), Palette.success)
            legendItem(tr("Difficult"), Palette.error)
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
