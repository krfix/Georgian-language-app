import SwiftUI

/// Georgian text whose words can be tapped: a small bubble says what the word is and why it
/// looks the way it does (the ending, the person, the polite -თ…), in the learner's language.
/// Words with an explanation have a dotted underline. The explanations come from
/// glossary.json (content_glossary.py), so every word in examples, conversations and phrases
/// has one.
struct TappableGeorgian: View {
    let text: String
    var font: Font = .system(.title3, weight: .semibold)
    var color: Color = Palette.ink
    var alignment: HorizontalAlignment = .leading
    @Environment(LearningStore.self) private var store
    @State private var open: Int?

    var body: some View {
        let words = Curriculum.wordsForTapping(text)
        FlowLayout(spacing: 5, rowSpacing: 4, alignment: alignment, hugsContent: true) {
            ForEach(Array(words.enumerated()), id: \.offset) { i, word in
                if let entry = store.curriculum.gloss(word) {
                    Button {
                        Haptics.select()
                        open = i
                    } label: {
                        Text(word)
                            .underline(true, pattern: .dot, color: color.opacity(0.45))
                            .font(font)
                            .foregroundStyle(color)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(tr("Explains this word"))
                    .popover(isPresented: Binding(get: { open == i }, set: { if !$0 { open = nil } })) {
                        WordBubble(word: Curriculum.glossaryKey(word), entry: entry)
                            .presentationCompactAdaptation(.popover)
                    }
                } else {
                    Text(word).font(font).foregroundStyle(color)
                }
            }
        }
    }
}

/// The bubble for one word: Georgian, Latin, meaning, the dictionary form and why.
struct WordBubble: View {
    let word: String
    let entry: GlossaryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(word).font(.system(.title2, weight: .bold)).foregroundStyle(Palette.ink)
                Text(entry.lat).font(.calloutRounded.italic()).foregroundStyle(Palette.inkSoft)
            }
            if let meaning = entry.meaning {
                Text(meaning).font(.headlineRounded).foregroundStyle(Palette.saperavi)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let base = entry.base {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("Dictionary form")).font(.captionBold).textCase(.uppercase).foregroundStyle(Palette.inkFaint)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(base).font(.system(.body, weight: .semibold)).foregroundStyle(Palette.ink)
                        if let lat = entry.baseLat { Text(lat).font(.caption.italic()).foregroundStyle(Palette.inkSoft) }
                    }
                    if let m = entry.baseMeaning {
                        Text(m).font(.calloutRounded).foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            if let note = entry.note {
                Divider()
                Label {
                    Text(note).font(.calloutRounded).foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "lightbulb.fill").foregroundStyle(Palette.gold)
                }
            }
        }
        .padding(16)
        .frame(width: 290, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
