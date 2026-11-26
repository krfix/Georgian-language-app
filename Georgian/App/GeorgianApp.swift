import SwiftData
import SwiftUI

@main
struct GeorgianApp: App {
    @State private var app = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                switch app.state {
                case .ready(let store, let audio):
                    RootView()
                        .id(app.language)
                        .environment(\.locale, app.language.locale)
                        .environment(store)
                        .environment(audio)
                        .environment(app)
                        .modelContainer(app.container!)
                case .failed(let problem):
                    StartupProblemView(problem: problem, retry: { app.start() }, startFresh: { app.startFresh() })
                case .loading:
                    Palette.background.ignoresSafeArea()
                }
            }
            .preferredColorScheme(app.colorScheme)
            .tint(Palette.pomegranate)
            .onAppear { app.start() }
            .onChange(of: scenePhase) { _, phase in
                // Each time Ara comes to the front: the reminder's next two weeks.
                if phase == .active, case .ready(let store, _) = app.state { store.refreshReminders() }
            }
        }
    }
}

/// Opens the course and the saved progress once, and holds what the screens share.
@MainActor @Observable
final class AppModel {
    enum State {
        case loading
        case ready(LearningStore, AudioService)
        case failed(StartupProblem)
    }

    private(set) var state: State = .loading
    private(set) var container: ModelContainer?
    /// The language the app speaks (English or Polish); changing it reloads the course.
    private(set) var language: AppLanguage = .en

    var colorScheme: ColorScheme? {
        guard case .ready(let store, _) = state else { return nil }
        switch store.profile.appearance {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    func start() {
        if case .ready = state { return }
        let options = LaunchOptions.current
        AppLanguage.use(AppLanguage.stored, save: false)
        language = AppLanguage.current
        let curriculum: Curriculum
        do {
            curriculum = try Curriculum.load(language: language)
        } catch {
            state = .failed(StartupProblem(kind: .course, detail: String(describing: error)))
            return
        }
        do {
            let url: URL? = options.inMemory ? nil : ProgressStore.defaultURL
            if let url, options.resetData { ProgressStore.delete(at: url) }
            let container = try ProgressStore.open(at: url).container
            self.container = container
            let store = LearningStore(curriculum: curriculum, context: container.mainContext)
            if options.seedDemo && store.lessonRecords.isEmpty { store.seedDemo() }
            if options.seedAll { store.completeAllLessons() }
            let audio = AudioService()
            audio.slow = store.profile.slowAudio
            Haptics.enabled = store.profile.hapticsOn
            state = .ready(store, audio)
            store.refreshReminders()
        } catch {
            state = .failed(StartupProblem(kind: .progress, detail: String(describing: error)))
        }
    }

    /// The saved progress can't be opened: keep it aside (never deleted) and start afresh.
    func startFresh() {
        guard case .failed(let problem) = state, problem.kind == .progress else { return }
        do {
            try ProgressStore.setAside(ProgressStore.defaultURL)
        } catch {
            state = .failed(StartupProblem(kind: .progress, detail: String(describing: error)))
            return
        }
        state = .loading
        start()
    }

    /// Switches the app to another language: its own words, the course and the phrasebook.
    /// Progress is kept (it's stored by id, the same in every language); the screens start
    /// again from the top.
    func setLanguage(_ new: AppLanguage) {
        guard new != language, case .ready(let old, let audio) = state, let container else { return }
        do {
            let curriculum = try Curriculum.load(language: new)
            AppLanguage.use(new)
            let store = LearningStore(curriculum: curriculum, context: container.mainContext)
            store.developerMode = old.developerMode
            store.devOpenAllLessons = old.devOpenAllLessons
            store.devQuickPass = old.devQuickPass
            language = new
            state = .ready(store, audio)
            store.refreshReminders()   // the reminder's text in the new language
        } catch {
            // The other language's files are missing: stay in this one.
        }
    }
}

/// Why the app couldn't start.
struct StartupProblem {
    enum Kind { case course, progress }
    let kind: Kind
    /// The technical message, shown small (useful when the learner writes to us).
    let detail: String
}

/// Shown only if the course or the saved progress can't be opened. For progress there's a
/// way out that loses nothing: the old file is kept aside, and the app starts afresh.
struct StartupProblemView: View {
    let problem: StartupProblem
    let retry: () -> Void
    let startFresh: () -> Void
    @State private var confirmFresh = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ParrotView(height: 120, mood: .think, bobbing: false)
                Text(problem.kind == .progress ? tr("Ara couldn't open your saved progress") : tr("Ara couldn't load its lessons"))
                    .font(.title2Bold)
                    .multilineTextAlignment(.center)
                Text(problem.kind == .progress
                     ? tr("Nothing has been deleted. Try again first. If it keeps happening, you can start with fresh progress: your old progress stays kept aside on this iPhone, so a later update can bring it back.")
                     : tr("Try again. If it keeps happening, please reinstall Ara from the App Store or TestFlight."))
                    .font(.calloutRounded)
                    .foregroundStyle(Palette.inkSoft)
                    .multilineTextAlignment(.center)
                Button(tr("Try again"), action: retry)
                    .buttonStyle(ChunkyButtonStyle())
                if problem.kind == .progress {
                    Button(tr("Start with fresh progress")) { confirmFresh = true }
                        .font(.headlineRounded)
                        .foregroundStyle(Palette.pomegranate)
                        .padding(.top, 4)
                }
                Text(tr("Please tell us at {0}, with the details below.", "ara.learn.app@gmail.com"))
                    .font(.calloutRounded)
                    .foregroundStyle(Palette.inkSoft)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
                Text(problem.detail)
                    .font(.caption.monospaced())
                    .foregroundStyle(Palette.inkSoft)
                    .multilineTextAlignment(.leading)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background.ignoresSafeArea())
        .confirmationDialog(tr("Start with fresh progress?"), isPresented: $confirmFresh, titleVisibility: .visible) {
            Button(tr("Start fresh, keep the old progress aside"), role: .destructive, action: startFresh)
            Button(tr("Cancel"), role: .cancel) {}
        } message: {
            Text(tr("Your current progress is moved aside on this iPhone, not deleted."))
        }
    }
}
