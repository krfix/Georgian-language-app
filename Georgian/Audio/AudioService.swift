import AVFoundation
import Foundation
import Observation

/// Plays Georgian aloud. The sources are kept apart and labelled in the app:
/// - **Clips in the app** (`Resources/Audio`, indexed by `audio.json` for Eka and
///   `audio-giorgi.json` for Giorgi: text → file): Azure's voices, made once by
///   tools/audio/make_audio.py and marked "synthetic". The learner picks the voice
///   (`Voice`, onboarding and Profile). A native speaker's recording can replace any clip
///   and is marked "native"; a native recording plays whichever voice is chosen. A native
///   recording changed into one voice (for a speaker who doesn't want to be recognised) is
///   marked "converted" and plays only in that voice.
/// - **The iPhone's own Georgian voice**, only if this iPhone really has one, for any text
///   without a clip.
/// When neither exists for a text, nothing pretends to speak: no speaker button, and no
/// listening exercise for it.
@MainActor @Observable
final class AudioService: NSObject {
    /// Who speaks in a clip, as `source` in the audio index says.
    enum ClipKind: Equatable {
        /// An Azure voice ("synthetic").
        case synthetic
        /// A person's recording ("native").
        case native
        /// A person's recording changed into the chosen voice ("converted").
        case converted

        init(_ source: String) {
            switch source {
            case "native": self = .native
            case "converted": self = .converted
            default: self = .synthetic
            }
        }
    }

    enum Source: Equatable {
        /// A clip in the app.
        case clip(URL, kind: ClipKind)
        /// The iPhone's own Georgian voice.
        case systemVoice

        var isSynthetic: Bool {
            if case .clip(_, let kind) = self { return kind == .synthetic }
            return true
        }

        /// The tag shown next to the speaker.
        var label: String {
            switch self {
            case .clip(_, .native): return tr("Native recording")
            case .clip(_, .converted): return tr("Native recording, voice changed")
            default: return tr("Synthetic voice")
            }
        }
    }

    /// The synthetic voices. `giorgi` is the male voice's id (saved choices, "kam-" files,
    /// audio-giorgi.json); since KART #18 it is ElevenLabs' Luka, shown as "Luka".
    enum Voice: String, CaseIterable, Identifiable {
        case eka, giorgi
        var id: String { rawValue }
        var name: String { self == .eka ? "Eka" : "Luka" }
        var indexFile: String { self == .eka ? "audio" : "audio-giorgi" }
        /// What the voice says when the learner listens to a sample.
        static let sample = "გამარჯობა, როგორ ხარ?"
        /// The voices in the app. Eka is off for now (owner, KART #18): her clips stay in the
        /// repo but aren't bundled (project.yml); add her back here and there together.
        static let available: [Voice] = [.giorgi]

        static let storageKey = "audioVoice"
        static var stored: Voice {
            let saved = Voice(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "")
            return saved.flatMap { available.contains($0) ? $0 : nil } ?? available[0]
        }
    }

    enum PlaybackState: Equatable {
        case idle
        case playing(text: String, source: Source)
    }

    private(set) var state: PlaybackState = .idle
    /// The voice of the clip playing now (the voice picker's samples say the same text).
    private(set) var playingVoice: Voice?
    /// 0…1 through what is playing.
    private(set) var progress: Double = 0
    /// A Georgian voice installed on this iPhone, if any.
    private(set) var georgianVoice: AVSpeechSynthesisVoice?
    var slow = false

    private let synthesizer = AVSpeechSynthesizer()
    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private var timer: Timer?
    private let bundle: Bundle
    /// The clips in the app for each voice, by the Georgian text they say.
    private let clipsByVoice: [Voice: [String: AudioIndex.Clip]]
    /// The voice the learner chose (saved on this iPhone).
    var voice: Voice {
        get { chosenVoice }
        set {
            chosenVoice = newValue
            UserDefaults.standard.set(newValue.rawValue, forKey: Voice.storageKey)
        }
    }
    private var chosenVoice: Voice = Voice.stored

    /// "Play Georgian automatically" (Profile › Audio; owner, KART #18): lessons and cards
    /// speak by themselves (`AutoSpeech`, `autoSay`). On unless turned off; saved on this iPhone.
    var autoPlay: Bool {
        get { autoPlayOn }
        set {
            autoPlayOn = newValue
            UserDefaults.standard.set(newValue, forKey: Self.autoPlayKey)
        }
    }
    private var autoPlayOn: Bool = UserDefaults.standard.object(forKey: AudioService.autoPlayKey) as? Bool ?? true
    static let autoPlayKey = "audioAutoPlay"

    /// Says `text` by itself, if automatic playback is on and there is something to play it with.
    func autoSay(_ text: String?) {
        guard autoPlay, let text, !text.isEmpty, canPlay(text) else { return }
        play(text)
    }
    /// The chosen voice's clips.
    private var clips: [String: AudioIndex.Clip] { clipsByVoice[voice] ?? [:] }

    init(bundle: Bundle = .main) {
        self.bundle = bundle
        var all: [Voice: [String: AudioIndex.Clip]] = [:]
        for v in Voice.available {
            if let index = AudioIndex.load(from: bundle, name: v.indexFile) { all[v] = index.clips }
        }
        clipsByVoice = all
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

    /// Which clip says `text` in `voice`: a native recording first (in any voice's index),
    /// then the chosen voice's clip, then the other voice's, then the iPhone's own voice.
    func source(for text: String, voice: Voice? = nil) -> Source? {
        let chosen = voice ?? self.voice
        let order = [chosen] + Voice.allCases.filter { $0 != chosen }
        for v in order {
            if let clip = clipsByVoice[v]?[text], clip.source == "native", let url = clipURL(clip) { return .clip(url, kind: .native) }
        }
        for v in order {
            if let clip = clipsByVoice[v]?[text], let url = clipURL(clip) { return .clip(url, kind: ClipKind(clip.source)) }
        }
        return georgianVoice == nil ? nil : .systemVoice
    }

    /// Whether the app has clips in this voice.
    func hasClips(_ voice: Voice) -> Bool { !(clipsByVoice[voice]?.isEmpty ?? true) }

    func canPlay(_ text: String) -> Bool { source(for: text) != nil }

    var syntheticClipCount: Int { clips.values.filter { ClipKind($0.source) == .synthetic }.count }
    /// A person's recordings in the chosen voice: native, or changed into this voice.
    var nativeClipCount: Int { clips.values.filter { ClipKind($0.source) != .synthetic }.count }
    var hasAnyAudio: Bool { georgianVoice != nil || !clips.isEmpty }

    func isPlaying(_ text: String) -> Bool {
        if case .playing(let t, _) = state { return t == text }
        return false
    }

    /// Plays `text`; `voice` picks a voice just this once (the samples on the voice picker).
    func play(_ text: String, slow: Bool? = nil, voice: Voice? = nil) {
        stop()
        guard let source = source(for: text, voice: voice) else { return }
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
        playingVoice = voice ?? self.voice
        state = .playing(text: text, source: source)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        player?.stop()
        player = nil
        timer?.invalidate()
        timer = nil
        state = .idle
        playingVoice = nil
        progress = 0
    }

    fileprivate func finished() {
        timer?.invalidate()
        timer = nil
        progress = 1
        state = .idle
        playingVoice = nil
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
        /// "synthetic", "native" or "converted".
        let source: String
    }

    let version: Int
    let voice: String?
    let clips: [String: Clip]

    static func load(from bundle: Bundle, name: String = "audio") -> AudioIndex? {
        let url = bundle.url(forResource: name, withExtension: "json")
            ?? bundle.url(forResource: name, withExtension: "json", subdirectory: "Audio")
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(AudioIndex.self, from: data)
    }
}
