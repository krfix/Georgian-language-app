import AVFoundation
import Foundation
import Observation

/// Plays Georgian aloud. The sources are kept apart and labelled in the app:
/// - **Clips in the app** (`Resources/Audio`, indexed by `audio.json`: text → file): today
///   Azure's Eka voice, made once by tools/audio/make_audio.py and marked "synthetic"; a
///   native speaker's recording can replace any clip and is marked "native".
/// - **The iPhone's own Georgian voice**, only if this iPhone really has one, for any text
///   without a clip.
/// When neither exists for a text, nothing pretends to speak: no speaker button, and no
/// listening exercise for it.
@MainActor @Observable
final class AudioService: NSObject {
    enum Source: Equatable {
        /// A clip in the app; `native` when a person recorded it.
        case clip(URL, native: Bool)
        /// The iPhone's own Georgian voice.
        case systemVoice

        var isSynthetic: Bool {
            if case .clip(_, let native) = self { return !native }
            return true
        }
    }

    enum PlaybackState: Equatable {
        case idle
        case playing(text: String, source: Source)
    }

    private(set) var state: PlaybackState = .idle
    /// 0…1 through what is playing.
    private(set) var progress: Double = 0
    /// A Georgian voice installed on this iPhone, if any.
    private(set) var georgianVoice: AVSpeechSynthesisVoice?
    var slow = false

    private let synthesizer = AVSpeechSynthesizer()
    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private var timer: Timer?
    private let bundle: Bundle
    /// The clips in the app, by the Georgian text they say.
    private let clips: [String: AudioIndex.Clip]
    /// The voice the synthetic clips were made with ("Eka (Azure neural, ka-GE)").
    let clipVoice: String?

    init(bundle: Bundle = .main) {
        self.bundle = bundle
        let index = AudioIndex.load(from: bundle)
        clips = index?.clips ?? [:]
        clipVoice = index?.voice
        super.init()
        synthesizer.delegate = self
        findVoice()
        NotificationCenter.default.addObserver(forName: AVSpeechSynthesizer.availableVoicesDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.findVoice() }
        }
    }

    private func findVoice() {
        georgianVoice = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.lowercased().hasPrefix("ka") }
            .max { $0.quality.rawValue < $1.quality.rawValue }
    }

    private func clipURL(_ clip: AudioIndex.Clip) -> URL? {
        let name = (clip.file as NSString).deletingPathExtension
        let ext = (clip.file as NSString).pathExtension
        return bundle.url(forResource: name, withExtension: ext)
            ?? bundle.url(forResource: name, withExtension: ext, subdirectory: "Audio")
    }

    func source(for text: String) -> Source? {
        if let clip = clips[text], let url = clipURL(clip) { return .clip(url, native: clip.source == "native") }
        return georgianVoice == nil ? nil : .systemVoice
    }

    func canPlay(_ text: String) -> Bool { source(for: text) != nil }

    var syntheticClipCount: Int { clips.values.filter { $0.source != "native" }.count }
    var nativeClipCount: Int { clips.values.filter { $0.source == "native" }.count }
    var hasAnyAudio: Bool { georgianVoice != nil || !clips.isEmpty }

    func isPlaying(_ text: String) -> Bool {
        if case .playing(let t, _) = state { return t == text }
        return false
    }

    func play(_ text: String, slow: Bool? = nil) {
        stop()
        guard let source = source(for: text) else { return }
        let slower = slow ?? self.slow
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
        switch source {
        case .clip(let url, _):
            guard let p = try? AVAudioPlayer(contentsOf: url) else { return }
            p.enableRate = true
            p.rate = slower ? 0.75 : 1
            p.delegate = self
            p.play()
            player = p
            timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, let p = self.player, p.duration > 0 else { return }
                    self.progress = p.currentTime / p.duration
                }
            }
        case .systemVoice:
            let u = AVSpeechUtterance(string: text)
            u.voice = georgianVoice
            u.rate = slower ? AVSpeechUtteranceDefaultSpeechRate * 0.7 : AVSpeechUtteranceDefaultSpeechRate * 0.9
            synthesizer.speak(u)
        }
        progress = 0
        state = .playing(text: text, source: source)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        player?.stop()
        player = nil
        timer?.invalidate()
        timer = nil
        state = .idle
        progress = 0
    }

    fileprivate func finished() {
        timer?.invalidate()
        timer = nil
        progress = 1
        state = .idle
    }
}

extension AudioService: AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.finished() }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        let total = max(1, (utterance.speechString as NSString).length)
        let done = Double(characterRange.location + characterRange.length) / Double(total)
        Task { @MainActor in self.progress = done }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.finished() }
    }
}

/// `Resources/Audio/audio.json`: which clip says which Georgian text.
struct AudioIndex: Decodable {
    struct Clip: Decodable {
        let file: String
        /// "synthetic" or "native".
        let source: String
    }

    let version: Int
    let voice: String?
    let clips: [String: Clip]

    static func load(from bundle: Bundle) -> AudioIndex? {
        let url = bundle.url(forResource: "audio", withExtension: "json")
            ?? bundle.url(forResource: "audio", withExtension: "json", subdirectory: "Audio")
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(AudioIndex.self, from: data)
    }
}
