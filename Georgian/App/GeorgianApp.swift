import SwiftData
import SwiftUI

@main
struct GeorgianApp: App {
    @State private var app = AppModel()

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
                case .failed(let message):
                    StartupProblemView(message: message) { app.start() }
                case .loading:
                    Palette.background.ignoresSafeArea()
                }
            }
            .preferredColorScheme(app.colorScheme)
            .tint(Palette.pomegranate)
            .onAppear { app.start() }
        }
    }
}

/// Opens the course and the saved progress once, and holds what the screens share.
@MainActor @Observable
final class AppModel {
    enum State {
        case loading
        case ready(LearningStore, AudioService)
        case failed(String)
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
        do {
            let curriculum = try Curriculum.load(language: language)
            let schema = Schema(versionedSchema: GeorgianSchemaV2.self)
            let config: ModelConfiguration
            if options.inMemory {
                config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            } else {
                let url = URL.applicationSupportDirectory.appending(path: "Georgian.store")
                if options.resetData {
                    for suffix in ["", "-shm", "-wal"] {
                        try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + suffix))
                    }
                }
                try? FileManager.default.createDirectory(at: URL.applicationSupportDirectory, withIntermediateDirectories: true)
                config = ModelConfiguration(schema: schema, url: url)
            }
            let container: ModelContainer
            do {
                container = try ModelContainer(for: schema, migrationPlan: GeorgianMigrationPlan.self, configurations: config)
            } catch {
                // If the planned step fails, let SwiftData infer it (adding a model is a
                // lightweight change it can work out by itself) rather than refuse to open.
                container = try ModelContainer(for: schema, configurations: config)
            }
            self.container = container
            let store = LearningStore(curriculum: curriculum, context: container.mainContext)
            if options.seedDemo && store.lessonRecords.isEmpty { store.seedDemo() }
            let audio = AudioService()
            audio.slow = store.profile.slowAudio
            Haptics.enabled = store.profile.hapticsOn
            state = .ready(store, audio)
        } catch {
            state = .failed(error.localizedDescription)
        }
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
            let p = store.profile
            if p.remindersOn {
                Task { _ = await ReminderScheduler.enable(hour: p.reminderHour, minute: p.reminderMinute, name: p.name) }
            }
        } catch {
            // The other language's files are missing: stay in this one.
        }
    }
}

/// Shown only if the course or the saved progress can't be opened.
struct StartupProblemView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            ParrotView(height: 120, mood: .think, bobbing: false)
            Text(tr("Something went wrong opening the app"))
                .font(.title2Bold)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.calloutRounded)
                .foregroundStyle(Palette.inkSoft)
                .multilineTextAlignment(.center)
            Button(tr("Try again"), action: retry)
                .buttonStyle(ChunkyButtonStyle())
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background.ignoresSafeArea())
    }
}
