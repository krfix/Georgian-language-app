import AVFoundation
import Foundation
import Observation

/// Plays Georgian aloud. Two sources, kept apart and labelled in the app:
/// - **Native recordings**: `Audio/<item id>.m4a` in the app bundle. None are included yet;
///   recordings by a native speaker can be dropped in later with no code change.
/// - **Synthetic speech**: only when the iPhone actually has a Georgian voice (iOS doesn't
///   ship one for every device or version), checked at start and when voices change.
/// When neither exists, nothing pretends to speak: speaker buttons are hidden and listening
/// exercises aren't made.
@MainActor @Observable
final class AudioService: NSObject {
    enum Source: Equatable {
        case recording(URL)
        case synthetic
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
    /// Bundle file names for each text: the item id of the word or letter.
    @ObservationIgnored private var recordingNames: [String: String] = [:]

    init(bundle: Bundle = .main) {
        self.bundle = bundle
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

    /// Tells the service which recording belongs to which Georgian text.
    func register(text: String, itemID: String) { recordingNames[text] = itemID }

    func recording(for text: String) -> URL? {
        guard let name = recordingNames[text] else { return nil }
        return bundle.url(forResource: name, withExtension: "m4a", subdirectory: "Audio")
            ?? bundle.url(forResource: name, withExtension: "m4a")
    }

    func source(for text: String) -> Source? {
        if let url = recording(for: text) { return .recording(url) }
        return georgianVoice == nil ? nil : .synthetic
    }

    func canPlay(_ text: String) -> Bool { source(for: text) != nil }

    /// Whether any native recordings are in the app.
    var hasRecordings: Bool {
        bundle.urls(forResourcesWithExtension: "m4a", subdirectory: "Audio")?.isEmpty == false
            || bundle.urls(forResourcesWithExtension: "m4a", subdirectory: nil)?.isEmpty == false
    }

    var hasAnyAudio: Bool { georgianVoice != nil || hasRecordings }

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
        case .recording(let url):
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
        case .synthetic:
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
