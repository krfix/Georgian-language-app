import SwiftUI

/// Plays Georgian aloud, when this iPhone can (see AudioService). Shows nothing otherwise:
/// the app never pretends to have audio it doesn't have. A small tag says whether it is a
/// recording or the iPhone's synthetic voice.
struct SpeakerButton: View {
    let text: String
    var size: CGFloat = 44
    var showsSource = false
    /// On a coloured card: white buttons and tag, so they read on any brand colour.
    var onColor = false
    @Environment(AudioService.self) private var audio

    var body: some View {
        if let source = audio.source(for: text) {
            HStack(spacing: 8) {
                Button {
                    Haptics.tap()
                    if audio.isPlaying(text) { audio.stop() } else { audio.play(text) }
                } label: {
                    Image(systemName: audio.isPlaying(text) ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                        .font(.system(size: size * 0.42, weight: .bold))
                        .foregroundStyle(onColor ? Color(hex: 0x0D6077) : .white)
                        .frame(width: size, height: size)
                        .background(Circle().fill(onColor ? Color.white : Palette.blacksea))
                        .symbolEffect(.variableColor.iterative, isActive: audio.isPlaying(text))
                }
                .buttonStyle(.pressable)
                .accessibilityLabel("Play")
                .accessibilityIdentifier("speaker")
                Button {
                    Haptics.tap()
                    audio.play(text, slow: true)
                } label: {
                    Image(systemName: "tortoise.fill")
                        .font(.system(size: size * 0.34, weight: .bold))
                        .foregroundStyle(onColor ? Color.white : Palette.blacksea)
                        .frame(width: size * 0.8, height: size * 0.8)
                        .background(Circle().fill(onColor ? Color.white.opacity(0.24) : Palette.blacksea.opacity(0.15)))
                }
                .buttonStyle(.pressable)
                .accessibilityLabel("Play slowly")
                if showsSource {
                    Pill(text: source.isSynthetic ? "Synthetic voice" : "Native recording",
                         color: onColor ? .white : (source.isSynthetic ? Palette.inkSoft : Palette.tkemali),
                         symbol: source.isSynthetic ? "waveform" : "person.wave.2.fill")
                }
            }
        }
    }
}
