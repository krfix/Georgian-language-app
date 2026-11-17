import SwiftUI
import UIKit

extension PhraseCategory {
    var brand: BrandColor { BrandColor(named: color) }
}

extension Phrasebook {
    func brand(of p: Phrase) -> BrandColor { category(p.category)?.brand ?? .saperavi }
}

/// One play button (no slow button): for rows and small cards. Shows nothing without audio.
struct PlayButton: View {
    let text: String
    var size: CGFloat = 40
    var color: Color = Palette.blacksea
    @Environment(AudioService.self) private var audio

    var body: some View {
        if audio.canPlay(text) {
            Button {
                Haptics.tap()
                if audio.isPlaying(text) { audio.stop() } else { audio.play(text) }
            } label: {
                Image(systemName: audio.isPlaying(text) ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: size, height: size)
                    .background(Circle().fill(color))
                    .symbolEffect(.variableColor.iterative, isActive: audio.isPlaying(text))
            }
            .buttonStyle(.pressable)
            .accessibilityLabel(tr("Play"))
        }
    }
}

/// A phrase in a list: Georgian large, then the Latin spelling and the English. Tap for the
/// phrase card; the buttons play it and show it full screen to someone.
struct PhraseRow: View {
    let phrase: Phrase
    var showsCategory = false
    @Environment(LearningStore.self) private var store
    @Environment(Navigator.self) private var navigator

    var body: some View {
        let brand = store.phrasebook.brand(of: phrase)
        HStack(alignment: .center, spacing: 10) {
            Button {
                Haptics.tap()
                navigator.openPhrase = phrase
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    if showsCategory, let c = store.phrasebook.category(phrase.category) {
                        Label(c.title, systemImage: c.symbol)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(brand.color)
                            .textCase(.uppercase)
                    }
                    Text(phrase.ka)
                        .font(.system(.title3, weight: .bold))
                        .foregroundStyle(phrase.urgent ? Palette.error : Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(phrase.lat)
                        .font(.caption.italic())
                        .foregroundStyle(Palette.inkSoft)
                    Text(phrase.en)
                        .font(.calloutRounded.weight(.semibold))
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.pressable)
            .accessibilityElement(children: .combine)
            .accessibilityHint(tr("Opens the phrase card"))
            .accessibilityIdentifier("phrase-\(phrase.id)")

            VStack(spacing: 8) {
                PlayButton(text: phrase.ka, size: 38)
                Button {
                    Haptics.tap()
                    navigator.showPhrase = phrase
                } label: {
                    Image(systemName: "textformat.size")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(brand.color)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(brand.color.opacity(0.14)))
                }
                .buttonStyle(.pressable)
                .accessibilityLabel(tr("Show to someone"))
                .accessibilityIdentifier("show-\(phrase.id)")
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Palette.surface)
                .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
        )
        .overlay(alignment: .leading) {
            // A coloured edge: the situation's colour, red for emergencies.
            UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: 18, style: .continuous)
                .fill(phrase.urgent ? Palette.error : brand.color.opacity(0.75))
                .frame(width: 5)
        }
        .overlay(alignment: .topTrailing) {
            if store.isSaved(phrase.id) {
                Image(systemName: "star.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Palette.gold)
                    .padding(8)
                    .accessibilityLabel(tr("Saved"))
            }
        }
    }
}

/// A situation as a colourful tile: icon, name in English and Georgian, how many phrases.
struct CategoryTile: View {
    let category: PhraseCategory
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: category.symbol)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(category.brand.onColor)
                .frame(width: 46, height: 46)
                .background(Circle().fill(category.brand.onColor.opacity(0.18)))
            Spacer(minLength: 0)
            Text(category.title)
                .font(.headlineRounded)
                .foregroundStyle(category.brand.onColor)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
            Text(category.ka)
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(category.brand.onColor.opacity(0.85))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(tr("{0} phrases", count))
                .font(.caption2.weight(.bold))
                .foregroundStyle(category.brand.onColor.opacity(0.8))
        }
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .gradientCard(category.brand, padding: 14, cornerRadius: 24)
    }
}

/// A search field that isn't one yet: Home and the Phrasebook open the Search tab with it.
struct SearchBarButton: View {
    var prompt = tr("Search phrases: taxi, how much, pharmacy…")
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Palette.pomegranate)
                Text(prompt)
                    .font(.calloutRounded)
                    .foregroundStyle(Palette.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .background(Capsule().fill(Palette.surface))
            .overlay(Capsule().strokeBorder(Palette.pomegranate.opacity(0.25), lineWidth: 1.5))
            .shadow(color: Palette.pomegranate.opacity(0.10), radius: 10, y: 4)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(tr("Search phrases"))
        .accessibilityIdentifier("search-bar")
    }
}

/// A small card for a phrase in a carousel (recent or saved phrases on Home).
struct PhraseMiniCard: View {
    let phrase: Phrase
    @Environment(LearningStore.self) private var store
    @Environment(Navigator.self) private var navigator

    var body: some View {
        let brand = store.phrasebook.brand(of: phrase)
        VStack(alignment: .leading, spacing: 6) {
            Button {
                Haptics.tap()
                navigator.openPhrase = phrase
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(phrase.ka)
                        .font(.system(.headline, weight: .bold))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(phrase.en)
                        .font(.caption)
                        .foregroundStyle(Palette.inkSoft)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.pressable)
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                PlayButton(text: phrase.ka, size: 32)
                Button {
                    Haptics.tap()
                    navigator.showPhrase = phrase
                } label: {
                    Image(systemName: "textformat.size")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(brand.color)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(brand.color.opacity(0.14)))
                }
                .buttonStyle(.pressable)
                .accessibilityLabel(tr("Show to someone"))
            }
        }
        .padding(14)
        .frame(width: 180, height: 140, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Palette.surface)
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(brand.fill.opacity(0.08)))
                .shadow(color: Color.black.opacity(0.06), radius: 10, y: 4)
        )
    }
}

/// A dialogue as a card in a carousel or list.
struct DialogueCard: View {
    let dialogue: PhraseDialogue
    @Environment(LearningStore.self) private var store

    var body: some View {
        let c = store.phrasebook.category(dialogue.category)
        let brand = c?.brand ?? .saperavi
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: -8) {
                avatar(dialogue.roles.first ?? "", brand.fill)
                avatar(dialogue.roles.last ?? "", brand.partner)
            }
            Text(dialogue.title)
                .font(.headlineRounded)
                .foregroundStyle(Palette.ink)
                .lineLimit(2)
            Text(dialogue.roles.joined(separator: " & "))
                .font(.caption)
                .foregroundStyle(Palette.inkSoft)
                .lineLimit(1)
            Text(tr("{0} lines", dialogue.lines.count))
                .font(.caption2.weight(.bold))
                .foregroundStyle(brand.color)
        }
        .padding(14)
        .frame(width: 170, height: 150, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Palette.surface)
                .shadow(color: Color.black.opacity(0.06), radius: 10, y: 4)
        )
    }

    private func avatar(_ name: String, _ color: Color) -> some View {
        Text(String(name.prefix(1)))
            .font(.system(.headline, design: .rounded, weight: .heavy))
            .foregroundStyle(.white)
            .frame(width: 36, height: 36)
            .background(Circle().fill(color))
            .overlay(Circle().strokeBorder(Palette.surface, lineWidth: 2))
    }
}

/// A short message that floats up and fades ("Copied").
struct Toast: View {
    let text: String
    var symbol = "checkmark.circle.fill"

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.calloutRounded.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Capsule().fill(Palette.ink.opacity(0.92)))
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .accessibilityAddTraits(.updatesFrequently)
    }
}

/// Who checked the Georgian, said plainly.
struct ContentCheckNote: View {
    @Environment(LearningStore.self) private var store
    @Environment(AudioService.self) private var audio

    var body: some View {
        Label {
            Text(store.phrasebook.isNativeChecked
                 ? tr("Phrases checked by a native Georgian speaker. Audio: {0}, a synthetic voice.", audio.voice.name)
                 : tr("Phrases written and checked by Claude, an AI, for natural everyday Georgian. A native speaker's check is still to come. Audio: {0}, a synthetic voice.", audio.voice.name))
        } icon: {
            Image(systemName: "checkmark.shield.fill")
        }
        .font(.caption)
        .foregroundStyle(Palette.inkSoft)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 6)
    }
}
