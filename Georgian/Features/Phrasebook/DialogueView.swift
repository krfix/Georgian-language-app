import SwiftUI

/// A conversation to read and hear, line by line, with the useful expressions explained,
/// then practise from either side.
struct DialogueView: View {
    let dialogue: PhraseDialogue
    @Environment(LearningStore.self) private var store
    @Environment(Navigator.self) private var navigator
    @State private var showEnglish = true
    @State private var showLatin = true

    private var brand: BrandColor { store.phrasebook.category(dialogue.category)?.brand ?? .saperavi }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                toggles
                VStack(spacing: 12) {
                    ForEach(Array(dialogue.lines.enumerated()), id: \.offset) { _, line in
                        LineBubble(line: line, name: name(line.who), brand: brand,
                                   showEnglish: showEnglish, showLatin: showLatin)
                    }
                }
                if !dialogue.notes.isEmpty { notes }
                practice
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .background(AmbientBackground(tint: brand))
        .navigationTitle(dialogue.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func name(_ who: Int) -> String { dialogue.roles.indices.contains(who) ? dialogue.roles[who] : "" }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(store.phrasebook.category(dialogue.category)?.title ?? "")
                .font(.captionBold).textCase(.uppercase)
                .foregroundStyle(brand.onColor.opacity(0.85))
            Text(dialogue.title).font(.titleBold).foregroundStyle(brand.onColor)
            Text("\(name(0)) and \(name(1)). Tap a line to hear it.")
                .font(.calloutRounded).foregroundStyle(brand.onColor.opacity(0.9))
        }
        .gradientCard(brand)
        .padding(.top, 8)
    }

    private var toggles: some View {
        HStack(spacing: 8) {
            toggle("English", on: $showEnglish)
            toggle("Latin letters", on: $showLatin)
            Spacer()
        }
    }

    private func toggle(_ title: String, on: Binding<Bool>) -> some View {
        Button {
            Haptics.select()
            withMotion { on.wrappedValue.toggle() }
        } label: {
            Label(title, systemImage: on.wrappedValue ? "eye.fill" : "eye.slash")
                .font(.calloutRounded.weight(.semibold))
                .foregroundStyle(on.wrappedValue ? brand.onColor : brand.color)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(on.wrappedValue ? AnyShapeStyle(brand.fill) : AnyShapeStyle(brand.color.opacity(0.12))))
        }
        .buttonStyle(.pressable)
        .accessibilityAddTraits(on.wrappedValue ? .isSelected : [])
    }

    private var notes: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Useful expressions", systemImage: "lightbulb.fill").font(.headlineRounded).foregroundStyle(Palette.gold)
            ForEach(dialogue.notes, id: \.ka) { n in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(n.ka).font(.system(.headline, weight: .bold)).foregroundStyle(Palette.ink)
                        Text(n.en).font(.calloutRounded.weight(.semibold)).foregroundStyle(Palette.inkSoft)
                    }
                    Text(n.why).font(.calloutRounded).foregroundStyle(Palette.inkSoft).fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .card()
    }

    private var practice: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "Practise it")
            Text("Choose each of your lines; the other side speaks. Then swap.")
                .font(.calloutRounded).foregroundStyle(Palette.inkSoft)
            Button {
                Haptics.tap()
                navigator.practise(dialogue, as: 0, in: store.phrasebook)
            } label: {
                Label("Be the \(name(0).lowercased())", systemImage: "play.fill")
            }
            .buttonStyle(ChunkyButtonStyle(color: brand == .gold ? .pomegranate : brand))
            .accessibilityIdentifier("practise-0")
            Button {
                Haptics.tap()
                navigator.practise(dialogue, as: 1, in: store.phrasebook)
            } label: {
                Label(name(1) == "Nana" ? "Be Nana" : "Be the \(name(1).lowercased())", systemImage: "arrow.left.arrow.right")
            }
            .buttonStyle(SoftButtonStyle())
            .accessibilityIdentifier("practise-1")
        }
    }
}

/// One line as a chat bubble: the learner's usual side on the right in colour, the other on
/// the left. Tap to play.
private struct LineBubble: View {
    let line: PhraseDialogueLine
    let name: String
    let brand: BrandColor
    let showEnglish: Bool
    let showLatin: Bool
    @Environment(AudioService.self) private var audio

    var body: some View {
        let mine = line.who == 0
        HStack(alignment: .bottom, spacing: 8) {
            if mine { Spacer(minLength: 40) } else { avatar }
            Button {
                Haptics.tap()
                if audio.isPlaying(line.ka) { audio.stop() } else { audio.play(line.ka) }
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(name).font(.caption2.weight(.bold)).textCase(.uppercase)
                            .foregroundStyle(mine ? brand.onColor.opacity(0.85) : brand.color)
                        if audio.canPlay(line.ka) {
                            Image(systemName: audio.isPlaying(line.ka) ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(mine ? brand.onColor.opacity(0.85) : brand.color)
                                .symbolEffect(.variableColor.iterative, isActive: audio.isPlaying(line.ka))
                        }
                    }
                    Text(line.ka)
                        .font(.system(.headline, weight: .bold))
                        .foregroundStyle(mine ? brand.onColor : Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    if showLatin {
                        Text(line.lat).font(.caption.italic()).foregroundStyle(mine ? brand.onColor.opacity(0.8) : Palette.inkSoft)
                    }
                    if showEnglish {
                        Text(line.en).font(.calloutRounded).foregroundStyle(mine ? brand.onColor.opacity(0.92) : Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    UnevenRoundedRectangle(topLeadingRadius: 20, bottomLeadingRadius: mine ? 20 : 6,
                                           bottomTrailingRadius: mine ? 6 : 20, topTrailingRadius: 20, style: .continuous)
                        .fill(mine ? AnyShapeStyle(brand.gradient) : AnyShapeStyle(Palette.surface))
                        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
                )
            }
            .buttonStyle(.pressable)
            .accessibilityElement(children: .combine)
            .accessibilityHint("Plays the line")
            if !mine { Spacer(minLength: 40) }
        }
    }

    private var avatar: some View {
        Text(String(name.prefix(1)))
            .font(.system(.subheadline, design: .rounded, weight: .heavy))
            .foregroundStyle(.white)
            .frame(width: 32, height: 32)
            .background(Circle().fill(brand.partner))
            .accessibilityHidden(true)
    }
}
