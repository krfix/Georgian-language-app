import SwiftUI
import UIKit

/// Show to someone: the Georgian huge, white on black, to hold up to a taxi driver, a
/// shopkeeper or a waiter. The English can be hidden, the text turned upside down for the
/// person across the table, and the phrase played aloud. The screen stays on while it's open.
struct ShowPhraseView: View {
    let phrase: Phrase
    @Environment(\.dismiss) private var dismiss
    @Environment(AudioService.self) private var audio
    @State private var showTranslation = true
    @State private var flipped = false
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if phrase.urgent {
                RadialGradient(colors: [Palette.error.opacity(0.35), .clear], center: .top, startRadius: 0, endRadius: 500)
                    .ignoresSafeArea()
            }
            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 12)
                GeometryReader { geo in
                    let width = geo.size.width - 48
                    let height = geo.size.height * (showTranslation ? 0.66 : 0.9)
                    let size = GeorgianFit.size(for: phrase.ka, maxSize: 88, minSize: 24, width: width, height: height, lineSpacing: 10)
                    VStack(spacing: 22) {
                        Text(phrase.ka)
                            .font(.system(size: size, weight: .bold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .lineSpacing(10)
                            .minimumScaleFactor(0.8)
                            .padding(.vertical, 8)
                            .environment(\.locale, Locale(identifier: "ka_GE"))
                            .accessibilityIdentifier("show-georgian")
                        if showTranslation {
                            VStack(spacing: 8) {
                                Text(phrase.en)
                                    .font(.system(.title2, design: .rounded, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.75))
                                Text(phrase.lat)
                                    .font(.system(.body, design: .rounded).italic())
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            .multilineTextAlignment(.center)
                            .transition(.opacity)
                        }
                    }
                    .padding(.horizontal, 24)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .rotationEffect(.degrees(flipped ? 180 : 0))
                    .scaleEffect(appeared ? 1 : 0.92)
                    .opacity(appeared ? 1 : 0)
                }
                Spacer(minLength: 12)
                bottomBar
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            withMotion(Motion.spring) { appeared = true }
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            audio.stop()
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("show-phrase")
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            roundButton("xmark", label: tr("Close"), id: "show-close") { dismiss() }
            Spacer()
            roundButton(showTranslation ? "character.bubble.fill" : "character.bubble", label: showTranslation ? tr("Hide English") : tr("Show English"),
                        id: "show-translation") {
                withMotion(Motion.gentle) { showTranslation.toggle() }
            }
            roundButton("arrow.up.arrow.down", label: flipped ? tr("Turn the right way up") : tr("Turn upside down for the person opposite"),
                        id: "show-flip") {
                withMotion(Motion.spring) { flipped.toggle() }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            if audio.canPlay(phrase.ka) {
                HStack(spacing: 16) {
                    Button {
                        Haptics.tap()
                        if audio.isPlaying(phrase.ka) { audio.stop() } else { audio.play(phrase.ka) }
                    } label: {
                        Label(tr("Play"), systemImage: audio.isPlaying(phrase.ka) ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                            .font(.headlineRounded)
                            .foregroundStyle(.black)
                            .padding(.horizontal, 28)
                            .frame(height: 56)
                            .background(Capsule().fill(.white))
                            .symbolEffect(.variableColor.iterative, isActive: audio.isPlaying(phrase.ka))
                    }
                    .buttonStyle(.pressable)
                    .accessibilityIdentifier("show-play")
                    Button {
                        Haptics.tap()
                        audio.play(phrase.ka, slow: true)
                    } label: {
                        Image(systemName: "tortoise.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .background(Circle().fill(.white.opacity(0.16)))
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel(tr("Play slowly"))
                }
                Text(audio.source(for: phrase.ka)?.isSynthetic == false ? tr("Native recording") : tr("Synthetic voice"))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(.bottom, 24)
    }

    private func roundButton(_ symbol: String, label: String, id: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(Circle().fill(.white.opacity(0.14)))
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(label)
        .accessibilityIdentifier(id)
    }
}
