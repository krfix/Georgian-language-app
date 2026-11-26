import SwiftUI

/// A card per voice in the app (`Voice.available`; only Luka since KART #18), each with a
/// button to hear it say a short greeting. Used on the welcome steps and in Profile › Voice.
/// Choosing saves at once (AudioService).
struct VoicePicker: View {
    var color: BrandColor = .blacksea
    @Environment(AudioService.self) private var audio

    var body: some View {
        VStack(spacing: 12) {
            ForEach(AudioService.Voice.available) { v in
                if audio.hasClips(v) { card(v) }
            }
            VStack(spacing: 2) {
                Text(AudioService.Voice.sample)
                    .font(.headlineRounded)
                    .foregroundStyle(Palette.ink)
                Text(tr("\u{201C}Hello, how are you?\u{201D}"))
                    .font(.calloutRounded)
                    .foregroundStyle(Palette.inkSoft)
            }
            .padding(.top, 4)
            .accessibilityElement(children: .combine)
        }
    }

    private func card(_ v: AudioService.Voice) -> some View {
        let isOn = audio.voice == v
        let playing = audio.isPlaying(AudioService.Voice.sample) && audio.playingVoice == v
        return HStack(spacing: 14) {
            Button {
                Haptics.select()
                withMotion(Motion.spring) { audio.voice = v }
                audio.play(AudioService.Voice.sample, voice: v)
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 26))
                        .foregroundStyle(isOn ? color.color : Palette.line)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(v.name).font(.headlineRounded).foregroundStyle(Palette.ink)
                        Text(v == .eka ? tr("Female voice") : tr("Male voice"))
                            .font(.calloutRounded).foregroundStyle(Palette.inkSoft)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isOn ? .isSelected : [])
            .accessibilityIdentifier("voice-\(v.rawValue)")

            Button {
                Haptics.tap()
                if playing { audio.stop() } else { audio.play(AudioService.Voice.sample, voice: v) }
            } label: {
                Label(tr("Listen"), systemImage: playing ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                    .font(.calloutRounded.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Palette.blacksea))
                    .symbolEffect(.variableColor.iterative, isActive: playing)
            }
            .buttonStyle(.pressable)
            .accessibilityLabel(tr("Listen to {0}", v.name))
            .accessibilityIdentifier("voice-listen-\(v.rawValue)")
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Palette.surface))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(isOn ? color.color : Palette.line, lineWidth: isOn ? 3 : 1.5))
    }
}
