import SwiftUI

/// All 33 letters in a grid; a dot under each shows how well it is known. Tap a letter to
/// see its name, sound and a word.
struct AlphabetView: View {
    @Environment(ProgressStore.self) private var progress
    @State private var open: Letter?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(title: "Alphabet",
                             subtitle: "\(progress.letters.knownCount) of \(Alphabet.letters.count) letters known")
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(Alphabet.letters) { letter in
                        Button { open = letter } label: { tile(letter) }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(letter.name), \(letter.latin)")
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Theme.bg)
        .sheet(item: $open) { LetterView(letter: $0) }
    }

    private func tile(_ letter: Letter) -> some View {
        VStack(spacing: 4) {
            Text(letter.char).font(.app(32)).foregroundStyle(Theme.text)
            Text(letter.latin).font(.app(13)).foregroundStyle(Theme.mute)
            BoxDots(box: progress.letters.isSeen(letter.char) ? progress.letters.box(letter.char) : -1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// Four small dots: how many boxes up the letter is (none lit: not practised yet).
struct BoxDots: View {
    let box: Int
    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...LetterProgress.top, id: \.self) { i in
                Circle()
                    .fill(i <= box ? (box >= LetterProgress.top ? Theme.ok : Theme.accent) : Theme.line)
                    .frame(width: 5, height: 5)
            }
        }
        .accessibilityHidden(true)
    }
}

/// One letter, big, with everything about it.
struct LetterView: View {
    let letter: Letter
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Spacer()
                Button("Done") { dismiss() }.font(.app(17, weight: .semibold))
            }
            Text(letter.char)
                .font(.app(120))
                .foregroundStyle(Theme.text)
                .frame(maxWidth: .infinity)
            VStack(alignment: .leading, spacing: 12) {
                row("Name", letter.name)
                row("Written", letter.latin)
                row("Sounds like", letter.sound)
            }
            .card()
            VStack(alignment: .leading, spacing: 6) {
                Caption("Word")
                Text(letter.word).font(.app(32, weight: .semibold)).foregroundStyle(Theme.text)
                Text("\(letter.wordLatin) · \(letter.meaning)").font(.app(15)).foregroundStyle(Theme.mute)
            }
            .card()
            Spacer()
        }
        .padding(16)
        .background(Theme.bg)
        .presentationDetents([.large])
    }

    private func row(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Caption(label)
            Text(value).font(.app(17)).foregroundStyle(Theme.text)
        }
    }
}
