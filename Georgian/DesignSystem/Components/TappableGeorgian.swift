import SwiftUI

/// Georgian text whose words can be tapped: a small bubble says what the word is and why it
/// looks the way it does (the ending, the person, the polite -თ…), in the learner's language;
/// tap the word again, or ×, to fold it away.
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

    // The explanation unfolds under the sentence, inside the same screen. (A system popover
    // here could close the lesson's full-screen cover with it when dismissed: build #25.)
    var body: some View {
        let words = Curriculum.wordsForTapping(text)
        VStack(alignment: alignment, spacing: 8) {
            FlowLayout(spacing: 5, rowSpacing: 4, alignment: alignment, hugsContent: true) {
                ForEach(Array(words.enumerated()), id: \.offset) { i, word in
                    if store.curriculum.gloss(word) != nil {
                        Button {
                            Haptics.select()
                            withMotion(Motion.spring) { open = open == i ? nil : i }
                        } label: {
                            Text(word)
                                .underline(true, pattern: .dot, color: color.opacity(0.45))
                                .font(font)
                                .foregroundStyle(color)
                                .padding(.horizontal, 2)
                                .background(RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(open == i ? Palette.gold.opacity(0.35) : Color.clear))
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint(tr("Explains this word"))
                    } else {
                        Text(word).font(font).foregroundStyle(color)
                    }
                }
            }
            if let i = open, words.indices.contains(i), let entry = store.curriculum.gloss(words[i]) {
                WordBubble(word: Curriculum.glossaryKey(words[i]), entry: entry) {
                    withMotion(Motion.spring) { open = nil }
                }
                .transition(.scale(scale: 0.9, anchor: .top).combined(with: .opacity))
            }
        }
        .onChange(of: text) { _, _ in open = nil }
    }
}

/// The bubble for one word: Georgian, Latin, meaning, the dictionary form and why.
struct WordBubble: View {
    let word: String
    let entry: GlossaryEntry
    var onClose: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(word).font(.system(.title2, weight: .bold)).foregroundStyle(Palette.ink)
                Text(entry.lat).font(.calloutRounded.italic()).foregroundStyle(Palette.inkSoft)
                Spacer(minLength: 0)
                if let onClose {
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill").font(.title3).foregroundStyle(Palette.inkFaint)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tr("Close"))
                }
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
        .padding(14)
        .frame(maxWidth: 340, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.surface))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Palette.gold.opacity(0.6), lineWidth: 1.5))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
        .accessibilityElement(children: .contain)
    }
}

/// A paragraph in the learner's language with Georgian words in it ("Before you start",
/// grammar notes): the Georgian words stand out and can be tapped for the same bubble
/// (Georgian, Latin, meaning, why). Pieces written with a hyphen (-ში, წა-ვ-ედი) and single
/// letters are about spelling, so they stay plain.
struct TappableProse: View {
    let text: String
    var font: Font = .bodyRounded
    @Environment(LearningStore.self) private var store
    @State private var open: Int?

    var body: some View {
        let words = Curriculum.wordsForTapping(text)
        let hasTappable = words.contains { tappableKey($0) != nil }
        VStack(alignment: .leading, spacing: 10) {
            FlowLayout(spacing: 4, rowSpacing: 4, alignment: .leading, hugsContent: true) {
                ForEach(Array(words.enumerated()), id: \.offset) { i, word in
                    if tappableKey(word) != nil {
                        Button {
                            Haptics.select()
                            withMotion(Motion.spring) { open = open == i ? nil : i }
                        } label: {
                            Text(word)
                                .font(font.weight(.bold))
                                .foregroundStyle(Palette.saperavi)
                                .underline(true, pattern: .dot, color: Palette.saperavi.opacity(0.5))
                                .padding(.horizontal, 2)
                                .background(RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(open == i ? Palette.gold.opacity(0.35) : Color.clear))
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint(tr("Explains this word"))
                    } else {
                        Text(word).font(font).foregroundStyle(Palette.ink)
                    }
                }
            }
            if let i = open, words.indices.contains(i), let key = tappableKey(words[i]), let entry = store.curriculum.gloss(key) {
                WordBubble(word: key, entry: entry) {
                    withMotion(Motion.spring) { open = nil }
                }
                .transition(.scale(scale: 0.9, anchor: .top).combined(with: .opacity))
            } else if hasTappable {
                Label(tr("Tap a Georgian word to see what it means."), systemImage: "hand.tap.fill")
                    .font(.caption)
                    .foregroundStyle(Palette.inkFaint)
            }
        }
        .onChange(of: text) { _, _ in open = nil }
    }

    /// The glossary key of a Georgian word in the text, or nil for English, Polish, a
    /// hyphenated piece, a single letter or a word without an explanation.
    private func tappableKey(_ word: String) -> String? {
        let key = word.trimmingCharacters(in: CharacterSet(charactersIn: ".,?!—–:;\"«»…()„”“"))
        guard !word.contains("-"), key.count > 1,
              key.unicodeScalars.contains(where: { (0x10D0...0x10FF).contains($0.value) }),
              store.curriculum.gloss(key) != nil else { return nil }
        return key
    }
}
